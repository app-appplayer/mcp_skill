/// Rubric Evaluation Engine - Deterministic rubric evaluation.
///
/// Provides the core evaluation engine for evaluating artifacts against
/// rubrics. LLM is used only for measurement extraction, not for scoring.
library;

import 'rubric.dart';
import 'measurement_extractor.dart';

/// Interface for rubric evaluation engines.
abstract class RubricEvaluationEngine {
  /// Evaluate an artifact against a rubric.
  Future<EvaluationResult> evaluate(
    Rubric rubric,
    EvaluationInput input,
    EvaluationContext? context,
  );

  /// Validate evaluation input against a rubric.
  ValidationResult validateInput(Rubric rubric, EvaluationInput input);

  /// Get measurement extractors for a rubric.
  List<MeasurementExtractor> getMeasurementExtractors(Rubric rubric);
}

/// Default implementation of RubricEvaluationEngine.
///
/// Evaluates artifacts against rubrics deterministically.
/// LLM is used ONLY for measurement extraction, NOT for scoring.
class DefaultRubricEvaluationEngine implements RubricEvaluationEngine {
  /// Registry for measurement extractors.
  final MeasurementExtractorRegistry extractorRegistry;

  /// Optional cache for evaluation results.
  final RubricCache? cache;

  DefaultRubricEvaluationEngine({
    required this.extractorRegistry,
    this.cache,
  });

  @override
  Future<EvaluationResult> evaluate(
    Rubric rubric,
    EvaluationInput input,
    EvaluationContext? context,
  ) async {
    final startTime = DateTime.now();

    // Step 1: Validate inputs
    final validation = validateInput(rubric, input);
    if (!validation.valid) {
      throw RubricValidationException(
        rubricId: rubric.id,
        errors: validation.errors,
      );
    }

    // Step 2: Check cache
    final cacheKey = _buildCacheKey(rubric, input);
    if (cache != null) {
      final cached = await cache!.get(cacheKey);
      if (cached != null && !_isStale(cached, context?.asOf)) {
        return cached;
      }
    }

    // Step 3: Calculate dimension scores
    final dimensionScores = <DimensionScore>[];

    for (final dimension in rubric.dimensions) {
      final measurement = input.measurements[dimension.id];
      if (measurement == null) {
        throw MissingMeasurementException(
          rubricId: rubric.id,
          dimensionId: dimension.id,
        );
      }

      final score =
          _calculateDimensionScore(dimension, measurement, rubric.weights);
      dimensionScores.add(score);
    }

    // Step 4: Calculate overall weighted score
    final overallScore = dimensionScores
        .map((s) => s.weightedScore)
        .fold(0.0, (a, b) => a + b);

    // Step 5: Determine classification
    final classification = _classify(overallScore, rubric.thresholds);

    // Step 6: Build result
    final result = EvaluationResult(
      rubricId: rubric.id,
      rubricVersion: rubric.version,
      artifactId: input.artifactId,
      evaluatedAt: startTime,
      overallScore: overallScore,
      classification: classification,
      dimensionScores: dimensionScores,
      passed: overallScore >= (rubric.thresholds['pass'] ?? 60),
      breakdown: ScoreBreakdown(
        formula: 'sum(dimension.normalizedScore * dimension.weight)',
        weights: rubric.weights,
        thresholdApplied: classification,
        thresholdValue: rubric.thresholds[classification] ?? 0,
      ),
    );

    // Step 7: Cache result
    if (cache != null) {
      await cache!.set(cacheKey, result);
    }

    return result;
  }

  @override
  ValidationResult validateInput(Rubric rubric, EvaluationInput input) {
    final errors = <String>[];
    final warnings = <String>[];

    // Check all required dimensions have measurements
    for (final dimension in rubric.dimensions) {
      final measurement = input.measurements[dimension.id];

      if (measurement == null) {
        errors.add('Missing measurement for dimension: ${dimension.id}');
        continue;
      }

      // Validate measurement type matches dimension spec
      if (!_isValidMeasurementType(
          measurement.value, dimension.measurementType)) {
        errors.add(
          'Invalid measurement type for ${dimension.id}: '
          'expected ${dimension.measurementType}, '
          'got ${measurement.value.runtimeType}',
        );
      }

      // Validate value is in range for numeric types
      if (dimension.measurementType == 'numeric' &&
          measurement.value is num) {
        final numValue = (measurement.value as num).toDouble();
        if (numValue < dimension.minScore || numValue > dimension.maxScore) {
          warnings.add(
            'Measurement for ${dimension.id} ($numValue) is outside '
            'expected range [${dimension.minScore}, ${dimension.maxScore}]',
          );
        }
      }

      // Check confidence threshold
      if (measurement.confidence != null && measurement.confidence! < 0.5) {
        warnings.add(
          'Low confidence measurement for ${dimension.id}: ${measurement.confidence}',
        );
      }
    }

    // Check weights sum to 1.0
    final weightSum = rubric.weights.values.fold(0.0, (a, b) => a + b);
    if ((weightSum - 1.0).abs() > 0.001) {
      warnings.add('Rubric weights sum to $weightSum, expected 1.0');
    }

    return ValidationResult(
      valid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  @override
  List<MeasurementExtractor> getMeasurementExtractors(Rubric rubric) {
    return rubric.dimensions.map((dimension) {
      return extractorRegistry.getExtractor(
        dimension.measurementMethod,
        dimension.id,
      );
    }).toList();
  }

  /// Calculate score for a single dimension.
  DimensionScore _calculateDimensionScore(
    RubricDimension dimension,
    DimensionMeasurement measurement,
    Map<String, double> weights,
  ) {
    // Normalize the raw value to 0-100 scale
    final rawValue = measurement.value;
    double normalizedScore;

    switch (dimension.measurementType) {
      case 'numeric':
        final numValue = (rawValue as num).toDouble();
        // Linear normalization: (value - min) / (max - min) * 100
        normalizedScore = ((numValue - dimension.minScore) /
                (dimension.maxScore - dimension.minScore)) *
            100;
        normalizedScore = normalizedScore.clamp(0.0, 100.0);
        break;

      case 'boolean':
        normalizedScore = (rawValue as bool) ? 100.0 : 0.0;
        break;

      case 'categorical':
        // Find the level that matches and use its score
        if (dimension.levels.isNotEmpty) {
          final level = dimension.levels.firstWhere(
            (l) =>
                l.label.toLowerCase() == (rawValue as String).toLowerCase(),
            orElse: () => dimension.levels.last,
          );
          normalizedScore = ((level.minScore + level.maxScore) / 2);
        } else {
          normalizedScore = 50.0; // Default midpoint
        }
        break;

      default:
        normalizedScore = 0.0;
    }

    // Get weight for this dimension
    final weight = weights[dimension.id] ?? (1.0 / weights.length);
    final weightedScore = normalizedScore * weight;

    // Determine level label
    final level = _determineLevelLabel(rawValue, dimension);

    return DimensionScore(
      dimensionId: dimension.id,
      rawValue: rawValue,
      normalizedScore: normalizedScore,
      weight: weight,
      weightedScore: weightedScore,
      level: level,
      confidence: measurement.confidence,
    );
  }

  /// Determine the level label for a raw value.
  String _determineLevelLabel(dynamic rawValue, RubricDimension dimension) {
    if (dimension.measurementType == 'categorical') {
      return rawValue as String;
    }

    if (dimension.levels.isEmpty) {
      return 'Unknown';
    }

    final numValue = rawValue is num ? rawValue.toDouble() : 0.0;

    for (final level in dimension.levels) {
      if (numValue >= level.minScore && numValue <= level.maxScore) {
        return level.label;
      }
    }

    return dimension.levels.last.label;
  }

  /// Classify the overall score based on thresholds.
  String _classify(double score, Map<String, double> thresholds) {
    // Sort thresholds by value descending
    final sortedThresholds = thresholds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedThresholds) {
      if (score >= entry.value) {
        return entry.key;
      }
    }

    return 'fail';
  }

  bool _isValidMeasurementType(dynamic value, String expectedType) {
    switch (expectedType) {
      case 'numeric':
        return value is num;
      case 'boolean':
        return value is bool;
      case 'categorical':
        return value is String;
      default:
        return true;
    }
  }

  String _buildCacheKey(Rubric rubric, EvaluationInput input) {
    return '${rubric.id}:${rubric.version}:${input.artifactId}:${input.asOf?.toIso8601String() ?? 'latest'}';
  }

  bool _isStale(EvaluationResult cached, DateTime? asOf) {
    if (asOf == null) return false;
    return cached.evaluatedAt.isBefore(asOf);
  }
}

/// Interface for rubric caching.
abstract class RubricCache {
  /// Get cached result.
  Future<EvaluationResult?> get(String key);

  /// Set cached result.
  Future<void> set(String key, EvaluationResult result);

  /// Invalidate a cache entry.
  Future<void> invalidate(String key);

  /// Clear all cache entries.
  Future<void> clear();
}

/// In-memory rubric cache with TTL.
class InMemoryRubricCache implements RubricCache {
  /// Time-to-live for cache entries.
  final Duration ttl;

  final Map<String, _CacheEntry> _cache = {};

  InMemoryRubricCache({this.ttl = const Duration(minutes: 15)});

  @override
  Future<EvaluationResult?> get(String key) async {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _cache.remove(key);
      return null;
    }

    return entry.result;
  }

  @override
  Future<void> set(String key, EvaluationResult result) async {
    _cache[key] = _CacheEntry(
      result: result,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  @override
  Future<void> invalidate(String key) async {
    _cache.remove(key);
  }

  @override
  Future<void> clear() async {
    _cache.clear();
  }
}

class _CacheEntry {
  final EvaluationResult result;
  final DateTime expiresAt;

  _CacheEntry({required this.result, required this.expiresAt});
}

/// Interface for rubric registry.
abstract class RubricRegistry {
  /// Get a rubric by ID.
  Future<Rubric?> getRubric(String rubricId);

  /// List all available rubrics.
  Future<List<Rubric>> listRubrics();

  /// Register a rubric.
  Future<void> registerRubric(Rubric rubric);

  /// Unregister a rubric.
  Future<void> unregisterRubric(String rubricId);
}

/// In-memory rubric registry.
class InMemoryRubricRegistry implements RubricRegistry {
  final Map<String, Rubric> _rubrics = {};

  @override
  Future<Rubric?> getRubric(String rubricId) async {
    return _rubrics[rubricId];
  }

  @override
  Future<List<Rubric>> listRubrics() async {
    return _rubrics.values.toList();
  }

  @override
  Future<void> registerRubric(Rubric rubric) async {
    _rubrics[rubric.id] = rubric;
  }

  @override
  Future<void> unregisterRubric(String rubricId) async {
    _rubrics.remove(rubricId);
  }
}

/// Rubric evaluation exception.
class RubricException implements Exception {
  final String message;

  RubricException(this.message);

  @override
  String toString() => 'RubricException: $message';
}

/// Exception for rubric validation failures.
class RubricValidationException extends RubricException {
  final String rubricId;
  final List<String> errors;

  RubricValidationException({required this.rubricId, required this.errors})
      : super('Validation failed for rubric $rubricId: ${errors.join(', ')}');
}

/// Exception for rubric not found.
class RubricNotFoundException extends RubricException {
  RubricNotFoundException(String rubricId)
      : super('Rubric not found: $rubricId');
}

/// Exception for missing measurement.
class MissingMeasurementException extends RubricException {
  final String rubricId;
  final String dimensionId;

  MissingMeasurementException({
    required this.rubricId,
    required this.dimensionId,
  }) : super(
            'Missing measurement for dimension $dimensionId in rubric $rubricId');
}
