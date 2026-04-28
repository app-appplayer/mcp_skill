import 'package:test/test.dart';
import 'package:mcp_skill/src/definition/procedure.dart';

void main() {
  group('QualityGate', () {
    test('constructor with required fields', () {
      final gate = QualityGate(id: 'g1', type: 'threshold');

      expect(gate.id, equals('g1'));
      expect(gate.type, equals('threshold'));
      expect(gate.config, isEmpty);
      expect(gate.blocking, isTrue);
    });

    test('constructor with all fields', () {
      final gate = QualityGate(
        id: 'g1',
        type: 'rubric',
        config: {'rubricRef': 'rb1', 'minScore': 70},
        blocking: false,
      );

      expect(gate.type, equals('rubric'));
      expect(gate.config['rubricRef'], equals('rb1'));
      expect(gate.config['minScore'], equals(70));
      expect(gate.blocking, isFalse);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'g1',
        'type': 'validator',
        'config': {'validatorRef': 'v1', 'strict': true},
        'blocking': true,
      };
      final gate = QualityGate.fromJson(json);
      final result = gate.toJson();

      expect(result['id'], equals('g1'));
      expect(result['type'], equals('validator'));
      expect(result['config'], equals({'validatorRef': 'v1', 'strict': true}));
      expect(result['blocking'], isTrue);
    });

    test('toJson excludes empty config', () {
      final gate = QualityGate(id: 'g1', type: 'threshold');
      final json = gate.toJson();

      expect(json.containsKey('config'), isFalse);
      expect(json['blocking'], isTrue);
    });

    test('fromJson with empty map uses defaults', () {
      final gate = QualityGate.fromJson({});

      expect(gate.id, equals(''));
      expect(gate.type, equals('threshold'));
      expect(gate.config, isEmpty);
      expect(gate.blocking, isTrue);
    });

    test('toString with blocking gate', () {
      final gate = QualityGate(id: 'g1', type: 'rubric', blocking: true);

      expect(gate.toString(), equals('QualityGate(g1: rubric [blocking])'));
    });

    test('toString with non-blocking gate', () {
      final gate = QualityGate(id: 'g2', type: 'threshold', blocking: false);

      expect(gate.toString(), equals('QualityGate(g2: threshold)'));
    });
  });

  group('Procedure', () {
    test('constructor with required fields', () {
      final proc = Procedure(
        id: 'proc1',
        name: 'Main Procedure',
        steps: [],
      );

      expect(proc.id, equals('proc1'));
      expect(proc.name, equals('Main Procedure'));
      expect(proc.steps, isEmpty);
      expect(proc.description, isNull);
      expect(proc.version, isNull);
      expect(proc.inputs, isNull);
      expect(proc.outputs, isNull);
      expect(proc.qualityGates, isNull);
      expect(proc.retrieverRefs, isNull);
    });

    test('constructor with all fields', () {
      final proc = Procedure(
        id: 'proc1',
        name: 'Analysis',
        description: 'Analyzes input data',
        version: '2.0.0',
        inputs: [],
        outputs: [],
        steps: [],
        qualityGates: [
          QualityGate(id: 'g1', type: 'threshold'),
        ],
        retrieverRefs: ['r1', 'r2'],
      );

      expect(proc.description, equals('Analyzes input data'));
      expect(proc.version, equals('2.0.0'));
      expect(proc.inputs, isEmpty);
      expect(proc.outputs, isEmpty);
      expect(proc.qualityGates!.length, equals(1));
      expect(proc.retrieverRefs, equals(['r1', 'r2']));
    });

    test('fromJson/toJson round-trip with minimal data', () {
      final json = {
        'id': 'proc1',
        'name': 'Test',
        'steps': [
          {
            'id': 's1',
            'order': 1,
            'name': 'Step 1',
            'action': {'type': 'llm', 'prompt': 'Hello'},
          },
        ],
      };
      final proc = Procedure.fromJson(json);
      final result = proc.toJson();

      expect(result['id'], equals('proc1'));
      expect(result['name'], equals('Test'));
      expect((result['steps'] as List).length, equals(1));
      expect(result.containsKey('description'), isFalse);
      expect(result.containsKey('version'), isFalse);
      expect(result.containsKey('inputs'), isFalse);
      expect(result.containsKey('outputs'), isFalse);
      expect(result.containsKey('qualityGates'), isFalse);
      expect(result.containsKey('retrieverRefs'), isFalse);
    });

    test('fromJson/toJson round-trip with all fields', () {
      final json = {
        'id': 'proc1',
        'name': 'Full Procedure',
        'description': 'A complete procedure',
        'version': '1.2.0',
        'inputs': [
          {'name': 'query', 'type': 'string', 'required': true},
        ],
        'outputs': [
          {'name': 'result', 'type': 'object', 'required': true},
        ],
        'steps': [
          {
            'id': 's1',
            'order': 1,
            'name': 'Analyze',
            'action': {'type': 'llm', 'prompt': 'Analyze: \${inputs.query}'},
          },
        ],
        'qualityGates': [
          {'id': 'g1', 'type': 'threshold', 'config': {'min': 0.7}, 'blocking': true},
        ],
        'retrieverRefs': ['r1'],
      };
      final proc = Procedure.fromJson(json);
      final result = proc.toJson();

      expect(result['description'], equals('A complete procedure'));
      expect(result['version'], equals('1.2.0'));
      expect((result['inputs'] as List).length, equals(1));
      expect((result['outputs'] as List).length, equals(1));
      expect((result['qualityGates'] as List).length, equals(1));
      expect(result['retrieverRefs'], equals(['r1']));
    });

    test('fromJson with empty map uses defaults', () {
      final proc = Procedure.fromJson({});

      expect(proc.id, equals(''));
      expect(proc.name, equals(''));
      expect(proc.steps, isEmpty);
    });

    test('toString with version', () {
      final proc = Procedure(
        id: 'proc1',
        name: 'Test',
        version: '2.0.0',
        steps: [],
      );

      expect(proc.toString(), equals('Procedure(proc1: Test v2.0.0)'));
    });

    test('toString without version uses default', () {
      final proc = Procedure(
        id: 'proc1',
        name: 'Test',
        steps: [],
      );

      expect(proc.toString(), equals('Procedure(proc1: Test v1.0.0)'));
    });
  });
}
