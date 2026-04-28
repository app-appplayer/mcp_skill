/// Parallel Context - State isolation for parallel skill execution.
///
/// Provides branch context creation and budget allocation
/// for parallel execution scenarios.
library;

import 'skill_context.dart';
import 'context_types.dart';
import 'shared_budget_tracker.dart';
import 'branch_merger.dart';

/// Configuration for parallel execution.
class ParallelExecutionConfig {
  /// Maximum concurrent branches.
  final int maxBranches;

  /// Budget allocation strategy across branches.
  final BudgetAllocationStrategy budgetAllocation;

  /// Strategy for merging branch results.
  final MergeStrategy mergeStrategy;

  /// Error handling policy for branch failures.
  final ParallelErrorPolicy errorPolicy;

  /// Timeout for the entire parallel block.
  final Duration? timeout;

  const ParallelExecutionConfig({
    this.maxBranches = 5,
    this.budgetAllocation = const EqualSplitAllocation(),
    this.mergeStrategy = const AllSuccessMerge(),
    this.errorPolicy = const FailSlowPolicy(),
    this.timeout,
  });
}

/// Budget allocation strategy for parallel branches.
sealed class BudgetAllocationStrategy {
  const BudgetAllocationStrategy();
}

/// Divide budget evenly among all branches.
class EqualSplitAllocation extends BudgetAllocationStrategy {
  const EqualSplitAllocation();
}

/// Allocate budget proportionally by weight.
class ProportionalAllocation extends BudgetAllocationStrategy {
  final List<double> weights;
  const ProportionalAllocation(this.weights);
}

/// Shared pool allocation — first-come, first-served.
class FirstAvailableAllocation extends BudgetAllocationStrategy {
  const FirstAvailableAllocation();
}

/// Pre-allocated budget reservations per branch.
class ReservedAllocation extends BudgetAllocationStrategy {
  final List<BranchBudget> reservations;
  const ReservedAllocation(this.reservations);
}

/// Pre-allocated budget for a specific branch.
class BranchBudget {
  final String branchId;
  final int maxTokens;
  final Duration maxDuration;
  final int maxLlmCalls;
  final int maxMcpCalls;

  const BranchBudget({
    required this.branchId,
    this.maxTokens = 10000,
    this.maxDuration = const Duration(minutes: 1),
    this.maxLlmCalls = 5,
    this.maxMcpCalls = 20,
  });

  /// Check if cost fits within this branch budget.
  bool canAfford(BudgetCost cost) {
    return cost.estimatedTokens <= maxTokens &&
        cost.llmCalls <= maxLlmCalls &&
        cost.mcpCalls <= maxMcpCalls;
  }
}

/// Error handling policy for parallel execution.
sealed class ParallelErrorPolicy {
  const ParallelErrorPolicy();
}

/// Cancel all branches on first error.
class FailFastPolicy extends ParallelErrorPolicy {
  const FailFastPolicy();
}

/// Wait for all branches, then report errors.
class FailSlowPolicy extends ParallelErrorPolicy {
  const FailSlowPolicy();
}

/// Errors do not affect other branches.
class IsolatePolicy extends ParallelErrorPolicy {
  const IsolatePolicy();
}

/// Retry failed branches with backoff.
class RetryPolicy extends ParallelErrorPolicy {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;

  const RetryPolicy({
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(seconds: 5),
  });
}

/// Specification for a parallel branch.
class BranchSpec {
  /// Branch identifier.
  final String? branchId;

  /// Skill ID to execute in this branch.
  final String? skillId;

  /// Input overrides for this branch.
  final Map<String, dynamic>? inputs;

  const BranchSpec({
    this.branchId,
    this.skillId,
    this.inputs,
  });
}

/// Branch-specific context wrapper with state isolation.
///
/// Each branch gets its own copy of mutable state while sharing
/// immutable data (bundle, config, features) with the parent.
class BranchContext {
  /// Branch identifier.
  final String branchId;

  /// Parent context ID.
  final String parentContextId;

  /// Trace ID (inherited from parent).
  final String traceId;

  /// Isolated state (copy-on-branch).
  final ContextState state;

  /// Input parameters for this branch.
  final Map<String, dynamic> inputs;

  /// Branch-local step results.
  final Map<String, dynamic> previousSteps;

  /// Branch-specific budget.
  final BranchBudget branchBudget;

  /// Reference to the parent context.
  final SkillContext parentContext;

  BranchContext({
    required this.branchId,
    required this.parentContextId,
    required this.traceId,
    required this.state,
    required this.inputs,
    required this.branchBudget,
    required this.parentContext,
    Map<String, dynamic>? previousSteps,
  }) : previousSteps = previousSteps ?? {};

  /// Create a SkillContext for this branch.
  SkillContext toSkillContext() {
    return parentContext.copyWith(
      contextId: branchId,
      parentContextId: parentContextId,
      inputs: inputs,
    );
  }
}

/// Factory for creating isolated branch contexts from a parent context.
class ParallelContextFactory {
  /// Create branch contexts from a parent context.
  List<BranchContext> createBranches({
    required SkillContext parent,
    required List<BranchSpec> branches,
    required ParallelExecutionConfig config,
  }) {
    // Allocate budget across branches
    final budgets = _allocateBudget(
      parentBudget: parent.budget ?? const ExecutionBudget(),
      branches: branches,
      strategy: config.budgetAllocation,
    );

    return branches.asMap().entries.map((entry) {
      final index = entry.key;
      final spec = entry.value;

      return BranchContext(
        branchId: spec.branchId ?? '${parent.runId}_branch_$index',
        parentContextId: parent.contextId,
        traceId: parent.traceId,

        // COPY-ON-BRANCH — deep copy for isolation
        state: ContextState(),

        // Branch-specific inputs
        inputs: spec.inputs ?? Map<String, dynamic>.from(parent.inputs),

        // Branch-specific budget
        branchBudget: budgets[index],

        // Reference to parent
        parentContext: parent,
      );
    }).toList();
  }

  /// Allocate budget across branches based on strategy.
  List<BranchBudget> _allocateBudget({
    required ExecutionBudget parentBudget,
    required List<BranchSpec> branches,
    required BudgetAllocationStrategy strategy,
  }) {
    return switch (strategy) {
      EqualSplitAllocation() => _equalSplit(parentBudget, branches.length),
      ProportionalAllocation(:final weights) =>
        _proportional(parentBudget, branches, weights),
      FirstAvailableAllocation() => _firstAvailable(parentBudget, branches.length),
      ReservedAllocation(:final reservations) => reservations,
    };
  }

  /// Divide budget equally among branches.
  List<BranchBudget> _equalSplit(ExecutionBudget budget, int count) {
    if (count == 0) return [];

    return List.generate(count, (i) {
      return BranchBudget(
        branchId: 'branch_$i',
        maxTokens: budget.maxTokens ~/ count,
        maxDuration: Duration(
          milliseconds: budget.maxDuration.inMilliseconds ~/ count,
        ),
        maxLlmCalls: budget.maxLlmCalls ~/ count,
        maxMcpCalls: budget.maxMcpCalls ~/ count,
      );
    });
  }

  /// Allocate budget proportionally by weight.
  List<BranchBudget> _proportional(
    ExecutionBudget budget,
    List<BranchSpec> branches,
    List<double> weights,
  ) {
    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    if (totalWeight == 0) return _equalSplit(budget, branches.length);

    return List.generate(branches.length, (i) {
      final weight = i < weights.length ? weights[i] / totalWeight : 0.0;
      return BranchBudget(
        branchId: branches[i].branchId ?? 'branch_$i',
        maxTokens: (budget.maxTokens * weight).round(),
        maxDuration: Duration(
          milliseconds: (budget.maxDuration.inMilliseconds * weight).round(),
        ),
        maxLlmCalls: (budget.maxLlmCalls * weight).round(),
        maxMcpCalls: (budget.maxMcpCalls * weight).round(),
      );
    });
  }

  /// Shared pool allocation — each branch gets the full parent budget.
  List<BranchBudget> _firstAvailable(ExecutionBudget budget, int count) {
    return List.generate(count, (i) {
      return BranchBudget(
        branchId: 'branch_$i',
        maxTokens: budget.maxTokens,
        maxDuration: budget.maxDuration,
        maxLlmCalls: budget.maxLlmCalls,
        maxMcpCalls: budget.maxMcpCalls,
      );
    });
  }
}
