/// Exceptions for evaluation/rubric failures.
library;

import 'skill_exception.dart';

/// Base rubric exception.
class RubricException extends SkillException {
  RubricException(
    String message, {
    String? path,
    Object? cause,
  }) : super(message: message, code: 'RUBRIC_ERROR', path: path, cause: cause);
}

/// Rubric not found in registry.
class RubricNotFoundException extends RubricException {
  /// The rubric ID that was not found.
  final String rubricId;

  RubricNotFoundException(this.rubricId)
      : super('Rubric not found: $rubricId');

  @override
  String get code => 'RUBRIC_NOT_FOUND';
}

/// Missing measurement for a rubric dimension.
class MissingMeasurementException extends RubricException {
  /// The dimension ID missing the measurement.
  final String dimensionId;

  /// The rubric ID that requires the measurement.
  final String rubricId;

  MissingMeasurementException(this.dimensionId, this.rubricId)
      : super(
            'Missing measurement for dimension $dimensionId in rubric $rubricId');

  @override
  String get code => 'MISSING_MEASUREMENT';
}

/// Unknown extractor type referenced.
class UnknownExtractorException extends RubricException {
  /// The extractor type that was not found.
  final String extractorType;

  UnknownExtractorException(this.extractorType)
      : super('Unknown extractor type: $extractorType');

  @override
  String get code => 'UNKNOWN_EXTRACTOR';
}

/// Rubric validation failure.
class RubricValidationException extends RubricException {
  /// Validation issues found.
  final List<String> issues;

  RubricValidationException(
    String message, {
    this.issues = const [],
  }) : super(message);

  @override
  String get code => 'RUBRIC_VALIDATION_ERROR';
}
