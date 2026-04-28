/// Exceptions for skill loading failures.
///
/// Covers bundle/definition loading, parsing, and version errors.
library;

import 'skill_exception.dart';

/// Skill loading failure.
class SkillLoadException extends SkillException {
  SkillLoadException(
    String message, {
    String? path,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          message: message,
          code: 'SKILL_LOAD_ERROR',
          path: path,
          cause: cause,
          stackTrace: stackTrace,
        );
}

/// Skill not found in registry.
class SkillNotFoundException extends SkillLoadException {
  /// The skill ID that was not found.
  final String skillId;

  SkillNotFoundException(this.skillId)
      : super('Skill not found: $skillId', path: 'skills[$skillId]');

  @override
  String get code => 'SKILL_NOT_FOUND';
}

/// Procedure not found in skill.
class ProcedureNotFoundException extends SkillLoadException {
  /// The skill ID containing the procedure.
  final String skillId;

  /// The procedure ID that was not found.
  final String procedureId;

  ProcedureNotFoundException(this.skillId, this.procedureId)
      : super('Procedure $procedureId not found in skill $skillId');

  @override
  String get code => 'PROCEDURE_NOT_FOUND';
}

/// Skill version mismatch or constraint failure.
class SkillVersionException extends SkillLoadException {
  /// The requested version constraint.
  final String? requestedVersion;

  /// The available version.
  final String? availableVersion;

  SkillVersionException(
    String message, {
    this.requestedVersion,
    this.availableVersion,
    Object? cause,
  }) : super(message, cause: cause);

  @override
  String get code => 'SKILL_VERSION_ERROR';
}

/// Skill bundle parse failure.
class SkillParseException extends SkillLoadException {
  /// The line number where the parse error occurred (if available).
  final int? line;

  /// The column number where the parse error occurred (if available).
  final int? column;

  SkillParseException(
    String message, {
    String? path,
    this.line,
    this.column,
    Object? cause,
  }) : super(message, path: path, cause: cause);

  @override
  String get code => 'SKILL_PARSE_ERROR';
}

/// Skill routing failure.
class SkillRoutingException extends SkillLoadException {
  SkillRoutingException(String message) : super(message);

  @override
  String get code => 'SKILL_ROUTING_ERROR';
}
