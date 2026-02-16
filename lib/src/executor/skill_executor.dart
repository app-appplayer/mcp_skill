/// Skill executor for running skills.
library;

import 'package:mcp_bundle/mcp_bundle.dart' hide StepType, SkillStep;

import '../definition/skill.dart';
import '../definition/step.dart';
import 'execution_context.dart';

/// Executes skills.
class SkillExecutor {
  SkillExecutor({
    this.actionHandlers = const {},
    this.maxSteps = 1000,
    this.timeout,
  });

  /// Registered action handlers.
  final Map<String, ActionHandler> actionHandlers;

  /// Maximum steps to prevent infinite loops.
  final int maxSteps;

  /// Execution timeout.
  final Duration? timeout;

  /// Execute a skill with given inputs.
  Future<ExecutionResult> execute(
    Skill skill,
    Map<String, dynamic> inputs,
  ) async {
    final startTime = DateTime.now();

    // Validate inputs
    final errors = skill.validateInputs(inputs);
    if (errors.isNotEmpty) {
      return ExecutionResult.failure('Input validation failed: ${errors.join(', ')}');
    }

    // Apply defaults
    final effectiveInputs = <String, dynamic>{};
    for (final param in skill.inputs) {
      if (inputs.containsKey(param.name)) {
        effectiveInputs[param.name] = inputs[param.name];
      } else if (param.defaultValue != null) {
        effectiveInputs[param.name] = param.defaultValue;
      }
    }

    // Create execution context
    final context = ExecutionContext(inputs: effectiveInputs);
    final trace = ExecutionTrace();

    try {
      // Execute steps
      final result = await _executeSteps(skill, context, trace);

      final duration = DateTime.now().difference(startTime);
      return ExecutionResult.success(
        result,
        stepResults: context.stepResults,
        duration: duration,
      );
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      return ExecutionResult.failure(
        e.toString(),
        stepResults: context.stepResults,
        duration: duration,
      );
    }
  }

  Future<dynamic> _executeSteps(
    Skill skill,
    ExecutionContext context,
    ExecutionTrace trace,
  ) async {
    if (skill.steps.isEmpty) return null;

    var currentStep = skill.entryStep;
    var stepCount = 0;
    dynamic lastResult;

    while (currentStep != null && stepCount < maxSteps) {
      stepCount++;
      final step = currentStep;

      // Check condition
      if (step.condition != null) {
        final shouldExecute = await _evaluateCondition(
          step.condition!,
          context,
        );
        if (!shouldExecute) {
          // Skip to next
          currentStep = _getNextStep(skill, step, context);
          continue;
        }
      }

      // Record trace
      trace.add(TraceEntry(
        stepId: step.id,
        type: TraceType.start,
        timestamp: DateTime.now(),
        input: context.toMap(),
      ));

      try {
        // Execute step
        lastResult = await _executeStep(step, context);
        context.setStepResult(step.id, lastResult);

        // Record completion
        trace.add(TraceEntry(
          stepId: step.id,
          type: TraceType.complete,
          timestamp: DateTime.now(),
          output: lastResult,
        ));

        // Handle output step
        if (step.type == StepType.output) {
          return lastResult;
        }

        // Get next step
        currentStep = _getNextStep(skill, step, context);
      } catch (e) {
        trace.add(TraceEntry(
          stepId: step.id,
          type: TraceType.error,
          timestamp: DateTime.now(),
          error: e.toString(),
        ));

        // Try error handler
        if (step.onError != null) {
          currentStep = skill.getStep(step.onError!);
        } else {
          rethrow;
        }
      }
    }

    if (stepCount >= maxSteps) {
      throw ExecutionException('Maximum step count ($maxSteps) exceeded');
    }

    return lastResult;
  }

  Future<dynamic> _executeStep(
    SkillStep step,
    ExecutionContext context,
  ) async {
    switch (step.type) {
      case StepType.action:
        return _executeAction(step, context);

      case StepType.transform:
        return _executeTransform(step, context);

      case StepType.setVar:
        return _executeSetVar(step, context);

      case StepType.output:
        return _executeOutput(step, context);

      case StepType.log:
        return _executeLog(step, context);

      case StepType.wait:
        return _executeWait(step, context);

      case StepType.condition:
      case StepType.loop:
      case StepType.parallel:
      case StepType.call:
      case StepType.http:
      case StepType.unknown:
        throw ExecutionException('Step type ${step.type.name} not implemented');
    }
  }

  Future<dynamic> _executeAction(
    SkillStep step,
    ExecutionContext context,
  ) async {
    final actionName = step.config['action'] as String?;
    if (actionName == null) {
      throw ExecutionException('Action step missing action name');
    }

    final handler = actionHandlers[actionName];
    if (handler == null) {
      throw ExecutionException('Unknown action: $actionName');
    }

    // Evaluate arguments
    final args = <String, dynamic>{};
    final configArgs = step.config['arguments'] as Map<String, dynamic>? ?? {};
    for (final entry in configArgs.entries) {
      args[entry.key] = await _evaluateValue(entry.value, context);
    }

    return handler.call(args, context);
  }

  Future<dynamic> _executeTransform(
    SkillStep step,
    ExecutionContext context,
  ) async {
    final expression = step.config['expression'] as String?;
    if (expression == null) {
      throw ExecutionException('Transform step missing expression');
    }

    final result = await _evaluateExpression(expression, context);

    final resultVar = step.config['resultVar'] as String?;
    if (resultVar != null) {
      context.setVariable(resultVar, result);
    }

    return result;
  }

  Future<dynamic> _executeSetVar(
    SkillStep step,
    ExecutionContext context,
  ) async {
    final varName = step.config['name'] as String?;
    final value = step.config['value'];

    if (varName == null) {
      throw ExecutionException('SetVar step missing variable name');
    }

    final evaluated = await _evaluateValue(value, context);
    context.setVariable(varName, evaluated);
    return evaluated;
  }

  Future<dynamic> _executeOutput(
    SkillStep step,
    ExecutionContext context,
  ) async {
    final value = step.config['value'];
    if (value == null) {
      return null;
    }
    return _evaluateValue(value, context);
  }

  Future<void> _executeLog(
    SkillStep step,
    ExecutionContext context,
  ) async {
    // Log step - implementation depends on logging strategy
    // For now, just evaluate the message
    final message = step.config['message'];
    if (message != null) {
      await _evaluateValue(message, context);
    }
  }

  Future<void> _executeWait(
    SkillStep step,
    ExecutionContext context,
  ) async {
    final durationMs = step.config['duration'] as int? ?? 0;
    await Future<void>.delayed(Duration(milliseconds: durationMs));
  }

  Future<bool> _evaluateCondition(
    String expression,
    ExecutionContext context,
  ) async {
    final result = await _evaluateExpression(expression, context);
    if (result is bool) return result;
    if (result == null) return false;
    if (result is num) return result != 0;
    if (result is String) return result.isNotEmpty;
    if (result is List) return result.isNotEmpty;
    return true;
  }

  Future<dynamic> _evaluateExpression(
    String expression,
    ExecutionContext context,
  ) async {
    // Use mcp_bundle expression evaluator
    final lexer = Lexer(expression);
    final tokens = lexer.tokenize();
    final parser = Parser(tokens);
    final ast = parser.parse();

    final evalContext = EvaluationContext.from(
      inputs: context.inputs,
      steps: context.stepResults,
      state: context.variables,
    );

    final evaluator = ExpressionEvaluator(evalContext);
    final result = evaluator.evaluate(ast);

    if (result.success) {
      return result.value;
    } else {
      throw ExecutionException('Expression evaluation failed: ${result.error}');
    }
  }

  Future<dynamic> _evaluateValue(
    dynamic value,
    ExecutionContext context,
  ) async {
    if (value is String && value.startsWith('\${') && value.endsWith('}')) {
      // Expression
      final expr = value.substring(2, value.length - 1);
      return _evaluateExpression(expr, context);
    }
    return value;
  }

  SkillStep? _getNextStep(
    Skill skill,
    SkillStep currentStep,
    ExecutionContext context,
  ) {
    if (currentStep.next.isEmpty) {
      // No explicit next - try sequential
      final currentIndex = skill.steps.indexOf(currentStep);
      if (currentIndex >= 0 && currentIndex < skill.steps.length - 1) {
        return skill.steps[currentIndex + 1];
      }
      return null;
    }

    // Get first next step
    return skill.getStep(currentStep.next.first);
  }
}

/// Handler for skill actions.
typedef ActionHandler = Future<dynamic> Function(
  Map<String, dynamic> args,
  ExecutionContext context,
);

/// Exception during skill execution.
class ExecutionException implements Exception {
  ExecutionException(this.message);

  final String message;

  @override
  String toString() => 'ExecutionException: $message';
}
