import 'dart:convert';

import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/bundle_loader.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart';

void main() {
  group('DefaultBundleLoader', () {
    late DefaultBundleLoader loader;

    setUp(() {
      loader = DefaultBundleLoader();
    });

    // Helper to build a valid bundle JSON map
    Map<String, dynamic> validBundleJson({
      String id = 'com.test.skill',
      String name = 'Test Skill',
      String version = '1.0.0',
      String provider = 'test-provider',
      String schemaVersion = '0.1.0',
      List<Map<String, dynamic>>? procedures,
    }) {
      return {
        'schemaVersion': schemaVersion,
        'manifest': {
          'id': id,
          'name': name,
          'version': version,
          'provider': provider,
        },
        'procedures': procedures ??
            [
              {
                'id': 'proc-1',
                'name': 'Main Procedure',
                'steps': [
                  {
                    'id': 'step-1',
                    'order': 1,
                    'name': 'Step One',
                    'action': {'type': 'llm', 'prompt': 'Hello'},
                  },
                ],
              },
            ],
      };
    }

    group('loadJson', () {
      test('returns SkillBundle from valid JSON map', () async {
        final json = validBundleJson();
        final bundle = await loader.loadJson(json);

        expect(bundle, isA<SkillBundle>());
        expect(bundle.manifest.id, equals('com.test.skill'));
        expect(bundle.manifest.name, equals('Test Skill'));
        expect(bundle.manifest.version, equals('1.0.0'));
        expect(bundle.manifest.provider, equals('test-provider'));
        expect(bundle.schemaVersion, equals('0.1.0'));
      });

      test('parses procedures correctly', () async {
        final json = validBundleJson();
        final bundle = await loader.loadJson(json);

        expect(bundle.procedures, hasLength(1));
        expect(bundle.procedures.first.id, equals('proc-1'));
        expect(bundle.procedures.first.name, equals('Main Procedure'));
        expect(bundle.procedures.first.steps, hasLength(1));
      });

      test('parses multiple procedures', () async {
        final json = validBundleJson(procedures: [
          {
            'id': 'proc-1',
            'name': 'Procedure One',
            'steps': [
              {
                'id': 's1',
                'order': 1,
                'name': 'Step 1',
                'action': {'type': 'llm'},
              },
            ],
          },
          {
            'id': 'proc-2',
            'name': 'Procedure Two',
            'steps': [
              {
                'id': 's2',
                'order': 1,
                'name': 'Step 2',
                'action': {'type': 'tool'},
              },
            ],
          },
        ]);
        final bundle = await loader.loadJson(json);

        expect(bundle.procedures, hasLength(2));
        expect(bundle.procedures[0].id, equals('proc-1'));
        expect(bundle.procedures[1].id, equals('proc-2'));
      });

      test('uses defaults for missing optional fields', () async {
        final json = <String, dynamic>{
          'manifest': {
            'id': 'com.minimal.skill',
            'name': 'Minimal',
            'version': '1.0.0',
            'provider': 'test',
          },
          'procedures': <dynamic>[],
        };
        final bundle = await loader.loadJson(json);

        expect(bundle.schemaVersion, equals('0.1.0'));
        expect(bundle.assets, isNull);
        expect(bundle.knowledgeSources, isNull);
        expect(bundle.retrievers, isNull);
        expect(bundle.indexes, isNull);
        expect(bundle.rubrics, isNull);
        expect(bundle.validators, isNull);
        expect(bundle.ui, isNull);
        expect(bundle.tests, isNull);
        expect(bundle.extensions, isNull);
      });

      test('uses default manifest values when manifest keys are missing',
          () async {
        final json = <String, dynamic>{
          'manifest': <String, dynamic>{},
          'procedures': <dynamic>[],
        };
        final bundle = await loader.loadJson(json);

        expect(bundle.manifest.id, equals(''));
        expect(bundle.manifest.name, equals(''));
        expect(bundle.manifest.version, equals('1.0.0'));
        expect(bundle.manifest.provider, equals(''));
      });

      test('parses optional sections when present', () async {
        final json = validBundleJson();
        json['assets'] = [
          {'id': 'asset-1', 'type': 'text', 'content': 'Hello'},
        ];
        json['extensions'] = {'custom': 'data'};
        final bundle = await loader.loadJson(json);

        expect(bundle.assets, isNotNull);
        expect(bundle.assets, hasLength(1));
        expect(bundle.assets!.first.id, equals('asset-1'));
        expect(bundle.extensions, equals({'custom': 'data'}));
      });

      test('handles empty procedures list', () async {
        final json = validBundleJson(procedures: []);
        final bundle = await loader.loadJson(json);

        expect(bundle.procedures, isEmpty);
      });

      test('throws TypeError for completely wrong structure', () async {
        // A JSON that tries to pass a string where a list is expected
        final json = <String, dynamic>{
          'manifest': 'not-a-map',
          'procedures': [],
        };
        expect(
          () => loader.loadJson(json),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('loadString', () {
      test('parses valid JSON string into SkillBundle', () async {
        final jsonMap = validBundleJson();
        final jsonString = jsonEncode(jsonMap);

        final bundle = await loader.loadString(jsonString);

        expect(bundle, isA<SkillBundle>());
        expect(bundle.manifest.id, equals('com.test.skill'));
        expect(bundle.manifest.name, equals('Test Skill'));
      });

      test('handles JSON string with unicode characters', () async {
        final jsonMap = validBundleJson(name: 'Test \u00e9\u00e8\u00ea Skill');
        final jsonString = jsonEncode(jsonMap);

        final bundle = await loader.loadString(jsonString);

        expect(bundle.manifest.name, equals('Test \u00e9\u00e8\u00ea Skill'));
      });

      test('throws FormatException for invalid JSON string', () async {
        expect(
          () => loader.loadString('not json at all'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for empty string', () async {
        expect(
          () => loader.loadString(''),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws TypeError for JSON array instead of object', () async {
        expect(
          () => loader.loadString('[1, 2, 3]'),
          throwsA(isA<TypeError>()),
        );
      });

      test('throws FormatException for truncated JSON', () async {
        expect(
          () => loader.loadString('{"manifest": {"id": "test"'),
          throwsA(isA<FormatException>()),
        );
      });

      test('round-trips through toJson and back', () async {
        final original = validBundleJson(
          id: 'com.round.trip',
          name: 'Round Trip',
          version: '2.0.0',
        );
        final bundle1 = await loader.loadJson(original);
        final bundle2 = await loader.loadString(jsonEncode(bundle1.toJson()));

        expect(bundle2.manifest.id, equals(bundle1.manifest.id));
        expect(bundle2.manifest.name, equals(bundle1.manifest.name));
        expect(bundle2.manifest.version, equals(bundle1.manifest.version));
        expect(bundle2.procedures.length, equals(bundle1.procedures.length));
      });
    });

    group('BundleLoader abstract interface', () {
      test('DefaultBundleLoader is a BundleLoader', () {
        expect(loader, isA<BundleLoader>());
      });
    });
  });
}
