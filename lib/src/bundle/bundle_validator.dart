/// Bundle validator for validating skill bundle structure and content.
library;

import 'skill_bundle.dart';

/// Validation result for a bundle.
class BundleValidationResult {
  final bool isValid;
  final List<BundleValidationError> errors;
  final List<BundleValidationError> warnings;

  const BundleValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory BundleValidationResult.valid() =>
      const BundleValidationResult(isValid: true);

  factory BundleValidationResult.invalid(
    List<BundleValidationError> errors, {
    List<BundleValidationError> warnings = const [],
  }) =>
      BundleValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
}

/// A single validation error or warning.
class BundleValidationError {
  final String code;
  final String message;
  final String? path;
  final BundleValidationSeverity severity;

  const BundleValidationError({
    required this.code,
    required this.message,
    this.path,
    this.severity = BundleValidationSeverity.error,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (path != null) 'path': path,
        'severity': severity.name,
      };
}

/// Severity levels for validation issues.
enum BundleValidationSeverity { error, warning, info }

/// Abstract bundle validator.
abstract class BundleValidator {
  /// Validate a parsed skill bundle.
  Future<BundleValidationResult> validate(SkillBundle bundle);

  /// Validate a raw JSON map before parsing.
  Future<BundleValidationResult> validateJson(Map<String, dynamic> json);
}

/// Default bundle validator implementation.
class DefaultBundleValidator extends BundleValidator {
  @override
  Future<BundleValidationResult> validate(SkillBundle bundle) async {
    final errors = <BundleValidationError>[];
    final warnings = <BundleValidationError>[];

    // Validate manifest
    if (bundle.manifest.id.isEmpty) {
      errors.add(const BundleValidationError(
        code: 'MISSING_ID',
        message: 'Manifest ID is required',
        path: 'manifest.id',
      ));
    }
    if (bundle.manifest.name.isEmpty) {
      errors.add(const BundleValidationError(
        code: 'MISSING_NAME',
        message: 'Manifest name is required',
        path: 'manifest.name',
      ));
    }
    if (bundle.manifest.version.isEmpty) {
      errors.add(const BundleValidationError(
        code: 'MISSING_VERSION',
        message: 'Manifest version is required',
        path: 'manifest.version',
      ));
    }

    // Validate procedures
    if (bundle.procedures.isEmpty) {
      errors.add(const BundleValidationError(
        code: 'NO_PROCEDURES',
        message: 'At least one procedure is required',
        path: 'procedures',
      ));
    }

    for (var i = 0; i < bundle.procedures.length; i++) {
      final proc = bundle.procedures[i];
      if (proc.id.isEmpty) {
        errors.add(BundleValidationError(
          code: 'MISSING_PROC_ID',
          message: 'Procedure ID is required',
          path: 'procedures[$i].id',
        ));
      }
      if (proc.steps.isEmpty) {
        warnings.add(BundleValidationError(
          code: 'NO_STEPS',
          message: 'Procedure has no steps',
          path: 'procedures[$i].steps',
          severity: BundleValidationSeverity.warning,
        ));
      }
    }

    if (errors.isEmpty) return BundleValidationResult.valid();
    return BundleValidationResult.invalid(errors, warnings: warnings);
  }

  @override
  Future<BundleValidationResult> validateJson(Map<String, dynamic> json) async {
    final errors = <BundleValidationError>[];

    if (!json.containsKey('manifest')) {
      errors.add(const BundleValidationError(
        code: 'MISSING_MANIFEST',
        message: 'Manifest section is required',
        path: 'manifest',
      ));
    }
    if (!json.containsKey('procedures')) {
      errors.add(const BundleValidationError(
        code: 'MISSING_PROCEDURES',
        message: 'Procedures section is required',
        path: 'procedures',
      ));
    }

    if (errors.isNotEmpty) return BundleValidationResult.invalid(errors);

    // Parse and validate
    try {
      final bundle = SkillBundle.fromJson(json);
      return validate(bundle);
    } catch (e) {
      return BundleValidationResult.invalid([
        BundleValidationError(
          code: 'PARSE_ERROR',
          message: 'Failed to parse bundle: $e',
        ),
      ]);
    }
  }
}
