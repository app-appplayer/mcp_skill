/// Error Aggregator - Aggregates multiple step errors into procedure errors.
library;

import '../exceptions/exceptions.dart';
import 'recovery_strategy.dart';

/// Aggregates multiple step errors into a procedure-level error.
class ErrorAggregator {
  /// Collected step errors.
  final List<StepError> stepErrors = [];

  /// Add a step error.
  void addStepError(StepError error) {
    stepErrors.add(error);
  }

  /// Whether any errors have been collected.
  bool get hasErrors => stepErrors.isNotEmpty;

  /// Whether any fatal (unrecovered) errors exist.
  bool get hasFatalErrors => stepErrors.any((e) => !e.recovered);

  /// Aggregate collected errors into a single procedure error.
  ProcedureError aggregate() {
    if (stepErrors.isEmpty) {
      throw StateError('No errors to aggregate');
    }

    final fatalErrors = stepErrors.where((e) => !e.recovered);
    final primaryError =
        fatalErrors.isNotEmpty ? fatalErrors.first : stepErrors.first;

    return ProcedureError(
      primaryError: primaryError,
      allErrors: List.unmodifiable(stepErrors),
      message: _buildAggregateMessage(),
    );
  }

  String _buildAggregateMessage() {
    if (stepErrors.length == 1) {
      return stepErrors.first.message;
    }
    return 'Procedure failed with ${stepErrors.length} errors. '
        'Primary: ${stepErrors.first.message}';
  }
}

/// Error information for a single step.
class StepError {
  /// The step ID that failed.
  final String stepId;

  /// The exception that occurred.
  final SkillException exception;

  /// Whether the error was recovered from.
  final bool recovered;

  /// The recovery result (if recovery was attempted).
  final RecoveryResult? recoveryResult;

  StepError({
    required this.stepId,
    required this.exception,
    required this.recovered,
    this.recoveryResult,
  });

  /// The error message.
  String get message => exception.message;
}

/// Aggregated procedure-level error.
class ProcedureError {
  /// The primary (first fatal) error.
  final StepError primaryError;

  /// All errors encountered.
  final List<StepError> allErrors;

  /// Aggregate error message.
  final String message;

  ProcedureError({
    required this.primaryError,
    required this.allErrors,
    required this.message,
  });
}
