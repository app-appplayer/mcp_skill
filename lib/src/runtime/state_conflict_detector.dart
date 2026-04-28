/// State Conflict Detector - Detects conflicting state mutations across parallel branches.
///
/// Ensures correctness when merging state from parallel execution branches
/// by identifying keys modified by multiple branches.
library;

import 'context_types.dart';
import 'parallel_context.dart';

/// Type of state conflict between branches.
enum ConflictType {
  /// Same key modified by multiple branches.
  keyConflict,

  /// Accumulator ordering ambiguity.
  accumulatorOrder,

  /// Shared resource access conflict.
  resourceContention,
}

/// Suggested resolution for a state conflict.
enum ConflictResolution {
  /// Use last branch's value.
  lastWriteWins,

  /// Use first branch's value.
  firstWriteWins,

  /// Sum/merge values.
  aggregate,

  /// Reject parallel execution.
  fail,
}

/// A detected conflict between parallel branches.
class StateConflict {
  /// Type of conflict.
  final ConflictType type;

  /// State key involved.
  final String key;

  /// Branch IDs that conflict.
  final List<String> conflictingBranches;

  /// Suggested resolution (null if manual resolution required).
  final ConflictResolution? resolution;

  const StateConflict({
    required this.type,
    required this.key,
    required this.conflictingBranches,
    this.resolution,
  });

  @override
  String toString() =>
      'StateConflict($type, key: $key, branches: $conflictingBranches)';
}

/// Snapshot of a branch's state mutations.
class StateSnapshot {
  /// Branch identifier.
  final String branchId;

  /// Keys that were modified in this branch.
  final Set<String> modifiedKeys;

  /// Number of accumulated values.
  final int accumulatedCount;

  const StateSnapshot({
    required this.branchId,
    required this.modifiedKeys,
    this.accumulatedCount = 0,
  });
}

/// Report of all detected conflicts.
class ConflictReport {
  /// Whether any conflicts were detected.
  final bool hasConflicts;

  /// List of detected conflicts.
  final List<StateConflict> conflicts;

  /// Whether all conflicts can be auto-resolved.
  final bool canAutoResolve;

  const ConflictReport({
    required this.hasConflicts,
    required this.conflicts,
    required this.canAutoResolve,
  });

  /// Empty report with no conflicts.
  const ConflictReport.empty()
      : hasConflicts = false,
        conflicts = const [],
        canAutoResolve = true;
}

/// Detects conflicting state mutations across parallel branches.
class StateConflictDetector {
  /// Check for conflicts before merge.
  ConflictReport detectConflicts(
    List<BranchContext> branches,
    ContextState parentState,
  ) {
    final conflicts = <StateConflict>[];

    // Build state snapshots from each branch
    final snapshots = branches.map((b) {
      final branchKeys = b.state.toMap().keys.toSet();

      // Modified keys are those that differ from parent
      final modifiedKeys = <String>{};
      for (final key in branchKeys) {
        final branchValue = b.state.get<dynamic>(key);
        final parentValue = parentState.get<dynamic>(key);
        if (branchValue != parentValue) {
          modifiedKeys.add(key);
        }
      }

      return StateSnapshot(
        branchId: b.branchId,
        modifiedKeys: modifiedKeys,
      );
    }).toList();

    // Detect key conflicts (same key modified by multiple branches)
    final keyToBranches = <String, List<String>>{};
    for (final snapshot in snapshots) {
      for (final key in snapshot.modifiedKeys) {
        keyToBranches.putIfAbsent(key, () => []).add(snapshot.branchId);
      }
    }

    for (final entry in keyToBranches.entries) {
      if (entry.value.length > 1) {
        conflicts.add(StateConflict(
          type: ConflictType.keyConflict,
          key: entry.key,
          conflictingBranches: entry.value,
          resolution: _suggestResolution(entry.key),
        ));
      }
    }

    // Detect accumulator ordering conflicts
    final accumulatingBranches = snapshots
        .where((s) => s.accumulatedCount > 0)
        .map((s) => s.branchId)
        .toList();

    if (accumulatingBranches.length > 1) {
      conflicts.add(StateConflict(
        type: ConflictType.accumulatorOrder,
        key: '_accumulator',
        conflictingBranches: accumulatingBranches,
        resolution: ConflictResolution.aggregate,
      ));
    }

    return ConflictReport(
      hasConflicts: conflicts.isNotEmpty,
      conflicts: conflicts,
      canAutoResolve: conflicts.every((c) => c.resolution != null),
    );
  }

  /// Detect conflicts from state snapshots directly.
  ConflictReport detectFromSnapshots(List<StateSnapshot> snapshots) {
    final conflicts = <StateConflict>[];

    final keyToBranches = <String, List<String>>{};
    for (final snapshot in snapshots) {
      for (final key in snapshot.modifiedKeys) {
        keyToBranches.putIfAbsent(key, () => []).add(snapshot.branchId);
      }
    }

    for (final entry in keyToBranches.entries) {
      if (entry.value.length > 1) {
        conflicts.add(StateConflict(
          type: ConflictType.keyConflict,
          key: entry.key,
          conflictingBranches: entry.value,
          resolution: _suggestResolution(entry.key),
        ));
      }
    }

    return ConflictReport(
      hasConflicts: conflicts.isNotEmpty,
      conflicts: conflicts,
      canAutoResolve: conflicts.every((c) => c.resolution != null),
    );
  }

  /// Suggest resolution based on key naming convention.
  ConflictResolution? _suggestResolution(String key) {
    // Temporary keys — last write wins
    if (key.startsWith('_temp_')) {
      return ConflictResolution.lastWriteWins;
    }
    // Counters and sums — aggregate
    if (key.endsWith('_count') || key.endsWith('_sum') || key.endsWith('_total')) {
      return ConflictResolution.aggregate;
    }
    // No automatic resolution available
    return null;
  }

  /// Apply conflict resolutions to merge branch states.
  ContextState resolveConflicts(
    List<BranchContext> branches,
    ContextState parentState,
    ConflictReport report,
  ) {
    final merged = parentState.copy();

    if (!report.hasConflicts) {
      // No conflicts — merge all branch states
      for (final branch in branches) {
        final branchState = branch.state.toMap();
        for (final entry in branchState.entries) {
          merged.set(entry.key, entry.value);
        }
      }
      return merged;
    }

    // Resolve each conflict
    final conflictKeys = report.conflicts.map((c) => c.key).toSet();

    // First, merge non-conflicting keys
    for (final branch in branches) {
      final branchState = branch.state.toMap();
      for (final entry in branchState.entries) {
        if (!conflictKeys.contains(entry.key)) {
          merged.set(entry.key, entry.value);
        }
      }
    }

    // Then resolve conflicting keys
    for (final conflict in report.conflicts) {
      if (conflict.resolution == null) continue;

      switch (conflict.resolution!) {
        case ConflictResolution.lastWriteWins:
          // Use the last branch's value
          final lastBranch = branches.lastWhere(
            (b) => conflict.conflictingBranches.contains(b.branchId),
          );
          final value = lastBranch.state.get<dynamic>(conflict.key);
          if (value != null) merged.set(conflict.key, value);

        case ConflictResolution.firstWriteWins:
          // Use the first branch's value
          final firstBranch = branches.firstWhere(
            (b) => conflict.conflictingBranches.contains(b.branchId),
          );
          final value = firstBranch.state.get<dynamic>(conflict.key);
          if (value != null) merged.set(conflict.key, value);

        case ConflictResolution.aggregate:
          // Sum numeric values
          num total = 0;
          for (final branch in branches) {
            if (conflict.conflictingBranches.contains(branch.branchId)) {
              final value = branch.state.get<dynamic>(conflict.key);
              if (value is num) total += value;
            }
          }
          merged.set(conflict.key, total);

        case ConflictResolution.fail:
          // Leave the parent value unchanged
          break;
      }
    }

    return merged;
  }
}
