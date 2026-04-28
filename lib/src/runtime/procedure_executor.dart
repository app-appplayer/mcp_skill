/// Procedure Executor - Executes skill procedures with quality gates.
///
/// Handles the execution of procedures within skills, including
/// step ordering, condition evaluation, and quality gate checking.
library;

import 'skill_context.dart';
import 'skill_result.dart';
import 'step_executor.dart';
import '../ports/skill_ports.dart';

/// Executes a single procedure.
class ProcedureExecutor {
  /// Skill ports for external access.
  final SkillPorts ports;

  /// Step executor.
  late final StepExecutor _stepExecutor;

  /// Expression evaluator callback.
  final ExpressionEvaluator? expressionEvaluator;

  ProcedureExecutor({
    required this.ports,
    this.expressionEvaluator,
  }) {
    _stepExecutor = StepExecutor(
      ports: ports,
      expressionEvaluator: expressionEvaluator,
    );
  }

  /// Execute a procedure.
  Future<SkillResult> execute(
    Procedure procedure,
    SkillContext context,
  ) async {
    final startedAt = DateTime.now();
    final stepResults = <String, StepResult>{};
    final allClaims = <Claim>[];
    final allEvidenceRefs = <String>[];
    final toolsCalled = <String>[];

    // Sort steps by order
    final sortedSteps = procedure.steps.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    // Build a budget tracker when the context carries a budget. Enforcement
    // happens per step by calling `assertNotExpired` and `incrementStep`.
    final budgetTracker =
        context.budget != null ? BudgetTracker(context.budget!) : null;

    String? nextStepId;
    for (final step in sortedSteps) {
      // Skip if not the next step in flow
      if (nextStepId != null && step.id != nextStepId) continue;

      // Enforce budget before entering a step. `assertNotExpired` throws
      // BudgetExceededException when the wall-clock budget is exhausted;
      // `incrementStep` throws when step count would exceed the budget.
      if (budgetTracker != null) {
        budgetTracker.assertNotExpired();
        budgetTracker.incrementStep();
      }

      // Check condition
      if (step.condition != null) {
        final conditionMet = await _evaluateCondition(
          step.condition!,
          context,
          stepResults,
        );
        if (!conditionMet) {
          nextStepId = null;
          continue;
        }
      }

      // Execute step
      try {
        final result = await _stepExecutor.execute(
          step,
          context,
          stepResults,
        );

        stepResults[step.id] = result;
        allClaims.addAll(result.claims);
        allEvidenceRefs.addAll(result.evidenceRefs);
        if (result.toolCalled != null) toolsCalled.add(result.toolCalled!);

        // Determine next step
        nextStepId = step.onSuccess;
      } catch (e) {
        if (step.onFailure != null) {
          nextStepId = step.onFailure;
        } else {
          rethrow;
        }
      }
    }

    // Check quality gates
    await _checkQualityGates(procedure.qualityGates, stepResults, context);

    final finishedAt = DateTime.now();

    return SkillResult(
      claims: allClaims,
      evidenceRefs: allEvidenceRefs,
      confidence: _calculateConfidence(allClaims),
      asOf: context.asOf,
      policyVersion: context.policyVersion,
      metadata: ExecutionMetadata(
        skillId: context.activeSkills?.firstOrNull ?? 'unknown',
        skillVersion: '1.0.0',
        procedureId: procedure.id,
        startedAt: startedAt,
        finishedAt: finishedAt,
        duration: finishedAt.difference(startedAt),
        stepsExecuted: stepResults.length,
        toolsCalled: toolsCalled,
      ),
    );
  }

  /// Evaluate a condition expression.
  Future<bool> _evaluateCondition(
    String condition,
    SkillContext context,
    Map<String, StepResult> stepResults,
  ) async {
    if (expressionEvaluator != null) {
      final result = await expressionEvaluator!(condition, context, stepResults);
      if (result is bool) return result;
      return result != null;
    }
    // Simple fallback
    return true;
  }

  /// Check quality gates.
  Future<void> _checkQualityGates(
    List<QualityGate>? gates,
    Map<String, StepResult> stepResults,
    SkillContext context,
  ) async {
    if (gates == null || gates.isEmpty) return;

    for (final gate in gates) {
      final passed =
          await _evaluateCondition(gate.condition, context, stepResults);
      if (!passed) {
        switch (gate.onFailure) {
          case QualityGateAction.block:
            throw QualityGateException(gate.id, gate.message);
          case QualityGateAction.warn:
            // Would log warning in production
            break;
          case QualityGateAction.log:
            // Would log info in production
            break;
        }
      }
    }
  }

  /// Calculate overall confidence from claims.
  double _calculateConfidence(List<Claim> claims) {
    if (claims.isEmpty) return 0.0;
    return claims.map((c) => c.confidence).reduce((a, b) => a + b) /
        claims.length;
  }
}

/// Expression evaluator function type.
typedef ExpressionEvaluator = Future<dynamic> Function(
  String expression,
  SkillContext context,
  Map<String, StepResult> stepResults,
);

/// A procedure to execute.
class Procedure {
  /// Procedure ID.
  final String id;

  /// Procedure name.
  final String name;

  /// Procedure description.
  final String? description;

  /// Steps in the procedure.
  final List<ProcedureStep> steps;

  /// Quality gates.
  final List<QualityGate>? qualityGates;

  /// Input schema.
  final Map<String, dynamic>? inputSchema;

  /// Output schema.
  final Map<String, dynamic>? outputSchema;

  const Procedure({
    required this.id,
    required this.name,
    this.description,
    required this.steps,
    this.qualityGates,
    this.inputSchema,
    this.outputSchema,
  });

  /// Create from JSON.
  factory Procedure.fromJson(Map<String, dynamic> json) {
    return Procedure(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => ProcedureStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      qualityGates: (json['qualityGates'] as List<dynamic>?)
          ?.map((e) => QualityGate.fromJson(e as Map<String, dynamic>))
          .toList(),
      inputSchema: json['inputSchema'] as Map<String, dynamic>?,
      outputSchema: json['outputSchema'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'steps': steps.map((e) => e.toJson()).toList(),
        if (qualityGates != null)
          'qualityGates': qualityGates!.map((e) => e.toJson()).toList(),
        if (inputSchema != null) 'inputSchema': inputSchema,
        if (outputSchema != null) 'outputSchema': outputSchema,
      };
}

/// A step in a procedure.
class ProcedureStep {
  /// Step ID.
  final String id;

  /// Step order (for sequential execution).
  final int order;

  /// Step name.
  final String name;

  /// Step description.
  final String? description;

  /// Step action configuration.
  final StepAction action;

  /// Condition expression.
  final String? condition;

  /// Next step ID on success.
  final String? onSuccess;

  /// Next step ID on failure.
  final String? onFailure;

  const ProcedureStep({
    required this.id,
    required this.order,
    required this.name,
    this.description,
    required this.action,
    this.condition,
    this.onSuccess,
    this.onFailure,
  });

  /// Create from JSON.
  factory ProcedureStep.fromJson(Map<String, dynamic> json) {
    return ProcedureStep(
      id: json['id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      action: StepAction.fromJson(json['action'] as Map<String, dynamic>? ?? {}),
      condition: json['condition'] as String?,
      onSuccess: json['onSuccess'] as String?,
      onFailure: json['onFailure'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'name': name,
        if (description != null) 'description': description,
        'action': action.toJson(),
        if (condition != null) 'condition': condition,
        if (onSuccess != null) 'onSuccess': onSuccess,
        if (onFailure != null) 'onFailure': onFailure,
      };
}

/// Action configuration for a step.
class StepAction {
  /// Action type (llm, tool, retrieve, transform, validate, rubric, parallel, procedure).
  final String type;

  /// LLM prompt template.
  final String? prompt;

  /// System prompt.
  final String? systemPrompt;

  /// LLM model.
  final String? model;

  /// Temperature for LLM.
  final double? temperature;

  /// Max tokens for LLM.
  final int? maxTokens;

  /// Available tools for LLM.
  final List<String>? tools;

  /// Tool reference (for tool action).
  final String? toolRef;

  /// Arguments.
  final Map<String, dynamic>? args;

  /// Query (for retrieve action).
  final String? query;

  /// Retriever reference.
  final String? retrieverRef;

  /// Filters (for retrieve action).
  final Map<String, dynamic>? filters;

  /// Max results (for retrieve action).
  final int? maxResults;

  /// Rubric reference (for rubric action).
  final String? rubricRef;

  /// Evaluation input (for rubric action).
  final Map<String, dynamic>? evaluationInput;

  /// Transform expression.
  final String? expression;

  /// Parallel sub-actions.
  final List<StepAction>? parallel;

  /// Sub-procedure reference.
  final String? procedureRef;

  const StepAction({
    required this.type,
    this.prompt,
    this.systemPrompt,
    this.model,
    this.temperature,
    this.maxTokens,
    this.tools,
    this.toolRef,
    this.args,
    this.query,
    this.retrieverRef,
    this.filters,
    this.maxResults,
    this.rubricRef,
    this.evaluationInput,
    this.expression,
    this.parallel,
    this.procedureRef,
  });

  /// Create from JSON.
  factory StepAction.fromJson(Map<String, dynamic> json) {
    return StepAction(
      type: json['type'] as String? ?? 'unknown',
      prompt: json['prompt'] as String?,
      systemPrompt: json['systemPrompt'] as String?,
      model: json['model'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['maxTokens'] as int?,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>(),
      toolRef: json['toolRef'] as String?,
      args: json['args'] as Map<String, dynamic>?,
      query: json['query'] as String?,
      retrieverRef: json['retrieverRef'] as String?,
      filters: json['filters'] as Map<String, dynamic>?,
      maxResults: json['maxResults'] as int?,
      rubricRef: json['rubricRef'] as String?,
      evaluationInput: json['evaluationInput'] as Map<String, dynamic>?,
      expression: json['expression'] as String?,
      parallel: (json['parallel'] as List<dynamic>?)
          ?.map((e) => StepAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      procedureRef: json['procedureRef'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        if (prompt != null) 'prompt': prompt,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (tools != null) 'tools': tools,
        if (toolRef != null) 'toolRef': toolRef,
        if (args != null) 'args': args,
        if (query != null) 'query': query,
        if (retrieverRef != null) 'retrieverRef': retrieverRef,
        if (filters != null) 'filters': filters,
        if (maxResults != null) 'maxResults': maxResults,
        if (rubricRef != null) 'rubricRef': rubricRef,
        if (evaluationInput != null) 'evaluationInput': evaluationInput,
        if (expression != null) 'expression': expression,
        if (parallel != null)
          'parallel': parallel!.map((e) => e.toJson()).toList(),
        if (procedureRef != null) 'procedureRef': procedureRef,
      };
}

/// Quality gate for procedure validation.
class QualityGate {
  /// Gate ID.
  final String id;

  /// Gate name.
  final String name;

  /// Condition expression.
  final String condition;

  /// Message on failure.
  final String? message;

  /// Action on failure.
  final QualityGateAction onFailure;

  const QualityGate({
    required this.id,
    required this.name,
    required this.condition,
    this.message,
    this.onFailure = QualityGateAction.warn,
  });

  /// Create from JSON.
  factory QualityGate.fromJson(Map<String, dynamic> json) {
    return QualityGate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      message: json['message'] as String?,
      onFailure: QualityGateAction.fromString(json['onFailure'] as String?),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'condition': condition,
        if (message != null) 'message': message,
        'onFailure': onFailure.name,
      };
}

/// Quality gate failure actions.
enum QualityGateAction {
  /// Block execution.
  block,

  /// Warn but continue.
  warn,

  /// Log only.
  log;

  static QualityGateAction fromString(String? value) {
    switch (value) {
      case 'block':
        return QualityGateAction.block;
      case 'warn':
        return QualityGateAction.warn;
      case 'log':
        return QualityGateAction.log;
      default:
        return QualityGateAction.warn;
    }
  }
}

/// Exception thrown when a quality gate fails.
class QualityGateException implements Exception {
  /// Gate ID.
  final String gateId;

  /// Error message.
  final String? message;

  QualityGateException(this.gateId, [this.message]);

  @override
  String toString() =>
      'QualityGateException: Gate "$gateId" failed${message != null ? ': $message' : ''}';
}
