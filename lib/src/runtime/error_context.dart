/// Error Context - Rich error context for debugging and logging.
library;

import '../exceptions/exceptions.dart';
import 'recovery_strategy.dart';

/// Rich error context for debugging.
class ErrorContext {
  /// The skill ID where the error occurred.
  final String skillId;

  /// The procedure ID where the error occurred.
  final String procedureId;

  /// The step ID where the error occurred (if applicable).
  final String? stepId;

  /// Timestamp when the error occurred.
  final DateTime timestamp;

  /// Correlation ID for distributed tracing.
  final String? correlationId;

  /// Input parameters at the time of error.
  final Map<String, dynamic> inputs;

  /// Step results collected before the error.
  final Map<String, dynamic> stepResults;

  /// Steps executed before the error.
  final List<String> executedSteps;

  /// The exception that occurred.
  final SkillException exception;

  ErrorContext({
    required this.skillId,
    required this.procedureId,
    this.stepId,
    required this.timestamp,
    this.correlationId,
    required this.inputs,
    required this.stepResults,
    required this.executedSteps,
    required this.exception,
  });

  /// Serialize to JSON for structured logging.
  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'procedureId': procedureId,
        if (stepId != null) 'stepId': stepId,
        'timestamp': timestamp.toIso8601String(),
        if (correlationId != null) 'correlationId': correlationId,
        'executedSteps': executedSteps,
        'error': {
          'code': exception.code,
          'message': exception.message,
          'path': exception.path,
          'isRetryable': exception.isRetryable,
        },
      };
}

/// Error logging levels.
enum ErrorLogLevel {
  /// Log only fatal errors.
  fatal,

  /// Log all errors.
  error,

  /// Log errors with recovery context.
  debug,

  /// Log everything including retry attempts.
  trace,
}

/// Error logger interface (adapter pattern).
abstract class ErrorLogger {
  /// Log an error with context.
  void logError(ErrorContext context,
      {ErrorLogLevel level = ErrorLogLevel.error});

  /// Log a recovery attempt.
  void logRecovery(ErrorContext context, RecoveryResult result);

  /// Log a retry attempt.
  void logRetry(ErrorContext context, int attempt, Duration delay);
}
