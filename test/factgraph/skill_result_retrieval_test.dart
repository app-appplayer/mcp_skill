/// Tests for SkillResultRetrieval - retrieving skill results from FactGraph.
library;

import 'package:test/test.dart';

import 'package:mcp_skill/src/factgraph/skill_result_retrieval.dart';
import 'package:mcp_skill/src/factgraph/persistence_types.dart';

void main() {
  group('SkillResultRetrieval', () {
    late SkillResultRetrieval retrieval;

    setUp(() {
      retrieval = SkillResultRetrieval();
    });

    group('retrieve', () {
      test('returns empty list for any query', () async {
        final query = SkillResultQuery(skillId: 'com.test.skill');
        final results = await retrieval.retrieve(query);
        expect(results, isEmpty);
        expect(results, isA<List<SkillRunWithClaims>>());
      });

      test('returns empty list with minimal query', () async {
        const query = SkillResultQuery();
        final results = await retrieval.retrieve(query);
        expect(results, isEmpty);
      });

      test('returns empty list with fully specified query', () async {
        final query = SkillResultQuery(
          skillId: 'com.test.skill',
          version: '1.0.0',
          workspaceId: 'ws-001',
          from: DateTime(2025, 1, 1),
          to: DateTime(2025, 12, 31),
          claimTypes: ['fact', 'conclusion'],
          minConfidence: 0.8,
          limit: 10,
          offset: 0,
        );
        final results = await retrieval.retrieve(query);
        expect(results, isEmpty);
      });
    });

    group('getByRunId', () {
      test('returns null for any run ID', () async {
        final result = await retrieval.getByRunId('run-001');
        expect(result, isNull);
      });

      test('returns null for empty run ID', () async {
        final result = await retrieval.getByRunId('');
        expect(result, isNull);
      });
    });

    group('getLatestRun', () {
      test('returns null for any skill ID', () async {
        final result = await retrieval.getLatestRun('com.test.skill');
        expect(result, isNull);
      });

      test('returns null with workspace ID parameter', () async {
        final result = await retrieval.getLatestRun(
          'com.test.skill',
          workspaceId: 'ws-001',
        );
        expect(result, isNull);
      });

      test('returns null for empty skill ID', () async {
        final result = await retrieval.getLatestRun('');
        expect(result, isNull);
      });
    });
  });
}
