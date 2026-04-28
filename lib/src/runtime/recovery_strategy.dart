/// Recovery Strategy - Step-level failure recovery.
///
/// Implements fallback, cache, and skip recovery strategies
/// for handling step execution failures.
library;

import '../exceptions/exceptions.dart';
import 'skill_context.dart';

/// Step-level context for recovery strategies.
/// Provides step identity and input hash for cache key generation.
class StepContext {
  /// The skill ID.
  final String skillId;

  /// The step ID.
  final String stepId;

  /// Hash of step inputs for cache key generation.
  final String inputHash;

  /// The skill execution context.
  final SkillContext skillContext;

  StepContext({
    required this.skillId,
    required this.stepId,
    required this.inputHash,
    required this.skillContext,
  });
}

/// Recovery strategy for step failures.
abstract class RecoveryStrategy {
  /// Attempt recovery from the given exception.
  Future<RecoveryResult> recover(
    SkillException exception,
    StepContext context,
  );
}

/// Result of a recovery attempt.
class RecoveryResult {
  /// The outcome of the recovery attempt.
  final RecoveryOutcome outcome;

  /// The recovered result value (if recovered).
  final dynamic result;

  /// Human-readable message about the recovery.
  final String? message;

  const RecoveryResult._({
    required this.outcome,
    this.result,
    this.message,
  });

  /// Successfully recovered with a result.
  factory RecoveryResult.recovered(dynamic result, {String? message}) =>
      RecoveryResult._(
        outcome: RecoveryOutcome.recovered,
        result: result,
        message: message,
      );

  /// Step was skipped.
  factory RecoveryResult.skipped({String? message}) => RecoveryResult._(
        outcome: RecoveryOutcome.skipped,
        message: message,
      );

  /// Recovery failed.
  factory RecoveryResult.failed(String message) => RecoveryResult._(
        outcome: RecoveryOutcome.failed,
        message: message,
      );
}

/// Outcome of a recovery attempt.
enum RecoveryOutcome { recovered, skipped, failed }

/// Fallback recovery: try alternative implementations in order.
class FallbackRecovery extends RecoveryStrategy {
  /// Ordered list of fallback operations.
  final List<Future<dynamic> Function(StepContext)> fallbacks;

  FallbackRecovery(this.fallbacks);

  @override
  Future<RecoveryResult> recover(
      SkillException exception, StepContext context) async {
    for (final fallback in fallbacks) {
      try {
        final result = await fallback(context);
        return RecoveryResult.recovered(result, message: 'Used fallback');
      } catch (_) {
        continue;
      }
    }
    return RecoveryResult.failed('All fallbacks exhausted');
  }
}

/// Skip recovery: mark step as skipped and continue.
class SkipRecovery extends RecoveryStrategy {
  /// Default value to use when skipping.
  final dynamic defaultValue;

  SkipRecovery({this.defaultValue});

  @override
  Future<RecoveryResult> recover(
      SkillException exception, StepContext context) async {
    return RecoveryResult.skipped(
      message: 'Step skipped due to: ${exception.message}',
    );
  }
}
