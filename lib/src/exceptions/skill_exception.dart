/// Base exception for all skill-related errors.
///
/// All exceptions in the mcp_skill package extend this class,
/// providing a unified error handling interface.
library;

/// Base exception for all skill-related errors.
abstract class SkillException implements Exception {
  /// Human-readable error message.
  final String message;

  /// Unique error code for programmatic handling.
  final String code;

  /// JSON path to problematic field (if applicable).
  final String? path;

  /// Original cause (for exception chaining).
  final Object? cause;

  /// Stack trace at point of error.
  final StackTrace? stackTrace;

  /// Whether this error is retryable.
  bool get isRetryable => false;

  /// Suggested retry delay (if retryable).
  Duration? get retryDelay => null;

  SkillException({
    required this.message,
    required this.code,
    this.path,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() => 'SkillException[$code]: $message';

  /// Serialize to JSON for structured logging.
  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (path != null) 'path': path,
        'isRetryable': isRetryable,
      };
}
