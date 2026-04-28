import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/branch_merger.dart';

void main() {
  group('BranchResult', () {
    test('stores all fields correctly', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.success,
        output: 'hello',
        duration: Duration(seconds: 2),
        budgetUsage: {'tokensUsed': 100},
      );
      expect(result.branchId, 'b1');
      expect(result.status, BranchStatus.success);
      expect(result.output, 'hello');
      expect(result.error, isNull);
      expect(result.duration, const Duration(seconds: 2));
      expect(result.budgetUsage!['tokensUsed'], 100);
    });

    test('isSuccess returns true for success status', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.success,
      );
      expect(result.isSuccess, true);
    });

    test('isSuccess returns false for failed status', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.failed,
        error: 'something went wrong',
      );
      expect(result.isSuccess, false);
    });

    test('isSuccess returns false for cancelled status', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.cancelled,
      );
      expect(result.isSuccess, false);
    });

    test('isSuccess returns false for timedOut status', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.timedOut,
      );
      expect(result.isSuccess, false);
    });

    test('isSuccess returns false for skipped status', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.skipped,
      );
      expect(result.isSuccess, false);
    });

    test('defaults: duration is zero, budgetUsage is null', () {
      const result = BranchResult(
        branchId: 'b1',
        status: BranchStatus.success,
      );
      expect(result.duration, Duration.zero);
      expect(result.budgetUsage, isNull);
    });
  });

  group('MergeResult', () {
    test('successful factory creates a successful result', () {
      final result = MergeResult.successful(
        output: [1, 2, 3],
        branchResults: const [],
        totalUsage: {'tokensUsed': 50},
      );
      expect(result.success, true);
      expect(result.output, [1, 2, 3]);
      expect(result.failureReason, isNull);
      expect(result.failedBranches, isEmpty);
      expect(result.totalUsage!['tokensUsed'], 50);
    });

    test('failed factory creates a failed result', () {
      const failedBranch = BranchResult(
        branchId: 'b1',
        status: BranchStatus.failed,
        error: 'oops',
      );
      final result = MergeResult.failed(
        reason: 'branch failed',
        branchResults: const [failedBranch],
      );
      expect(result.success, false);
      expect(result.failureReason, 'branch failed');
      expect(result.failedBranches.length, 1);
      expect(result.output, isNull);
    });

    test('failed factory auto-detects failed branches when not specified', () {
      const results = [
        BranchResult(branchId: 'b1', status: BranchStatus.success, output: 1),
        BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e'),
        BranchResult(branchId: 'b3', status: BranchStatus.failed, error: 'e2'),
      ];
      final result = MergeResult.failed(
        reason: 'some failed',
        branchResults: results,
      );
      expect(result.failedBranches.length, 2);
      expect(result.failedBranches.map((b) => b.branchId), ['b2', 'b3']);
    });
  });

  group('DefaultBranchMerger', () {
    late DefaultBranchMerger merger;

    setUp(() {
      merger = DefaultBranchMerger();
    });

    group('AllSuccessMerge', () {
      test('all succeed with array aggregation returns list of outputs', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.success, output: 'b'),
        ];
        final merged = await merger.merge(results, const AllSuccessMerge());
        expect(merged.success, true);
        expect(merged.output, ['a', 'b']);
      });

      test('any failure causes merge failure', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'fail'),
        ];
        final merged = await merger.merge(results, const AllSuccessMerge());
        expect(merged.success, false);
        expect(merged.failureReason, contains('failed'));
        expect(merged.failedBranches.length, 1);
      });

      test('mergeObjects aggregation deep-merges maps', () async {
        final results = [
          BranchResult(
            branchId: 'b1',
            status: BranchStatus.success,
            output: <String, dynamic>{'a': 1, 'nested': <String, dynamic>{'x': 10}},
          ),
          BranchResult(
            branchId: 'b2',
            status: BranchStatus.success,
            output: <String, dynamic>{'b': 2, 'nested': <String, dynamic>{'y': 20}},
          ),
        ];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.mergeObjects),
        );
        expect(merged.success, true);
        final output = merged.output as Map<String, dynamic>;
        expect(output['a'], 1);
        expect(output['b'], 2);
        // Nested maps should be deep-merged
        final nested = output['nested'] as Map<String, dynamic>;
        expect(nested['x'], 10);
        expect(nested['y'], 20);
      });

      test('first aggregation returns first output', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'first'),
          BranchResult(branchId: 'b2', status: BranchStatus.success, output: 'second'),
        ];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.first),
        );
        expect(merged.success, true);
        expect(merged.output, 'first');
      });

      test('last aggregation returns last output', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'first'),
          BranchResult(branchId: 'b2', status: BranchStatus.success, output: 'second'),
        ];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.last),
        );
        expect(merged.success, true);
        expect(merged.output, 'second');
      });

      test('first aggregation returns null for empty results', () async {
        const results = <BranchResult>[];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.first),
        );
        expect(merged.success, true);
        expect(merged.output, isNull);
      });

      test('custom aggregation returns array like default', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 10),
          BranchResult(branchId: 'b2', status: BranchStatus.success, output: 20),
        ];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.custom),
        );
        expect(merged.success, true);
        expect(merged.output, [10, 20]);
      });
    });

    group('AnySuccessMerge', () {
      test('succeeds when minimum successful threshold is met', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e'),
          BranchResult(branchId: 'b3', status: BranchStatus.success, output: 'c'),
        ];
        final merged = await merger.merge(
          results,
          const AnySuccessMerge(minSuccessful: 2),
        );
        expect(merged.success, true);
        expect(merged.output, ['a', 'c']);
      });

      test('fails when below minimum successful threshold', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e'),
          BranchResult(branchId: 'b3', status: BranchStatus.failed, error: 'e2'),
        ];
        final merged = await merger.merge(
          results,
          const AnySuccessMerge(minSuccessful: 2),
        );
        expect(merged.success, false);
        expect(merged.failureReason, contains('1'));
        expect(merged.failureReason, contains('2'));
      });

      test('default minSuccessful of 1 requires at least one success', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.failed, error: 'e'),
          BranchResult(branchId: 'b2', status: BranchStatus.success, output: 'ok'),
        ];
        final merged = await merger.merge(
          results,
          const AnySuccessMerge(),
        );
        expect(merged.success, true);
        expect(merged.output, ['ok']);
      });

      test('fails when all branches fail', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.failed, error: 'e1'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e2'),
        ];
        final merged = await merger.merge(
          results,
          const AnySuccessMerge(),
        );
        expect(merged.success, false);
      });
    });

    group('BestEffortMerge', () {
      test('includeSuccessful includes only successful outputs', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e'),
          BranchResult(branchId: 'b3', status: BranchStatus.success, output: 'c'),
        ];
        final merged = await merger.merge(
          results,
          const BestEffortMerge(
            onPartialFailure: PartialFailureAction.includeSuccessful,
          ),
        );
        expect(merged.success, true);
        expect(merged.output, ['a', 'c']);
      });

      test('includeAll includes all outputs including failed', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, output: null),
        ];
        final merged = await merger.merge(
          results,
          const BestEffortMerge(
            onPartialFailure: PartialFailureAction.includeAll,
          ),
        );
        expect(merged.success, true);
        expect(merged.output, ['a', null]);
      });

      test('fail action causes failure when any branch fails', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e'),
        ];
        final merged = await merger.merge(
          results,
          const BestEffortMerge(
            onPartialFailure: PartialFailureAction.fail,
          ),
        );
        expect(merged.success, false);
        expect(merged.failureReason, contains('Partial failure'));
      });

      test('fail action succeeds when all branches succeed', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 'a'),
          BranchResult(branchId: 'b2', status: BranchStatus.success, output: 'b'),
        ];
        final merged = await merger.merge(
          results,
          const BestEffortMerge(
            onPartialFailure: PartialFailureAction.fail,
          ),
        );
        expect(merged.success, true);
      });

      test('fails when all branches fail regardless of action', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.failed, error: 'e1'),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, error: 'e2'),
        ];
        final merged = await merger.merge(
          results,
          const BestEffortMerge(),
        );
        expect(merged.success, false);
        expect(merged.failureReason, contains('All branches failed'));
      });
    });

    group('CustomMerge', () {
      test('returns all outputs as-is for external handling', () async {
        const results = [
          BranchResult(branchId: 'b1', status: BranchStatus.success, output: 1),
          BranchResult(branchId: 'b2', status: BranchStatus.failed, output: null),
        ];
        final merged = await merger.merge(
          results,
          const CustomMerge('custom-merger-ref'),
        );
        expect(merged.success, true);
        expect(merged.output, [1, null]);
      });
    });

    group('budget usage aggregation', () {
      test('aggregates budget usage across branches', () async {
        const results = [
          BranchResult(
            branchId: 'b1',
            status: BranchStatus.success,
            output: 'a',
            budgetUsage: {
              'tokensUsed': 100,
              'stepsExecuted': 3,
              'llmCallsMade': 2,
              'mcpCallsMade': 5,
              'elapsedMs': 500,
            },
          ),
          BranchResult(
            branchId: 'b2',
            status: BranchStatus.success,
            output: 'b',
            budgetUsage: {
              'tokensUsed': 200,
              'stepsExecuted': 4,
              'llmCallsMade': 1,
              'mcpCallsMade': 3,
              'elapsedMs': 800,
            },
          ),
        ];
        final merged = await merger.merge(results, const AllSuccessMerge());
        expect(merged.totalUsage!['tokensUsed'], 300);
        expect(merged.totalUsage!['stepsExecuted'], 7);
        expect(merged.totalUsage!['llmCallsMade'], 3);
        expect(merged.totalUsage!['mcpCallsMade'], 8);
        expect(merged.totalUsage!['maxElapsedMs'], 800);
        expect(merged.totalUsage!['branchCount'], 2);
      });

      test('handles null budgetUsage gracefully', () async {
        const results = [
          BranchResult(
            branchId: 'b1',
            status: BranchStatus.success,
            output: 'a',
            budgetUsage: {'tokensUsed': 50},
          ),
          BranchResult(
            branchId: 'b2',
            status: BranchStatus.success,
            output: 'b',
          ),
        ];
        final merged = await merger.merge(results, const AllSuccessMerge());
        expect(merged.totalUsage!['tokensUsed'], 50);
        expect(merged.totalUsage!['branchCount'], 2);
      });
    });

    group('deep merge of objects', () {
      test('last write wins for non-map values', () async {
        const results = [
          BranchResult(
            branchId: 'b1',
            status: BranchStatus.success,
            output: {'key': 'first'},
          ),
          BranchResult(
            branchId: 'b2',
            status: BranchStatus.success,
            output: {'key': 'second'},
          ),
        ];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.mergeObjects),
        );
        final output = merged.output as Map<String, dynamic>;
        expect(output['key'], 'second');
      });

      test('skips non-map outputs in mergeObjects mode', () async {
        const results = [
          BranchResult(
            branchId: 'b1',
            status: BranchStatus.success,
            output: 'not a map',
          ),
          BranchResult(
            branchId: 'b2',
            status: BranchStatus.success,
            output: {'key': 'value'},
          ),
        ];
        final merged = await merger.merge(
          results,
          const AllSuccessMerge(aggregation: AggregationType.mergeObjects),
        );
        final output = merged.output as Map<String, dynamic>;
        expect(output['key'], 'value');
      });
    });
  });
}
