/// Exceptions for input/output validation failures.
library;

import 'skill_exception.dart';

/// Base validation exception.
class SkillValidationException extends SkillException {
  /// Validation errors encountered.
  final List<String> errors;

  SkillValidationException(
    String message, {
    this.errors = const [],
    String? path,
    Object? cause,
  }) : super(
          message: message,
          code: 'VALIDATION_ERROR',
          path: path,
          cause: cause,
        );

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        if (errors.isNotEmpty) 'errors': errors,
      };
}

/// Input validation failure.
class InputValidationException extends SkillValidationException {
  /// The parameter name that failed validation.
  final String? parameterName;

  InputValidationException(
    String message, {
    this.parameterName,
    List<String> errors = const [],
    String? path,
  }) : super(message, errors: errors, path: path);

  @override
  String get code => 'INPUT_VALIDATION_ERROR';
}

/// Output validation failure.
class OutputValidationException extends SkillValidationException {
  OutputValidationException(
    String message, {
    List<String> errors = const [],
    String? path,
  }) : super(message, errors: errors, path: path);

  @override
  String get code => 'OUTPUT_VALIDATION_ERROR';
}

/// Schema validation failure.
class SchemaValidationException extends SkillValidationException {
  /// The schema path that failed.
  final String? schemaPath;

  SchemaValidationException(
    String message, {
    this.schemaPath,
    List<String> errors = const [],
    String? path,
  }) : super(message, errors: errors, path: path);

  @override
  String get code => 'SCHEMA_VALIDATION_ERROR';
}
