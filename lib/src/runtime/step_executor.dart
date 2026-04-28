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
import '../evaluation/rubric.dart';
import '../evaluation/rubric_engine.dart';
import '../evaluation/measurement_extractor.dart';

/// Executes individual procedure steps.
class StepExecutor {
  /// Skill ports for external access.
  final SkillPorts ports;

  /// Expression evaluator callback.
  final ExpressionEvaluator? expressionEvaluator;

  /// Rubric evaluation engine.
  final RubricEvaluationEngine? rubricEngine;

  /// Rubric registry for looking up rubrics.
  final RubricRegistry? rubricRegistry;

  /// Claim extractor.
  late final ClaimExtractor _claimExtractor;

  /// Measurement extractor registry.
  late final MeasurementExtractorRegistry _extractorRegistry;

  StepExecutor({
    required this.ports,
    this.expressionEvaluator,
    this.rubricEngine,
    this.rubricRegistry,
    ClaimExtractor? claimExtractor,
    MeasurementExtractorRegistry? extractorRegistry,
  }) {
    _claimExtractor = claimExtractor ??
        ClaimExtractor(
          llmPort: ports.llm,
          workspaceId: 'default',
        );
    _extractorRegistry = extractorRegistry ??
        MeasurementExtractorRegistry(
          llmPort: ports.llm,
          retrievalPort: ports.retrieval,
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
                parameters: {},
              ))
          .toList(),
    );

    final response = await ports.llm.complete(request);

    return StepResult(
      stepId: step.id,
      result: response.content,
      claims: await _claimExtractor.extract(response.content),
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
    final retrievalPort = ports.retrieval;
    if (retrievalPort == null) {
      throw UnsupportedActionException(
          'retrieve requires RetrievalPort to be configured');
    }

    final query = _interpolate(action.query ?? '', context, previousResults);
    final filters =
        _interpolateMap(action.filters ?? {}, context, previousResults);

    final result = await retrievalPort.queryKnowledge(
      query,
      retrieverId: action.retrieverRef ?? 'default',
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
    // Gather candidate claims from previous steps.
    final claimsToValidate = <Claim>[];
    for (final result in previousResults.values) {
      claimsToValidate.addAll(result.claims);
    }

    final claimsPort = ports.claims;
    if (claimsPort == null) {
      // Graceful fallback — without a claims port, validation passes.
      return StepResult(
        stepId: step.id,
        result: const {
          'valid': true,
          'passed': true,
          'issues': <Map<String, dynamic>>[],
          'skipped': true,
        },
      );
    }

    final report = await claimsPort.validateClaims(
      claimsToValidate,
      asOf: context.asOf,
      policyVersion: context.policyVersion,
    );

    return StepResult(
      stepId: step.id,
      result: {
        'valid': report.passed,
        'passed': report.passed,
        'issues': report.issues,
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
    final rubricId = action.rubricRef;
    if (rubricId == null) {
      return StepResult(
        stepId: step.id,
        result: {
          'evaluated': false,
          'reason': 'No rubric reference provided',
        },
      );
    }

    // Get rubric from registry
    final rubric = await _getRubric(rubricId, context);
    if (rubric == null) {
      return StepResult(
        stepId: step.id,
        result: {
          'rubricId': rubricId,
          'evaluated': false,
          'reason': 'Rubric not found: $rubricId',
        },
      );
    }

    // Build evaluation input
    final evaluationInput = await _buildEvaluationInput(
      action.evaluationInput ?? {},
      context,
      previousResults,
      rubric,
    );

    // Get or create the evaluation engine
    final engine = rubricEngine ??
        DefaultRubricEvaluationEngine(extractorRegistry: _extractorRegistry);

    // Execute evaluation
    final result = await engine.evaluate(
      rubric,
      evaluationInput,
      EvaluationContext(asOf: context.asOf),
    );

    // Convert to RubricScore for SkillResult
    final rubricScore = RubricScore(
      rubricId: result.rubricId,
      dimensionScores: Map.fromEntries(
        result.dimensionScores
            .map((d) => MapEntry(d.dimensionId, d.normalizedScore)),
      ),
      totalScore: result.overallScore,
      grade: result.classification,
      findings: _generateFindings(result),
    );

    return StepResult(
      stepId: step.id,
      result: result.toJson(),
      claims: [
        Claim(
          id: 'rubric_result_${step.id}',
          workspaceId: context.workspaceId,
          type: ClaimType.conclusion,
          text:
              'Rubric ${rubric.name} evaluation: ${result.classification} (${result.overallScore.toStringAsFixed(1)})',
          evidenceRefs: const [],
          confidence: 1.0,
          metadata: {'rubricScore': rubricScore.toJson()},
        ),
      ],
    );
  }

  /// Get rubric from registry or inline definition.
  Future<Rubric?> _getRubric(String rubricId, SkillContext context) async {
    // Try to get from registry
    if (rubricRegistry != null) {
      final rubric = await rubricRegistry!.getRubric(rubricId);
      if (rubric != null) return rubric;
    }

    // Try to get from context metadata (inline definition)
    final inlineRubrics =
        context.metadata?['rubrics'] as Map<String, dynamic>?;
    if (inlineRubrics != null && inlineRubrics.containsKey(rubricId)) {
      return Rubric.fromJson(inlineRubrics[rubricId] as Map<String, dynamic>);
    }

    return null;
  }

  /// Build evaluation input from step action config.
  Future<EvaluationInput> _buildEvaluationInput(
    Map<String, dynamic> config,
    SkillContext context,
    Map<String, StepResult> previousResults,
    Rubric rubric,
  ) async {
    // Get artifact reference
    final artifactId = _interpolate(
      config['artifactId']?.toString() ??
          context.inputs['artifactId']?.toString() ??
          'artifact_${DateTime.now().millisecondsSinceEpoch}',
      context,
      previousResults,
    );

    // Build measurements from config or previous steps
    final measurements = <String, DimensionMeasurement>{};

    for (final dimension in rubric.dimensions) {
      // Check if measurement is provided in config
      if (config.containsKey(dimension.id)) {
        final value =
            _interpolate(config[dimension.id].toString(), context, previousResults);
        measurements[dimension.id] = DimensionMeasurement(
          dimensionId: dimension.id,
          value: _parseValue(value, dimension.measurementType),
          confidence: 1.0,
          source:
              MeasurementSource.computed(expression: config[dimension.id].toString()),
        );
      } else if (config['measurements'] != null &&
          (config['measurements'] as Map<String, dynamic>)
              .containsKey(dimension.id)) {
        // Measurement provided in measurements map
        final measurementConfig =
            (config['measurements'] as Map<String, dynamic>)[dimension.id]
                as Map<String, dynamic>;
        measurements[dimension.id] = DimensionMeasurement(
          dimensionId: dimension.id,
          value: measurementConfig['value'],
          confidence:
              (measurementConfig['confidence'] as num?)?.toDouble() ?? 1.0,
          source: MeasurementSource.manual(userId: 'system'),
        );
      }
      // If no measurement provided, extraction will be needed
    }

    return EvaluationInput(
      artifactId: artifactId,
      artifactType: config['artifactType']?.toString() ?? 'unknown',
      measurements: measurements,
      asOf: context.asOf,
    );
  }

  /// Parse value based on measurement type.
  dynamic _parseValue(String value, String measurementType) {
    switch (measurementType) {
      case 'numeric':
        return double.tryParse(value) ?? 0.0;
      case 'boolean':
        return value.toLowerCase() == 'true';
      case 'categorical':
        return value;
      default:
        return value;
    }
  }

  /// Generate findings from evaluation result.
  List<Finding> _generateFindings(EvaluationResult result) {
    final findings = <Finding>[];

    for (final score in result.dimensionScores) {
      if (score.normalizedScore >= 90) {
        findings.add(Finding(
          type: 'strength',
          dimensionId: score.dimensionId,
          description: '${score.dimensionId} rated ${score.level}',
        ));
      } else if (score.normalizedScore < 50) {
        findings.add(Finding(
          type: 'weakness',
          dimensionId: score.dimensionId,
          description: '${score.dimensionId} needs improvement (${score.level})',
          impact: (50 - score.normalizedScore) / 100,
        ));
      }
    }

    return findings;
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

  // Note: _toFactGraphClaim removed - canonical Claim type is used directly.

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
