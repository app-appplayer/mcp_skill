/// Multi-Skill Execution Types.
///
/// Configuration types for chain, competition, and parallel execution modes.
library;

/// Configuration for multi-skill execution.
class MultiSkillConfig {
  /// Execution mode.
  final MultiSkillMode mode;

  /// Skills to execute.
  final List<SkillRef> skills;

  /// Chain-specific configuration.
  final ChainConfig? chainConfig;

  /// Competition-specific configuration.
  final CompetitionConfig? competitionConfig;

  /// Parallel-specific configuration.
  final ParallelConfig? parallelConfig;

  /// Overall timeout for multi-skill execution.
  final Duration? timeout;

  /// Error handling strategy.
  final MultiSkillErrorStrategy errorStrategy;

  const MultiSkillConfig({
    required this.mode,
    required this.skills,
    this.chainConfig,
    this.competitionConfig,
    this.parallelConfig,
    this.timeout,
    this.errorStrategy = MultiSkillErrorStrategy.failFast,
  });
}

/// Multi-skill execution modes.
enum MultiSkillMode {
  /// Sequential execution with output passing.
  chain,

  /// Parallel execution with best result selection.
  competition,

  /// Parallel execution with result aggregation.
  parallel,
}

/// Reference to a skill for multi-skill execution.
class SkillRef {
  /// Skill ID.
  final String skillId;

  /// Specific version (optional).
  final String? version;

  /// Input overrides for this skill.
  final Map<String, dynamic>? inputOverrides;

  /// Condition for including this skill.
  final String? condition;

  const SkillRef({
    required this.skillId,
    this.version,
    this.inputOverrides,
    this.condition,
  });

  factory SkillRef.fromJson(Map<String, dynamic> json) => SkillRef(
        skillId: json['skillId'] as String? ?? '',
        version: json['version'] as String?,
        inputOverrides: json['inputOverrides'] as Map<String, dynamic>?,
        condition: json['condition'] as String?,
      );
}

/// Configuration for chain execution mode.
class ChainConfig {
  /// Output-to-input mappings between skills.
  final List<OutputMapping> outputMappings;

  /// Whether to stop on first failure.
  final bool stopOnFailure;

  const ChainConfig({
    this.outputMappings = const [],
    this.stopOnFailure = true,
  });
}

/// Maps output of one skill to input of the next.
class OutputMapping {
  /// Source expression (from previous skill output).
  final String source;

  /// Target input parameter name.
  final String target;

  /// Optional transform expression.
  final String? transform;

  const OutputMapping({
    required this.source,
    required this.target,
    this.transform,
  });
}

/// Configuration for competition execution mode.
class CompetitionConfig {
  /// Criteria for selecting the winner.
  final SelectionCriteria criteria;

  /// Custom scoring expression (for custom criteria).
  final String? scoringExpression;

  /// Rubric ID for rubric-based scoring.
  final String? rubricId;

  const CompetitionConfig({
    this.criteria = SelectionCriteria.highestConfidence,
    this.scoringExpression,
    this.rubricId,
  });
}

/// Selection criteria for competition mode.
enum SelectionCriteria {
  /// Select skill with highest confidence score.
  highestConfidence,

  /// Select skill with most evidence references.
  mostEvidence,

  /// Select based on rubric evaluation.
  rubricScore,

  /// Custom scoring expression.
  custom,
}

/// Configuration for parallel execution mode.
class ParallelConfig {
  /// Maximum concurrent executions.
  final int maxConcurrency;

  /// Aggregation strategy for combining results.
  final AggregationStrategy aggregation;

  /// Minimum ratio of successful results required.
  final double minSuccessRatio;

  const ParallelConfig({
    this.maxConcurrency = 5,
    this.aggregation = AggregationStrategy.mergeClaims,
    this.minSuccessRatio = 0.5,
  });
}

/// Aggregation strategies for parallel results.
enum AggregationStrategy {
  /// Merge all claims from all skills.
  mergeClaims,

  /// Union all evidence references.
  unionEvidence,

  /// Weighted merge based on confidence.
  weightedMerge,

  /// Custom aggregation.
  custom,
}

/// Error handling strategies for multi-skill execution.
enum MultiSkillErrorStrategy {
  /// Stop on first error.
  failFast,

  /// Continue and collect errors.
  continueOnError,

  /// Use fallback skill on error.
  fallback,
}
