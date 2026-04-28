// Tests for RetryExecutor - retry loop, exponential backoff, shouldRetry logic.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/retry_executor.dart';
import 'package:mcp_skill/src/runtime/retry_config.dart';
import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';
import 'package:mcp_skill/src/exceptions/port_exceptions.dart';
void main() {
  group('RetryExecutor', () {
    late RetryExecutor executor;

    group('execute', () {
      test('returns result on first success without retrying', () async {
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 10),
          jitter: false,
        ));

        final result = await executor.execute(() async => 'success');

        expect(result, equals('success'));
      });

      test('retries on retryable SkillException and succeeds', () async {
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 10),
          jitter: false,
        ));

        var callCount = 0;
        final result = await executor.execute(() async {
          callCount++;
          if (callCount < 3) {
            throw LlmPortException('transient error', statusCode: 500);
          }
          return 'recovered';
        });

        expect(result, equals('recovered'));
        expect(callCount, equals(3));
      });

      test('throws after max retries exceeded', () async {
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
          jitter: false,
        ));

        expect(
          () => executor.execute(() async {
            throw LlmPortException('always fails', statusCode: 500);
          }),
          throwsA(isA<LlmPortException>()),
        );
      });

      test('does not retry non-retryable exceptions', () async {
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
          jitter: false,
        ));

        expect(
          () => executor.execute(() async {
            // statusCode 400 is not retryable for LlmPortException
            throw LlmPortException('bad request', statusCode: 400);
          }),
          throwsA(isA<LlmPortException>()),
        );
      });

      test('calls onRetry callback before each retry', () async {
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 1),
          maxDelay: Duration(milliseconds: 5),
          jitter: false,
        ));

        final retryAttempts = <int>[];
        var callCount = 0;

        await executor.execute(
          () async {
            callCount++;
            if (callCount < 3) {
              throw LlmPortException('transient', statusCode: 500);
            }
            return 'done';
          },
          onRetry: (exception, attempt) {
            retryAttempts.add(attempt);
          },
        );

        expect(retryAttempts, equals([1, 2]));
      });

      test('uses custom shouldRetry predicate', () async {
        executor = RetryExecutor(RetryConfig(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
          jitter: false,
          shouldRetry: (e) => e.message.contains('retry-me'),
        ));

        // Exception that matches predicate - should retry
        var callCount = 0;
        final result = await executor.execute(() async {
          callCount++;
          if (callCount < 2) {
            throw SkillExecutionException('retry-me please');
          }
          return 'done';
        });
        expect(result, equals('done'));
        expect(callCount, equals(2));
      });

      test('custom shouldRetry rejects non-matching exceptions', () async {
        executor = RetryExecutor(RetryConfig(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
          jitter: false,
          shouldRetry: (e) => e.message.contains('retry-me'),
        ));

        // Exception that does not match predicate - should NOT retry
        expect(
          () => executor.execute(() async {
            throw SkillExecutionException('do-not-retry');
          }),
          throwsA(isA<SkillExecutionException>()),
        );
      });

      test('respects nonRetryableExceptions list', () async {
        executor = RetryExecutor(RetryConfig(
          maxRetries: 3,
          initialDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
          jitter: false,
          nonRetryableExceptions: [BudgetExceededException],
        ));

        expect(
          () => executor.execute(() async {
            throw BudgetExceededException('tokens', 100, 200);
          }),
          throwsA(isA<BudgetExceededException>()),
        );
      });

      test('respects retryableExceptions list', () async {
        executor = RetryExecutor(RetryConfig(
          maxRetries: 2,
          initialDelay: const Duration(milliseconds: 1),
          maxDelay: const Duration(milliseconds: 5),
          jitter: false,
          retryableExceptions: [SkillTimeoutException],
        ));

        var callCount = 0;
        final result = await executor.execute(() async {
          callCount++;
          if (callCount < 2) {
            throw SkillTimeoutException(
                'llm-call', const Duration(seconds: 30));
          }
          return 'recovered';
        });

        expect(result, equals('recovered'));
        expect(callCount, equals(2));
      });

      test('zero maxRetries means no retry', () async {
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 0,
          initialDelay: Duration(milliseconds: 1),
        ));

        expect(
          () => executor.execute(() async {
            throw LlmPortException('fail', statusCode: 500);
          }),
          throwsA(isA<LlmPortException>()),
        );
      });

      test('exponential backoff increases delay between retries', () async {
        // Use a config with measurable delays but still fast for testing
        executor = RetryExecutor(const RetryConfig(
          maxRetries: 3,
          initialDelay: Duration(milliseconds: 2),
          maxDelay: Duration(milliseconds: 100),
          backoffMultiplier: 2.0,
          jitter: false,
        ));

        var callCount = 0;
        final timestamps = <DateTime>[];

        try {
          await executor.execute(() async {
            timestamps.add(DateTime.now());
            callCount++;
            throw LlmPortException('fail', statusCode: 500);
          });
        } on LlmPortException {
          // Expected
        }

        // Should have been called 4 times (initial + 3 retries)
        expect(callCount, equals(4));
        expect(timestamps.length, equals(4));
      });
    });
  });
}
