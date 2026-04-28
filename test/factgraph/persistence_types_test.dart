import 'package:test/test.dart';
import 'package:mcp_skill/src/factgraph/persistence_types.dart';

void main() {
  group('PersistenceConfig', () {
    test('default constructor uses expected defaults', () {
      const config = PersistenceConfig();
      expect(config.persistClaims, true);
      expect(config.linkEvidence, true);
      expect(config.recordEvaluation, true);
      expect(config.emitSignals, false);
    });

    test('defaultConfig matches default constructor', () {
      const config = PersistenceConfig.defaultConfig;
      expect(config.persistClaims, true);
      expect(config.linkEvidence, true);
      expect(config.recordEvaluation, true);
      expect(config.emitSignals, false);
    });

    test('minimal disables linkEvidence and recordEvaluation', () {
      const config = PersistenceConfig.minimal;
      expect(config.persistClaims, true);
      expect(config.linkEvidence, false);
      expect(config.recordEvaluation, false);
      expect(config.emitSignals, false);
    });

    test('custom values are preserved', () {
      const config = PersistenceConfig(
        persistClaims: false,
        linkEvidence: false,
        recordEvaluation: false,
        emitSignals: true,
      );
      expect(config.persistClaims, false);
      expect(config.linkEvidence, false);
      expect(config.recordEvaluation, false);
      expect(config.emitSignals, true);
    });
  });

  group('PersistenceResult', () {
    test('constructor sets fields', () {
      const result = PersistenceResult(
        success: true,
        runId: 'run-1',
        claimsPersisted: 5,
        evidenceLinked: 3,
      );
      expect(result.success, true);
      expect(result.runId, 'run-1');
      expect(result.claimsPersisted, 5);
      expect(result.evidenceLinked, 3);
      expect(result.error, isNull);
    });

    test('success factory creates success result', () {
      final result = PersistenceResult.success(
        runId: 'run-ok',
        claimsPersisted: 10,
        evidenceLinked: 7,
      );
      expect(result.success, true);
      expect(result.runId, 'run-ok');
      expect(result.claimsPersisted, 10);
      expect(result.evidenceLinked, 7);
      expect(result.error, isNull);
    });

    test('failure factory creates failure result', () {
      final result = PersistenceResult.failure('db connection failed');
      expect(result.success, false);
      expect(result.error, 'db connection failed');
      expect(result.runId, isNull);
      expect(result.claimsPersisted, 0);
      expect(result.evidenceLinked, 0);
    });

    test('toJson produces correct map', () {
      final result = PersistenceResult.success(
        runId: 'run-1',
        claimsPersisted: 2,
        evidenceLinked: 1,
      );
      final json = result.toJson();
      expect(json['success'], true);
      expect(json['runId'], 'run-1');
      expect(json['claimsPersisted'], 2);
      expect(json['evidenceLinked'], 1);
      expect(json.containsKey('error'), false);
    });

    test('toJson includes error when present', () {
      final result = PersistenceResult.failure('error msg');
      final json = result.toJson();
      expect(json['success'], false);
      expect(json['error'], 'error msg');
    });

    test('toJson omits null runId', () {
      final result = PersistenceResult.failure('error');
      final json = result.toJson();
      expect(json.containsKey('runId'), false);
    });
  });

  group('SkillResultQuery', () {
    test('default constructor has all null/default fields', () {
      const query = SkillResultQuery();
      expect(query.skillId, isNull);
      expect(query.version, isNull);
      expect(query.workspaceId, isNull);
      expect(query.from, isNull);
      expect(query.to, isNull);
      expect(query.claimTypes, isNull);
      expect(query.minConfidence, isNull);
      expect(query.limit, isNull);
      expect(query.offset, isNull);
    });

    test('toJson omits null fields', () {
      const query = SkillResultQuery();
      final json = query.toJson();
      expect(json, isEmpty);
    });

    test('toJson includes all set fields', () {
      final from = DateTime(2025, 1, 1);
      final to = DateTime(2025, 12, 31);
      final query = SkillResultQuery(
        skillId: 'skill-1',
        version: '1.0.0',
        workspaceId: 'ws-1',
        from: from,
        to: to,
        claimTypes: ['conclusion', 'observation'],
        minConfidence: 0.7,
        limit: 50,
        offset: 10,
      );
      final json = query.toJson();
      expect(json['skillId'], 'skill-1');
      expect(json['version'], '1.0.0');
      expect(json['workspaceId'], 'ws-1');
      expect(json['from'], from.toIso8601String());
      expect(json['to'], to.toIso8601String());
      expect(json['claimTypes'], ['conclusion', 'observation']);
      expect(json['minConfidence'], 0.7);
      expect(json['limit'], 50);
      expect(json['offset'], 10);
    });
  });

  group('SkillRunWithClaims', () {
    test('constructor sets all fields', () {
      final started = DateTime(2025, 6, 1, 10, 0);
      final completed = DateTime(2025, 6, 1, 10, 5);
      final run = SkillRunWithClaims(
        runId: 'run-1',
        skillId: 'skill-1',
        workspaceId: 'ws-1',
        startedAt: started,
        completedAt: completed,
        status: 'completed',
        claims: ['claim1', 'claim2'],
        metadata: {'key': 'val'},
      );
      expect(run.runId, 'run-1');
      expect(run.skillId, 'skill-1');
      expect(run.workspaceId, 'ws-1');
      expect(run.startedAt, started);
      expect(run.completedAt, completed);
      expect(run.status, 'completed');
      expect(run.claims, hasLength(2));
      expect(run.metadata, {'key': 'val'});
    });

    test('claims defaults to empty list', () {
      final run = SkillRunWithClaims(
        runId: 'r',
        skillId: 's',
        workspaceId: 'w',
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        status: 'done',
      );
      expect(run.claims, isEmpty);
      expect(run.metadata, isNull);
    });
  });

  group('GraphEdge', () {
    test('constructor sets all fields', () {
      const edge = GraphEdge(
        fromId: 'node-1',
        toId: 'node-2',
        type: EdgeType.supports,
        metadata: {'weight': 0.9},
      );
      expect(edge.fromId, 'node-1');
      expect(edge.toId, 'node-2');
      expect(edge.type, EdgeType.supports);
      expect(edge.metadata, {'weight': 0.9});
    });

    test('toJson produces correct map', () {
      const edge = GraphEdge(
        fromId: 'a',
        toId: 'b',
        type: EdgeType.derivedFrom,
      );
      final json = edge.toJson();
      expect(json['fromId'], 'a');
      expect(json['toId'], 'b');
      expect(json['type'], 'derivedFrom');
      expect(json.containsKey('metadata'), false);
    });

    test('toJson includes metadata when present', () {
      const edge = GraphEdge(
        fromId: 'a',
        toId: 'b',
        type: EdgeType.producedBy,
        metadata: {'key': 'value'},
      );
      final json = edge.toJson();
      expect(json['metadata'], {'key': 'value'});
    });
  });

  group('EdgeType', () {
    test('has all expected values', () {
      expect(EdgeType.values, hasLength(5));
      expect(EdgeType.values, contains(EdgeType.producedBy));
      expect(EdgeType.values, contains(EdgeType.supports));
      expect(EdgeType.values, contains(EdgeType.refutes));
      expect(EdgeType.values, contains(EdgeType.relatedTo));
      expect(EdgeType.values, contains(EdgeType.derivedFrom));
    });
  });

  group('ClaimValidationMode', () {
    test('has all expected values', () {
      expect(ClaimValidationMode.values, hasLength(3));
      expect(ClaimValidationMode.values, contains(ClaimValidationMode.strict));
      expect(ClaimValidationMode.values, contains(ClaimValidationMode.lenient));
      expect(ClaimValidationMode.values, contains(ClaimValidationMode.disabled));
    });
  });
}
