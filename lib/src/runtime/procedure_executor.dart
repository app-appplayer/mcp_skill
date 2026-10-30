/// Procedure Executor - Executes skill procedures with quality gates.
///
/// Handles the execution of procedures within skills, including
/// step ordering, condition evaluation, and quality gate checking.
library;

import '../exceptions/execution_exceptions.dart' show InvalidProcedureException;
import 'claim_extractor.dart' show ClaimExtractionConfig;
import 'default_expression_evaluator.dart';
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

  /// Most iterations any single `loop` step may run, whatever its own
  /// `maxIterations` says.
  final int loopLimit;

  ProcedureExecutor({
    required this.ports,
    this.expressionEvaluator,
    this.loopLimit = 1000,
    ClaimExtractionConfig? claimExtraction,
  }) {
    _stepExecutor = StepExecutor(
      ports: ports,
      expressionEvaluator: expressionEvaluator,
      claimExtraction: claimExtraction,
    );
  }

  /// Execute a procedure.
  ///
  /// The steps run as one forward pass in `order` (bundle spec 03 §3.5.1): a
  /// false `condition` skips the step, `onSuccess` / a `branch` jumps to a
  /// later step, `onFailure` takes over when a step fails, an `output` step
  /// ends the procedure and a `loop` step repeats its nested body.
  Future<SkillResult> execute(
    Procedure procedure,
    SkillContext context,
  ) async {
    final startedAt = DateTime.now();
    final run = _Run(
      budget: context.budget != null ? BudgetTracker(context.budget!) : null,
    );

    final sortedSteps = procedure.steps.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    await _runSteps(sortedSteps, context, run, run.stepResults);

    // Check quality gates
    await _checkQualityGates(procedure.qualityGates, run.stepResults, context);

    final finishedAt = DateTime.now();

    return SkillResult(
      claims: run.claims,
      evidenceRefs: run.evidenceRefs,
      confidence: _calculateConfidence(run.claims),
      asOf: context.asOf,
      policyVersion: context.policyVersion,
      metadata: ExecutionMetadata(
        skillId: context.activeSkills?.firstOrNull ?? 'unknown',
        skillVersion: '1.0.0',
        procedureId: procedure.id,
        startedAt: startedAt,
        finishedAt: finishedAt,
        duration: finishedAt.difference(startedAt),
        stepsExecuted: run.stepsExecuted,
        toolsCalled: run.toolsCalled,
      ),
      output: run.output,
    );
  }

  /// Runs [steps] once, front to back. Results are written to [results].
  Future<void> _runSteps(
    List<ProcedureStep> steps,
    SkillContext context,
    _Run run,
    Map<String, StepResult> results,
  ) async {
    var index = 0;
    while (index < steps.length && !run.ended) {
      final step = steps[index];

      // Enforce budget before entering a step. `assertNotExpired` throws
      // BudgetExceededException when the wall-clock budget is exhausted;
      // `incrementStep` throws when step count would exceed the budget.
      run.budget?.assertNotExpired();
      run.budget?.incrementStep();

      if (step.condition != null &&
          !await _evaluateCondition(step.condition!, context, results)) {
        index += 1;
        continue;
      }

      try {
        final result = step.action.type == 'loop'
            ? await _executeLoop(step, context, run, results)
            : await _stepExecutor.execute(step, context, results);

        results[step.id] = result;
        run.stepsExecuted += 1;
        run.claims.addAll(result.claims);
        run.evidenceRefs.addAll(result.evidenceRefs);
        if (result.toolCalled != null) run.toolsCalled.add(result.toolCalled!);
        run.lastResult = result;

        if (result.metadata?['end'] == true) {
          run.ended = true;
          run.output = result.result;
          return;
        }
        if (run.ended) return;

        final target =
            result.metadata?['goto'] as String? ?? step.onSuccess;
        index = target == null
            ? index + 1
            : _forwardIndex(steps, index, target, step.id);
      } on InvalidProcedureException {
        rethrow;
      } catch (e) {
        if (step.onFailure == null) rethrow;
        index = _forwardIndex(steps, index, step.onFailure!, step.id);
      }
    }
  }

  /// Index of the step named [target], which must come after [from].
  int _forwardIndex(
    List<ProcedureStep> steps,
    int from,
    String target,
    String stepId,
  ) {
    final to = steps.indexWhere((s) => s.id == target);
    if (to < 0) {
      throw InvalidProcedureException('Step "$stepId" continues at unknown step "$target"');
    }
    if (to <= from) {
      throw InvalidProcedureException(
          'Step "$stepId" continues at "$target", which is not a later step');
    }
    return to;
  }

  /// Runs the nested body of a `loop` step once per element (`over`) or
  /// while the `while` condition holds. Each iteration and each nested step
  /// counts against the run budget.
  Future<StepResult> _executeLoop(
    ProcedureStep step,
    SkillContext context,
    _Run run,
    Map<String, StepResult> results,
  ) async {
    final action = step.action;
    final body = action.steps ?? const <ProcedureStep>[];
    final hasOver = action.over != null;
    final hasWhile = action.whileCondition != null;
    if (hasOver == hasWhile) {
      throw InvalidProcedureException(
          'Loop "${step.id}" needs exactly one of "over" and "while"');
    }
    if (hasWhile && action.maxIterations == null) {
      throw InvalidProcedureException('Loop "${step.id}" with "while" needs "maxIterations"');
    }
    final cap = action.maxIterations == null
        ? loopLimit
        : (action.maxIterations! < loopLimit ? action.maxIterations! : loopLimit);
    final name = action.loopVariable ?? 'item';

    List<dynamic> items = const [];
    if (hasOver) {
      final value = await evaluateValue(
          action.over!, expressionEvaluator ?? defaultEvaluator, context, results);
      if (value is! List) {
        throw InvalidProcedureException('Loop "${step.id}": "over" is not a list');
      }
      items = value;
      if (items.length > cap) {
        throw InvalidProcedureException(
            'Loop "${step.id}": ${items.length} iterations exceed the limit $cap');
      }
    }

    final perIteration = <dynamic>[];
    var iteration = 0;
    while (!run.ended) {
      if (hasOver && iteration >= items.length) break;

      final scoped = context.copyWith(metadata: {
        ...?context.metadata,
        'loop': {
          if (hasOver) name: items[iteration],
          'index': iteration,
        },
      });
      if (hasWhile) {
        if (!await _evaluateCondition(action.whileCondition!, scoped, results)) {
          break;
        }
        if (iteration >= cap) {
          throw InvalidProcedureException(
              'Loop "${step.id}" is still running after $cap iterations');
        }
      }

      run.budget?.assertNotExpired();
      run.budget?.incrementStep();

      final scopedResults = Map<String, StepResult>.of(results);
      run.lastResult = null;
      await _runSteps(body, scoped, run, scopedResults);
      perIteration.add(run.lastResult?.result);
      iteration += 1;
    }

    return StepResult(stepId: step.id, result: perIteration);
  }

  /// Evaluate a condition expression (bundle spec 11 §11.8: JavaScript-like
  /// truthiness). A condition that cannot be evaluated is not met.
  Future<bool> _evaluateCondition(
    String condition,
    SkillContext context,
    Map<String, StepResult> stepResults,
  ) async {
    try {
      final result = await (expressionEvaluator ?? defaultEvaluator)(
          condition, context, stepResults);
      return isTruthy(result);
    } catch (_) {
      return false;
    }
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

/// Mutable state of one procedure run.
class _Run {
  _Run({this.budget});

  final BudgetTracker? budget;
  final Map<String, StepResult> stepResults = {};
  final List<Claim> claims = [];
  final List<String> evidenceRefs = [];
  final List<String> toolsCalled = [];
  int stepsExecuted = 0;
  StepResult? lastResult;
  bool ended = false;
  dynamic output;
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
  factory ProcedureStep.fromJson(Map<String, dynamic> json,
      {int defaultOrder = 0}) {
    return ProcedureStep(
      id: json['id'] as String? ?? '',
      order: json['order'] as int? ?? defaultOrder,
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

  /// How an `llm` step extracts claims from its reply: `none`, `rules`,
  /// `llm` or `hybrid`. Without it the host's setting applies.
  final String? extractClaims;

  /// Cases of a `branch` action, tried in order.
  final List<BranchCase>? cases;

  /// Step a `branch` continues at when no case matches.
  final String? defaultTarget;

  /// List expression a `loop` iterates over.
  final String? over;

  /// Condition a `loop` repeats while truthy.
  final String? whileCondition;

  /// Name the current element of a `loop` is bound to (default `item`).
  final String? loopVariable;

  /// Upper bound on the iterations of a `loop`.
  final int? maxIterations;

  /// Body of a `loop`.
  final List<ProcedureStep>? steps;

  /// Value an `output` action returns (expression or templated text).
  final String? value;

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
    this.extractClaims,
    this.cases,
    this.defaultTarget,
    this.over,
    this.whileCondition,
    this.loopVariable,
    this.maxIterations,
    this.steps,
    this.value,
  });

  /// Create from JSON.
  ///
  /// The bundle names the model step `prompt` and may write its text as
  /// `template`, and may name a tool `tool`; the runtime executes `llm` and
  /// reads `prompt` / `toolRef`. Both spellings are accepted (bundle spec 03
  /// §3.5.1).
  factory StepAction.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'unknown';
    return StepAction(
      type: rawType == 'prompt' ? 'llm' : rawType,
      prompt: (json['prompt'] ?? json['template']) as String?,
      systemPrompt: json['systemPrompt'] as String?,
      model: json['model'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['maxTokens'] as int?,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>(),
      toolRef: (json['toolRef'] ?? json['tool']) as String?,
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
      extractClaims: json['extractClaims'] as String?,
      cases: (json['cases'] as List<dynamic>?)
          ?.map((e) => BranchCase.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultTarget: json['default'] as String?,
      over: json['over'] as String?,
      whileCondition: json['while'] as String?,
      loopVariable: json['as'] as String?,
      maxIterations: json['maxIterations'] as int?,
      steps: (json['steps'] as List<dynamic>?)?.indexed
          .map((e) => ProcedureStep.fromJson(
              e.$2 as Map<String, dynamic>,
              defaultOrder: e.$1 + 1))
          .toList(),
      value: json['value']?.toString(),
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
        if (extractClaims != null) 'extractClaims': extractClaims,
        if (cases != null) 'cases': cases!.map((e) => e.toJson()).toList(),
        if (defaultTarget != null) 'default': defaultTarget,
        if (over != null) 'over': over,
        if (whileCondition != null) 'while': whileCondition,
        if (loopVariable != null) 'as': loopVariable,
        if (maxIterations != null) 'maxIterations': maxIterations,
        if (steps != null) 'steps': steps!.map((e) => e.toJson()).toList(),
        if (value != null) 'value': value,
      };
}

/// One case of a `branch` action: when [when] is truthy the procedure
/// continues at the later step [goto].
class BranchCase {
  /// Condition expression.
  final String when;

  /// Id of the step to continue at.
  final String goto;

  const BranchCase({required this.when, required this.goto});

  factory BranchCase.fromJson(Map<String, dynamic> json) => BranchCase(
        when: json['when'] as String? ?? '',
        goto: json['goto'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'when': when, 'goto': goto};
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
