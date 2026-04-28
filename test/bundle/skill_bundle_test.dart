import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart';
import 'package:mcp_skill/src/definition/procedure.dart';

void main() {
  group('Author', () {
    test('constructor with required fields', () {
      final author = Author(name: 'Jane Doe');

      expect(author.name, equals('Jane Doe'));
      expect(author.email, isNull);
      expect(author.url, isNull);
    });

    test('constructor with all fields', () {
      final author = Author(
        name: 'Jane Doe',
        email: 'jane@example.com',
        url: 'https://example.com',
      );

      expect(author.name, equals('Jane Doe'));
      expect(author.email, equals('jane@example.com'));
      expect(author.url, equals('https://example.com'));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'url': 'https://example.com',
      };
      final author = Author.fromJson(json);
      final result = author.toJson();

      expect(result['name'], equals('Jane Doe'));
      expect(result['email'], equals('jane@example.com'));
      expect(result['url'], equals('https://example.com'));
    });

    test('toJson excludes null fields', () {
      final author = Author(name: 'Jane Doe');
      final json = author.toJson();

      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('url'), isFalse);
    });

    test('fromJson with empty map uses defaults', () {
      final author = Author.fromJson({});

      expect(author.name, equals(''));
      expect(author.email, isNull);
    });
  });

  group('Asset', () {
    test('constructor with required fields', () {
      final asset = Asset(id: 'a1', type: 'text');

      expect(asset.id, equals('a1'));
      expect(asset.type, equals('text'));
      expect(asset.path, isNull);
      expect(asset.content, isNull);
      expect(asset.metadata, isNull);
    });

    test('constructor with all fields', () {
      final asset = Asset(
        id: 'a1',
        type: 'markdown',
        path: 'docs/readme.md',
        content: '# Hello',
        metadata: {'encoding': 'utf-8'},
      );

      expect(asset.path, equals('docs/readme.md'));
      expect(asset.content, equals('# Hello'));
      expect(asset.metadata!['encoding'], equals('utf-8'));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'a1',
        'type': 'image',
        'path': 'img/logo.png',
        'metadata': {'size': 1024},
      };
      final asset = Asset.fromJson(json);
      final result = asset.toJson();

      expect(result['id'], equals('a1'));
      expect(result['type'], equals('image'));
      expect(result['path'], equals('img/logo.png'));
      expect(result['metadata'], equals({'size': 1024}));
      expect(result.containsKey('content'), isFalse);
    });

    test('fromJson with empty map uses defaults', () {
      final asset = Asset.fromJson({});

      expect(asset.id, equals(''));
      expect(asset.type, equals('text'));
    });
  });

  group('KnowledgeSource', () {
    test('constructor with required fields', () {
      final ks = KnowledgeSource(id: 'ks1', type: 'file');

      expect(ks.id, equals('ks1'));
      expect(ks.type, equals('file'));
      expect(ks.config, isEmpty);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'ks1',
        'type': 'database',
        'config': {'connection': 'postgres://localhost'},
      };
      final ks = KnowledgeSource.fromJson(json);
      final result = ks.toJson();

      expect(result['id'], equals('ks1'));
      expect(result['type'], equals('database'));
      expect(result['config'], equals({'connection': 'postgres://localhost'}));
    });

    test('toJson excludes empty config', () {
      final ks = KnowledgeSource(id: 'ks1', type: 'file');
      final json = ks.toJson();

      expect(json.containsKey('config'), isFalse);
    });
  });

  group('RetrieverConfig', () {
    test('constructor with required fields', () {
      final rc = RetrieverConfig(id: 'r1', type: 'vector');

      expect(rc.id, equals('r1'));
      expect(rc.type, equals('vector'));
      expect(rc.config, isEmpty);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'r1',
        'type': 'hybrid',
        'config': {'topK': 10},
      };
      final rc = RetrieverConfig.fromJson(json);
      final result = rc.toJson();

      expect(result['id'], equals('r1'));
      expect(result['type'], equals('hybrid'));
      expect(result['config'], equals({'topK': 10}));
    });

    test('fromJson with empty map uses defaults', () {
      final rc = RetrieverConfig.fromJson({});

      expect(rc.id, equals(''));
      expect(rc.type, equals('vector'));
    });
  });

  group('IndexConfig', () {
    test('constructor with required fields', () {
      final ic = IndexConfig(id: 'i1', type: 'vector');

      expect(ic.id, equals('i1'));
      expect(ic.type, equals('vector'));
      expect(ic.config, isEmpty);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'i1',
        'type': 'keyword',
        'config': {'analyzer': 'standard'},
      };
      final ic = IndexConfig.fromJson(json);
      final result = ic.toJson();

      expect(result['id'], equals('i1'));
      expect(result['type'], equals('keyword'));
      expect(result['config'], equals({'analyzer': 'standard'}));
    });

    test('fromJson with empty map uses defaults', () {
      final ic = IndexConfig.fromJson({});

      expect(ic.id, equals(''));
      expect(ic.type, equals('vector'));
    });
  });

  group('RubricDimension', () {
    test('constructor with required fields', () {
      final dim = RubricDimension(id: 'd1', name: 'Accuracy');

      expect(dim.id, equals('d1'));
      expect(dim.name, equals('Accuracy'));
      expect(dim.maxScore, equals(10));
    });

    test('constructor with custom maxScore', () {
      final dim = RubricDimension(id: 'd1', name: 'Quality', maxScore: 5);

      expect(dim.maxScore, equals(5));
    });

    test('fromJson/toJson round-trip', () {
      final json = {'id': 'd1', 'name': 'Clarity', 'maxScore': 20};
      final dim = RubricDimension.fromJson(json);
      final result = dim.toJson();

      expect(result['id'], equals('d1'));
      expect(result['name'], equals('Clarity'));
      expect(result['maxScore'], equals(20));
    });
  });

  group('BundleRubric', () {
    test('constructor with required fields', () {
      final rubric = BundleRubric(id: 'rb1', name: 'Quality Rubric');

      expect(rubric.id, equals('rb1'));
      expect(rubric.name, equals('Quality Rubric'));
      expect(rubric.dimensions, isEmpty);
    });

    test('constructor with dimensions', () {
      final rubric = BundleRubric(
        id: 'rb1',
        name: 'Quality Rubric',
        dimensions: [
          RubricDimension(id: 'd1', name: 'Accuracy'),
          RubricDimension(id: 'd2', name: 'Completeness'),
        ],
      );

      expect(rubric.dimensions.length, equals(2));
      expect(rubric.dimensions[0].name, equals('Accuracy'));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'rb1',
        'name': 'Eval Rubric',
        'dimensions': [
          {'id': 'd1', 'name': 'Accuracy', 'maxScore': 10},
          {'id': 'd2', 'name': 'Relevance', 'maxScore': 5},
        ],
      };
      final rubric = BundleRubric.fromJson(json);
      final result = rubric.toJson();

      expect(result['id'], equals('rb1'));
      expect(result['name'], equals('Eval Rubric'));
      expect((result['dimensions'] as List).length, equals(2));
    });
  });

  group('BundleValidator', () {
    test('constructor with required fields', () {
      final v = BundleValidator(id: 'v1', type: 'json');

      expect(v.id, equals('v1'));
      expect(v.type, equals('json'));
      expect(v.config, isEmpty);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'v1',
        'type': 'schema',
        'config': {'strict': true},
      };
      final v = BundleValidator.fromJson(json);
      final result = v.toJson();

      expect(result['id'], equals('v1'));
      expect(result['type'], equals('schema'));
      expect(result['config'], equals({'strict': true}));
    });

    test('toJson excludes empty config', () {
      final v = BundleValidator(id: 'v1', type: 'json');
      final json = v.toJson();

      expect(json.containsKey('config'), isFalse);
    });

    test('fromJson with empty map uses defaults', () {
      final v = BundleValidator.fromJson({});

      expect(v.id, equals(''));
      expect(v.type, equals('json'));
    });
  });

  group('UiSection', () {
    test('constructor with no fields', () {
      const ui = UiSection();

      expect(ui.screens, isNull);
      expect(ui.components, isNull);
      expect(ui.theme, isNull);
    });

    test('constructor with all fields', () {
      final ui = UiSection(
        screens: [
          {'id': 's1', 'type': 'form'}
        ],
        components: [
          {'id': 'c1', 'type': 'button'}
        ],
        theme: {'primaryColor': '#FF0000'},
      );

      expect(ui.screens!.length, equals(1));
      expect(ui.components!.length, equals(1));
      expect(ui.theme!['primaryColor'], equals('#FF0000'));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'screens': [
          {'id': 's1'}
        ],
        'theme': {'color': 'blue'},
      };
      final ui = UiSection.fromJson(json);
      final result = ui.toJson();

      expect(result['screens'], isNotNull);
      expect(result['theme'], equals({'color': 'blue'}));
      expect(result.containsKey('components'), isFalse);
    });

    test('toJson excludes null fields', () {
      const ui = UiSection();
      final json = ui.toJson();

      expect(json.containsKey('screens'), isFalse);
      expect(json.containsKey('components'), isFalse);
      expect(json.containsKey('theme'), isFalse);
    });
  });

  group('TestSection', () {
    test('constructor with no fields', () {
      const ts = TestSection();

      expect(ts.evalSets, isNull);
      expect(ts.regressionTests, isNull);
      expect(ts.benchmarks, isNull);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'evalSets': [
          {'id': 'e1', 'name': 'basic'}
        ],
        'regressionTests': [
          {'id': 'r1'}
        ],
        'benchmarks': [
          {'id': 'b1'}
        ],
      };
      final ts = TestSection.fromJson(json);
      final result = ts.toJson();

      expect((result['evalSets'] as List).length, equals(1));
      expect((result['regressionTests'] as List).length, equals(1));
      expect((result['benchmarks'] as List).length, equals(1));
    });

    test('toJson excludes null fields', () {
      const ts = TestSection();
      final json = ts.toJson();

      expect(json.containsKey('evalSets'), isFalse);
      expect(json.containsKey('regressionTests'), isFalse);
      expect(json.containsKey('benchmarks'), isFalse);
    });
  });

  group('SkillManifest', () {
    test('constructor with required fields', () {
      final manifest = SkillManifest(
        id: 'com.example.skill',
        name: 'Test Skill',
        version: '1.0.0',
        provider: 'example',
      );

      expect(manifest.id, equals('com.example.skill'));
      expect(manifest.name, equals('Test Skill'));
      expect(manifest.version, equals('1.0.0'));
      expect(manifest.provider, equals('example'));
      expect(manifest.description, isNull);
      expect(manifest.author, isNull);
      expect(manifest.keywords, isNull);
    });

    test('constructor with all fields', () {
      final manifest = SkillManifest(
        id: 'com.example.skill',
        name: 'Test Skill',
        version: '2.0.0',
        provider: 'example',
        description: 'A test skill',
        longDescription: '# Test\nDetailed description.',
        author: Author(name: 'Jane'),
        license: 'MIT',
        homepage: 'https://example.com',
        repository: 'https://github.com/example/skill',
        keywords: ['test', 'example'],
        category: 'analysis',
        capabilities: ['summarize', 'translate'],
        compat: {'minRuntime': '1.0.0'},
        integrity: {'checksum': 'abc123'},
        defaultLocale: 'en',
        supportedLocales: ['en', 'ko'],
        localizedMetadata: {
          'ko': {'name': 'Test'}
        },
      );

      expect(manifest.description, equals('A test skill'));
      expect(manifest.author!.name, equals('Jane'));
      expect(manifest.keywords!.length, equals(2));
      expect(manifest.capabilities!.length, equals(2));
      expect(manifest.defaultLocale, equals('en'));
      expect(manifest.supportedLocales!.length, equals(2));
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'com.example.skill',
        'name': 'Test Skill',
        'version': '1.0.0',
        'provider': 'example',
        'description': 'A test',
        'author': {'name': 'Jane', 'email': 'jane@test.com'},
        'license': 'MIT',
        'keywords': ['ai'],
        'category': 'analysis',
      };
      final manifest = SkillManifest.fromJson(json);
      final result = manifest.toJson();

      expect(result['id'], equals('com.example.skill'));
      expect(result['name'], equals('Test Skill'));
      expect(result['version'], equals('1.0.0'));
      expect(result['provider'], equals('example'));
      expect(result['description'], equals('A test'));
      expect((result['author'] as Map)['name'], equals('Jane'));
      expect(result['license'], equals('MIT'));
      expect(result['keywords'], equals(['ai']));
    });

    test('toJson excludes null fields', () {
      final manifest = SkillManifest(
        id: 'test',
        name: 'Test',
        version: '1.0.0',
        provider: 'p',
      );
      final json = manifest.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('author'), isFalse);
      expect(json.containsKey('license'), isFalse);
      expect(json.containsKey('keywords'), isFalse);
      expect(json.containsKey('capabilities'), isFalse);
    });

    test('fromJson with empty map uses defaults', () {
      final manifest = SkillManifest.fromJson({});

      expect(manifest.id, equals(''));
      expect(manifest.name, equals(''));
      expect(manifest.version, equals('1.0.0'));
      expect(manifest.provider, equals(''));
    });

    test('toString returns expected format', () {
      final manifest = SkillManifest(
        id: 'com.example.skill',
        name: 'My Skill',
        version: '1.0.0',
        provider: 'example',
      );

      expect(
        manifest.toString(),
        equals('SkillManifest(com.example.skill: My Skill v1.0.0)'),
      );
    });
  });

  group('SkillBundle', () {
    SkillBundle _createBundle({
      String schemaVersion = '0.1.0',
      List<Procedure>? procedures,
      List<Asset>? assets,
      List<KnowledgeSource>? knowledgeSources,
      List<RetrieverConfig>? retrievers,
      List<IndexConfig>? indexes,
      List<BundleRubric>? rubrics,
      List<BundleValidator>? validators,
      UiSection? ui,
      TestSection? tests,
      Map<String, dynamic>? extensions,
    }) {
      return SkillBundle(
        schemaVersion: schemaVersion,
        manifest: SkillManifest(
          id: 'com.test.skill',
          name: 'Test',
          version: '1.0.0',
          provider: 'test',
        ),
        procedures: procedures ??
            [
              Procedure(
                id: 'proc1',
                name: 'Main',
                steps: [],
              ),
            ],
        assets: assets,
        knowledgeSources: knowledgeSources,
        retrievers: retrievers,
        indexes: indexes,
        rubrics: rubrics,
        validators: validators,
        ui: ui,
        tests: tests,
        extensions: extensions,
      );
    }

    test('constructor with required fields', () {
      final bundle = _createBundle();

      expect(bundle.schemaVersion, equals('0.1.0'));
      expect(bundle.manifest.id, equals('com.test.skill'));
      expect(bundle.procedures.length, equals(1));
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

    test('constructor with all optional sections', () {
      final bundle = _createBundle(
        assets: [Asset(id: 'a1', type: 'text')],
        knowledgeSources: [KnowledgeSource(id: 'ks1', type: 'file')],
        retrievers: [RetrieverConfig(id: 'r1', type: 'vector')],
        indexes: [IndexConfig(id: 'i1', type: 'vector')],
        rubrics: [BundleRubric(id: 'rb1', name: 'Quality')],
        validators: [BundleValidator(id: 'v1', type: 'json')],
        ui: const UiSection(),
        tests: const TestSection(),
        extensions: {'customKey': 'customValue'},
      );

      expect(bundle.assets!.length, equals(1));
      expect(bundle.knowledgeSources!.length, equals(1));
      expect(bundle.retrievers!.length, equals(1));
      expect(bundle.indexes!.length, equals(1));
      expect(bundle.rubrics!.length, equals(1));
      expect(bundle.validators!.length, equals(1));
      expect(bundle.ui, isNotNull);
      expect(bundle.tests, isNotNull);
      expect(bundle.extensions!['customKey'], equals('customValue'));
    });

    test('fromJson/toJson round-trip with minimal data', () {
      final json = {
        'schemaVersion': '0.1.0',
        'manifest': {
          'id': 'com.test.skill',
          'name': 'Test',
          'version': '1.0.0',
          'provider': 'test',
        },
        'procedures': [
          {
            'id': 'proc1',
            'name': 'Main',
            'steps': [
              {
                'id': 's1',
                'order': 1,
                'name': 'Step 1',
                'action': {'type': 'llm', 'prompt': 'Hello'},
              },
            ],
          },
        ],
      };
      final bundle = SkillBundle.fromJson(json);
      final result = bundle.toJson();

      expect(result['schemaVersion'], equals('0.1.0'));
      expect((result['manifest'] as Map)['id'], equals('com.test.skill'));
      expect((result['procedures'] as List).length, equals(1));
      expect(result.containsKey('assets'), isFalse);
      expect(result.containsKey('knowledgeSources'), isFalse);
    });

    test('fromJson/toJson round-trip with all sections', () {
      final json = {
        'schemaVersion': '0.1.0',
        'manifest': {
          'id': 'com.test.skill',
          'name': 'Full Skill',
          'version': '2.0.0',
          'provider': 'test',
        },
        'procedures': [
          {
            'id': 'p1',
            'name': 'Proc',
            'steps': [],
          },
        ],
        'assets': [
          {'id': 'a1', 'type': 'text', 'content': 'hello'},
        ],
        'knowledgeSources': [
          {'id': 'ks1', 'type': 'api', 'config': {'url': 'https://api.test'}},
        ],
        'retrievers': [
          {'id': 'r1', 'type': 'vector'},
        ],
        'indexes': [
          {'id': 'i1', 'type': 'keyword'},
        ],
        'rubrics': [
          {
            'id': 'rb1',
            'name': 'Quality',
            'dimensions': [
              {'id': 'd1', 'name': 'Accuracy', 'maxScore': 10}
            ],
          },
        ],
        'validators': [
          {'id': 'v1', 'type': 'schema', 'config': {'strict': true}},
        ],
        'ui': {
          'screens': [
            {'id': 's1'}
          ],
        },
        'tests': {
          'evalSets': [
            {'id': 'e1'}
          ],
        },
        'extensions': {'foo': 'bar'},
      };
      final bundle = SkillBundle.fromJson(json);
      final result = bundle.toJson();

      expect(result.containsKey('assets'), isTrue);
      expect(result.containsKey('knowledgeSources'), isTrue);
      expect(result.containsKey('retrievers'), isTrue);
      expect(result.containsKey('indexes'), isTrue);
      expect(result.containsKey('rubrics'), isTrue);
      expect(result.containsKey('validators'), isTrue);
      expect(result.containsKey('ui'), isTrue);
      expect(result.containsKey('tests'), isTrue);
      expect(result['extensions'], equals({'foo': 'bar'}));
    });

    test('fromJson with empty map uses defaults', () {
      final bundle = SkillBundle.fromJson({});

      expect(bundle.schemaVersion, equals('0.1.0'));
      expect(bundle.manifest.id, equals(''));
      expect(bundle.procedures, isEmpty);
    });

    test('getProcedure returns matching procedure', () {
      final bundle = _createBundle(
        procedures: [
          Procedure(id: 'proc1', name: 'First', steps: []),
          Procedure(id: 'proc2', name: 'Second', steps: []),
        ],
      );

      final result = bundle.getProcedure('proc2');
      expect(result, isNotNull);
      expect(result!.name, equals('Second'));
    });

    test('getProcedure returns null for missing ID', () {
      final bundle = _createBundle();

      expect(bundle.getProcedure('nonexistent'), isNull);
    });

    test('toString returns expected format', () {
      final bundle = _createBundle();

      expect(
        bundle.toString(),
        equals('SkillBundle(com.test.skill v1.0.0, 1 procedures)'),
      );
    });
  });
}
