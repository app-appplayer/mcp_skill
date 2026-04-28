/// Retry Executor - Executes operations with retry logic.
///
/// Implements exponential backoff with jitter for transient failures.
library;

import 'dart:math';

import '../exceptions/exceptions.dart';
import 'retry_config.dart';

/// Executes operations with configurable retry logic.
class RetryExecutor {
  /// Retry configuration.
  final RetryConfig config;

  final Random _random = Random();

  RetryExecutor(this.config);

  /// Execute an operation with retries.
  ///
  /// Retries the [operation] according to the configured retry policy.
  /// Calls [onRetry] before each retry attempt.
  Future<T> execute<T>(
    Future<T> Function() operation, {
    void Function(SkillException, int)? onRetry,
  }) async {
    int attempt = 0;
    SkillException? lastException;

    while (attempt <= config.maxRetries) {
      try {
        return await operation();
      } on SkillException catch (e) {
        lastException = e;

        if (!_shouldRetry(e, attempt)) {
          throw e;
        }

        attempt++;
        final delay = _calculateDelay(attempt);

        onRetry?.call(e, attempt);

        await Future.delayed(delay);
      }
    }

    throw lastException!;
  }

  /// Determine whether to retry based on exception and attempt count.
  bool _shouldRetry(SkillException e, int attempt) {
    if (attempt >= config.maxRetries) return false;

    // Check custom predicate
    if (config.shouldRetry != null) {
      return config.shouldRetry!(e);
    }

    // Check non-retryable exceptions
    if (config.nonRetryableExceptions?.any((t) => e.runtimeType == t) ??
        false) {
      return false;
    }

    // Check retryable exceptions list
    if (config.retryableExceptions != null) {
      return config.retryableExceptions!.any((t) => e.runtimeType == t);
    }

    // Default: use exception's isRetryable property
    return e.isRetryable;
  }

  /// Calculate delay with exponential backoff and optional jitter.
  Duration _calculateDelay(int attempt) {
    final exponentialDelay = config.initialDelay.inMilliseconds *
        pow(config.backoffMultiplier, attempt - 1);

    final cappedDelay =
        min(exponentialDelay.toInt(), config.maxDelay.inMilliseconds);

    if (config.jitter) {
      final jitter = _random.nextInt(max(1, (cappedDelay * 0.25).toInt()));
      return Duration(milliseconds: cappedDelay + jitter);
    }

    return Duration(milliseconds: cappedDelay);
  }
}
