/// Tests for ChainExecutor - sequential multi-skill execution.
library;

import 'package:test/test.dart';

import 'package:mcp_skill/src/multi_skill/chain_executor.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_types.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_result.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/ports/llm_port.dart';

import '../helpers/mock_registry.dart';
import '../helpers/mock_ports.dart';
import '../helpers/test_data.dart';

void main() {
  group('ChainExecutor', () {
    late MockSkillBundleRegistry registry;
    late SkillPorts ports;
    late ChainExecutor executor;

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
      executor = ChainExecutor(registry: registry, ports: ports);
    });

    group('execute', () {
      test('executes single skill in chain', () async {
        final bundle = makeSkillBundle(id: 'chain-skill-1');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [const SkillRef(skillId: 'chain-skill-1')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result, isA<ChainResult>());
        expect(result.mode, equals('chain'));
        expect(result.individualResults, hasLength(1));
        expect(result.totalDuration, isNotNull);
      });

      test('executes multiple skills sequentially', () async {
        final bundle1 = makeSkillBundle(id: 'chain-a');
        final bundle2 = makeSkillBundle(id: 'chain-b');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(skillId: 'chain-a'),
            const SkillRef(skillId: 'chain-b'),
          ],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.individualResults, hasLength(2));
        expect(result.chainSteps, hasLength(2));
        expect(result.chainSteps[0].skillId, equals('chain-a'));
        expect(result.chainSteps[1].skillId, equals('chain-b'));
      });

      test('stopOnFailure=true halts chain on skill not found', () async {
        // Only register the first skill
        final bundle1 = makeSkillBundle(id: 'chain-exists');
        await registry.registerSkill(bundle1);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(skillId: 'chain-exists'),
            const SkillRef(skillId: 'chain-missing'),
            const SkillRef(skillId: 'chain-exists'),
          ],
          chainConfig: const ChainConfig(stopOnFailure: true),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // Chain should stop after the missing skill
        // First skill succeeds, second fails (not found), chain stops
        expect(result.individualResults, hasLength(2));
      });

      test('stopOnFailure=false continues after failure', () async {
        // Register first and third skills, skip second
        final bundle1 = makeSkillBundle(id: 'chain-ok-1');
        final bundle3 = makeSkillBundle(id: 'chain-ok-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle3);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(skillId: 'chain-ok-1'),
            const SkillRef(skillId: 'chain-not-found'),
            const SkillRef(skillId: 'chain-ok-2'),
          ],
          chainConfig: const ChainConfig(stopOnFailure: false),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // All three skills attempted, second fails but continues
        expect(result.individualResults, hasLength(3));
      });

      test('handles skill not found gracefully', () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [const SkillRef(skillId: 'nonexistent')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.individualResults, hasLength(1));
        expect(result.individualResults.first.isSuccess, isFalse);
      });

      test('handles skill with no procedures', () async {
        final emptyBundle = makeSkillBundle(
          id: 'chain-empty',
          procedures: [],
        );
        await registry.registerSkill(emptyBundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [const SkillRef(skillId: 'chain-empty')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.individualResults, hasLength(1));
        expect(result.individualResults.first.isSuccess, isFalse);
      });

      test('passes previous result as input when no output mappings',
          () async {
        final bundle1 = makeSkillBundle(id: 'chain-pass-1');
        final bundle2 = makeSkillBundle(id: 'chain-pass-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(skillId: 'chain-pass-1'),
            const SkillRef(skillId: 'chain-pass-2'),
          ],
          // No chainConfig / no output mappings
        );
        final context = makeSkillContext(inputs: {'initial': 'data'});

        final result = await executor.execute(config, context);

        // Second step should have received the result of the first step
        // as 'previousResult' in its inputs
        expect(result.individualResults, hasLength(2));
        if (result.chainSteps.length >= 2) {
          expect(
            result.chainSteps[1].inputs.containsKey('previousResult'),
            isTrue,
          );
        }
      });

      test('applies output mappings between steps', () async {
        final bundle1 = makeSkillBundle(id: 'chain-map-1');
        final bundle2 = makeSkillBundle(id: 'chain-map-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(skillId: 'chain-map-1'),
            const SkillRef(skillId: 'chain-map-2'),
          ],
          chainConfig: const ChainConfig(
            outputMappings: [
              OutputMapping(source: 'confidence', target: 'inputConfidence'),
            ],
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result, isA<ChainResult>());
        expect(result.individualResults, hasLength(2));
      });

      test('applies input overrides for individual skills', () async {
        final bundle = makeSkillBundle(id: 'chain-override');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(
              skillId: 'chain-override',
              inputOverrides: {'extra': 'value'},
            ),
          ],
        );
        final context = makeSkillContext(inputs: {'base': 'input'});

        final result = await executor.execute(config, context);

        expect(result.individualResults, hasLength(1));
        // The chain step should have both base and extra inputs
        if (result.chainSteps.isNotEmpty) {
          expect(result.chainSteps.first.inputs['extra'], equals('value'));
          expect(result.chainSteps.first.inputs['base'], equals('input'));
        }
      });

      test('returns empty result for no skills', () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.individualResults, isEmpty);
        // result.result is SkillResult.empty() when no results
        expect(result.result.isSuccess, isFalse);
      });

      test('final result is the last skill result', () async {
        final bundle1 = makeSkillBundle(id: 'chain-final-1');
        final bundle2 = makeSkillBundle(id: 'chain-final-2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.chain,
          skills: [
            const SkillRef(skillId: 'chain-final-1'),
            const SkillRef(skillId: 'chain-final-2'),
          ],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // The final result should be the last individual result
        expect(result.result, equals(result.individualResults.last));
      });
    });
  });
}
