/// Retry Configuration - Configuration for retry behavior.
///
/// Defines retry policies for handling transient failures.
library;

import '../exceptions/skill_exception.dart';

/// Retry configuration for error handling.
class RetryConfig {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial backoff delay.
  final Duration initialDelay;

  /// Maximum backoff delay.
  final Duration maxDelay;

  /// Backoff multiplier for exponential backoff.
  final double backoffMultiplier;

  /// Whether to add jitter to delay.
  final bool jitter;

  /// Exception types that should be retried.
  final List<Type>? retryableExceptions;

  /// Exception types that should NOT be retried.
  final List<Type>? nonRetryableExceptions;

  /// Custom retry predicate for fine-grained control.
  final bool Function(SkillException)? shouldRetry;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.jitter = true,
    this.retryableExceptions,
    this.nonRetryableExceptions,
    this.shouldRetry,
  });

  /// Default configuration for LLM calls.
  static const llmDefault = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 60),
    backoffMultiplier: 2.0,
    jitter: true,
  );

  /// Default configuration for MCP tool calls.
  static const mcpDefault = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    backoffMultiplier: 1.5,
    jitter: true,
  );

  /// No retries.
  static const noRetry = RetryConfig(maxRetries: 0);

  /// Create from JSON.
  factory RetryConfig.fromJson(Map<String, dynamic> json) {
    return RetryConfig(
      maxRetries: json['maxRetries'] as int? ?? 3,
      initialDelay: json['initialDelayMs'] != null
          ? Duration(milliseconds: json['initialDelayMs'] as int)
          : const Duration(seconds: 1),
      maxDelay: json['maxDelayMs'] != null
          ? Duration(milliseconds: json['maxDelayMs'] as int)
          : const Duration(seconds: 30),
      backoffMultiplier: (json['backoffMultiplier'] as num?)?.toDouble() ?? 2.0,
      jitter: json['jitter'] as bool? ?? true,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'maxRetries': maxRetries,
        'initialDelayMs': initialDelay.inMilliseconds,
        'maxDelayMs': maxDelay.inMilliseconds,
        'backoffMultiplier': backoffMultiplier,
        'jitter': jitter,
      };

  /// Calculate delay for given attempt number.
  Duration delayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;

    var delay = initialDelay * (backoffMultiplier * attempt);
    if (delay > maxDelay) delay = maxDelay;

    if (jitter) {
      final jitterAmount =
          delay * (0.1 + (DateTime.now().millisecond % 20) / 100);
      delay = delay + jitterAmount;
    }

    return delay;
  }

  @override
  String toString() =>
      'RetryConfig(maxRetries: $maxRetries, initialDelay: $initialDelay)';
}

/// Cache configuration hints.
class CacheConfig {
  /// Whether caching is enabled.
  final bool enabled;

  /// Cache TTL (time-to-live).
  final Duration? ttl;

  /// Cache key prefix.
  final String? keyPrefix;

  /// Whether to use stale cache while revalidating.
  final bool staleWhileRevalidate;

  /// Cache scope (e.g., 'user', 'workspace', 'global').
  final String scope;

  const CacheConfig({
    this.enabled = true,
    this.ttl,
    this.keyPrefix,
    this.staleWhileRevalidate = false,
    this.scope = 'workspace',
  });

  /// Disable caching.
  static const disabled = CacheConfig(enabled: false);

  /// Short-lived cache (5 minutes).
  static const short = CacheConfig(
    enabled: true,
    ttl: Duration(minutes: 5),
  );

  /// Medium-lived cache (1 hour).
  static const medium = CacheConfig(
    enabled: true,
    ttl: Duration(hours: 1),
  );

  /// Long-lived cache (24 hours).
  static const long = CacheConfig(
    enabled: true,
    ttl: Duration(hours: 24),
  );

  /// Create from JSON.
  factory CacheConfig.fromJson(Map<String, dynamic> json) {
    return CacheConfig(
      enabled: json['enabled'] as bool? ?? true,
      ttl: json['ttlMs'] != null
          ? Duration(milliseconds: json['ttlMs'] as int)
          : null,
      keyPrefix: json['keyPrefix'] as String?,
      staleWhileRevalidate: json['staleWhileRevalidate'] as bool? ?? false,
      scope: json['scope'] as String? ?? 'workspace',
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        if (ttl != null) 'ttlMs': ttl!.inMilliseconds,
        if (keyPrefix != null) 'keyPrefix': keyPrefix,
        'staleWhileRevalidate': staleWhileRevalidate,
        'scope': scope,
      };

  @override
  String toString() =>
      'CacheConfig(enabled: $enabled, ttl: $ttl, scope: $scope)';
}
