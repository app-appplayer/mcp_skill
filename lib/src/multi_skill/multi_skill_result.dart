/// Multi-Skill Result Types.
///
/// Result types for chain, competition, and parallel execution.
library;

import '../runtime/skill_result.dart';

/// Result from multi-skill execution.
class MultiSkillResult {
  /// The final aggregated result.
  final SkillResult result;

  /// Individual results from each skill.
  final List<SkillResult> individualResults;

  /// Execution mode that was used.
  final String mode;

  /// Total execution duration.
  final Duration totalDuration;

  const MultiSkillResult({
    required this.result,
    required this.individualResults,
    required this.mode,
    required this.totalDuration,
  });
}

/// Result from chain execution.
class ChainResult extends MultiSkillResult {
  /// Ordered chain of results.
  final List<ChainStepResult> chainSteps;

  ChainResult({
    required super.result,
    required super.individualResults,
    required super.totalDuration,
    required this.chainSteps,
  }) : super(mode: 'chain');
}

/// A single step in a chain execution.
class ChainStepResult {
  /// Skill ID that executed.
  final String skillId;

  /// The result from this step.
  final SkillResult result;

  /// Duration of this step.
  final Duration duration;

  /// Inputs that were passed to this step.
  final Map<String, dynamic> inputs;

  const ChainStepResult({
    required this.skillId,
    required this.result,
    required this.duration,
    this.inputs = const {},
  });
}

/// Result from competition execution.
class CompetitionResult extends MultiSkillResult {
  /// The winning skill ID.
  final String winnerId;

  /// All competitor outcomes.
  final List<CompetitorOutcome> outcomes;

  CompetitionResult({
    required super.result,
    required super.individualResults,
    required super.totalDuration,
    required this.winnerId,
    required this.outcomes,
  }) : super(mode: 'competition');
}

/// Outcome of a single competitor in competition mode.
class CompetitorOutcome {
  /// Skill ID.
  final String skillId;

  /// The result.
  final SkillResult? result;

  /// The score assigned.
  final double score;

  /// Whether this competitor won.
  final bool isWinner;

  /// Error if the competitor failed.
  final String? error;

  const CompetitorOutcome({
    required this.skillId,
    this.result,
    required this.score,
    required this.isWinner,
    this.error,
  });
}

/// Result from parallel execution.
class ParallelResult extends MultiSkillResult {
  /// All parallel outcomes.
  final List<ParallelOutcome> outcomes;

  /// Number of successful executions.
  final int successCount;

  /// Number of failed executions.
  final int failureCount;

  ParallelResult({
    required super.result,
    required super.individualResults,
    required super.totalDuration,
    required this.outcomes,
    required this.successCount,
    required this.failureCount,
  }) : super(mode: 'parallel');
}

/// Outcome of a single skill in parallel execution.
class ParallelOutcome {
  /// Skill ID.
  final String skillId;

  /// The result (null if failed).
  final SkillResult? result;

  /// Whether this execution succeeded.
  final bool success;

  /// Execution duration.
  final Duration duration;

  /// Error message if failed.
  final String? error;

  const ParallelOutcome({
    required this.skillId,
    this.result,
    required this.success,
    required this.duration,
    this.error,
  });
}
