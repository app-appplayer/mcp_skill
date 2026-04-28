/// Branch Merger - Merge strategies for parallel branch results.
///
/// Defines how results from parallel branches are combined
/// back into a single result.
library;

/// Strategy for merging parallel branch results.
sealed class MergeStrategy {
  const MergeStrategy();
}

/// All branches must succeed; aggregate by type.
class AllSuccessMerge extends MergeStrategy {
  final AggregationType aggregation;
  const AllSuccessMerge({this.aggregation = AggregationType.array});
}

/// N of M branches must succeed.
class AnySuccessMerge extends MergeStrategy {
  final int minSuccessful;
  const AnySuccessMerge({this.minSuccessful = 1});
}

/// Best-effort merge with partial failure handling.
class BestEffortMerge extends MergeStrategy {
  final PartialFailureAction onPartialFailure;
  const BestEffortMerge({
    this.onPartialFailure = PartialFailureAction.includeSuccessful,
  });
}

/// Custom merge via external reference.
class CustomMerge extends MergeStrategy {
  final String mergerRef;
  const CustomMerge(this.mergerRef);
}

/// How to aggregate results from multiple branches.
enum AggregationType {
  /// Collect all outputs into a list.
  array,

  /// Deep-merge result maps.
  mergeObjects,

  /// Use the first branch's result.
  first,

  /// Use the last branch's result.
  last,

  /// Custom aggregation.
  custom,
}

/// Action to take on partial failure in best-effort mode.
enum PartialFailureAction {
  /// Include only successful results.
  includeSuccessful,

  /// Include all results (with errors marked).
  includeAll,

  /// Fail the entire merge.
  fail,
}

/// Status of a branch execution.
enum BranchStatus {
  /// Branch completed successfully.
  success,

  /// Branch failed with an error.
  failed,

  /// Branch was cancelled (e.g., fail-fast).
  cancelled,

  /// Branch timed out.
  timedOut,

  /// Branch was skipped.
  skipped,
}

/// Result from a single parallel branch.
class BranchResult {
  /// Branch identifier.
  final String branchId;

  /// Branch execution status.
  final BranchStatus status;

  /// Branch output (null if failed/cancelled).
  final dynamic output;

  /// Error details (null if successful).
  final String? error;

  /// Branch execution duration.
  final Duration duration;

  /// Branch budget usage.
  final Map<String, dynamic>? budgetUsage;

  const BranchResult({
    required this.branchId,
    required this.status,
    this.output,
    this.error,
    this.duration = Duration.zero,
    this.budgetUsage,
  });

  /// Whether this branch succeeded.
  bool get isSuccess => status == BranchStatus.success;
}

/// Merged result from all parallel branches.
class MergeResult {
  /// Whether the merge was successful.
  final bool success;

  /// Merged output value.
  final dynamic output;

  /// Individual branch results.
  final List<BranchResult> branchResults;

  /// Failure reason (if merge failed).
  final String? failureReason;

  /// Failed branches (if any).
  final List<BranchResult> failedBranches;

  /// Aggregated budget usage across all branches.
  final Map<String, dynamic>? totalUsage;

  const MergeResult({
    required this.success,
    this.output,
    required this.branchResults,
    this.failureReason,
    this.failedBranches = const [],
    this.totalUsage,
  });

  /// Create a successful merge result.
  factory MergeResult.successful({
    required dynamic output,
    required List<BranchResult> branchResults,
    Map<String, dynamic>? totalUsage,
  }) {
    return MergeResult(
      success: true,
      output: output,
      branchResults: branchResults,
      totalUsage: totalUsage,
    );
  }

  /// Create a failed merge result.
  factory MergeResult.failed({
    required String reason,
    required List<BranchResult> branchResults,
    List<BranchResult>? failedBranches,
  }) {
    return MergeResult(
      success: false,
      branchResults: branchResults,
      failureReason: reason,
      failedBranches:
          failedBranches ?? branchResults.where((r) => !r.isSuccess).toList(),
    );
  }
}

/// Merges results from parallel branches.
abstract class BranchMerger {
  /// Merge branch results according to the given strategy.
  Future<MergeResult> merge(
    List<BranchResult> results,
    MergeStrategy strategy,
  );
}

/// Default implementation of branch result merging.
class DefaultBranchMerger implements BranchMerger {
  @override
  Future<MergeResult> merge(
    List<BranchResult> results,
    MergeStrategy strategy,
  ) async {
    return switch (strategy) {
      AllSuccessMerge(:final aggregation) =>
        _mergeAllSuccess(results, aggregation),
      AnySuccessMerge(:final minSuccessful) =>
        _mergeAnySuccess(results, minSuccessful),
      BestEffortMerge(:final onPartialFailure) =>
        _mergeBestEffort(results, onPartialFailure),
      CustomMerge() => _mergeCustom(results),
    };
  }

  MergeResult _mergeAllSuccess(
    List<BranchResult> results,
    AggregationType aggregation,
  ) {
    // Check all succeeded
    final failures = results.where((r) => !r.isSuccess).toList();
    if (failures.isNotEmpty) {
      return MergeResult.failed(
        reason: 'One or more branches failed',
        branchResults: results,
        failedBranches: failures,
      );
    }

    // Aggregate based on type
    final aggregated = _aggregate(results, aggregation);

    return MergeResult.successful(
      output: aggregated,
      branchResults: results,
      totalUsage: _aggregateUsage(results),
    );
  }

  MergeResult _mergeAnySuccess(
    List<BranchResult> results,
    int minSuccessful,
  ) {
    final successful = results.where((r) => r.isSuccess).toList();

    if (successful.length < minSuccessful) {
      return MergeResult.failed(
        reason: 'Only ${successful.length} of $minSuccessful required branches succeeded',
        branchResults: results,
      );
    }

    return MergeResult.successful(
      output: successful.map((r) => r.output).toList(),
      branchResults: results,
      totalUsage: _aggregateUsage(results),
    );
  }

  MergeResult _mergeBestEffort(
    List<BranchResult> results,
    PartialFailureAction onPartialFailure,
  ) {
    final successful = results.where((r) => r.isSuccess).toList();

    if (successful.isEmpty) {
      return MergeResult.failed(
        reason: 'All branches failed',
        branchResults: results,
      );
    }

    return switch (onPartialFailure) {
      PartialFailureAction.includeSuccessful => MergeResult.successful(
          output: successful.map((r) => r.output).toList(),
          branchResults: results,
          totalUsage: _aggregateUsage(results),
        ),
      PartialFailureAction.includeAll => MergeResult.successful(
          output: results.map((r) => r.output).toList(),
          branchResults: results,
          totalUsage: _aggregateUsage(results),
        ),
      PartialFailureAction.fail => results.any((r) => !r.isSuccess)
          ? MergeResult.failed(
              reason: 'Partial failure not allowed',
              branchResults: results,
            )
          : MergeResult.successful(
              output: results.map((r) => r.output).toList(),
              branchResults: results,
              totalUsage: _aggregateUsage(results),
            ),
    };
  }

  MergeResult _mergeCustom(List<BranchResult> results) {
    // Custom merge returns results as-is for external handling
    return MergeResult.successful(
      output: results.map((r) => r.output).toList(),
      branchResults: results,
      totalUsage: _aggregateUsage(results),
    );
  }

  dynamic _aggregate(List<BranchResult> results, AggregationType type) {
    return switch (type) {
      AggregationType.array => results.map((r) => r.output).toList(),
      AggregationType.mergeObjects => _deepMergeObjects(results),
      AggregationType.first =>
        results.isNotEmpty ? results.first.output : null,
      AggregationType.last =>
        results.isNotEmpty ? results.last.output : null,
      AggregationType.custom => results.map((r) => r.output).toList(),
    };
  }

  dynamic _deepMergeObjects(List<BranchResult> results) {
    final merged = <String, dynamic>{};
    for (final result in results) {
      if (result.output is Map<String, dynamic>) {
        _deepMerge(merged, result.output as Map<String, dynamic>);
      }
    }
    return merged;
  }

  void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    for (final entry in source.entries) {
      if (target.containsKey(entry.key) &&
          target[entry.key] is Map<String, dynamic> &&
          entry.value is Map<String, dynamic>) {
        _deepMerge(
          target[entry.key] as Map<String, dynamic>,
          entry.value as Map<String, dynamic>,
        );
      } else {
        target[entry.key] = entry.value; // Last write wins
      }
    }
  }

  Map<String, dynamic> _aggregateUsage(List<BranchResult> results) {
    var totalTokens = 0;
    var totalSteps = 0;
    var totalLlm = 0;
    var totalMcp = 0;
    var maxElapsed = 0;

    for (final result in results) {
      final usage = result.budgetUsage;
      if (usage != null) {
        totalTokens += (usage['tokensUsed'] as int?) ?? 0;
        totalSteps += (usage['stepsExecuted'] as int?) ?? 0;
        totalLlm += (usage['llmCallsMade'] as int?) ?? 0;
        totalMcp += (usage['mcpCallsMade'] as int?) ?? 0;
        final elapsed = (usage['elapsedMs'] as int?) ?? 0;
        if (elapsed > maxElapsed) maxElapsed = elapsed;
      }
    }

    return {
      'tokensUsed': totalTokens,
      'stepsExecuted': totalSteps,
      'llmCallsMade': totalLlm,
      'mcpCallsMade': totalMcp,
      'maxElapsedMs': maxElapsed,
      'branchCount': results.length,
    };
  }
}
