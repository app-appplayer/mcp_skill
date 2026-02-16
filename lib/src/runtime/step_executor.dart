/// Step Executor - Executes individual procedure steps.
///
/// Handles the execution of different step action types including
/// LLM calls, tool invocations, retrieval, and transformations.
library;

import 'skill_context.dart';
import 'skill_result.dart';
import 'procedure_executor.dart';
import 'claim_extractor.dart';
import '../ports/skill_ports.dart';
import '../ports/llm_port.dart';
import '../ports/fact_graph_port.dart' as fg;

/// Executes individual procedure steps.
class StepExecutor {
  /// Skill ports for external access.
  final SkillPorts ports;

  /// Expression evaluator callback.
  final ExpressionEvaluator? expressionEvaluator;

  /// Claim extractor.
  late final ClaimExtractor _claimExtractor;

  StepExecutor({
    required this.ports,
    this.expressionEvaluator,
    ClaimExtractor? claimExtractor,
  }) {
    _claimExtractor = claimExtractor ??
        ClaimExtractor(
          config: const ClaimExtractionConfig(),
          llmPort: ports.llm,
        );
  }

  /// Execute a step.
  Future<StepResult> execute(
    ProcedureStep step,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final action = step.action;

    switch (action.type) {
      case 'llm':
        return await _executeLlm(step, action, context, previousResults);
      case 'tool':
        return await _executeTool(step, action, context, previousResults);
      case 'retrieve':
        return await _executeRetrieve(step, action, context, previousResults);
      case 'transform':
        return await _executeTransform(step, action, context, previousResults);
      case 'validate':
        return await _executeValidate(step, action, context, previousResults);
      case 'rubric':
        return await _executeRubric(step, action, context, previousResults);
      case 'parallel':
        return await _executeParallel(step, action, context, previousResults);
      case 'procedure':
        return await _executeProcedure(step, action, context, previousResults);
      default:
        throw UnsupportedActionException(action.type);
    }
  }

  /// Execute LLM action.
  Future<StepResult> _executeLlm(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final prompt = _interpolate(action.prompt ?? '', context, previousResults);

    final request = LlmRequest(
      messages: [
        if (action.systemPrompt != null)
          LlmMessage(role: 'system', content: action.systemPrompt!),
        LlmMessage(role: 'user', content: prompt),
      ],
      model: action.model,
      temperature: action.temperature,
      maxTokens: action.maxTokens,
      tools: action.tools
          ?.map((t) => LlmTool(
                name: t,
                description: '',
                inputSchema: {},
              ))
          .toList(),
    );

    final response = await ports.llm.complete(request);

    return StepResult(
      stepId: step.id,
      result: response.content,
      claims: _claimExtractor.extract(response.content),
    );
  }

  /// Execute tool action.
  Future<StepResult> _executeTool(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final args = _interpolateMap(action.args ?? {}, context, previousResults);

    final result = await ports.mcp.callTool(
      action.toolRef ?? '',
      args,
    );

    return StepResult(
      stepId: step.id,
      result: result.content,
      toolCalled: action.toolRef,
    );
  }

  /// Execute retrieve action.
  Future<StepResult> _executeRetrieve(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final query = _interpolate(action.query ?? '', context, previousResults);
    final filters =
        _interpolateMap(action.filters ?? {}, context, previousResults);

    final result = await ports.knowledge.query(
      action.retrieverRef ?? 'default',
      query,
      filters: filters,
      maxResults: action.maxResults,
    );

    return StepResult(
      stepId: step.id,
      result: result.passages.map((p) => p.content).join('\n\n'),
      evidenceRefs: result.passages.map((p) => p.sourceUri ?? p.id).toList(),
    );
  }

  /// Execute transform action.
  Future<StepResult> _executeTransform(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    if (expressionEvaluator == null) {
      throw UnsupportedActionException('transform requires expressionEvaluator');
    }

    final result = await expressionEvaluator!(
      action.expression ?? '',
      context,
      previousResults,
    );

    return StepResult(
      stepId: step.id,
      result: result,
    );
  }

  /// Execute validate action.
  Future<StepResult> _executeValidate(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    // Validate claims against FactGraph
    final factGraphPort = ports.factGraph;
    if (factGraphPort == null) {
      return StepResult(
        stepId: step.id,
        result: {'valid': true, 'reason': 'No FactGraph port configured'},
      );
    }

    // Get claims from previous steps to validate
    final claimsToValidate = <Claim>[];
    for (final result in previousResults.values) {
      claimsToValidate.addAll(result.claims);
    }

    // Convert to FactGraph claims format
    final fgClaims = claimsToValidate.map((c) => _toFactGraphClaim(c)).toList();

    final validationResult = await factGraphPort.validateClaims(
      fgClaims,
      asOf: context.asOf,
      policyVersion: context.policyVersion,
    );

    return StepResult(
      stepId: step.id,
      result: {
        'valid': validationResult.passed,
        'passed': validationResult.passed,
        'issues': validationResult.issues.map((i) => i.toJson()).toList(),
      },
    );
  }

  /// Execute rubric action.
  Future<StepResult> _executeRubric(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    // Rubric evaluation would be handled by RubricEvaluationEngine
    // For now, return a placeholder
    return StepResult(
      stepId: step.id,
      result: {
        'rubricId': action.rubricRef,
        'evaluated': false,
        'reason': 'Rubric evaluation engine not configured',
      },
    );
  }

  /// Execute parallel action.
  Future<StepResult> _executeParallel(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final parallelActions = action.parallel ?? [];
    if (parallelActions.isEmpty) {
      return StepResult(stepId: step.id, result: []);
    }

    final futures = parallelActions.map((subAction) async {
      final subStep = ProcedureStep(
        id: '${step.id}_${subAction.type}',
        order: 0,
        name: subAction.type,
        action: subAction,
      );
      return await execute(subStep, context, previousResults);
    });

    final results = await Future.wait(futures);

    return StepResult(
      stepId: step.id,
      result: results.map((r) => r.result).toList(),
      claims: results.expand((r) => r.claims).toList(),
      evidenceRefs: results.expand((r) => r.evidenceRefs).toList(),
    );
  }

  /// Execute sub-procedure action.
  Future<StepResult> _executeProcedure(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    // Sub-procedure execution would be handled by ProcedureExecutor
    // This would require access to the procedure registry
    return StepResult(
      stepId: step.id,
      result: {
        'procedureRef': action.procedureRef,
        'executed': false,
        'reason': 'Sub-procedure execution not implemented',
      },
    );
  }

  /// Convert internal Claim to FactGraph Claim.
  fg.Claim _toFactGraphClaim(Claim claim) {
    return fg.Claim(
      id: claim.id,
      content: claim.text,
      claimType: claim.type.name,
      confidence: claim.confidence,
      evidenceRefs: claim.evidenceRefs,
      metadata: claim.metadata,
    );
  }

  /// Interpolate template string with context values.
  String _interpolate(
    String template,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) {
    var result = template;

    // Replace inputs: ${inputs.xxx}
    final inputRegex = RegExp(r'\$\{inputs\.(\w+)\}');
    result = result.replaceAllMapped(inputRegex, (match) {
      final key = match.group(1)!;
      return context.inputs[key]?.toString() ?? '';
    });

    // Replace step results: ${steps.xxx.result}
    final stepRegex = RegExp(r'\$\{steps\.(\w+)\.result\}');
    result = result.replaceAllMapped(stepRegex, (match) {
      final stepId = match.group(1)!;
      return previousResults[stepId]?.result?.toString() ?? '';
    });

    // Replace context values: ${context.xxx}
    final contextRegex = RegExp(r'\$\{context\.(\w+)\}');
    result = result.replaceAllMapped(contextRegex, (match) {
      final key = match.group(1)!;
      switch (key) {
        case 'request':
          return context.request;
        case 'workspaceId':
          return context.workspaceId;
        case 'asOf':
          return context.asOf.toIso8601String();
        default:
          return context.metadata?[key]?.toString() ?? '';
      }
    });

    return result;
  }

  /// Interpolate map values.
  Map<String, dynamic> _interpolateMap(
    Map<String, dynamic> template,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) {
    return template.map((key, value) {
      if (value is String) {
        return MapEntry(key, _interpolate(value, context, previousResults));
      } else if (value is Map<String, dynamic>) {
        return MapEntry(
            key, _interpolateMap(value, context, previousResults));
      }
      return MapEntry(key, value);
    });
  }
}

/// Exception thrown when an action type is not supported.
class UnsupportedActionException implements Exception {
  /// Action type.
  final String actionType;

  UnsupportedActionException(this.actionType);

  @override
  String toString() => 'UnsupportedActionException: Action type "$actionType" is not supported';
}
