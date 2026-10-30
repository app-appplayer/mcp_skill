/// Step Executor - Executes individual procedure steps.
///
/// Handles the execution of different step action types including
/// LLM calls, tool invocations, retrieval, and transformations.
library;

import 'skill_context.dart';
import 'skill_result.dart';
import '../exceptions/execution_exceptions.dart'
    show ActionExecutionException, InvalidProcedureException;
import 'default_expression_evaluator.dart';
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

  /// Expression evaluator callback. Without one the package's own
  /// evaluator is used ([defaultEvaluator]).
  final ExpressionEvaluator? expressionEvaluator;

  ExpressionEvaluator get _eval => expressionEvaluator ?? defaultEvaluator;

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
    ClaimExtractionConfig? claimExtraction,
  }) {
    _claimExtractor = claimExtractor ??
        ClaimExtractor(
          llmPort: ports.llm,
          workspaceId: 'default',
          config: claimExtraction ?? const ClaimExtractionConfig(),
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
      case 'prompt':
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
      case 'branch':
        return await _executeBranch(step, action, context, previousResults);
      case 'output':
        return await _executeOutput(step, action, context, previousResults);
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
    final prompt = await _render(action.prompt ?? '', context, previousResults);

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
      claims: await _extractorFor(step, action).extract(response.content),
    );
  }

  /// The claim extractor for [action]: the host's, unless the step names its
  /// own strategy with `extractClaims` (`none`, `rules`, `llm` or `hybrid`).
  ClaimExtractor _extractorFor(ProcedureStep step, StepAction action) {
    final named = action.extractClaims;
    if (named == null) return _claimExtractor;
    final strategy = switch (named) {
      'none' => ClaimExtractionStrategy.none,
      'rules' => ClaimExtractionStrategy.ruleBased,
      'llm' => ClaimExtractionStrategy.llmBased,
      'hybrid' => ClaimExtractionStrategy.hybrid,
      _ => throw InvalidProcedureException(
          'extractClaims "$named" is not one of none, rules, llm, hybrid',
          stepId: step.id,
        ),
    };
    final base = _claimExtractor.config;
    return ClaimExtractor(
      llmPort: _claimExtractor.llmPort,
      workspaceId: _claimExtractor.workspaceId,
      config: ClaimExtractionConfig(
        strategy: strategy,
        minConfidence: base.minConfidence,
        maxClaims: base.maxClaims,
      ),
    );
  }

  /// Execute tool action.
  Future<StepResult> _executeTool(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final args = await _renderMap(action.args ?? {}, context, previousResults);

    final result = await ports.mcp.callTool(
      action.toolRef ?? '',
      args,
    );

    // An MCP tool reports its own failure as a value with `isError`; that is
    // a failed step (bundle spec 03 §3.5.1), so `onFailure` routes it.
    if (result.isError) {
      throw ActionExecutionException(
        'tool',
        result.errorMessage ?? 'Tool ${action.toolRef} returned an error',
        stepId: step.id,
      );
    }

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

    final query = await _render(action.query ?? '', context, previousResults);
    final filters =
        await _renderMap(action.filters ?? {}, context, previousResults);

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
    final result = await _eval(
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
    final artifactId = await _render(
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
            await _render(config[dimension.id].toString(), context, previousResults);
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

  /// Execute a `branch` action: the first case whose `when` is truthy names
  /// the step to continue at (an expression that fails counts as falsy).
  Future<StepResult> _executeBranch(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    for (final branchCase in action.cases ?? const <BranchCase>[]) {
      dynamic matched;
      try {
        matched = await _eval(branchCase.when, context, previousResults);
      } catch (_) {
        matched = false;
      }
      if (isTruthy(matched)) {
        return StepResult(
          stepId: step.id,
          result: {'taken': branchCase.goto},
          metadata: {'goto': branchCase.goto},
        );
      }
    }
    final fallback = action.defaultTarget;
    return StepResult(
      stepId: step.id,
      result: {'taken': fallback},
      metadata: fallback == null ? null : {'goto': fallback},
    );
  }

  /// Execute an `output` action: evaluates `value` and ends the procedure.
  Future<StepResult> _executeOutput(
    ProcedureStep step,
    StepAction action,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final text = action.value;
    final value = text == null || text.trim().isEmpty
        ? null
        : await evaluateValue(text, _eval, context, previousResults);
    return StepResult(
      stepId: step.id,
      result: value,
      metadata: const {'end': true},
    );
  }

  /// Renders `${...}` templates with the expression language (bundle spec 11).
  Future<String> _render(
    String template,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) =>
      renderTemplate(template, _eval, context, previousResults);

  /// Renders the templates in [template] at any depth of maps and lists; a
  /// string that is exactly one `${...}` keeps the value's type.
  Future<Map<String, dynamic>> _renderMap(
    Map<String, dynamic> template,
    SkillContext context,
    Map<String, StepResult> previousResults,
  ) async {
    final rendered = await renderValue(template, _eval, context, previousResults);
    return Map<String, dynamic>.from(rendered as Map);
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
