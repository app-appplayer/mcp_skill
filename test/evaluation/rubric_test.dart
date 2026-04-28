import 'package:test/test.dart';
import 'package:mcp_skill/src/evaluation/rubric.dart';

void main() {
  group('Rubric', () {
    test('constructor sets all fields', () {
      const rubric = Rubric(
        id: 'rubric-1',
        name: 'Code Quality',
        version: '1.0.0',
        description: 'Evaluates code quality',
        dimensions: [],
        weights: {'dim1': 0.5, 'dim2': 0.5},
        thresholds: {'pass': 60.0, 'excellent': 90.0},
        metadata: {'author': 'test'},
      );
      expect(rubric.id, 'rubric-1');
      expect(rubric.name, 'Code Quality');
      expect(rubric.version, '1.0.0');
      expect(rubric.description, 'Evaluates code quality');
      expect(rubric.dimensions, isEmpty);
      expect(rubric.weights, {'dim1': 0.5, 'dim2': 0.5});
      expect(rubric.thresholds, {'pass': 60.0, 'excellent': 90.0});
      expect(rubric.metadata, {'author': 'test'});
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'r1',
        'name': 'Test Rubric',
        'version': '2.0.0',
        'description': 'A rubric',
        'dimensions': [
          {
            'id': 'd1',
            'name': 'Clarity',
            'measurementMethod': 'llm_extraction',
            'measurementType': 'numeric',
            'minScore': 0,
            'maxScore': 100,
            'levels': [
              {'label': 'Good', 'minScore': 70, 'maxScore': 100},
            ],
          },
        ],
        'weights': {'d1': 1.0},
        'thresholds': {'pass': 50.0},
        'metadata': {'source': 'test'},
      };
      final rubric = Rubric.fromJson(json);
      expect(rubric.id, 'r1');
      expect(rubric.dimensions.length, 1);
      expect(rubric.dimensions[0].id, 'd1');
      expect(rubric.dimensions[0].levels.length, 1);

      final reJson = rubric.toJson();
      expect(reJson['id'], 'r1');
      expect(reJson['name'], 'Test Rubric');
      expect(reJson['version'], '2.0.0');
      expect(reJson['description'], 'A rubric');
      expect((reJson['dimensions'] as List).length, 1);
      expect(reJson['weights'], {'d1': 1.0});
      expect(reJson['thresholds'], {'pass': 50.0});
      expect(reJson['metadata'], {'source': 'test'});
    });

    test('fromJson uses defaults for missing values', () {
      final rubric = Rubric.fromJson({});
      expect(rubric.id, '');
      expect(rubric.name, '');
      expect(rubric.version, '1.0.0');
      expect(rubric.description, isNull);
      expect(rubric.dimensions, isEmpty);
      expect(rubric.weights, isEmpty);
      expect(rubric.thresholds, {'pass': 60.0});
    });

    test('toJson omits null optional fields', () {
      const rubric = Rubric(
        id: 'r',
        name: 'n',
        version: 'v',
        dimensions: [],
        weights: {},
        thresholds: {},
      );
      final json = rubric.toJson();
      expect(json.containsKey('description'), false);
      expect(json.containsKey('metadata'), false);
    });

    test('toString contains id, name, version', () {
      const rubric = Rubric(
        id: 'r1',
        name: 'Name',
        version: '3.0',
        dimensions: [],
        weights: {},
        thresholds: {},
      );
      expect(rubric.toString(), contains('r1'));
      expect(rubric.toString(), contains('Name'));
      expect(rubric.toString(), contains('v3.0'));
    });
  });

  group('RubricDimension', () {
    test('constructor defaults', () {
      const dim = RubricDimension(
        id: 'd1',
        name: 'Dim',
        measurementMethod: 'code_complexity',
      );
      expect(dim.measurementType, 'numeric');
      expect(dim.minScore, 0);
      expect(dim.maxScore, 100);
      expect(dim.levels, isEmpty);
      expect(dim.config, isNull);
      expect(dim.description, isNull);
    });

    test('fromJson/toJson round-trip', () {
      final json = {
        'id': 'd1',
        'name': 'Security',
        'description': 'Security checks',
        'measurementMethod': 'security_scan',
        'measurementType': 'boolean',
        'minScore': 0,
        'maxScore': 1,
        'levels': [
          {'label': 'Pass', 'minScore': 1, 'maxScore': 1, 'description': 'Passed all checks'},
        ],
        'config': {'tool': 'semgrep'},
      };
      final dim = RubricDimension.fromJson(json);
      expect(dim.id, 'd1');
      expect(dim.name, 'Security');
      expect(dim.description, 'Security checks');
      expect(dim.measurementMethod, 'security_scan');
      expect(dim.measurementType, 'boolean');
      expect(dim.minScore, 0);
      expect(dim.maxScore, 1);
      expect(dim.levels.length, 1);
      expect(dim.levels[0].description, 'Passed all checks');
      expect(dim.config, {'tool': 'semgrep'});

      final reJson = dim.toJson();
      final restored = RubricDimension.fromJson(reJson);
      expect(restored.id, dim.id);
      expect(restored.measurementMethod, dim.measurementMethod);
    });

    test('fromJson uses defaults for missing values', () {
      final dim = RubricDimension.fromJson({});
      expect(dim.id, '');
      expect(dim.name, '');
      expect(dim.measurementMethod, 'manual');
      expect(dim.measurementType, 'numeric');
      expect(dim.minScore, 0);
      expect(dim.maxScore, 100);
      expect(dim.levels, isEmpty);
    });

    test('toJson omits null/empty optional fields', () {
      const dim = RubricDimension(
        id: 'd',
        name: 'n',
        measurementMethod: 'mm',
      );
      final json = dim.toJson();
      expect(json.containsKey('description'), false);
      expect(json.containsKey('levels'), false);
      expect(json.containsKey('config'), false);
    });

    test('toString contains id and name', () {
      const dim = RubricDimension(id: 'dx', name: 'DimX', measurementMethod: 'mm');
      expect(dim.toString(), contains('dx'));
      expect(dim.toString(), contains('DimX'));
    });
  });

  group('ScoreLevel', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'label': 'Excellent',
        'minScore': 90.0,
        'maxScore': 100.0,
        'description': 'Outstanding quality',
      };
      final level = ScoreLevel.fromJson(json);
      expect(level.label, 'Excellent');
      expect(level.minScore, 90.0);
      expect(level.maxScore, 100.0);
      expect(level.description, 'Outstanding quality');

      final reJson = level.toJson();
      final restored = ScoreLevel.fromJson(reJson);
      expect(restored.label, 'Excellent');
      expect(restored.minScore, 90.0);
    });

    test('fromJson uses defaults for missing values', () {
      final level = ScoreLevel.fromJson({});
      expect(level.label, '');
      expect(level.minScore, 0);
      expect(level.maxScore, 100);
      expect(level.description, isNull);
    });

    test('toJson omits null description', () {
      const level = ScoreLevel(label: 'L', minScore: 0, maxScore: 50);
      final json = level.toJson();
      expect(json.containsKey('description'), false);
    });

    test('toString contains label and score range', () {
      const level = ScoreLevel(label: 'Good', minScore: 70, maxScore: 89);
      expect(level.toString(), contains('Good'));
      expect(level.toString(), contains('70'));
      expect(level.toString(), contains('89'));
    });
  });

  group('EvaluationInput', () {
    test('constructor defaults', () {
      const input = EvaluationInput(
        artifactId: 'art-1',
        artifactType: 'code',
      );
      expect(input.measurements, isEmpty);
      expect(input.asOf, isNull);
      expect(input.context, isNull);
    });

    test('fromJson/toJson round-trip', () {
      final asOf = DateTime(2025, 6, 1, 12, 0, 0);
      final json = {
        'artifactId': 'art-1',
        'artifactType': 'document',
        'measurements': {
          'dim1': {
            'dimensionId': 'dim1',
            'value': 85,
            'confidence': 0.9,
            'source': {'type': 'codeAnalysis', 'tool': 'eslint', 'version': '8.0'},
          },
        },
        'asOf': asOf.toIso8601String(),
        'context': {'env': 'test'},
      };
      final input = EvaluationInput.fromJson(json);
      expect(input.artifactId, 'art-1');
      expect(input.artifactType, 'document');
      expect(input.measurements.length, 1);
      expect(input.measurements['dim1']!.dimensionId, 'dim1');
      expect(input.measurements['dim1']!.value, 85);
      expect(input.measurements['dim1']!.confidence, 0.9);
      expect(input.measurements['dim1']!.source.type, MeasurementSourceType.codeAnalysis);
      expect(input.asOf, asOf);
      expect(input.context, {'env': 'test'});

      final reJson = input.toJson();
      expect(reJson['artifactId'], 'art-1');
      expect(reJson['artifactType'], 'document');
    });

    test('fromJson uses defaults for missing values', () {
      final input = EvaluationInput.fromJson({});
      expect(input.artifactId, '');
      expect(input.artifactType, 'unknown');
      expect(input.measurements, isEmpty);
    });

    test('toJson omits empty/null optional fields', () {
      const input = EvaluationInput(
        artifactId: 'a',
        artifactType: 't',
      );
      final json = input.toJson();
      expect(json.containsKey('measurements'), false);
      expect(json.containsKey('asOf'), false);
      expect(json.containsKey('context'), false);
    });
  });

  group('DimensionMeasurement', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'dimensionId': 'dim1',
        'value': 92.5,
        'confidence': 0.95,
        'source': {'type': 'metricQuery', 'query': 'SELECT ...'},
        'metadata': {'note': 'auto'},
      };
      final m = DimensionMeasurement.fromJson(json);
      expect(m.dimensionId, 'dim1');
      expect(m.value, 92.5);
      expect(m.confidence, 0.95);
      expect(m.source.type, MeasurementSourceType.metricQuery);
      expect(m.source.query, 'SELECT ...');
      expect(m.metadata, {'note': 'auto'});

      final reJson = m.toJson();
      final restored = DimensionMeasurement.fromJson(reJson);
      expect(restored.dimensionId, 'dim1');
      expect(restored.value, 92.5);
    });

    test('toJson omits null optional fields', () {
      const m = DimensionMeasurement(
        dimensionId: 'd',
        value: 10,
        source: MeasurementSource(type: MeasurementSourceType.manual),
      );
      final json = m.toJson();
      expect(json.containsKey('confidence'), false);
      expect(json.containsKey('metadata'), false);
    });

    test('toString contains dimensionId and value', () {
      const m = DimensionMeasurement(
        dimensionId: 'dx',
        value: 42,
        source: MeasurementSource(type: MeasurementSourceType.manual),
      );
      expect(m.toString(), contains('dx'));
      expect(m.toString(), contains('42'));
    });
  });

  group('MeasurementSource', () {
    test('codeAnalysis factory', () {
      final src = MeasurementSource.codeAnalysis(tool: 'eslint', version: '8.0');
      expect(src.type, MeasurementSourceType.codeAnalysis);
      expect(src.tool, 'eslint');
      expect(src.version, '8.0');
    });

    test('metricQuery factory', () {
      final src = MeasurementSource.metricQuery(query: 'SELECT COUNT(*)');
      expect(src.type, MeasurementSourceType.metricQuery);
      expect(src.query, 'SELECT COUNT(*)');
    });

    test('evidenceExtraction factory', () {
      final src = MeasurementSource.evidenceExtraction(evidenceId: 'ev-1');
      expect(src.type, MeasurementSourceType.evidenceExtraction);
      expect(src.evidenceId, 'ev-1');
    });

    test('manual factory', () {
      final src = MeasurementSource.manual(userId: 'user-1');
      expect(src.type, MeasurementSourceType.manual);
      expect(src.userId, 'user-1');
    });

    test('computed factory', () {
      final src = MeasurementSource.computed(expression: 'dim1 * 0.5 + dim2 * 0.5');
      expect(src.type, MeasurementSourceType.computed);
      expect(src.expression, 'dim1 * 0.5 + dim2 * 0.5');
    });

    test('fromJson/toJson round-trip', () {
      final original = MeasurementSource.codeAnalysis(tool: 'tool', version: 'v1');
      final json = original.toJson();
      final restored = MeasurementSource.fromJson(json);
      expect(restored.type, MeasurementSourceType.codeAnalysis);
      expect(restored.tool, 'tool');
      expect(restored.version, 'v1');
    });

    test('fromJson defaults to manual for unknown type', () {
      final src = MeasurementSource.fromJson({'type': 'nonexistent'});
      expect(src.type, MeasurementSourceType.manual);
    });

    test('toJson omits null optional fields', () {
      const src = MeasurementSource(type: MeasurementSourceType.manual);
      final json = src.toJson();
      expect(json['type'], 'manual');
      expect(json.containsKey('tool'), false);
      expect(json.containsKey('version'), false);
      expect(json.containsKey('query'), false);
      expect(json.containsKey('evidenceId'), false);
      expect(json.containsKey('userId'), false);
      expect(json.containsKey('expression'), false);
    });

    test('toString contains type name', () {
      const src = MeasurementSource(type: MeasurementSourceType.computed);
      expect(src.toString(), contains('computed'));
    });
  });

  group('MeasurementSourceType', () {
    test('has all expected values', () {
      expect(MeasurementSourceType.values, hasLength(5));
      expect(MeasurementSourceType.values, contains(MeasurementSourceType.codeAnalysis));
      expect(MeasurementSourceType.values, contains(MeasurementSourceType.metricQuery));
      expect(MeasurementSourceType.values, contains(MeasurementSourceType.evidenceExtraction));
      expect(MeasurementSourceType.values, contains(MeasurementSourceType.manual));
      expect(MeasurementSourceType.values, contains(MeasurementSourceType.computed));
    });

    test('fromString parses known values', () {
      expect(MeasurementSourceType.fromString('codeAnalysis'), MeasurementSourceType.codeAnalysis);
      expect(MeasurementSourceType.fromString('metricQuery'), MeasurementSourceType.metricQuery);
      expect(MeasurementSourceType.fromString('evidenceExtraction'), MeasurementSourceType.evidenceExtraction);
      expect(MeasurementSourceType.fromString('manual'), MeasurementSourceType.manual);
      expect(MeasurementSourceType.fromString('computed'), MeasurementSourceType.computed);
    });

    test('fromString defaults to manual for unknown', () {
      expect(MeasurementSourceType.fromString('unknown'), MeasurementSourceType.manual);
      expect(MeasurementSourceType.fromString(null), MeasurementSourceType.manual);
    });
  });

  group('EvaluationContext', () {
    test('constructor sets fields', () {
      final asOf = DateTime(2025, 1, 1);
      final ctx = EvaluationContext(
        asOf: asOf,
        data: {'key': 'val'},
      );
      expect(ctx.asOf, asOf);
      expect(ctx.data, {'key': 'val'});
    });

    test('default values are null', () {
      const ctx = EvaluationContext();
      expect(ctx.asOf, isNull);
      expect(ctx.data, isNull);
    });
  });

  group('EvaluationResult', () {
    test('fromJson/toJson round-trip', () {
      final evaluatedAt = DateTime(2025, 7, 1, 9, 0, 0);
      final json = {
        'rubricId': 'r1',
        'rubricVersion': '1.0',
        'artifactId': 'a1',
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'overallScore': 85.0,
        'classification': 'good',
        'dimensionScores': [
          {
            'dimensionId': 'd1',
            'rawValue': 90,
            'normalizedScore': 90.0,
            'weight': 0.5,
            'weightedScore': 45.0,
            'level': 'excellent',
            'confidence': 0.95,
          },
        ],
        'passed': true,
        'breakdown': {
          'formula': 'weighted_sum',
          'weights': {'d1': 0.5},
          'thresholdApplied': 'pass',
          'thresholdValue': 60.0,
        },
      };
      final result = EvaluationResult.fromJson(json);
      expect(result.rubricId, 'r1');
      expect(result.rubricVersion, '1.0');
      expect(result.artifactId, 'a1');
      expect(result.evaluatedAt, evaluatedAt);
      expect(result.overallScore, 85.0);
      expect(result.classification, 'good');
      expect(result.dimensionScores.length, 1);
      expect(result.passed, true);
      expect(result.breakdown.formula, 'weighted_sum');

      final reJson = result.toJson();
      expect(reJson['rubricId'], 'r1');
      expect(reJson['overallScore'], 85.0);
      expect(reJson['passed'], true);
      expect((reJson['dimensionScores'] as List).length, 1);
    });

    test('fromJson uses defaults for missing values', () {
      final result = EvaluationResult.fromJson({});
      expect(result.rubricId, '');
      expect(result.rubricVersion, '');
      expect(result.artifactId, '');
      expect(result.overallScore, 0);
      expect(result.classification, 'unknown');
      expect(result.dimensionScores, isEmpty);
      expect(result.passed, false);
    });

    test('toString contains rubricId, score, classification', () {
      final result = EvaluationResult(
        rubricId: 'r1',
        rubricVersion: '1.0',
        artifactId: 'a1',
        evaluatedAt: DateTime.now(),
        overallScore: 75.0,
        classification: 'good',
        dimensionScores: [],
        passed: true,
        breakdown: const ScoreBreakdown(
          formula: 'f',
          weights: {},
          thresholdApplied: 'pass',
          thresholdValue: 60,
        ),
      );
      expect(result.toString(), contains('r1'));
      expect(result.toString(), contains('75.0'));
      expect(result.toString(), contains('good'));
    });
  });

  group('DimensionScore', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'dimensionId': 'd1',
        'rawValue': 88,
        'normalizedScore': 88.0,
        'weight': 0.4,
        'weightedScore': 35.2,
        'level': 'good',
        'confidence': 0.92,
      };
      final score = DimensionScore.fromJson(json);
      expect(score.dimensionId, 'd1');
      expect(score.rawValue, 88);
      expect(score.normalizedScore, 88.0);
      expect(score.weight, 0.4);
      expect(score.weightedScore, 35.2);
      expect(score.level, 'good');
      expect(score.confidence, 0.92);

      final reJson = score.toJson();
      final restored = DimensionScore.fromJson(reJson);
      expect(restored.dimensionId, 'd1');
      expect(restored.normalizedScore, 88.0);
    });

    test('toJson omits null confidence', () {
      const score = DimensionScore(
        dimensionId: 'd',
        rawValue: 50,
        normalizedScore: 50,
        weight: 1.0,
        weightedScore: 50,
        level: 'fair',
      );
      final json = score.toJson();
      expect(json.containsKey('confidence'), false);
    });

    test('toString contains dimensionId and scores', () {
      const score = DimensionScore(
        dimensionId: 'dx',
        rawValue: 77,
        normalizedScore: 77.0,
        weight: 0.5,
        weightedScore: 38.5,
        level: 'good',
      );
      expect(score.toString(), contains('dx'));
      expect(score.toString(), contains('77.0'));
      expect(score.toString(), contains('38.5'));
    });
  });

  group('ScoreBreakdown', () {
    test('fromJson/toJson round-trip', () {
      final json = {
        'formula': 'weighted_average',
        'weights': {'d1': 0.6, 'd2': 0.4},
        'thresholdApplied': 'pass',
        'thresholdValue': 60.0,
      };
      final breakdown = ScoreBreakdown.fromJson(json);
      expect(breakdown.formula, 'weighted_average');
      expect(breakdown.weights, {'d1': 0.6, 'd2': 0.4});
      expect(breakdown.thresholdApplied, 'pass');
      expect(breakdown.thresholdValue, 60.0);

      final reJson = breakdown.toJson();
      final restored = ScoreBreakdown.fromJson(reJson);
      expect(restored.formula, 'weighted_average');
      expect(restored.weights, {'d1': 0.6, 'd2': 0.4});
    });

    test('fromJson uses defaults for missing values', () {
      final breakdown = ScoreBreakdown.fromJson({});
      expect(breakdown.formula, '');
      expect(breakdown.weights, isEmpty);
      expect(breakdown.thresholdApplied, '');
      expect(breakdown.thresholdValue, 0);
    });
  });

  group('ValidationResult', () {
    test('constructor sets all fields', () {
      const result = ValidationResult(
        valid: true,
        errors: ['err1'],
        warnings: ['warn1'],
      );
      expect(result.valid, true);
      expect(result.errors, ['err1']);
      expect(result.warnings, ['warn1']);
    });

    test('defaults to empty lists', () {
      const result = ValidationResult(valid: false);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
    });
  });
}
