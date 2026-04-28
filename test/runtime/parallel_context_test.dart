import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/parallel_context.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/context_types.dart';
import 'package:mcp_skill/src/runtime/shared_budget_tracker.dart';
import 'package:mcp_skill/src/runtime/branch_merger.dart';

/// Helper to create a minimal SkillContext for testing.
SkillContext _createParentContext({
  String contextId = 'ctx-1',
  String skillId = 'skill-1',
  String runId = 'run-1',
  String traceId = 'trace-1',
  Map<String, dynamic> inputs = const {'key': 'value'},
  ExecutionBudget? budget,
}) {
  return SkillContext(
    contextId: contextId,
    skillId: skillId,
    runId: runId,
    traceId: traceId,
    request: 'test request',
    workspaceId: 'ws-1',
    asOf: DateTime(2026, 1, 1),
    inputs: inputs,
    budget: budget ?? const ExecutionBudget(),
  );
}

void main() {
  group('ParallelExecutionConfig', () {
    test('default values are correct', () {
      const config = ParallelExecutionConfig();
      expect(config.maxBranches, 5);
      expect(config.budgetAllocation, isA<EqualSplitAllocation>());
      expect(config.mergeStrategy, isA<AllSuccessMerge>());
      expect(config.errorPolicy, isA<FailSlowPolicy>());
      expect(config.timeout, isNull);
    });

    test('custom values are respected', () {
      final config = ParallelExecutionConfig(
        maxBranches: 10,
        budgetAllocation: const FirstAvailableAllocation(),
        mergeStrategy: const AnySuccessMerge(minSuccessful: 2),
        errorPolicy: const FailFastPolicy(),
        timeout: const Duration(seconds: 30),
      );
      expect(config.maxBranches, 10);
      expect(config.budgetAllocation, isA<FirstAvailableAllocation>());
      expect(config.mergeStrategy, isA<AnySuccessMerge>());
      expect(config.errorPolicy, isA<FailFastPolicy>());
      expect(config.timeout, const Duration(seconds: 30));
    });
  });

  group('BranchSpec', () {
    test('default constructor has all null fields', () {
      const spec = BranchSpec();
      expect(spec.branchId, isNull);
      expect(spec.skillId, isNull);
      expect(spec.inputs, isNull);
    });

    test('custom constructor stores values', () {
      const spec = BranchSpec(
        branchId: 'b1',
        skillId: 's1',
        inputs: {'a': 1},
      );
      expect(spec.branchId, 'b1');
      expect(spec.skillId, 's1');
      expect(spec.inputs, {'a': 1});
    });
  });

  group('BranchBudget', () {
    test('default values', () {
      const budget = BranchBudget(branchId: 'b1');
      expect(budget.branchId, 'b1');
      expect(budget.maxTokens, 10000);
      expect(budget.maxDuration, const Duration(minutes: 1));
      expect(budget.maxLlmCalls, 5);
      expect(budget.maxMcpCalls, 20);
    });

    test('canAfford returns true when cost fits', () {
      const budget = BranchBudget(
        branchId: 'b1',
        maxTokens: 1000,
        maxLlmCalls: 5,
        maxMcpCalls: 10,
      );
      const cost = BudgetCost(
        estimatedTokens: 500,
        llmCalls: 3,
        mcpCalls: 5,
      );
      expect(budget.canAfford(cost), true);
    });

    test('canAfford returns false when tokens exceed limit', () {
      const budget = BranchBudget(
        branchId: 'b1',
        maxTokens: 1000,
        maxLlmCalls: 5,
        maxMcpCalls: 10,
      );
      const cost = BudgetCost(
        estimatedTokens: 1500,
        llmCalls: 1,
        mcpCalls: 1,
      );
      expect(budget.canAfford(cost), false);
    });

    test('canAfford returns false when llmCalls exceed limit', () {
      const budget = BranchBudget(
        branchId: 'b1',
        maxTokens: 10000,
        maxLlmCalls: 3,
        maxMcpCalls: 10,
      );
      const cost = BudgetCost(
        estimatedTokens: 100,
        llmCalls: 5,
        mcpCalls: 1,
      );
      expect(budget.canAfford(cost), false);
    });

    test('canAfford returns false when mcpCalls exceed limit', () {
      const budget = BranchBudget(
        branchId: 'b1',
        maxTokens: 10000,
        maxLlmCalls: 5,
        maxMcpCalls: 3,
      );
      const cost = BudgetCost(
        estimatedTokens: 100,
        llmCalls: 1,
        mcpCalls: 5,
      );
      expect(budget.canAfford(cost), false);
    });

    test('canAfford boundary: exact budget matches cost', () {
      const budget = BranchBudget(
        branchId: 'b1',
        maxTokens: 100,
        maxLlmCalls: 2,
        maxMcpCalls: 3,
      );
      const cost = BudgetCost(
        estimatedTokens: 100,
        llmCalls: 2,
        mcpCalls: 3,
      );
      expect(budget.canAfford(cost), true);
    });
  });

  group('ParallelErrorPolicy', () {
    test('FailFastPolicy is constructable', () {
      const policy = FailFastPolicy();
      expect(policy, isA<ParallelErrorPolicy>());
    });

    test('FailSlowPolicy is constructable', () {
      const policy = FailSlowPolicy();
      expect(policy, isA<ParallelErrorPolicy>());
    });

    test('IsolatePolicy is constructable', () {
      const policy = IsolatePolicy();
      expect(policy, isA<ParallelErrorPolicy>());
    });

    test('RetryPolicy stores custom values', () {
      const policy = RetryPolicy(
        maxRetries: 5,
        baseDelay: Duration(milliseconds: 200),
        maxDelay: Duration(seconds: 10),
      );
      expect(policy.maxRetries, 5);
      expect(policy.baseDelay, const Duration(milliseconds: 200));
      expect(policy.maxDelay, const Duration(seconds: 10));
    });

    test('RetryPolicy uses defaults', () {
      const policy = RetryPolicy();
      expect(policy.maxRetries, 3);
      expect(policy.baseDelay, const Duration(milliseconds: 100));
      expect(policy.maxDelay, const Duration(seconds: 5));
    });
  });

  group('BranchContext', () {
    test('constructor stores all fields', () {
      final parent = _createParentContext();
      final state = ContextState();
      state.set('x', 10);
      final branch = BranchContext(
        branchId: 'b1',
        parentContextId: 'ctx-1',
        traceId: 'trace-1',
        state: state,
        inputs: {'a': 1},
        branchBudget: const BranchBudget(branchId: 'b1'),
        parentContext: parent,
      );
      expect(branch.branchId, 'b1');
      expect(branch.parentContextId, 'ctx-1');
      expect(branch.traceId, 'trace-1');
      expect(branch.state.get<int>('x'), 10);
      expect(branch.inputs, {'a': 1});
      expect(branch.previousSteps, isEmpty);
    });

    test('previousSteps defaults to empty map when null', () {
      final parent = _createParentContext();
      final branch = BranchContext(
        branchId: 'b1',
        parentContextId: 'ctx-1',
        traceId: 'trace-1',
        state: ContextState(),
        inputs: {},
        branchBudget: const BranchBudget(branchId: 'b1'),
        parentContext: parent,
      );
      expect(branch.previousSteps, isA<Map<String, dynamic>>());
      expect(branch.previousSteps, isEmpty);
    });

    test('previousSteps accepts custom map', () {
      final parent = _createParentContext();
      final branch = BranchContext(
        branchId: 'b1',
        parentContextId: 'ctx-1',
        traceId: 'trace-1',
        state: ContextState(),
        inputs: {},
        branchBudget: const BranchBudget(branchId: 'b1'),
        parentContext: parent,
        previousSteps: {'step1': 'result1'},
      );
      expect(branch.previousSteps['step1'], 'result1');
    });

    test('toSkillContext creates a SkillContext from the branch', () {
      final parent = _createParentContext(
        contextId: 'parent-ctx',
        inputs: {'original': true},
      );
      final branch = BranchContext(
        branchId: 'branch-ctx',
        parentContextId: 'parent-ctx',
        traceId: 'trace-1',
        state: ContextState(),
        inputs: {'branch': true},
        branchBudget: const BranchBudget(branchId: 'branch-ctx'),
        parentContext: parent,
      );

      final ctx = branch.toSkillContext();
      expect(ctx.contextId, 'branch-ctx');
      expect(ctx.parentContextId, 'parent-ctx');
      expect(ctx.inputs, {'branch': true});
      // Inherited from parent
      expect(ctx.skillId, 'skill-1');
      expect(ctx.runId, 'run-1');
      expect(ctx.traceId, 'trace-1');
    });
  });

  group('ParallelContextFactory', () {
    late ParallelContextFactory factory;
    late SkillContext parent;

    setUp(() {
      factory = ParallelContextFactory();
      parent = _createParentContext(
        budget: const ExecutionBudget(
          maxTokens: 10000,
          maxDuration: Duration(minutes: 10),
          maxLlmCalls: 20,
          maxMcpCalls: 100,
        ),
      );
    });

    test('createBranches creates correct number of branches', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [
          const BranchSpec(branchId: 'b1'),
          const BranchSpec(branchId: 'b2'),
          const BranchSpec(branchId: 'b3'),
        ],
        config: const ParallelExecutionConfig(),
      );
      expect(branches.length, 3);
    });

    test('createBranches inherits parentContextId and traceId', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [const BranchSpec(branchId: 'b1')],
        config: const ParallelExecutionConfig(),
      );
      expect(branches.first.parentContextId, parent.contextId);
      expect(branches.first.traceId, parent.traceId);
    });

    test('createBranches uses spec branchId when provided', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [const BranchSpec(branchId: 'custom-id')],
        config: const ParallelExecutionConfig(),
      );
      expect(branches.first.branchId, 'custom-id');
    });

    test('createBranches generates branchId when not provided', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [const BranchSpec()],
        config: const ParallelExecutionConfig(),
      );
      expect(branches.first.branchId, '${parent.runId}_branch_0');
    });

    test('createBranches copies parent inputs when spec has no inputs', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [const BranchSpec()],
        config: const ParallelExecutionConfig(),
      );
      expect(branches.first.inputs, parent.inputs);
    });

    test('createBranches uses spec inputs when provided', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [const BranchSpec(inputs: {'custom': true})],
        config: const ParallelExecutionConfig(),
      );
      expect(branches.first.inputs, {'custom': true});
    });

    test('state isolation: branches get independent state', () {
      final branches = factory.createBranches(
        parent: parent,
        branches: [
          const BranchSpec(branchId: 'b1'),
          const BranchSpec(branchId: 'b2'),
        ],
        config: const ParallelExecutionConfig(),
      );

      // Modify state in branch 1
      branches[0].state.set('key', 'branch1_value');

      // Branch 2 should not be affected
      expect(branches[1].state.get<String>('key'), isNull);
    });

    group('EqualSplitAllocation', () {
      test('divides budget equally among branches', () {
        final branches = factory.createBranches(
          parent: parent,
          branches: [
            const BranchSpec(branchId: 'b1'),
            const BranchSpec(branchId: 'b2'),
          ],
          config: const ParallelExecutionConfig(
            budgetAllocation: EqualSplitAllocation(),
          ),
        );
        expect(branches[0].branchBudget.maxTokens, 5000);
        expect(branches[1].branchBudget.maxTokens, 5000);
        expect(branches[0].branchBudget.maxLlmCalls, 10);
        expect(branches[1].branchBudget.maxLlmCalls, 10);
        expect(branches[0].branchBudget.maxMcpCalls, 50);
        expect(branches[1].branchBudget.maxMcpCalls, 50);
      });

      test('returns empty list for zero branches', () {
        final branches = factory.createBranches(
          parent: parent,
          branches: [],
          config: const ParallelExecutionConfig(),
        );
        expect(branches, isEmpty);
      });
    });

    group('ProportionalAllocation', () {
      test('allocates budget proportionally by weight', () {
        final branches = factory.createBranches(
          parent: parent,
          branches: [
            const BranchSpec(branchId: 'b1'),
            const BranchSpec(branchId: 'b2'),
          ],
          config: const ParallelExecutionConfig(
            budgetAllocation: ProportionalAllocation([3.0, 1.0]),
          ),
        );
        // Weight 3/4 for b1, 1/4 for b2
        expect(branches[0].branchBudget.maxTokens, 7500);
        expect(branches[1].branchBudget.maxTokens, 2500);
        expect(branches[0].branchBudget.maxLlmCalls, 15);
        expect(branches[1].branchBudget.maxLlmCalls, 5);
      });

      test('falls back to equal split when total weight is zero', () {
        final branches = factory.createBranches(
          parent: parent,
          branches: [
            const BranchSpec(branchId: 'b1'),
            const BranchSpec(branchId: 'b2'),
          ],
          config: const ParallelExecutionConfig(
            budgetAllocation: ProportionalAllocation([0.0, 0.0]),
          ),
        );
        expect(branches[0].branchBudget.maxTokens, 5000);
        expect(branches[1].branchBudget.maxTokens, 5000);
      });

      test('uses zero weight for missing entries', () {
        final branches = factory.createBranches(
          parent: parent,
          branches: [
            const BranchSpec(branchId: 'b1'),
            const BranchSpec(branchId: 'b2'),
            const BranchSpec(branchId: 'b3'),
          ],
          config: const ParallelExecutionConfig(
            budgetAllocation: ProportionalAllocation([1.0]),
          ),
        );
        // Only first branch has weight 1.0, others get 0
        expect(branches[0].branchBudget.maxTokens, 10000);
        expect(branches[1].branchBudget.maxTokens, 0);
        expect(branches[2].branchBudget.maxTokens, 0);
      });
    });

    group('FirstAvailableAllocation', () {
      test('each branch gets full parent budget', () {
        final branches = factory.createBranches(
          parent: parent,
          branches: [
            const BranchSpec(branchId: 'b1'),
            const BranchSpec(branchId: 'b2'),
          ],
          config: const ParallelExecutionConfig(
            budgetAllocation: FirstAvailableAllocation(),
          ),
        );
        expect(branches[0].branchBudget.maxTokens, 10000);
        expect(branches[1].branchBudget.maxTokens, 10000);
        expect(branches[0].branchBudget.maxLlmCalls, 20);
        expect(branches[1].branchBudget.maxLlmCalls, 20);
      });
    });

    group('ReservedAllocation', () {
      test('uses pre-allocated reservations directly', () {
        final reservations = [
          const BranchBudget(branchId: 'b1', maxTokens: 3000, maxLlmCalls: 8),
          const BranchBudget(branchId: 'b2', maxTokens: 7000, maxLlmCalls: 12),
        ];
        final branches = factory.createBranches(
          parent: parent,
          branches: [
            const BranchSpec(branchId: 'b1'),
            const BranchSpec(branchId: 'b2'),
          ],
          config: ParallelExecutionConfig(
            budgetAllocation: ReservedAllocation(reservations),
          ),
        );
        expect(branches[0].branchBudget.maxTokens, 3000);
        expect(branches[0].branchBudget.maxLlmCalls, 8);
        expect(branches[1].branchBudget.maxTokens, 7000);
        expect(branches[1].branchBudget.maxLlmCalls, 12);
      });
    });
  });
}
