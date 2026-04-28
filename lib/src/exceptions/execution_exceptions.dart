/// Exceptions for runtime execution failures.
library;

import 'skill_exception.dart';

/// Base execution exception.
class SkillExecutionException extends SkillException {
  SkillExecutionException(
    String message, {
    String? path,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: 'EXECUTION_ERROR',
          path: path,
          cause: cause,
          stackTrace: stackTrace,
        );
}

/// Step execution failure.
class StepExecutionException extends SkillExecutionException {
  /// The step ID that failed.
  final String stepId;

  /// The step order in the procedure.
  final int stepOrder;

  StepExecutionException(
    this.stepId,
    this.stepOrder,
    String message, {
    Object? cause,
  }) : super(message, path: 'steps[$stepId]', cause: cause);

  @override
  String get code => 'STEP_EXECUTION_ERROR';
}

/// Action execution failure within a step.
class ActionExecutionException extends SkillExecutionException {
  /// The action type that failed.
  final String actionType;

  /// The step ID containing the action.
  final String? stepId;

  ActionExecutionException(
    this.actionType,
    String message, {
    this.stepId,
    Object? cause,
  }) : super(message, cause: cause);

  @override
  String get code => 'ACTION_EXECUTION_ERROR';
}

/// Unsupported action type.
class UnsupportedActionException extends SkillExecutionException {
  /// The unsupported action type.
  final String actionType;

  UnsupportedActionException(this.actionType)
      : super('Action type "$actionType" is not supported');

  @override
  String get code => 'UNSUPPORTED_ACTION';
}

/// Operation timeout.
class SkillTimeoutException extends SkillExecutionException {
  /// The timeout duration that was exceeded.
  final Duration timeout;

  /// The operation that timed out.
  final String operation;

  SkillTimeoutException(this.operation, this.timeout)
      : super(
            'Operation $operation timed out after ${timeout.inMilliseconds}ms');

  @override
  String get code => 'TIMEOUT';

  @override
  bool get isRetryable => true;

  @override
  Duration get retryDelay => const Duration(seconds: 1);
}

/// Budget exceeded (tokens, calls, duration).
class BudgetExceededException extends SkillExecutionException {
  /// The type of budget that was exceeded ('tokens', 'calls', 'duration').
  final String budgetType;

  /// The budget limit.
  final int limit;

  /// The actual value that exceeded the limit.
  final int actual;

  BudgetExceededException(this.budgetType, this.limit, this.actual)
      : super('$budgetType budget exceeded: $actual > $limit');

  @override
  String get code => 'BUDGET_EXCEEDED';
}

/// Quality gate failure.
class QualityGateException extends SkillExecutionException {
  /// The quality gate ID that failed.
  final String gateId;

  QualityGateException(this.gateId, String? message)
      : super(message ?? 'Quality gate $gateId failed');

  @override
  String get code => 'QUALITY_GATE_FAILED';
}
