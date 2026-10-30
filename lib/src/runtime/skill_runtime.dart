/// Skill Runtime - Main runtime for executing skills.
///
/// Implements the 7-step execution pipeline as specified in design docs.
library;

import 'package:mcp_bundle/mcp_bundle.dart' show RunRecord, RunStatus;
import 'package:mcp_bundle/src/ports/context_bundle_port.dart'
    show ContextBundleRequest, ContextBudget;

import '../registry/skill_registry.dart';
import '../ports/skill_ports.dart';
import '../exceptions/load_exceptions.dart';
import 'skill_router.dart';
import 'skill_context.dart';
import 'skill_result.dart';
import 'claim_extractor.dart' show ClaimExtractionConfig, ClaimExtractionStrategy;
import 'procedure_executor.dart';
import 'runtime_hooks.dart';

/// Main runtime for executing skills.
///
/// Execution Pipeline (7 steps):
/// 1. Route: Select skill(s) to execute
/// 2. Build Context: Get FactGraph context if available
/// 3. Plan: Determine execution strategy
/// 4. Execute: Run procedures
/// 5. Validate: Check results against validators
/// 6. Persist: Write to FactGraph if available
/// 7. Return: Aggregate and return
class SkillRuntime {
  /// Skill registry for looking up skills.
  final SkillBundleRegistry registry;

  /// Ports for external system access.
  final SkillPorts ports;

  /// Router for skill selection (optional).
  final SkillRouter? router;

  /// Hooks for observability (optional).
  final List<RuntimeHook>? hooks;

  /// How `llm` steps extract claims from a reply. Without it the strategy is
  /// `hybrid`; a host that uses the reply as plain text sets
  /// [ClaimExtractionStrategy.none], which also avoids the extra LLM call. A
  /// step can still name its own with `extractClaims`.
  final ClaimExtractionConfig? claimExtraction;

  SkillRuntime({
    required this.registry,
    required this.ports,
    this.router,
    this.hooks,
    this.claimExtraction,
  });

  /// Execute a skill based on context.
  ///
  /// This is the main entry point that implements the 7-step pipeline.
  Future<SkillResult> run(SkillContext context) async {
    await _notifyHooks((hook) => hook.beforeExecution(context));

    try {
      // Step 1: Route - Select skill(s) to execute
      final selectedSkills = await _route(context);

      // Step 2: Build Context - Get FactGraph context if available
      final enrichedContext = await _buildContext(context);

      // Step 3: Plan - Determine execution strategy
      final plan = await _plan(selectedSkills, enrichedContext);

      // Step 4: Execute - Run procedures
      final rawResults = await _execute(plan, enrichedContext);

      // Step 5: Validate - Check results against validators
      final validatedResults = await _validate(rawResults, enrichedContext);

      // Step 6: Persist - Write to FactGraph if available
      await _persist(validatedResults, enrichedContext);

      // Step 7: Return - Aggregate and return
      final finalResult = _aggregate(validatedResults);

      await _notifyHooks((hook) => hook.afterExecution(context, finalResult));

      return finalResult;
    } catch (e, stackTrace) {
      await _notifyHooks((hook) => hook.onError(context, e, stackTrace));
      rethrow;
    }
  }

  /// Execute a specific procedure directly.
  Future<SkillResult> runProcedure(
    String skillId,
    String procedureId,
    SkillContext context,
  ) async {
    final bundle = await registry.getSkill(skillId);
    if (bundle == null) {
      throw SkillNotFoundException(skillId);
    }

    final defProc = bundle.procedures
        .where((p) => p.id == procedureId)
        .firstOrNull;
    if (defProc == null) {
      throw ProcedureNotFoundException(skillId, procedureId);
    }

    // Convert definition Procedure to runtime Procedure
    final procedure = Procedure.fromJson(defProc.toJson());
    final executor = ProcedureExecutor(ports: ports, claimExtraction: claimExtraction);
    return await executor.execute(procedure, context);
  }

  // ========================================================================
  // STEP 1: ROUTE
  // ========================================================================

  /// Route: Select skill(s) to execute based on context.
  Future<List<String>> _route(SkillContext context) async {
    await _notifyHooks((hook) => hook.onRouting(context));

    // If skills explicitly specified, use those
    if (context.activeSkills != null && context.activeSkills!.isNotEmpty) {
      return context.activeSkills!;
    }

    // Otherwise use router
    if (router != null) {
      final routedSkills = await router!.route(context);
      return routedSkills;
    }

    // Fallback: try to infer from skillId in context
    if (context.skillId.isNotEmpty) {
      return [context.skillId];
    }

    throw SkillRoutingException('No skills selected and no router configured');
  }

  // ========================================================================
  // STEP 2: BUILD CONTEXT
  // ========================================================================

  /// Build Context: Enrich context via [ContextBundlePort] if present.
  Future<SkillContext> _buildContext(SkillContext context) async {
    await _notifyHooks((hook) => hook.onContextBuilding(context));

    // Skip when a context bundle has already been built upstream.
    if (context.contextBundle != null) {
      return context;
    }

    // Scenario B (Skill + LLM + MCP only) — no context bundle port wired.
    final contextBundlePort = ports.contextBundle;
    if (contextBundlePort == null) {
      return context;
    }

    try {
      final request = ContextBundleRequest(
        workspaceId: context.workspaceId,
        query: context.request,
        asOf: context.asOf,
        period: context.period,
        policyVersion: context.policyVersion,
        budget: ContextBudget(
          maxTokens: context.budget?.maxTokens ?? 20000,
          maxNodes: 500,
        ),
      );

      final bundle = await contextBundlePort.buildContextBundle(request);
      return context.copyWith(contextBundle: bundle);
    } catch (e) {
      await _notifyHooks(
        (hook) => hook.onWarning(context, 'Context bundle build failed: $e'),
      );
      return context;
    }
  }

  // ========================================================================
  // STEP 3: PLAN
  // ========================================================================

  /// Plan: Determine execution strategy.
  ///
  /// The strategy is resolved in this precedence order:
  /// 1. `context.metadata['plan_strategy']` — explicit host override.
  /// 2. The first selected skill's `metadata['plan_strategy']` — skill
  ///    authors may declare a preferred strategy.
  /// 3. Default: [ExecutionStrategy.sequential] (legacy behavior).
  Future<ExecutionPlan> _plan(
      List<String> skillIds, SkillContext context) async {
    await _notifyHooks((hook) => hook.onPlanning(context, skillIds));

    final strategy = await _resolveStrategy(skillIds, context);

    return ExecutionPlan(
      skillIds: skillIds,
      strategy: strategy,
    );
  }

  /// Resolve [ExecutionStrategy] from context or skill metadata.
  Future<ExecutionStrategy> _resolveStrategy(
      List<String> skillIds, SkillContext context) async {
    final ctxRaw = context.metadata?['plan_strategy'];
    final ctxStrategy = _parseStrategy(ctxRaw);
    if (ctxStrategy != null) return ctxStrategy;

    if (skillIds.isNotEmpty) {
      final bundle = await registry.getSkill(skillIds.first);
      if (bundle != null) {
        final raw = bundle.extensions?['plan_strategy'];
        final parsed = _parseStrategy(raw);
        if (parsed != null) return parsed;
      }
    }

    return ExecutionStrategy.sequential;
  }

  /// Parse a strategy string into an [ExecutionStrategy]. Returns null when
  /// the value is missing or unrecognized so the caller can fall through to
  /// the next precedence level.
  ExecutionStrategy? _parseStrategy(Object? raw) {
    if (raw is! String) return null;
    switch (raw.toLowerCase()) {
      case 'sequential':
        return ExecutionStrategy.sequential;
      case 'parallel':
        return ExecutionStrategy.parallel;
      case 'fallback':
        return ExecutionStrategy.fallback;
      default:
        return null;
    }
  }

  // ========================================================================
  // STEP 4: EXECUTE
  // ========================================================================

  /// Execute: Run procedures for selected skills.
  ///
  /// Dispatches to the concrete executor per [ExecutionPlan.strategy]:
  /// - [ExecutionStrategy.sequential] runs skills one-by-one (default).
  /// - [ExecutionStrategy.parallel] runs every skill concurrently with
  ///   `Future.wait`; any skill throwing propagates to the caller.
  /// - [ExecutionStrategy.fallback] runs skills sequentially and returns
  ///   at the first successful result; if all fail, the last error is
  ///   rethrown.
  Future<List<SkillResult>> _execute(
      ExecutionPlan plan, SkillContext context) async {
    await _notifyHooks((hook) => hook.onExecutionStart(context));

    switch (plan.strategy) {
      case ExecutionStrategy.sequential:
        return _executeSequential(plan, context);
      case ExecutionStrategy.parallel:
        return _executeParallel(plan, context);
      case ExecutionStrategy.fallback:
        return _executeFallback(plan, context);
    }
  }

  /// Sequential execution: run skills in order, capturing failures as
  /// failure [SkillResult]s (preserves legacy behavior).
  Future<List<SkillResult>> _executeSequential(
      ExecutionPlan plan, SkillContext context) async {
    final results = <SkillResult>[];
    for (final skillId in plan.skillIds) {
      results.add(await _runSkill(skillId, context));
    }
    return results;
  }

  /// Parallel execution: all skills run concurrently. Any thrown exception
  /// surfaces to the caller. Non-throwing failures (missing skill, missing
  /// procedure, handled errors) remain in the result list.
  Future<List<SkillResult>> _executeParallel(
      ExecutionPlan plan, SkillContext context) async {
    if (plan.skillIds.isEmpty) return const <SkillResult>[];
    final futures = plan.skillIds
        .map((skillId) => _runSkill(skillId, context, rethrowOnError: true))
        .toList();
    return await Future.wait(futures, eagerError: true);
  }

  /// Fallback execution: sequential attempts, return the first skill whose
  /// procedure executes without throwing. If every attempt throws, rethrow
  /// the most recent exception preserving its original stack trace.
  Future<List<SkillResult>> _executeFallback(
      ExecutionPlan plan, SkillContext context) async {
    if (plan.skillIds.isEmpty) return const <SkillResult>[];

    Object? lastError;
    StackTrace? lastStack;

    for (final skillId in plan.skillIds) {
      try {
        final result = await _runSkill(skillId, context, rethrowOnError: true);
        return [result];
      } catch (e, stackTrace) {
        lastError = e;
        lastStack = stackTrace;
      }
    }

    // All attempts threw — re-throw the last captured error.
    Error.throwWithStackTrace(
      lastError ?? StateError('Fallback exhausted with no recorded error'),
      lastStack ?? StackTrace.current,
    );
  }

  /// Run a single skill, translating missing skills/procedures into failure
  /// [SkillResult]s. When [rethrowOnError] is true, exceptions raised by the
  /// procedure executor propagate to the caller instead of being wrapped in
  /// a failure result.
  Future<SkillResult> _runSkill(
    String skillId,
    SkillContext context, {
    bool rethrowOnError = false,
  }) async {
    final bundle = await registry.getSkill(skillId);
    if (bundle == null) {
      return SkillResult.failure(
        skillId: skillId,
        error: 'Skill not found: $skillId',
      );
    }

    // The run names the procedure it wants; without one the first runs.
    final wanted = context.procedureId;
    final defProc = wanted == null
        ? bundle.procedures.firstOrNull
        : bundle.procedures.where((p) => p.id == wanted).firstOrNull;
    if (defProc == null) {
      return SkillResult.failure(
        skillId: skillId,
        error: wanted == null
            ? 'No procedures found in skill'
            : 'Procedure $wanted not found in skill $skillId',
      );
    }

    try {
      final procedure = Procedure.fromJson(defProc.toJson());
      final executor = ProcedureExecutor(ports: ports, claimExtraction: claimExtraction);
      return await executor.execute(procedure, context);
    } catch (e, stackTrace) {
      await _notifyHooks((hook) => hook.onError(context, e, stackTrace));
      if (rethrowOnError) rethrow;
      return SkillResult.failure(
        skillId: skillId,
        error: e.toString(),
      );
    }
  }

  // ========================================================================
  // STEP 5: VALIDATE
  // ========================================================================

  /// Validate: Check results against validators.
  Future<List<SkillResult>> _validate(
      List<SkillResult> results, SkillContext context) async {
    await _notifyHooks((hook) => hook.onValidation(context));

    // Validation is handled by quality gates in ProcedureExecutor
    return results;
  }

  // ========================================================================
  // STEP 6: PERSIST
  // ========================================================================

  /// Persist: Write run records via [RunsPort] and claims via [ClaimsPort]
  /// when the corresponding optional ports are configured.
  Future<void> _persist(
      List<SkillResult> results, SkillContext context) async {
    await _notifyHooks((hook) => hook.onPersistence(context));

    final runsPort = ports.runs;
    final claimsPort = ports.claims;
    if (runsPort == null && claimsPort == null) {
      return;
    }

    try {
      for (final result in results) {
        if (!result.success) continue;

        if (runsPort != null) {
          final record = RunRecord(
            id: context.runId,
            workspaceId: context.workspaceId,
            producerId: result.metadata.skillId,
            producerKind: 'skill',
            producerVersion: result.metadata.skillVersion,
            startedAt: result.metadata.startedAt,
            finishedAt: DateTime.now(),
            status: result.success ? RunStatus.completed : RunStatus.failed,
            inputs: context.inputs,
            claimIds: result.claims.map((c) => c.id).toList(),
            evidenceRefs: result.evidenceRefs,
          );
          await runsPort.writeRun(record);
        }

        if (claimsPort != null && result.claims.isNotEmpty) {
          await claimsPort.writeClaims(
            result.claims,
            evidenceRefs: result.evidenceRefs,
          );
        }
      }
    } catch (e) {
      await _notifyHooks(
        (hook) => hook.onWarning(context, 'Run/claim persistence failed: $e'),
      );
    }
  }

  // ========================================================================
  // STEP 7: AGGREGATE
  // ========================================================================

  /// Aggregate: Combine multiple results into final result.
  SkillResult _aggregate(List<SkillResult> results) {
    if (results.isEmpty) {
      return SkillResult.failure(
        skillId: 'unknown',
        error: 'No results to aggregate',
      );
    }

    if (results.length == 1) {
      return results.first;
    }

    // Combine multiple results
    return results.first;
  }

  // ========================================================================
  // HOOKS
  // ========================================================================

  /// Notify all hooks with given callback.
  Future<void> _notifyHooks(
      Future<void> Function(RuntimeHook hook) callback) async {
    if (hooks == null || hooks!.isEmpty) return;

    for (final hook in hooks!) {
      try {
        await callback(hook);
      } catch (_) {
        // Ignore hook errors to not break execution
      }
    }
  }
}

/// Execution plan for selected skills.
class ExecutionPlan {
  final List<String> skillIds;
  final ExecutionStrategy strategy;

  const ExecutionPlan({
    required this.skillIds,
    this.strategy = ExecutionStrategy.sequential,
  });
}

/// Execution strategy.
enum ExecutionStrategy {
  /// Execute skills sequentially.
  sequential,

  /// Execute skills in parallel.
  parallel,

  /// Execute with fallback chain.
  fallback,
}
