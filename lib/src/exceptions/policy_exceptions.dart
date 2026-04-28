/// Exceptions for policy/profile violations.
library;

import 'skill_exception.dart';

/// Base policy exception.
class PolicyException extends SkillException {
  PolicyException(
    String message, {
    String? path,
    Object? cause,
  }) : super(
          message: message,
          code: 'POLICY_ERROR',
          path: path,
          cause: cause,
        );
}

/// Policy violation detected.
class PolicyViolationException extends PolicyException {
  /// The policy rule that was violated.
  final String? policyRule;

  /// The policy version.
  final String? policyVersion;

  PolicyViolationException(
    String message, {
    this.policyRule,
    this.policyVersion,
  }) : super(message);

  @override
  String get code => 'POLICY_VIOLATION';
}

/// Permission denied.
class PermissionDeniedException extends PolicyException {
  /// The required permission.
  final String? requiredPermission;

  /// The resource that access was denied to.
  final String? resource;

  PermissionDeniedException(
    String message, {
    this.requiredPermission,
    this.resource,
  }) : super(message);

  @override
  String get code => 'PERMISSION_DENIED';
}

/// Rate limit exceeded.
class RateLimitException extends PolicyException {
  /// The rate limit that was exceeded.
  final int? limit;

  /// The time window for the rate limit.
  final Duration? window;

  /// When the rate limit resets.
  final DateTime? resetsAt;

  RateLimitException(
    String message, {
    this.limit,
    this.window,
    this.resetsAt,
  }) : super(message);

  @override
  String get code => 'RATE_LIMIT_EXCEEDED';

  @override
  bool get isRetryable => true;

  @override
  Duration? get retryDelay {
    if (resetsAt != null) {
      final delay = resetsAt!.difference(DateTime.now());
      return delay.isNegative ? const Duration(seconds: 1) : delay;
    }
    return const Duration(seconds: 30);
  }
}
