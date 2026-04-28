/// Tests for SkillResultPersistence - persisting skill results via
/// capability-named ports (RunsPort / ClaimsPort).
library;

import 'package:test/test.dart';
import 'package:mcp_bundle/mcp_bundle.dart' show RunStatus;

import 'package:mcp_skill/src/factgraph/skill_result_persistence.dart';
import 'package:mcp_skill/src/factgraph/persistence_types.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';

import '../helpers/mock_ports.dart';
import '../helpers/test_data.dart';

void main() {
  group('SkillResultPersistence', () {
    late MockRunsPort mockRuns;
    late MockClaimsPort mockClaims;
    late SkillResultPersistence persistence;

    setUp(() {
      mockRuns = MockRunsPort();
      mockClaims = MockClaimsPort();
      persistence = SkillResultPersistence(
        runsPort: mockRuns,
        claimsPort: mockClaims,
      );
    });

    group('persist', () {
      test('writes run record and claims on successful persistence', () async {
        final result = makeSkillResult(
          claims: [
            makeClaim(id: 'c1', text: 'Claim one'),
            makeClaim(id: 'c2', text: 'Claim two'),
          ],
          evidenceRefs: ['ev-1', 'ev-2'],
          confidence: 0.85,
        );
        final context = makeSkillContext(runId: 'run-persist-01');

        final persisted = await persistence.persist(result, context);

        expect(persisted.success, isTrue);
        expect(persisted.runId, equals('run-persist-01'));
        expect(persisted.claimsPersisted, equals(2));
        expect(persisted.evidenceLinked, equals(2));

        // Verify writeRun was called
        expect(mockRuns.writtenRuns, hasLength(1));
        final record = mockRuns.writtenRuns.first;
        expect(record.producerId, equals(result.metadata.skillId));
        expect(record.producerKind, equals('skill'));

        // Verify writeClaims was called
        expect(mockClaims.writtenClaims, hasLength(1));
        final (writtenClaims, writtenRefs) = mockClaims.writtenClaims.first;
        expect(writtenClaims, hasLength(2));
        expect(writtenRefs, equals(['ev-1', 'ev-2']));
      });

      test('skips claims when persistClaims is false', () async {
        final result = makeSkillResult(
          claims: [makeClaim(id: 'c1')],
          evidenceRefs: ['ev-1'],
        );
        final context = makeSkillContext(runId: 'run-no-claims');
        const config = PersistenceConfig(
          persistClaims: false,
          linkEvidence: true,
        );

        final persisted =
            await persistence.persist(result, context, config: config);

        expect(persisted.success, isTrue);
        expect(persisted.claimsPersisted, equals(0));
        expect(persisted.evidenceLinked, equals(1));

        // Run record was still written
        expect(mockRuns.writtenRuns, hasLength(1));
        // Claims were NOT written
        expect(mockClaims.writtenClaims, isEmpty);
      });

      test('skips evidence linking when linkEvidence is false', () async {
        final result = makeSkillResult(
          claims: [makeClaim(id: 'c1')],
          evidenceRefs: ['ev-1', 'ev-2', 'ev-3'],
        );
        final context = makeSkillContext(runId: 'run-no-evidence');
        const config = PersistenceConfig(
          persistClaims: true,
          linkEvidence: false,
        );

        final persisted =
            await persistence.persist(result, context, config: config);

        expect(persisted.success, isTrue);
        expect(persisted.claimsPersisted, equals(1));
        expect(persisted.evidenceLinked, equals(0));
      });

      test('returns failure result when writeRun throws', () async {
        mockRuns.writeError = Exception('DB connection lost');
        final result = makeSkillResult();
        final context = makeSkillContext(runId: 'run-fail');

        final persisted = await persistence.persist(result, context);

        expect(persisted.success, isFalse);
        expect(persisted.error, contains('DB connection lost'));
        expect(persisted.runId, isNull);
      });

      test('handles result with empty claims and evidence', () async {
        final result = makeSkillResult(
          claims: [],
          evidenceRefs: [],
          confidence: 0.0,
        );
        final context = makeSkillContext(runId: 'run-empty');

        final persisted = await persistence.persist(result, context);

        expect(persisted.success, isTrue);
        expect(persisted.claimsPersisted, equals(0));
        expect(persisted.evidenceLinked, equals(0));

        expect(mockRuns.writtenRuns, hasLength(1));
        expect(mockClaims.writtenClaims, isEmpty);
      });

      test('uses default config when none specified', () async {
        final result = makeSkillResult(
          claims: [makeClaim(id: 'c1')],
          evidenceRefs: ['ev-1'],
        );
        final context = makeSkillContext(runId: 'run-default');

        final persisted = await persistence.persist(result, context);

        expect(persisted.success, isTrue);
        expect(persisted.claimsPersisted, equals(1));
        expect(persisted.evidenceLinked, equals(1));
      });

      test('skips writes when neither port is configured', () async {
        final nopPersistence = SkillResultPersistence();
        final result = makeSkillResult(
          claims: [makeClaim(id: 'c1')],
          evidenceRefs: ['ev-1'],
        );
        final context = makeSkillContext(runId: 'run-nop');

        final persisted = await nopPersistence.persist(result, context);

        expect(persisted.success, isTrue);
        expect(persisted.runId, equals('run-nop'));
      });
    });

    group('retrieve', () {
      test('returns empty list', () async {
        final query = SkillResultQuery(skillId: 'com.test.skill');
        final results = await persistence.retrieve(query);
        expect(results, isEmpty);
      });
    });
  });

  group('SkillRunMapper.toRunRecord', () {
    test('maps fields correctly from SkillResult and SkillContext', () {
      final startedAt = DateTime(2025, 6, 1, 10, 0);
      final finishedAt = DateTime(2025, 6, 1, 10, 5);

      final metadata = ExecutionMetadata(
        skillId: 'com.test.mapper',
        skillVersion: '2.1.0',
        procedureId: 'proc-map-01',
        startedAt: startedAt,
        finishedAt: finishedAt,
        duration: finishedAt.difference(startedAt),
        stepsExecuted: 5,
        toolsCalled: ['llm.complete', 'tool.search'],
      );

      final result = SkillResult(
        claims: [
          makeClaim(id: 'claim-a'),
          makeClaim(id: 'claim-b'),
        ],
        evidenceRefs: ['ev-x', 'ev-y'],
        confidence: 0.92,
        asOf: DateTime(2025, 6, 1),
        metadata: metadata,
      );

      final context = makeSkillContext(
        runId: 'run-map-01',
        inputs: {'key': 'value', 'count': 42},
      );

      final record = SkillRunMapper.toRunRecord(result, context);

      expect(record.id, equals('run-map-01'));
      expect(record.producerId, equals('com.test.mapper'));
      expect(record.producerKind, equals('skill'));
      expect(record.producerVersion, equals('2.1.0'));
      expect(record.startedAt, equals(startedAt));
      expect(record.finishedAt, equals(finishedAt));
      expect(record.status, equals(RunStatus.completed));
      expect(record.inputs, equals({'key': 'value', 'count': 42}));
      expect(record.claimIds, equals(['claim-a', 'claim-b']));
      expect(record.evidenceRefs, equals(['ev-x', 'ev-y']));
    });

    test('sets status to failed when result is not successful', () {
      final result = SkillResult.failure(
        skillId: 'com.test.fail',
        error: 'Something went wrong',
      );
      final context = makeSkillContext(runId: 'run-fail');

      final record = SkillRunMapper.toRunRecord(result, context);

      expect(record.status, equals(RunStatus.failed));
      expect(record.claimIds, isEmpty);
    });

    test('maps empty inputs from context', () {
      final result = makeSkillResult();
      final context = makeSkillContext(inputs: {});

      final record = SkillRunMapper.toRunRecord(result, context);

      expect(record.inputs, isEmpty);
    });
  });
}
