import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/capability_types.dart';

void main() {
  group('PortType', () {
    test('has all expected values', () {
      expect(PortType.values, contains(PortType.llm));
      expect(PortType.values, contains(PortType.mcp));
      expect(PortType.values, contains(PortType.knowledge));
      expect(PortType.values, contains(PortType.factGraph));
    });

    test('has exactly 4 values', () {
      expect(PortType.values.length, equals(4));
    });
  });

  group('PortRequirement', () {
    test('constructor with required fields', () {
      final req = PortRequirement(type: PortType.llm);

      expect(req.type, equals(PortType.llm));
      expect(req.required, isTrue);
      expect(req.minVersion, isNull);
      expect(req.features, isNull);
    });

    test('constructor with all fields', () {
      final req = PortRequirement(
        type: PortType.mcp,
        required: false,
        minVersion: '2.0.0',
        features: ['streaming', 'batching'],
      );

      expect(req.type, equals(PortType.mcp));
      expect(req.required, isFalse);
      expect(req.minVersion, equals('2.0.0'));
      expect(req.features, equals(['streaming', 'batching']));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'type': 'llm',
        'required': true,
        'minVersion': '1.0.0',
        'features': ['chat'],
      };
      final req = PortRequirement.fromJson(json);
      final result = req.toJson();

      expect(result['type'], equals('llm'));
      expect(result['required'], isTrue);
      expect(result['minVersion'], equals('1.0.0'));
      expect(result['features'], equals(['chat']));
    });

    test('toJson excludes null fields', () {
      final req = PortRequirement(type: PortType.knowledge);
      final json = req.toJson();

      expect(json.containsKey('minVersion'), isFalse);
      expect(json.containsKey('features'), isFalse);
    });

    test('fromJson with unknown type defaults to mcp', () {
      final req = PortRequirement.fromJson({'type': 'unknown'});

      expect(req.type, equals(PortType.mcp));
    });

    test('fromJson parses all port types', () {
      for (final pt in PortType.values) {
        final req = PortRequirement.fromJson({'type': pt.name});
        expect(req.type, equals(pt));
      }
    });
  });

  group('SkillCapability', () {
    test('constructor with required fields', () {
      final cap = SkillCapability(name: 'summarize');

      expect(cap.name, equals('summarize'));
      expect(cap.description, isNull);
      expect(cap.parameters, isNull);
    });

    test('constructor with all fields', () {
      final cap = SkillCapability(
        name: 'translate',
        description: 'Translates text',
        parameters: {'sourceLang': 'string', 'targetLang': 'string'},
      );

      expect(cap.description, equals('Translates text'));
      expect(cap.parameters!['sourceLang'], equals('string'));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'name': 'analyze',
        'description': 'Analyzes data',
        'parameters': {'depth': 'integer'},
      };
      final cap = SkillCapability.fromJson(json);
      final result = cap.toJson();

      expect(result['name'], equals('analyze'));
      expect(result['description'], equals('Analyzes data'));
      expect(result['parameters'], equals({'depth': 'integer'}));
    });

    test('toJson excludes null fields', () {
      final cap = SkillCapability(name: 'test');
      final json = cap.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('parameters'), isFalse);
    });

    test('fromJson with empty map uses defaults', () {
      final cap = SkillCapability.fromJson({});

      expect(cap.name, equals(''));
    });
  });

  group('ProvidedCapabilities', () {
    test('constructor with defaults', () {
      const pc = ProvidedCapabilities();

      expect(pc.capabilities, isEmpty);
      expect(pc.tags, isEmpty);
    });

    test('constructor with all fields', () {
      final pc = ProvidedCapabilities(
        capabilities: [SkillCapability(name: 'summarize')],
        tags: ['ai', 'nlp'],
      );

      expect(pc.capabilities.length, equals(1));
      expect(pc.tags, equals(['ai', 'nlp']));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'capabilities': [
          {'name': 'summarize', 'description': 'Summarizes text'},
        ],
        'tags': ['ai'],
      };
      final pc = ProvidedCapabilities.fromJson(json);
      final result = pc.toJson();

      expect((result['capabilities'] as List).length, equals(1));
      expect(result['tags'], equals(['ai']));
    });

    test('fromJson with empty map uses defaults', () {
      final pc = ProvidedCapabilities.fromJson({});

      expect(pc.capabilities, isEmpty);
      expect(pc.tags, isEmpty);
    });
  });

  group('RequiredCapabilities', () {
    test('constructor with defaults', () {
      const rc = RequiredCapabilities();

      expect(rc.ports, isEmpty);
      expect(rc.skills, isEmpty);
    });

    test('constructor with all fields', () {
      final rc = RequiredCapabilities(
        ports: [PortRequirement(type: PortType.llm)],
        skills: ['com.example.other'],
      );

      expect(rc.ports.length, equals(1));
      expect(rc.skills, equals(['com.example.other']));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'ports': [
          {'type': 'llm', 'required': true},
          {'type': 'factGraph', 'required': false},
        ],
        'skills': ['dep1', 'dep2'],
      };
      final rc = RequiredCapabilities.fromJson(json);
      final result = rc.toJson();

      expect((result['ports'] as List).length, equals(2));
      expect(result['skills'], equals(['dep1', 'dep2']));
    });

    test('fromJson with empty map uses defaults', () {
      final rc = RequiredCapabilities.fromJson({});

      expect(rc.ports, isEmpty);
      expect(rc.skills, isEmpty);
    });
  });

  group('PortPermission', () {
    test('constructor with required fields', () {
      final pp = PortPermission(port: PortType.llm);

      expect(pp.port, equals(PortType.llm));
      expect(pp.operations, isEmpty);
      expect(pp.readOnly, isFalse);
    });

    test('constructor with all fields', () {
      final pp = PortPermission(
        port: PortType.factGraph,
        operations: ['read', 'write'],
        readOnly: true,
      );

      expect(pp.port, equals(PortType.factGraph));
      expect(pp.operations, equals(['read', 'write']));
      expect(pp.readOnly, isTrue);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'port': 'knowledge',
        'operations': ['query', 'index'],
        'readOnly': true,
      };
      final pp = PortPermission.fromJson(json);
      final result = pp.toJson();

      expect(result['port'], equals('knowledge'));
      expect(result['operations'], equals(['query', 'index']));
      expect(result['readOnly'], isTrue);
    });

    test('fromJson with unknown port defaults to mcp', () {
      final pp = PortPermission.fromJson({'port': 'invalid'});

      expect(pp.port, equals(PortType.mcp));
    });
  });

  group('DataPermission', () {
    test('constructor with required fields', () {
      final dp = DataPermission(scope: 'workspace');

      expect(dp.scope, equals('workspace'));
      expect(dp.operations, isEmpty);
    });

    test('constructor with all fields', () {
      final dp = DataPermission(
        scope: 'user',
        operations: ['read', 'write', 'delete'],
      );

      expect(dp.scope, equals('user'));
      expect(dp.operations, equals(['read', 'write', 'delete']));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'scope': 'global',
        'operations': ['read'],
      };
      final dp = DataPermission.fromJson(json);
      final result = dp.toJson();

      expect(result['scope'], equals('global'));
      expect(result['operations'], equals(['read']));
    });

    test('fromJson with empty map uses defaults', () {
      final dp = DataPermission.fromJson({});

      expect(dp.scope, equals(''));
      expect(dp.operations, isEmpty);
    });
  });

  group('PermissionCapabilities', () {
    test('constructor with defaults', () {
      const pc = PermissionCapabilities();

      expect(pc.portPermissions, isEmpty);
      expect(pc.dataPermissions, isEmpty);
    });

    test('constructor with all fields', () {
      final pc = PermissionCapabilities(
        portPermissions: [
          PortPermission(port: PortType.llm, operations: ['generate']),
        ],
        dataPermissions: [
          DataPermission(scope: 'user', operations: ['read']),
        ],
      );

      expect(pc.portPermissions.length, equals(1));
      expect(pc.dataPermissions.length, equals(1));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'portPermissions': [
          {
            'port': 'llm',
            'operations': ['generate'],
            'readOnly': false,
          },
        ],
        'dataPermissions': [
          {
            'scope': 'workspace',
            'operations': ['read', 'write'],
          },
        ],
      };
      final pc = PermissionCapabilities.fromJson(json);
      final result = pc.toJson();

      expect((result['portPermissions'] as List).length, equals(1));
      expect((result['dataPermissions'] as List).length, equals(1));
    });

    test('fromJson with empty map uses defaults', () {
      final pc = PermissionCapabilities.fromJson({});

      expect(pc.portPermissions, isEmpty);
      expect(pc.dataPermissions, isEmpty);
    });
  });
}
