/// Context Builder - Builder pattern for constructing SkillContext.
library;

import 'package:mcp_bundle/mcp_bundle.dart' show ContextBundlePort;
import 'package:mcp_bundle/src/ports/context_bundle_port.dart'
    show ContextBundleRequest;

import 'skill_context.dart';

/// Builder pattern for constructing [SkillContext] instances.
class SkillContextBuilder {
  String _contextId = '';
  String _skillId = '';
  String _runId = '';
  String _traceId = '';
  String? _parentContextId;
  String _request = '';
  String _workspaceId = '';
  DateTime? _asOf;
  Period? _period;
  String? _policyVersion;
  List<String>? _activeSkills;
  Map<String, dynamic> _inputs = {};
  ContextBundle? _contextBundle;
  ExecutionBudget? _budget;
  String? _userId;
  RetryConfig? _retryConfig;
  CacheConfig? _cacheConfig;
  Map<String, dynamic>? _metadata;

  /// Set the context ID.
  SkillContextBuilder contextId(String id) {
    _contextId = id;
    return this;
  }

  /// Set the skill ID.
  SkillContextBuilder skillId(String id) {
    _skillId = id;
    return this;
  }

  /// Set the run ID.
  SkillContextBuilder runId(String id) {
    _runId = id;
    return this;
  }

  /// Set the trace ID.
  SkillContextBuilder traceId(String id) {
    _traceId = id;
    return this;
  }

  /// Set the parent context ID.
  SkillContextBuilder parentContextId(String? id) {
    _parentContextId = id;
    return this;
  }

  /// Set the request.
  SkillContextBuilder request(String req) {
    _request = req;
    return this;
  }

  /// Set the workspace ID.
  SkillContextBuilder workspaceId(String id) {
    _workspaceId = id;
    return this;
  }

  /// Set the as-of timestamp.
  SkillContextBuilder asOf(DateTime time) {
    _asOf = time;
    return this;
  }

  /// Set the period filter.
  SkillContextBuilder period(Period? p) {
    _period = p;
    return this;
  }

  /// Set the policy version.
  SkillContextBuilder policyVersion(String? version) {
    _policyVersion = version;
    return this;
  }

  /// Set active skills.
  SkillContextBuilder activeSkills(List<String>? skills) {
    _activeSkills = skills;
    return this;
  }

  /// Set input parameters.
  SkillContextBuilder inputs(Map<String, dynamic> inputs) {
    _inputs = inputs;
    return this;
  }

  /// Add a single input parameter.
  SkillContextBuilder input(String key, dynamic value) {
    _inputs[key] = value;
    return this;
  }

  /// Set the context bundle.
  SkillContextBuilder contextBundle(ContextBundle? bundle) {
    _contextBundle = bundle;
    return this;
  }

  /// Set the execution budget.
  SkillContextBuilder budget(ExecutionBudget? budget) {
    _budget = budget;
    return this;
  }

  /// Set the user ID.
  SkillContextBuilder userId(String? id) {
    _userId = id;
    return this;
  }

  /// Set retry configuration.
  SkillContextBuilder retryConfig(RetryConfig? config) {
    _retryConfig = config;
    return this;
  }

  /// Set cache configuration.
  SkillContextBuilder cacheConfig(CacheConfig? config) {
    _cacheConfig = config;
    return this;
  }

  /// Set metadata.
  SkillContextBuilder metadata(Map<String, dynamic>? meta) {
    _metadata = meta;
    return this;
  }

  /// Build the SkillContext.
  SkillContext build() {
    return SkillContext(
      contextId: _contextId.isEmpty
          ? 'ctx_${DateTime.now().microsecondsSinceEpoch}'
          : _contextId,
      skillId: _skillId,
      runId: _runId.isEmpty
          ? 'run_${DateTime.now().microsecondsSinceEpoch}'
          : _runId,
      traceId: _traceId.isEmpty
          ? 'trace_${DateTime.now().microsecondsSinceEpoch}'
          : _traceId,
      parentContextId: _parentContextId,
      request: _request,
      workspaceId: _workspaceId,
      asOf: _asOf ?? DateTime.now(),
      period: _period,
      policyVersion: _policyVersion,
      activeSkills: _activeSkills,
      inputs: _inputs,
      contextBundle: _contextBundle,
      budget: _budget,
      userId: _userId,
      retryConfig: _retryConfig,
      cacheConfig: _cacheConfig,
      metadata: _metadata,
    );
  }
}

/// Service that builds SkillContext optionally enriched via a
/// [ContextBundlePort].
///
/// Replaces the legacy `buildFromFactGraph(factGraphPort: dynamic)` helper
/// removed in REDESIGN-PLAN Phase 4. When [contextBundlePort] is null the
/// method returns the builder's raw context (Scenario B); otherwise it
/// asks the port to build a [ContextBundle] and attaches it to the
/// returned context.
class ContextBuildingService {
  /// Build a [SkillContext], optionally enriching it via the supplied
  /// [ContextBundlePort].
  Future<SkillContext> buildFromContextBundle({
    required SkillContextBuilder builder,
    ContextBundlePort? contextBundlePort,
    String? workspaceId,
    String? query,
    DateTime? asOf,
  }) async {
    final baseContext = builder.build();
    if (contextBundlePort == null) return baseContext;

    try {
      final bundle = await contextBundlePort.buildContextBundle(
        ContextBundleRequest(
          workspaceId: workspaceId ?? baseContext.workspaceId,
          query: query ?? baseContext.request,
          asOf: asOf ?? baseContext.asOf,
          period: baseContext.period,
          policyVersion: baseContext.policyVersion,
        ),
      );
      return baseContext.copyWith(contextBundle: bundle);
    } catch (_) {
      // Enrichment is best-effort — on failure return the base context
      // so callers can proceed without fact-graph data.
      return baseContext;
    }
  }
}
