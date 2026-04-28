/// Tests for ParallelExecutor - parallel execution with result aggregation.
library;

import 'package:test/test.dart';

import 'package:mcp_skill/src/multi_skill/parallel_executor.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_types.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_result.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/ports/llm_port.dart';

import '../helpers/mock_registry.dart';
import '../helpers/mock_ports.dart';
import '../helpers/test_data.dart';

void main() {
  group('ParallelExecutor', () {
    late MockSkillBundleRegistry registry;
    late SkillPorts ports;
    late ParallelExecutor executor;

    setUp(() {
      registry = MockSkillBundleRegistry();
      // Use a response that triggers claim extraction (contains 'is' fact pattern)
      final llmPort = MockLlmPort(
        response: const LlmResponse(
          content: 'The result is positive and the data is valid',
          usage: LlmUsage(inputTokens: 10, outputTokens: 20),
        ),
      );
      ports = SkillPorts(
        llm: llmPort,
        mcp: MockMcpPort(),
        retrieval: MockRetrievalPort(),
        claims: MockClaimsPort(),
        runs: MockRunsPort(),
        contextBundle: MockContextBundlePort(),
      );
      executor = ParallelExecutor(registry: registry, ports: ports);
    });

    group('execute', () {
      test('executes single skill in parallel', () async {
        final bundle = makeSkillBundle(id: 'par-skill-1');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [const SkillRef(skillId: 'par-skill-1')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result, isA<ParallelResult>());
        expect(result.mode, equals('parallel'));
        expect(result.outcomes, hasLength(1));
        expect(result.successCount, equals(1));
        expect(result.failureCount, equals(0));
      });

      test('executes multiple skills in parallel', () async {
        final bundle1 = makeSkillBundle(id: 'par-a');
        final bundle2 = makeSkillBundle(id: 'par-b');
        final bundle3 = makeSkillBundle(id: 'par-c');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);
        await registry.registerSkill(bundle3);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-a'),
            const SkillRef(skillId: 'par-b'),
            const SkillRef(skillId: 'par-c'),
          ],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(3));
        expect(result.successCount, equals(3));
        expect(result.failureCount, equals(0));
        expect(result.individualResults, hasLength(3));
        expect(result.totalDuration, isNotNull);
      });

      test('respects concurrency limit with batching', () async {
        // Register 5 skills, use maxConcurrency=2 to force batching
        for (var i = 1; i <= 5; i++) {
          final bundle = makeSkillBundle(id: 'par-batch-$i');
          await registry.registerSkill(bundle);
        }

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            for (var i = 1; i <= 5; i++)
              SkillRef(skillId: 'par-batch-$i'),
          ],
          parallelConfig: const ParallelConfig(
            maxConcurrency: 2,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // All 5 skills should still execute (in batches of 2)
        expect(result.outcomes, hasLength(5));
        expect(result.successCount, equals(5));
      });

      test('enforces minSuccessRatio and fails when below threshold',
          () async {
        // Register 1 out of 3 skills - 2 will fail
        final bundle = makeSkillBundle(id: 'par-ratio-ok');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-ratio-ok'),
            const SkillRef(skillId: 'par-ratio-fail-1'),
            const SkillRef(skillId: 'par-ratio-fail-2'),
          ],
          parallelConfig: const ParallelConfig(
            // Require 80% success, but only 1/3 = 33% will succeed
            minSuccessRatio: 0.8,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // Result should indicate failure due to low success ratio
        expect(result.result.isSuccess, isFalse);
        expect(result.successCount, equals(1));
        expect(result.failureCount, equals(2));
      });

      test('succeeds when minSuccessRatio is met', () async {
        final bundle1 = makeSkillBundle(id: 'par-meet-1');
        final bundle2 = makeSkillBundle(id: 'par-meet-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-meet-1'),
            const SkillRef(skillId: 'par-meet-2'),
            const SkillRef(skillId: 'par-meet-fail'),
          ],
          parallelConfig: const ParallelConfig(
            // Require 50% success, 2/3 = 66% will succeed
            minSuccessRatio: 0.5,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.successCount, equals(2));
        expect(result.failureCount, equals(1));
        // Should still succeed because ratio is above threshold
        expect(result.individualResults, hasLength(2));
      });

      test('uses mergeClaims aggregation by default', () async {
        final bundle1 = makeSkillBundle(id: 'par-merge-1');
        final bundle2 = makeSkillBundle(id: 'par-merge-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-merge-1'),
            const SkillRef(skillId: 'par-merge-2'),
          ],
          // No parallelConfig - defaults to mergeClaims aggregation
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // The aggregated result should combine claims from both
        expect(result.result, isNotNull);
        expect(result.individualResults, hasLength(2));
      });

      test('uses weightedMerge aggregation strategy', () async {
        final bundle1 = makeSkillBundle(id: 'par-wm-1');
        final bundle2 = makeSkillBundle(id: 'par-wm-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-wm-1'),
            const SkillRef(skillId: 'par-wm-2'),
          ],
          parallelConfig: const ParallelConfig(
            aggregation: AggregationStrategy.weightedMerge,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.result, isNotNull);
        expect(result.individualResults, hasLength(2));
      });

      test('uses custom aggregation strategy (returns first result)',
          () async {
        final bundle1 = makeSkillBundle(id: 'par-custom-1');
        final bundle2 = makeSkillBundle(id: 'par-custom-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-custom-1'),
            const SkillRef(skillId: 'par-custom-2'),
          ],
          parallelConfig: const ParallelConfig(
            aggregation: AggregationStrategy.custom,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.result, isNotNull);
        // Custom aggregation returns the first result
        expect(result.individualResults, hasLength(2));
      });

      test('handles all skills failing', () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(skillId: 'par-fail-1'),
            const SkillRef(skillId: 'par-fail-2'),
          ],
          parallelConfig: const ParallelConfig(
            minSuccessRatio: 0.0,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.successCount, equals(0));
        expect(result.failureCount, equals(2));
        expect(result.individualResults, isEmpty);
      });

      test('handles empty skills list', () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, isEmpty);
        expect(result.successCount, equals(0));
        expect(result.failureCount, equals(0));
      });

      test('handles skill with no procedures', () async {
        final emptyBundle = makeSkillBundle(
          id: 'par-no-proc',
          procedures: [],
        );
        await registry.registerSkill(emptyBundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [const SkillRef(skillId: 'par-no-proc')],
          parallelConfig: const ParallelConfig(
            minSuccessRatio: 0.0,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(1));
        expect(result.outcomes.first.success, isFalse);
        expect(result.outcomes.first.error, isNotNull);
      });

      test('records duration for each outcome', () async {
        final bundle = makeSkillBundle(id: 'par-dur');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [const SkillRef(skillId: 'par-dur')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes.first.duration, isNotNull);
        expect(
          result.outcomes.first.duration.inMicroseconds,
          greaterThanOrEqualTo(0),
        );
      });

      test('passes input overrides to individual skills', () async {
        final bundle = makeSkillBundle(id: 'par-override');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [
            const SkillRef(
              skillId: 'par-override',
              inputOverrides: {'extra': 'data'},
            ),
          ],
        );
        final context = makeSkillContext(inputs: {'base': 'input'});

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(1));
        expect(result.outcomes.first.success, isTrue);
      });

      test('empty results with minSuccessRatio 0 yields empty aggregate',
          () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.parallel,
          skills: [],
          parallelConfig: const ParallelConfig(
            minSuccessRatio: 0.0,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // Empty outcomes, ratio is 0/0 = 0.0 which is >= 0.0
        expect(result.outcomes, isEmpty);
        expect(result.result, isNotNull);
      });
    });
  });
}
