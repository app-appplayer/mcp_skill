/// Tests for CompetitionExecutor - parallel execution with winner selection.
library;

import 'package:test/test.dart';

import 'package:mcp_skill/src/multi_skill/competition_executor.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_types.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_result.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/ports/llm_port.dart';

import '../helpers/mock_registry.dart';
import '../helpers/mock_ports.dart';
import '../helpers/test_data.dart';

void main() {
  group('CompetitionExecutor', () {
    late MockSkillBundleRegistry registry;
    late SkillPorts ports;
    late CompetitionExecutor executor;

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
      executor = CompetitionExecutor(registry: registry, ports: ports);
    });

    group('execute', () {
      test('executes single skill and selects it as winner', () async {
        final bundle = makeSkillBundle(id: 'comp-skill-1');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [const SkillRef(skillId: 'comp-skill-1')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result, isA<CompetitionResult>());
        expect(result.mode, equals('competition'));
        expect(result.outcomes, hasLength(1));
        // The single successful skill should be the winner
        expect(result.winnerId, equals('comp-skill-1'));
        expect(result.outcomes.first.isWinner, isTrue);
      });

      test('executes multiple skills in parallel', () async {
        final bundle1 = makeSkillBundle(id: 'comp-a');
        final bundle2 = makeSkillBundle(id: 'comp-b');
        final bundle3 = makeSkillBundle(id: 'comp-c');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);
        await registry.registerSkill(bundle3);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [
            const SkillRef(skillId: 'comp-a'),
            const SkillRef(skillId: 'comp-b'),
            const SkillRef(skillId: 'comp-c'),
          ],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(3));
        expect(result.individualResults, isNotEmpty);
        // Exactly one winner
        final winners =
            result.outcomes.where((o) => o.isWinner).toList();
        expect(winners, hasLength(1));
        expect(result.winnerId, isNotEmpty);
      });

      test('uses highestConfidence criteria by default', () async {
        final bundle1 = makeSkillBundle(id: 'comp-hi');
        final bundle2 = makeSkillBundle(id: 'comp-lo');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [
            const SkillRef(skillId: 'comp-hi'),
            const SkillRef(skillId: 'comp-lo'),
          ],
          // No competitionConfig - defaults to highestConfidence
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        // Both skills use the same procedure, so they will have similar
        // confidence. The test verifies the scoring mechanism works.
        expect(result.outcomes.length, equals(2));
        for (final outcome in result.outcomes) {
          expect(outcome.score, isA<double>());
        }
      });

      test('selects winner by mostEvidence criteria', () async {
        final bundle1 = makeSkillBundle(id: 'comp-ev1');
        final bundle2 = makeSkillBundle(id: 'comp-ev2');
        await registry.registerSkill(bundle1);
        await registry.registerSkill(bundle2);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [
            const SkillRef(skillId: 'comp-ev1'),
            const SkillRef(skillId: 'comp-ev2'),
          ],
          competitionConfig: const CompetitionConfig(
            criteria: SelectionCriteria.mostEvidence,
          ),
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(2));
        // Winner should be selected based on evidence count
        expect(result.winnerId, isNotEmpty);
      });

      test('handles failed competitors gracefully', () async {
        // Register one valid skill and reference one nonexistent
        final bundle = makeSkillBundle(id: 'comp-valid');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [
            const SkillRef(skillId: 'comp-valid'),
            const SkillRef(skillId: 'comp-nonexistent'),
          ],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(2));
        // The valid skill should win
        expect(result.winnerId, equals('comp-valid'));

        // The failed competitor should have error info
        final failedOutcome =
            result.outcomes.where((o) => o.skillId == 'comp-nonexistent');
        expect(failedOutcome, hasLength(1));
        expect(failedOutcome.first.error, isNotNull);
        expect(failedOutcome.first.isWinner, isFalse);
      });

      test('handles all competitors failing', () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [
            const SkillRef(skillId: 'missing-1'),
            const SkillRef(skillId: 'missing-2'),
          ],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(2));
        // No winner when all fail (scores are -1.0)
        expect(result.individualResults, isEmpty);
      });

      test('handles empty skills list', () async {
        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, isEmpty);
        expect(result.individualResults, isEmpty);
      });

      test('handles skill with no procedures', () async {
        final emptyBundle = makeSkillBundle(
          id: 'comp-empty',
          procedures: [],
        );
        await registry.registerSkill(emptyBundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [const SkillRef(skillId: 'comp-empty')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(1));
        expect(result.outcomes.first.error, isNotNull);
      });

      test('passes input overrides to individual skills', () async {
        final bundle = makeSkillBundle(id: 'comp-override');
        await registry.registerSkill(bundle);

        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [
            const SkillRef(
              skillId: 'comp-override',
              inputOverrides: {'special': 'config'},
            ),
          ],
        );
        final context = makeSkillContext(inputs: {'base': 'value'});

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(1));
        // The skill should have been executed (winner or not)
        expect(result.winnerId, equals('comp-override'));
      });

      test('scores failed results as -1.0', () async {
        // A nonexistent skill produces null result, which should score -1.0
        final config = MultiSkillConfig(
          mode: MultiSkillMode.competition,
          skills: [const SkillRef(skillId: 'does-not-exist')],
        );
        final context = makeSkillContext();

        final result = await executor.execute(config, context);

        expect(result.outcomes, hasLength(1));
        expect(result.outcomes.first.score, equals(-1.0));
      });
    });
  });
}
