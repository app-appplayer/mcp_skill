import 'package:test/test.dart';
import 'package:mcp_skill/src/evaluation/measurement_extractor.dart';
import 'package:mcp_skill/src/evaluation/rubric.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';
import 'package:mcp_bundle/mcp_bundle.dart' show RetrievalPort, RetrieverInfo;
import 'package:mcp_bundle/src/types/knowledge_types.dart';

void main() {
  group('MeasurementExtractorRegistry', () {
    test('registers built-in extractors on construction', () {
      final registry = MeasurementExtractorRegistry();

      expect(registry.hasExtractor('code_complexity'), isTrue);
      expect(registry.hasExtractor('security_scan'), isTrue);
      expect(registry.hasExtractor('test_coverage'), isTrue);
      expect(registry.hasExtractor('documentation_check'), isTrue);
      expect(registry.hasExtractor('dependency_audit'), isTrue);
      expect(registry.hasExtractor('metric_query'), isTrue);
      expect(registry.hasExtractor('manual'), isTrue);
    });

    test('does not register llm_extraction without LLM port', () {
      final registry = MeasurementExtractorRegistry();

      expect(registry.hasExtractor('llm_extraction'), isFalse);
    });

    test('getExtractor returns correct extractor type', () {
      final registry = MeasurementExtractorRegistry();

      expect(
        registry.getExtractor('code_complexity', 'dim1'),
        isA<CodeComplexityExtractor>(),
      );
      expect(
        registry.getExtractor('security_scan', 'dim1'),
        isA<SecurityScanExtractor>(),
      );
      expect(
        registry.getExtractor('test_coverage', 'dim1'),
        isA<TestCoverageExtractor>(),
      );
      expect(
        registry.getExtractor('documentation_check', 'dim1'),
        isA<DocumentationExtractor>(),
      );
      expect(
        registry.getExtractor('dependency_audit', 'dim1'),
        isA<DependencyAuditExtractor>(),
      );
      expect(
        registry.getExtractor('metric_query', 'dim1'),
        isA<MetricQueryExtractor>(),
      );
      expect(
        registry.getExtractor('manual', 'dim1'),
        isA<ManualExtractor>(),
      );
    });

    test('getExtractor passes dimensionId to extractor', () {
      final registry = MeasurementExtractorRegistry();

      final extractor = registry.getExtractor('code_complexity', 'my-dim');

      expect(extractor.dimensionId, 'my-dim');
    });

    test('getExtractor throws for unknown extractor type', () {
      final registry = MeasurementExtractorRegistry();

      expect(
        () => registry.getExtractor('nonexistent', 'dim1'),
        throwsA(isA<UnknownExtractorException>()),
      );
    });

    test('register allows overriding built-in extractors', () {
      final registry = MeasurementExtractorRegistry();

      registry.register(
          'code_complexity', (dimId) => ManualExtractor(dimId));

      // Now 'code_complexity' returns ManualExtractor instead
      expect(
        registry.getExtractor('code_complexity', 'dim1'),
        isA<ManualExtractor>(),
      );
    });

    test('register allows adding custom extractor types', () {
      final registry = MeasurementExtractorRegistry();

      registry.register(
          'custom_extractor', (dimId) => ManualExtractor(dimId));

      expect(registry.hasExtractor('custom_extractor'), isTrue);
      expect(
        registry.getExtractor('custom_extractor', 'dim1'),
        isA<ManualExtractor>(),
      );
    });
  });

  group('ExtractorConfig', () {
    test('constructor sets optional fields', () {
      const config = ExtractorConfig(
        metric: 'cyclomatic_complexity',
        query: 'SELECT *',
        retrieverRef: 'metrics',
        extractionPrompt: 'Extract...',
        additional: {'key': 'value'},
      );

      expect(config.metric, 'cyclomatic_complexity');
      expect(config.query, 'SELECT *');
      expect(config.retrieverRef, 'metrics');
      expect(config.extractionPrompt, 'Extract...');
      expect(config.additional, {'key': 'value'});
    });

    test('fromJson parses all fields', () {
      final config = ExtractorConfig.fromJson({
        'metric': 'lines_of_code',
        'query': 'q',
        'retrieverRef': 'ref',
        'extractionPrompt': 'prompt',
        'additional': {'foo': 'bar'},
      });

      expect(config.metric, 'lines_of_code');
      expect(config.query, 'q');
      expect(config.retrieverRef, 'ref');
      expect(config.extractionPrompt, 'prompt');
      expect(config.additional, {'foo': 'bar'});
    });

    test('fromJson handles empty JSON', () {
      final config = ExtractorConfig.fromJson({});

      expect(config.metric, isNull);
      expect(config.query, isNull);
      expect(config.retrieverRef, isNull);
      expect(config.extractionPrompt, isNull);
      expect(config.additional, isNull);
    });
  });

  group('CodeComplexityExtractor', () {
    late CodeComplexityExtractor extractor;
    late Artifact artifact;

    setUp(() {
      extractor = CodeComplexityExtractor('complexity');
    });

    test('dimensionId is set correctly', () {
      expect(extractor.dimensionId, 'complexity');
    });

    test('calculates cyclomatic complexity by default', () async {
      artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
void main() {
  if (condition) {
    for (var i = 0; i < 10; i++) {
      while (running) {
        doSomething();
      }
    }
  } else if (other) {
    handle();
  }
}
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.dimensionId, 'complexity');
      expect(result.value, isA<double>());
      expect((result.value as double), greaterThan(1.0));
      expect(result.confidence, 1.0);
      expect(result.source.type, MeasurementSourceType.codeAnalysis);
      expect(result.metadata?['metric'], 'cyclomatic_complexity');
    });

    test('counts lines of code when metric is lines_of_code', () async {
      artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
// This is a comment
void main() {
  var x = 1;

  var y = 2;
}
''',
      );

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(metric: 'lines_of_code'),
      );

      // Should count non-empty, non-comment lines
      // "void main() {", "var x = 1;", "var y = 2;", "}" = 4 lines
      expect(result.value, isA<double>());
      expect((result.value as double), greaterThanOrEqualTo(3.0));
      expect(result.metadata?['metric'], 'lines_of_code');
    });

    test('calculates nesting depth when metric is nesting_depth', () async {
      artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
void main() {
  if (a) {
    if (b) {
      doSomething();
    }
  }
}
''',
      );

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(metric: 'nesting_depth'),
      );

      // Three levels of nesting: main{}, if(a){}, if(b){}
      expect(result.value, isA<double>());
      expect((result.value as double), greaterThanOrEqualTo(3.0));
    });

    test('handles empty content', () async {
      artifact = const Artifact(id: 'art-1', type: 'code', content: '');

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.value, isA<double>());
      // Base complexity = 1
      expect((result.value as double), 1.0);
    });

    test('handles null content', () async {
      artifact = const Artifact(id: 'art-1', type: 'code', content: null);

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.value, isA<double>());
      expect((result.value as double), 1.0);
    });
  });

  group('SecurityScanExtractor', () {
    late SecurityScanExtractor extractor;

    setUp(() {
      extractor = SecurityScanExtractor('security');
    });

    test('returns 100 for clean code with no vulnerabilities', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
void main() {
  final greeting = 'Hello World';
}
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.dimensionId, 'security');
      expect(result.value, isA<double>());
      expect((result.value as double), 100.0);
      expect(result.confidence, 0.95);
      expect(result.metadata?['findingCount'], 0);
    });

    test('penalizes hardcoded secrets', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
var password = "supersecret123";
var api_key = "key-abc-123";
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), lessThan(100.0));
      expect((result.metadata?['findingCount'] as int), greaterThan(0));
    });

    test('detects eval usage as high severity', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
var result = eval(userInput);
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), lessThan(100.0));
      final findings =
          result.metadata?['findings'] as List<Map<String, dynamic>>;
      expect(findings.any((f) => f['type'] == 'eval_usage'), isTrue);
    });

    test('detects non-localhost HTTP URLs as medium severity', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
var url = "http://example.com/api";
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), lessThan(100.0));
    });

    test('does not flag http://localhost as a vulnerability', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
var url = "http://localhost:3000/api";
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), 100.0);
    });

    test('score is never below 0', () async {
      // Multiple critical + high findings should not go below 0
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
var password = "secret1";
var secret = "secret2";
var api_key = "secret3";
var apikey = "secret4";
eval(input1);
eval(input2);
eval(input3);
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), greaterThanOrEqualTo(0.0));
    });
  });

  group('TestCoverageExtractor', () {
    late TestCoverageExtractor extractor;

    setUp(() {
      extractor = TestCoverageExtractor('coverage');
    });

    test('uses metadata coverage when available', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: 'some content',
        metadata: {'coverage': 85.5},
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.dimensionId, 'coverage');
      expect(result.value, 85.5);
      expect(result.confidence, 1.0);
    });

    test('estimates 70% coverage when test keywords present', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
test('should do something', () {
  expect(result, isTrue);
});
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.value, 70.0);
      expect(result.confidence, 0.7);
    });

    test('estimates 0% coverage when no test keywords present', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
void main() {
  var x = 1 + 2;
}
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.value, 0.0);
      expect(result.confidence, 0.7);
    });
  });

  group('DocumentationExtractor', () {
    late DocumentationExtractor extractor;

    setUp(() {
      extractor = DocumentationExtractor('docs');
    });

    test('returns 100 when no functions/classes exist', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: 'var x = 1;',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.dimensionId, 'docs');
      expect(result.value, 100.0);
      expect(result.confidence, 0.9);
    });

    test('returns high score when doc comments match functions', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
/// Does something.
void doSomething() {}

/// Also does something.
String getName() { return ""; }
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), greaterThan(50.0));
    });

    test('returns low score when functions have no doc comments', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: '''
void doSomething() {}
String getName() { return ""; }
int calculate() { return 0; }
Future doAsync() async {}
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect((result.value as double), 0.0);
    });
  });

  group('DependencyAuditExtractor', () {
    late DependencyAuditExtractor extractor;

    setUp(() {
      extractor = DependencyAuditExtractor('deps');
    });

    test('returns 100 for no dependency declarations', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'code',
        content: 'void main() {}',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      expect(result.dimensionId, 'deps');
      expect(result.value, 100.0);
      expect(result.confidence, 0.85);
    });

    test('scores higher when range versions are used', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'yaml',
        content: '''
dependencies:
  meta: ^1.9.0
  test: ^1.24.0
  lints: ^3.0.0
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      // Has dependencies with range specifiers
      expect((result.value as double), greaterThanOrEqualTo(60.0));
    });

    test('scores lower with all pinned versions', () async {
      final artifact = const Artifact(
        id: 'art-1',
        type: 'yaml',
        content: '''
dependencies:
  meta: 1.9.0
  test: 1.24.0
  lints: 3.0.0
''',
      );

      final result =
          await extractor.extract(artifact, const ExtractorConfig());

      // All pinned, rangeRatio = 0 -> score = 60
      expect((result.value as double), closeTo(60.0, 0.01));
    });
  });

  group('ManualExtractor', () {
    late ManualExtractor extractor;

    setUp(() {
      extractor = ManualExtractor('manual-dim');
    });

    test('returns value from config additional field', () async {
      final artifact =
          const Artifact(id: 'art-1', type: 'code', content: 'x');

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(additional: {'value': 75.0}),
      );

      expect(result.dimensionId, 'manual-dim');
      expect(result.value, 75.0);
      expect(result.confidence, 1.0);
      expect(result.source.type, MeasurementSourceType.manual);
    });

    test('defaults to 0.0 when no value in config', () async {
      final artifact =
          const Artifact(id: 'art-1', type: 'code', content: 'x');

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(),
      );

      expect(result.value, 0.0);
    });
  });

  group('MetricQueryExtractor', () {
    late MetricQueryExtractor extractor;

    test('returns default when no retrieval port provided', () async {
      extractor = MetricQueryExtractor('metric-dim', null);
      final artifact =
          const Artifact(id: 'art-1', type: 'code', content: 'x');

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(),
      );

      expect(result.dimensionId, 'metric-dim');
      expect(result.value, 0.0);
      expect(result.confidence, 0.5);
      expect(result.source.type, MeasurementSourceType.metricQuery);
      expect(result.metadata?['warning'], isNotNull);
    });

    test('returns parsed value when retrieval returns passages', () async {
      final mockPort = _MockRetrievalPortForMetric(
        passages: [
          const RetrievedPassage(id: 'p1', content: '42.5', score: 1.0),
        ],
      );
      extractor = MetricQueryExtractor('metric-dim', mockPort);
      final artifact =
          const Artifact(id: 'art-1', type: 'code', content: 'x');

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(retrieverRef: 'metrics'),
      );

      expect(result.dimensionId, 'metric-dim');
      expect(result.value, 42.5);
      expect(result.confidence, 1.0);
    });

    test('returns default when retrieval returns empty passages', () async {
      final mockPort = _MockRetrievalPortForMetric(passages: []);
      extractor = MetricQueryExtractor('metric-dim', mockPort);
      final artifact =
          const Artifact(id: 'art-1', type: 'code', content: 'x');

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(),
      );

      expect(result.value, 0.0);
      expect(result.confidence, 0.5);
      expect(result.metadata?['warning'], isNotNull);
    });

    test('returns default when retrieval throws', () async {
      final mockPort = _MockRetrievalPortForMetric(shouldThrow: true);
      extractor = MetricQueryExtractor('metric-dim', mockPort);
      final artifact =
          const Artifact(id: 'art-1', type: 'code', content: 'x');

      final result = await extractor.extract(
        artifact,
        const ExtractorConfig(),
      );

      expect(result.value, 0.0);
      expect(result.confidence, 0.5);
    });

    test('registry passes retrievalPort to MetricQueryExtractor', () {
      final mockPort = _MockRetrievalPortForMetric(passages: []);
      final registry = MeasurementExtractorRegistry(
        retrievalPort: mockPort,
      );

      final extractor = registry.getExtractor('metric_query', 'dim-1');
      expect(extractor, isA<MetricQueryExtractor>());
      expect(
        (extractor as MetricQueryExtractor).retrievalPort,
        same(mockPort),
      );
    });
  });

  group('UnknownExtractorException', () {
    test('contains extractor type in message', () {
      final exception = UnknownExtractorException('fancy_extractor');

      expect(exception.extractorType, 'fancy_extractor');
      expect(exception.toString(), contains('fancy_extractor'));
    });
  });
}

/// Minimal mock RetrievalPort for MetricQueryExtractor tests.
class _MockRetrievalPortForMetric implements RetrievalPort {
  final List<RetrievedPassage> passages;
  final bool shouldThrow;

  _MockRetrievalPortForMetric({
    this.passages = const [],
    this.shouldThrow = false,
  });

  @override
  Future<RetrievalResult> queryKnowledge(
    String query, {
    String? retrieverId,
    Map<String, dynamic>? filters,
    int? maxResults,
  }) async {
    if (shouldThrow) throw Exception('query failed');
    return RetrievalResult(passages: passages);
  }

  @override
  Future<List<RetrieverInfo>> listRetrievers() async => const [];
}
