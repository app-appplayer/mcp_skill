import 'package:test/test.dart';
import 'package:mcp_skill/src/evaluation/rubric_engine.dart';
import 'package:mcp_skill/src/evaluation/rubric.dart';
import 'package:mcp_skill/src/evaluation/measurement_extractor.dart';

void main() {
  // Helper to create a standard rubric with numeric dimensions.
  Rubric _createRubric({
    String id = 'rubric-1',
    String version = '1.0.0',
    List<RubricDimension>? dimensions,
    Map<String, double>? weights,
    Map<String, double>? thresholds,
  }) {
    final dims = dimensions ??
        [
          const RubricDimension(
            id: 'quality',
            name: 'Code Quality',
            measurementMethod: 'code_complexity',
            measurementType: 'numeric',
            minScore: 0,
            maxScore: 100,
            levels: [
              ScoreLevel(label: 'Poor', minScore: 0, maxScore: 39),
              ScoreLevel(label: 'Fair', minScore: 40, maxScore: 69),
              ScoreLevel(label: 'Good', minScore: 70, maxScore: 89),
              ScoreLevel(label: 'Excellent', minScore: 90, maxScore: 100),
            ],
          ),
          const RubricDimension(
            id: 'security',
            name: 'Security',
            measurementMethod: 'security_scan',
            measurementType: 'numeric',
            minScore: 0,
            maxScore: 100,
            levels: [
              ScoreLevel(label: 'Poor', minScore: 0, maxScore: 39),
              ScoreLevel(label: 'Fair', minScore: 40, maxScore: 69),
              ScoreLevel(label: 'Good', minScore: 70, maxScore: 89),
              ScoreLevel(label: 'Excellent', minScore: 90, maxScore: 100),
            ],
          ),
        ];

    return Rubric(
      id: id,
      name: 'Test Rubric',
      version: version,
      dimensions: dims,
      weights: weights ?? {'quality': 0.6, 'security': 0.4},
      thresholds: thresholds ??
          {
            'excellent': 90.0,
            'good': 70.0,
            'pass': 60.0,
          },
    );
  }

  // Helper to create measurement inputs.
  EvaluationInput _createInput({
    String artifactId = 'artifact-1',
    Map<String, DimensionMeasurement>? measurements,
  }) {
    return EvaluationInput(
      artifactId: artifactId,
      artifactType: 'code',
      measurements: measurements ??
          {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 80,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 90,
              confidence: 0.95,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
    );
  }

  late MeasurementExtractorRegistry registry;
  late DefaultRubricEvaluationEngine engine;

  setUp(() {
    registry = MeasurementExtractorRegistry();
    engine = DefaultRubricEvaluationEngine(extractorRegistry: registry);
  });

  group('DefaultRubricEvaluationEngine', () {
    group('evaluate', () {
      test('returns correct overall weighted score', () async {
        final rubric = _createRubric();
        final input = _createInput();

        final result = await engine.evaluate(rubric, input, null);

        // quality: normalized 80/100 * 100 = 80, weighted = 80 * 0.6 = 48
        // security: normalized 90/100 * 100 = 90, weighted = 90 * 0.4 = 36
        // overall = 48 + 36 = 84
        expect(result.overallScore, closeTo(84.0, 0.01));
        expect(result.rubricId, 'rubric-1');
        expect(result.rubricVersion, '1.0.0');
        expect(result.artifactId, 'artifact-1');
      });

      test('classifies score as excellent when above threshold', () async {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 95,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 98,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // quality: 95 * 0.6 = 57, security: 98 * 0.4 = 39.2, overall = 96.2
        expect(result.classification, 'excellent');
        expect(result.passed, isTrue);
      });

      test('classifies score as good when between good and excellent', () async {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 80,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 75,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // quality: 80 * 0.6 = 48, security: 75 * 0.4 = 30, overall = 78
        expect(result.classification, 'good');
        expect(result.passed, isTrue);
      });

      test('classifies score as fail when below all thresholds', () async {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 30,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 20,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // quality: 30 * 0.6 = 18, security: 20 * 0.4 = 8, overall = 26
        expect(result.classification, 'fail');
        expect(result.passed, isFalse);
      });

      test('marks passed=true when overall score >= pass threshold', () async {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 60,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 60,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // overall = 60 * 0.6 + 60 * 0.4 = 60 -> exactly at pass
        expect(result.overallScore, closeTo(60.0, 0.01));
        expect(result.passed, isTrue);
      });

      test('throws RubricValidationException when measurement is missing',
          () async {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 80,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            // 'security' measurement is missing
          },
        );

        expect(
          () => engine.evaluate(rubric, input, null),
          throwsA(isA<RubricValidationException>()),
        );
      });

      test('throws RubricValidationException for type mismatch', () async {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 'not_a_number',
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 90,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        expect(
          () => engine.evaluate(rubric, input, null),
          throwsA(isA<RubricValidationException>()),
        );
      });

      test('produces correct dimension scores with breakdown', () async {
        final rubric = _createRubric();
        final input = _createInput();

        final result = await engine.evaluate(rubric, input, null);

        expect(result.dimensionScores.length, 2);

        final qualityScore =
            result.dimensionScores.firstWhere((s) => s.dimensionId == 'quality');
        expect(qualityScore.normalizedScore, closeTo(80.0, 0.01));
        expect(qualityScore.weight, closeTo(0.6, 0.01));
        expect(qualityScore.weightedScore, closeTo(48.0, 0.01));

        final securityScore = result.dimensionScores
            .firstWhere((s) => s.dimensionId == 'security');
        expect(securityScore.normalizedScore, closeTo(90.0, 0.01));
        expect(securityScore.weight, closeTo(0.4, 0.01));
        expect(securityScore.weightedScore, closeTo(36.0, 0.01));

        expect(result.breakdown.formula, isNotEmpty);
        expect(result.breakdown.weights, {'quality': 0.6, 'security': 0.4});
      });
    });

    group('evaluate with boolean dimensions', () {
      test('normalizes true to 100 and false to 0', () async {
        final rubric = Rubric(
          id: 'bool-rubric',
          name: 'Boolean Rubric',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'has_tests',
              name: 'Has Tests',
              measurementMethod: 'manual',
              measurementType: 'boolean',
            ),
          ],
          weights: const {'has_tests': 1.0},
          thresholds: const {'pass': 50.0},
        );

        final inputTrue = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'has_tests': DimensionMeasurement(
              dimensionId: 'has_tests',
              value: true,
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final resultTrue = await engine.evaluate(rubric, inputTrue, null);
        expect(resultTrue.overallScore, closeTo(100.0, 0.01));
        expect(resultTrue.passed, isTrue);

        final inputFalse = EvaluationInput(
          artifactId: 'art-2',
          artifactType: 'code',
          measurements: const {
            'has_tests': DimensionMeasurement(
              dimensionId: 'has_tests',
              value: false,
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final resultFalse = await engine.evaluate(rubric, inputFalse, null);
        expect(resultFalse.overallScore, closeTo(0.0, 0.01));
        expect(resultFalse.passed, isFalse);
      });
    });

    group('evaluate with categorical dimensions', () {
      test('maps categorical label to level score midpoint', () async {
        final rubric = Rubric(
          id: 'cat-rubric',
          name: 'Categorical Rubric',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'readability',
              name: 'Readability',
              measurementMethod: 'manual',
              measurementType: 'categorical',
              levels: [
                ScoreLevel(label: 'Poor', minScore: 0, maxScore: 30),
                ScoreLevel(label: 'Good', minScore: 60, maxScore: 80),
                ScoreLevel(label: 'Excellent', minScore: 80, maxScore: 100),
              ],
            ),
          ],
          weights: const {'readability': 1.0},
          thresholds: const {'pass': 50.0},
        );

        final input = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'readability': DimensionMeasurement(
              dimensionId: 'readability',
              value: 'Good',
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // 'Good' level: minScore=60, maxScore=80, midpoint = 70
        expect(result.overallScore, closeTo(70.0, 0.01));
        expect(result.passed, isTrue);
      });

      test('falls back to last level when label not found', () async {
        final rubric = Rubric(
          id: 'cat-rubric-2',
          name: 'Categorical Rubric 2',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'style',
              name: 'Style',
              measurementMethod: 'manual',
              measurementType: 'categorical',
              levels: [
                ScoreLevel(label: 'Bad', minScore: 0, maxScore: 20),
                ScoreLevel(label: 'Ok', minScore: 40, maxScore: 60),
              ],
            ),
          ],
          weights: const {'style': 1.0},
          thresholds: const {'pass': 30.0},
        );

        final input = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'style': DimensionMeasurement(
              dimensionId: 'style',
              value: 'Unknown_Label',
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // Falls back to last level: 'Ok' (40+60)/2 = 50
        expect(result.overallScore, closeTo(50.0, 0.01));
      });

      test('uses 50 as default when no levels exist for categorical',
          () async {
        final rubric = Rubric(
          id: 'cat-no-levels',
          name: 'No Levels',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'cat_dim',
              name: 'Cat Dim',
              measurementMethod: 'manual',
              measurementType: 'categorical',
              levels: [], // No levels defined
            ),
          ],
          weights: const {'cat_dim': 1.0},
          thresholds: const {'pass': 40.0},
        );

        final input = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'cat_dim': DimensionMeasurement(
              dimensionId: 'cat_dim',
              value: 'anything',
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        expect(result.overallScore, closeTo(50.0, 0.01));
      });
    });

    group('evaluate normalization', () {
      test('normalizes numeric values with custom min/max range', () async {
        final rubric = Rubric(
          id: 'range-rubric',
          name: 'Range Rubric',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'metric',
              name: 'Metric',
              measurementMethod: 'manual',
              measurementType: 'numeric',
              minScore: 10,
              maxScore: 50,
            ),
          ],
          weights: const {'metric': 1.0},
          thresholds: const {'pass': 50.0},
        );

        final input = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'metric': DimensionMeasurement(
              dimensionId: 'metric',
              value: 30,
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // normalized = (30 - 10) / (50 - 10) * 100 = 20/40 * 100 = 50
        expect(result.overallScore, closeTo(50.0, 0.01));
        expect(result.passed, isTrue);
      });

      test('clamps normalized score to 0-100 range', () async {
        final rubric = Rubric(
          id: 'clamp-rubric',
          name: 'Clamp Rubric',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'metric',
              name: 'Metric',
              measurementMethod: 'manual',
              measurementType: 'numeric',
              minScore: 0,
              maxScore: 50,
            ),
          ],
          weights: const {'metric': 1.0},
          thresholds: const {'pass': 50.0},
        );

        // Value exceeds maxScore
        final input = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'metric': DimensionMeasurement(
              dimensionId: 'metric',
              value: 100,
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        // (100 - 0) / (50 - 0) * 100 = 200 -> clamped to 100
        expect(result.overallScore, closeTo(100.0, 0.01));
      });

      test('normalizes to 0 for unknown measurement type', () async {
        final rubric = Rubric(
          id: 'unknown-type-rubric',
          name: 'Unknown Type',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'dim',
              name: 'Dim',
              measurementMethod: 'manual',
              measurementType: 'some_unknown_type',
            ),
          ],
          weights: const {'dim': 1.0},
          thresholds: const {'pass': 50.0},
        );

        final input = EvaluationInput(
          artifactId: 'art-1',
          artifactType: 'code',
          measurements: const {
            'dim': DimensionMeasurement(
              dimensionId: 'dim',
              value: 'anything',
              source: MeasurementSource(type: MeasurementSourceType.manual),
            ),
          },
        );

        final result = await engine.evaluate(rubric, input, null);

        expect(result.overallScore, closeTo(0.0, 0.01));
      });
    });

    group('validateInput', () {
      test('returns valid when all measurements present and correct type',
          () {
        final rubric = _createRubric();
        final input = _createInput();

        final validation = engine.validateInput(rubric, input);

        expect(validation.valid, isTrue);
        expect(validation.errors, isEmpty);
      });

      test('returns error when measurement is missing for a dimension', () {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 80,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final validation = engine.validateInput(rubric, input);

        expect(validation.valid, isFalse);
        expect(validation.errors.length, 1);
        expect(validation.errors.first, contains('security'));
      });

      test('returns error when measurement type mismatches dimension spec',
          () {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 'text_not_number',
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 90,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final validation = engine.validateInput(rubric, input);

        expect(validation.valid, isFalse);
        expect(validation.errors.any((e) => e.contains('Invalid measurement')),
            isTrue);
      });

      test('generates warning for out-of-range numeric value', () {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 150,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 90,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final validation = engine.validateInput(rubric, input);

        expect(validation.valid, isTrue);
        expect(validation.warnings.any((w) => w.contains('outside')), isTrue);
      });

      test('generates warning for low confidence measurement', () {
        final rubric = _createRubric();
        final input = _createInput(
          measurements: {
            'quality': const DimensionMeasurement(
              dimensionId: 'quality',
              value: 80,
              confidence: 0.3,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
            'security': const DimensionMeasurement(
              dimensionId: 'security',
              value: 90,
              confidence: 1.0,
              source:
                  MeasurementSource(type: MeasurementSourceType.codeAnalysis),
            ),
          },
        );

        final validation = engine.validateInput(rubric, input);

        expect(validation.valid, isTrue);
        expect(
            validation.warnings.any((w) => w.contains('Low confidence')), isTrue);
      });

      test('generates warning when weights do not sum to 1.0', () {
        final rubric = _createRubric(
          weights: {'quality': 0.5, 'security': 0.3},
        );
        final input = _createInput();

        final validation = engine.validateInput(rubric, input);

        expect(validation.valid, isTrue);
        expect(validation.warnings.any((w) => w.contains('weights sum')),
            isTrue);
      });
    });

    group('getMeasurementExtractors', () {
      test('returns extractors for each rubric dimension', () {
        final rubric = _createRubric();

        final extractors = engine.getMeasurementExtractors(rubric);

        expect(extractors.length, 2);
        expect(extractors[0], isA<CodeComplexityExtractor>());
        expect(extractors[1], isA<SecurityScanExtractor>());
      });

      test('throws when unknown extractor type is referenced', () {
        final rubric = Rubric(
          id: 'unknown',
          name: 'Unknown',
          version: '1.0.0',
          dimensions: const [
            RubricDimension(
              id: 'dim',
              name: 'Dim',
              measurementMethod: 'nonexistent_extractor',
            ),
          ],
          weights: const {'dim': 1.0},
          thresholds: const {'pass': 60.0},
        );

        expect(
          () => engine.getMeasurementExtractors(rubric),
          throwsA(isA<UnknownExtractorException>()),
        );
      });
    });

    group('caching', () {
      test('caches evaluation result and returns cached on second call',
          () async {
        final cache = InMemoryRubricCache();
        final cachedEngine = DefaultRubricEvaluationEngine(
          extractorRegistry: registry,
          cache: cache,
        );

        final rubric = _createRubric();
        final input = _createInput();

        final result1 = await cachedEngine.evaluate(rubric, input, null);
        final result2 = await cachedEngine.evaluate(rubric, input, null);

        expect(result1.overallScore, result2.overallScore);
        expect(result1.classification, result2.classification);
        // Cached result reuses the evaluatedAt timestamp
        expect(result2.evaluatedAt, result1.evaluatedAt);
      });

      test('bypasses stale cache when asOf is after evaluatedAt', () async {
        final cache = InMemoryRubricCache();
        final cachedEngine = DefaultRubricEvaluationEngine(
          extractorRegistry: registry,
          cache: cache,
        );

        final rubric = _createRubric();
        final input = _createInput();

        final result1 = await cachedEngine.evaluate(rubric, input, null);

        // Evaluate again with an asOf in the future to bypass cache
        final futureContext = EvaluationContext(
          asOf: result1.evaluatedAt.add(const Duration(hours: 1)),
        );
        final result2 =
            await cachedEngine.evaluate(rubric, input, futureContext);

        // result2 is computed again, not the cached object. The clock is not
        // compared: the web clock ticks only every millisecond.
        expect(identical(result2, result1), isFalse);
      });
    });
  });

  group('InMemoryRubricCache', () {
    test('returns null for cache miss', () async {
      final cache = InMemoryRubricCache();

      final result = await cache.get('nonexistent');

      expect(result, isNull);
    });

    test('stores and retrieves a result', () async {
      final cache = InMemoryRubricCache();
      final result = EvaluationResult(
        rubricId: 'r1',
        rubricVersion: '1.0',
        artifactId: 'a1',
        evaluatedAt: DateTime.now(),
        overallScore: 85.0,
        classification: 'good',
        dimensionScores: const [],
        passed: true,
        breakdown: const ScoreBreakdown(
          formula: 'weighted_sum',
          weights: {},
          thresholdApplied: 'pass',
          thresholdValue: 60.0,
        ),
      );

      await cache.set('key1', result);
      final retrieved = await cache.get('key1');

      expect(retrieved, isNotNull);
      expect(retrieved!.rubricId, 'r1');
      expect(retrieved.overallScore, 85.0);
    });

    test('invalidate removes entry', () async {
      final cache = InMemoryRubricCache();
      final result = EvaluationResult(
        rubricId: 'r1',
        rubricVersion: '1.0',
        artifactId: 'a1',
        evaluatedAt: DateTime.now(),
        overallScore: 85.0,
        classification: 'good',
        dimensionScores: const [],
        passed: true,
        breakdown: const ScoreBreakdown(
          formula: 'f',
          weights: {},
          thresholdApplied: 'pass',
          thresholdValue: 60.0,
        ),
      );

      await cache.set('key1', result);
      await cache.invalidate('key1');
      final retrieved = await cache.get('key1');

      expect(retrieved, isNull);
    });

    test('clear removes all entries', () async {
      final cache = InMemoryRubricCache();
      final result = EvaluationResult(
        rubricId: 'r1',
        rubricVersion: '1.0',
        artifactId: 'a1',
        evaluatedAt: DateTime.now(),
        overallScore: 85.0,
        classification: 'good',
        dimensionScores: const [],
        passed: true,
        breakdown: const ScoreBreakdown(
          formula: 'f',
          weights: {},
          thresholdApplied: 'pass',
          thresholdValue: 60.0,
        ),
      );

      await cache.set('key1', result);
      await cache.set('key2', result);
      await cache.clear();

      expect(await cache.get('key1'), isNull);
      expect(await cache.get('key2'), isNull);
    });
  });

  group('InMemoryRubricRegistry', () {
    test('registers and retrieves rubric by ID', () async {
      final registry = InMemoryRubricRegistry();
      final rubric = _createRubric(id: 'test-rubric');

      await registry.registerRubric(rubric);
      final retrieved = await registry.getRubric('test-rubric');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'test-rubric');
    });

    test('returns null for unregistered rubric', () async {
      final registry = InMemoryRubricRegistry();

      final result = await registry.getRubric('nonexistent');

      expect(result, isNull);
    });

    test('listRubrics returns all registered rubrics', () async {
      final registry = InMemoryRubricRegistry();
      await registry.registerRubric(_createRubric(id: 'r1'));
      await registry.registerRubric(_createRubric(id: 'r2'));

      final list = await registry.listRubrics();

      expect(list.length, 2);
      expect(list.map((r) => r.id).toSet(), {'r1', 'r2'});
    });

    test('unregisterRubric removes rubric', () async {
      final registry = InMemoryRubricRegistry();
      await registry.registerRubric(_createRubric(id: 'r1'));

      await registry.unregisterRubric('r1');

      expect(await registry.getRubric('r1'), isNull);
      expect((await registry.listRubrics()).length, 0);
    });
  });

  group('RubricException types', () {
    test('RubricValidationException contains rubricId and errors', () {
      final ex = RubricValidationException(
        rubricId: 'r1',
        errors: ['error1', 'error2'],
      );

      expect(ex.rubricId, 'r1');
      expect(ex.errors, ['error1', 'error2']);
      expect(ex.toString(), contains('r1'));
      expect(ex.toString(), contains('error1'));
    });

    test('RubricNotFoundException contains rubricId', () {
      final ex = RubricNotFoundException('r1');

      expect(ex.toString(), contains('r1'));
    });

    test('MissingMeasurementException contains rubricId and dimensionId', () {
      final ex = MissingMeasurementException(
        rubricId: 'r1',
        dimensionId: 'd1',
      );

      expect(ex.rubricId, 'r1');
      expect(ex.dimensionId, 'd1');
      expect(ex.toString(), contains('r1'));
      expect(ex.toString(), contains('d1'));
    });
  });
}
