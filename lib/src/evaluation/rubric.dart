/// Rubric - Rubric model and related types.
///
/// Provides the rubric definition structure including dimensions,
/// score levels, weights, and thresholds.
library;

/// A rubric definition for evaluating artifacts.
class Rubric {
  /// Unique rubric identifier.
  final String id;

  /// Human-readable name.
  final String name;

  /// Version string.
  final String version;

  /// Optional description.
  final String? description;

  /// Evaluation dimensions.
  final List<RubricDimension> dimensions;

  /// Weight per dimension (dimension ID -> weight, sum to 1.0).
  final Map<String, double> weights;

  /// Classification thresholds (label -> minimum score).
  final Map<String, double> thresholds;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const Rubric({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    required this.dimensions,
    required this.weights,
    required this.thresholds,
    this.metadata,
  });

  factory Rubric.fromJson(Map<String, dynamic> json) {
    return Rubric(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String?,
      dimensions: (json['dimensions'] as List<dynamic>?)
              ?.map((e) => RubricDimension.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      weights: (json['weights'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      thresholds: (json['thresholds'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {'pass': 60.0},
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        if (description != null) 'description': description,
        'dimensions': dimensions.map((e) => e.toJson()).toList(),
        'weights': weights,
        'thresholds': thresholds,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() => 'Rubric($id, $name, v$version)';
}

/// A dimension within a rubric.
class RubricDimension {
  /// Unique dimension identifier.
  final String id;

  /// Human-readable name.
  final String name;

  /// Optional description.
  final String? description;

  /// Measurement method (e.g., 'code_complexity', 'security_scan', 'llm_extraction').
  final String measurementMethod;

  /// Measurement type ('numeric', 'boolean', 'categorical').
  final String measurementType;

  /// Minimum score value (for numeric types).
  final double minScore;

  /// Maximum score value (for numeric types).
  final double maxScore;

  /// Score levels for classification.
  final List<ScoreLevel> levels;

  /// Additional configuration for the measurement method.
  final Map<String, dynamic>? config;

  const RubricDimension({
    required this.id,
    required this.name,
    this.description,
    required this.measurementMethod,
    this.measurementType = 'numeric',
    this.minScore = 0,
    this.maxScore = 100,
    this.levels = const [],
    this.config,
  });

  factory RubricDimension.fromJson(Map<String, dynamic> json) {
    return RubricDimension(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      measurementMethod: json['measurementMethod'] as String? ?? 'manual',
      measurementType: json['measurementType'] as String? ?? 'numeric',
      minScore: (json['minScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 100,
      levels: (json['levels'] as List<dynamic>?)
              ?.map((e) => ScoreLevel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      config: json['config'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'measurementMethod': measurementMethod,
        'measurementType': measurementType,
        'minScore': minScore,
        'maxScore': maxScore,
        if (levels.isNotEmpty) 'levels': levels.map((e) => e.toJson()).toList(),
        if (config != null) 'config': config,
      };

  @override
  String toString() => 'RubricDimension($id, $name)';
}

/// A score level within a dimension.
class ScoreLevel {
  /// Level label (e.g., 'Excellent', 'Good', 'Fair', 'Poor').
  final String label;

  /// Minimum score for this level.
  final double minScore;

  /// Maximum score for this level.
  final double maxScore;

  /// Optional description.
  final String? description;

  const ScoreLevel({
    required this.label,
    required this.minScore,
    required this.maxScore,
    this.description,
  });

  factory ScoreLevel.fromJson(Map<String, dynamic> json) {
    return ScoreLevel(
      label: json['label'] as String? ?? '',
      minScore: (json['minScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 100,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'minScore': minScore,
        'maxScore': maxScore,
        if (description != null) 'description': description,
      };

  @override
  String toString() => 'ScoreLevel($label, $minScore-$maxScore)';
}

/// Input for rubric evaluation.
class EvaluationInput {
  /// Artifact identifier being evaluated.
  final String artifactId;

  /// Artifact type.
  final String artifactType;

  /// Pre-computed measurements per dimension.
  final Map<String, DimensionMeasurement> measurements;

  /// Point-in-time for evaluation.
  final DateTime? asOf;

  /// Additional context.
  final Map<String, dynamic>? context;

  const EvaluationInput({
    required this.artifactId,
    required this.artifactType,
    this.measurements = const {},
    this.asOf,
    this.context,
  });

  factory EvaluationInput.fromJson(Map<String, dynamic> json) {
    return EvaluationInput(
      artifactId: json['artifactId'] as String? ?? '',
      artifactType: json['artifactType'] as String? ?? 'unknown',
      measurements: (json['measurements'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, DimensionMeasurement.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      asOf: json['asOf'] != null
          ? DateTime.parse(json['asOf'] as String)
          : null,
      context: json['context'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'artifactId': artifactId,
        'artifactType': artifactType,
        if (measurements.isNotEmpty)
          'measurements': measurements.map((k, v) => MapEntry(k, v.toJson())),
        if (asOf != null) 'asOf': asOf!.toIso8601String(),
        if (context != null) 'context': context,
      };
}

/// Measurement for a single dimension.
class DimensionMeasurement {
  /// Dimension ID.
  final String dimensionId;

  /// Measured value.
  final dynamic value;

  /// Confidence in the measurement (0-1).
  final double? confidence;

  /// Source of the measurement.
  final MeasurementSource source;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const DimensionMeasurement({
    required this.dimensionId,
    required this.value,
    this.confidence,
    required this.source,
    this.metadata,
  });

  factory DimensionMeasurement.fromJson(Map<String, dynamic> json) {
    return DimensionMeasurement(
      dimensionId: json['dimensionId'] as String? ?? '',
      value: json['value'],
      confidence: (json['confidence'] as num?)?.toDouble(),
      source: MeasurementSource.fromJson(
        json['source'] as Map<String, dynamic>? ?? {},
      ),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'dimensionId': dimensionId,
        'value': value,
        if (confidence != null) 'confidence': confidence,
        'source': source.toJson(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() =>
      'DimensionMeasurement($dimensionId, value: $value, confidence: $confidence)';
}

/// Source of a measurement.
class MeasurementSource {
  /// Source type.
  final MeasurementSourceType type;

  /// Tool or method name.
  final String? tool;

  /// Tool version.
  final String? version;

  /// Query used (for metric queries).
  final String? query;

  /// Evidence ID (for evidence extraction).
  final String? evidenceId;

  /// User ID (for manual entry).
  final String? userId;

  /// Expression used (for computed values).
  final String? expression;

  const MeasurementSource({
    required this.type,
    this.tool,
    this.version,
    this.query,
    this.evidenceId,
    this.userId,
    this.expression,
  });

  /// Create a code analysis source.
  factory MeasurementSource.codeAnalysis({
    required String tool,
    required String version,
  }) {
    return MeasurementSource(
      type: MeasurementSourceType.codeAnalysis,
      tool: tool,
      version: version,
    );
  }

  /// Create a metric query source.
  factory MeasurementSource.metricQuery({required String query}) {
    return MeasurementSource(
      type: MeasurementSourceType.metricQuery,
      query: query,
    );
  }

  /// Create an evidence extraction source.
  factory MeasurementSource.evidenceExtraction({required String evidenceId}) {
    return MeasurementSource(
      type: MeasurementSourceType.evidenceExtraction,
      evidenceId: evidenceId,
    );
  }

  /// Create a manual entry source.
  factory MeasurementSource.manual({required String userId}) {
    return MeasurementSource(
      type: MeasurementSourceType.manual,
      userId: userId,
    );
  }

  /// Create a computed source.
  factory MeasurementSource.computed({required String expression}) {
    return MeasurementSource(
      type: MeasurementSourceType.computed,
      expression: expression,
    );
  }

  factory MeasurementSource.fromJson(Map<String, dynamic> json) {
    return MeasurementSource(
      type: MeasurementSourceType.fromString(json['type'] as String?),
      tool: json['tool'] as String?,
      version: json['version'] as String?,
      query: json['query'] as String?,
      evidenceId: json['evidenceId'] as String?,
      userId: json['userId'] as String?,
      expression: json['expression'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (tool != null) 'tool': tool,
        if (version != null) 'version': version,
        if (query != null) 'query': query,
        if (evidenceId != null) 'evidenceId': evidenceId,
        if (userId != null) 'userId': userId,
        if (expression != null) 'expression': expression,
      };

  @override
  String toString() => 'MeasurementSource(${type.name})';
}

/// Types of measurement sources.
enum MeasurementSourceType {
  /// Code analysis tool.
  codeAnalysis,

  /// Metric query.
  metricQuery,

  /// Evidence extraction.
  evidenceExtraction,

  /// Manual entry.
  manual,

  /// Computed from expression.
  computed;

  static MeasurementSourceType fromString(String? value) {
    return MeasurementSourceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MeasurementSourceType.manual,
    );
  }
}

/// Context for evaluation.
class EvaluationContext {
  /// Point-in-time for evaluation.
  final DateTime? asOf;

  /// Additional context data.
  final Map<String, dynamic>? data;

  const EvaluationContext({
    this.asOf,
    this.data,
  });
}

/// Result of rubric evaluation.
class EvaluationResult {
  /// Rubric ID.
  final String rubricId;

  /// Rubric version.
  final String rubricVersion;

  /// Artifact ID evaluated.
  final String artifactId;

  /// When evaluation was performed.
  final DateTime evaluatedAt;

  /// Overall score (0-100).
  final double overallScore;

  /// Classification label (e.g., 'excellent', 'good', 'pass', 'fail').
  final String classification;

  /// Scores per dimension.
  final List<DimensionScore> dimensionScores;

  /// Whether evaluation passed.
  final bool passed;

  /// Score breakdown for transparency.
  final ScoreBreakdown breakdown;

  const EvaluationResult({
    required this.rubricId,
    required this.rubricVersion,
    required this.artifactId,
    required this.evaluatedAt,
    required this.overallScore,
    required this.classification,
    required this.dimensionScores,
    required this.passed,
    required this.breakdown,
  });

  factory EvaluationResult.fromJson(Map<String, dynamic> json) {
    return EvaluationResult(
      rubricId: json['rubricId'] as String? ?? '',
      rubricVersion: json['rubricVersion'] as String? ?? '',
      artifactId: json['artifactId'] as String? ?? '',
      evaluatedAt: json['evaluatedAt'] != null
          ? DateTime.parse(json['evaluatedAt'] as String)
          : DateTime.now(),
      overallScore: (json['overallScore'] as num?)?.toDouble() ?? 0,
      classification: json['classification'] as String? ?? 'unknown',
      dimensionScores: (json['dimensionScores'] as List<dynamic>?)
              ?.map((e) => DimensionScore.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      passed: json['passed'] as bool? ?? false,
      breakdown:
          ScoreBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'rubricId': rubricId,
        'rubricVersion': rubricVersion,
        'artifactId': artifactId,
        'evaluatedAt': evaluatedAt.toIso8601String(),
        'overallScore': overallScore,
        'classification': classification,
        'dimensionScores': dimensionScores.map((e) => e.toJson()).toList(),
        'passed': passed,
        'breakdown': breakdown.toJson(),
      };

  @override
  String toString() =>
      'EvaluationResult($rubricId, score: $overallScore, classification: $classification)';
}

/// Score for a single dimension.
class DimensionScore {
  /// Dimension ID.
  final String dimensionId;

  /// Raw measured value.
  final dynamic rawValue;

  /// Normalized score (0-100).
  final double normalizedScore;

  /// Weight applied.
  final double weight;

  /// Weighted score contribution.
  final double weightedScore;

  /// Level label.
  final String level;

  /// Confidence in the score.
  final double? confidence;

  const DimensionScore({
    required this.dimensionId,
    required this.rawValue,
    required this.normalizedScore,
    required this.weight,
    required this.weightedScore,
    required this.level,
    this.confidence,
  });

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      dimensionId: json['dimensionId'] as String? ?? '',
      rawValue: json['rawValue'],
      normalizedScore: (json['normalizedScore'] as num?)?.toDouble() ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      weightedScore: (json['weightedScore'] as num?)?.toDouble() ?? 0,
      level: json['level'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dimensionId': dimensionId,
        'rawValue': rawValue,
        'normalizedScore': normalizedScore,
        'weight': weight,
        'weightedScore': weightedScore,
        'level': level,
        if (confidence != null) 'confidence': confidence,
      };

  @override
  String toString() =>
      'DimensionScore($dimensionId, normalized: $normalizedScore, weighted: $weightedScore)';
}

/// Score breakdown for transparency.
class ScoreBreakdown {
  /// Formula used.
  final String formula;

  /// Weights applied.
  final Map<String, double> weights;

  /// Classification threshold applied.
  final String thresholdApplied;

  /// Threshold value.
  final double thresholdValue;

  const ScoreBreakdown({
    required this.formula,
    required this.weights,
    required this.thresholdApplied,
    required this.thresholdValue,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      formula: json['formula'] as String? ?? '',
      weights: (json['weights'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      thresholdApplied: json['thresholdApplied'] as String? ?? '',
      thresholdValue: (json['thresholdValue'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'formula': formula,
        'weights': weights,
        'thresholdApplied': thresholdApplied,
        'thresholdValue': thresholdValue,
      };
}

/// Validation result for rubric input.
class ValidationResult {
  /// Whether input is valid.
  final bool valid;

  /// Validation errors.
  final List<String> errors;

  /// Validation warnings.
  final List<String> warnings;

  const ValidationResult({
    required this.valid,
    this.errors = const [],
    this.warnings = const [],
  });
}
