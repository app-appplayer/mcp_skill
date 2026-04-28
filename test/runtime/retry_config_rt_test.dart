import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/retry_config.dart';

void main() {
  group('RetryConfig', () {
    test('default constructor uses expected defaults', () {
      const config = RetryConfig();
      expect(config.maxRetries, 3);
      expect(config.initialDelay, const Duration(seconds: 1));
      expect(config.maxDelay, const Duration(seconds: 30));
      expect(config.backoffMultiplier, 2.0);
      expect(config.jitter, true);
      expect(config.retryableExceptions, isNull);
      expect(config.nonRetryableExceptions, isNull);
      expect(config.shouldRetry, isNull);
    });

    test('llmDefault has correct values', () {
      const config = RetryConfig.llmDefault;
      expect(config.maxRetries, 3);
      expect(config.initialDelay, const Duration(seconds: 2));
      expect(config.maxDelay, const Duration(seconds: 60));
      expect(config.backoffMultiplier, 2.0);
      expect(config.jitter, true);
    });

    test('mcpDefault has correct values', () {
      const config = RetryConfig.mcpDefault;
      expect(config.maxRetries, 2);
      expect(config.initialDelay, const Duration(seconds: 1));
      expect(config.maxDelay, const Duration(seconds: 10));
      expect(config.backoffMultiplier, 1.5);
      expect(config.jitter, true);
    });

    test('noRetry has maxRetries 0', () {
      const config = RetryConfig.noRetry;
      expect(config.maxRetries, 0);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'maxRetries': 5,
        'initialDelayMs': 500,
        'maxDelayMs': 10000,
        'backoffMultiplier': 3.0,
        'jitter': false,
      };
      final config = RetryConfig.fromJson(json);
      expect(config.maxRetries, 5);
      expect(config.initialDelay, const Duration(milliseconds: 500));
      expect(config.maxDelay, const Duration(milliseconds: 10000));
      expect(config.backoffMultiplier, 3.0);
      expect(config.jitter, false);
    });

    test('fromJson uses defaults for missing values', () {
      final config = RetryConfig.fromJson({});
      expect(config.maxRetries, 3);
      expect(config.initialDelay, const Duration(seconds: 1));
      expect(config.maxDelay, const Duration(seconds: 30));
      expect(config.backoffMultiplier, 2.0);
      expect(config.jitter, true);
    });

    test('toJson produces correct map', () {
      const config = RetryConfig(
        maxRetries: 2,
        initialDelay: Duration(milliseconds: 200),
        maxDelay: Duration(milliseconds: 5000),
        backoffMultiplier: 1.5,
        jitter: false,
      );
      final json = config.toJson();
      expect(json['maxRetries'], 2);
      expect(json['initialDelayMs'], 200);
      expect(json['maxDelayMs'], 5000);
      expect(json['backoffMultiplier'], 1.5);
      expect(json['jitter'], false);
    });

    test('fromJson/toJson round-trip', () {
      const original = RetryConfig(
        maxRetries: 4,
        initialDelay: Duration(milliseconds: 750),
        maxDelay: Duration(milliseconds: 15000),
        backoffMultiplier: 2.5,
        jitter: true,
      );
      final json = original.toJson();
      final restored = RetryConfig.fromJson(json);
      expect(restored.maxRetries, original.maxRetries);
      expect(restored.initialDelay, original.initialDelay);
      expect(restored.maxDelay, original.maxDelay);
      expect(restored.backoffMultiplier, original.backoffMultiplier);
      expect(restored.jitter, original.jitter);
    });

    group('delayForAttempt', () {
      test('returns Duration.zero for attempt <= 0', () {
        const config = RetryConfig(jitter: false);
        expect(config.delayForAttempt(0), Duration.zero);
        expect(config.delayForAttempt(-1), Duration.zero);
      });

      test('increases with attempt number (no jitter)', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          maxDelay: Duration(seconds: 100),
          jitter: false,
        );
        final delay1 = config.delayForAttempt(1);
        final delay2 = config.delayForAttempt(2);
        // delay = initialDelay * (backoffMultiplier * attempt)
        // attempt 1: 1s * 2.0 = 2s
        // attempt 2: 1s * 4.0 = 4s
        expect(delay2 > delay1, isTrue);
      });

      test('caps at maxDelay (no jitter)', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 10),
          backoffMultiplier: 10.0,
          maxDelay: Duration(seconds: 30),
          jitter: false,
        );
        final delay = config.delayForAttempt(5);
        expect(delay, const Duration(seconds: 30));
      });

      test('jitter adds additional delay', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          maxDelay: Duration(seconds: 100),
          jitter: true,
        );
        // With jitter, delay should be >= the base delay
        final delay = config.delayForAttempt(1);
        // Base delay = 1s * 2.0 = 2s; jitter adds 10-30% so >= 2s
        expect(delay.inMilliseconds, greaterThanOrEqualTo(2000));
      });
    });

    test('toString contains maxRetries and initialDelay', () {
      const config = RetryConfig(maxRetries: 5);
      final str = config.toString();
      expect(str, contains('maxRetries: 5'));
      expect(str, contains('initialDelay'));
    });
  });

  group('CacheConfig', () {
    test('default constructor uses expected defaults', () {
      const config = CacheConfig();
      expect(config.enabled, true);
      expect(config.ttl, isNull);
      expect(config.keyPrefix, isNull);
      expect(config.staleWhileRevalidate, false);
      expect(config.scope, 'workspace');
    });

    test('disabled has enabled false', () {
      const config = CacheConfig.disabled;
      expect(config.enabled, false);
    });

    test('short has 5 minute TTL', () {
      const config = CacheConfig.short;
      expect(config.enabled, true);
      expect(config.ttl, const Duration(minutes: 5));
    });

    test('medium has 1 hour TTL', () {
      const config = CacheConfig.medium;
      expect(config.enabled, true);
      expect(config.ttl, const Duration(hours: 1));
    });

    test('long has 24 hour TTL', () {
      const config = CacheConfig.long;
      expect(config.enabled, true);
      expect(config.ttl, const Duration(hours: 24));
    });

    test('fromJson creates correct instance', () {
      final json = {
        'enabled': true,
        'ttlMs': 60000,
        'keyPrefix': 'test_',
        'staleWhileRevalidate': true,
        'scope': 'global',
      };
      final config = CacheConfig.fromJson(json);
      expect(config.enabled, true);
      expect(config.ttl, const Duration(minutes: 1));
      expect(config.keyPrefix, 'test_');
      expect(config.staleWhileRevalidate, true);
      expect(config.scope, 'global');
    });

    test('fromJson uses defaults for missing values', () {
      final config = CacheConfig.fromJson({});
      expect(config.enabled, true);
      expect(config.ttl, isNull);
      expect(config.keyPrefix, isNull);
      expect(config.staleWhileRevalidate, false);
      expect(config.scope, 'workspace');
    });

    test('toJson produces correct map', () {
      const config = CacheConfig(
        enabled: true,
        ttl: Duration(minutes: 10),
        keyPrefix: 'mykey_',
        staleWhileRevalidate: true,
        scope: 'user',
      );
      final json = config.toJson();
      expect(json['enabled'], true);
      expect(json['ttlMs'], 600000);
      expect(json['keyPrefix'], 'mykey_');
      expect(json['staleWhileRevalidate'], true);
      expect(json['scope'], 'user');
    });

    test('toJson omits null optional fields', () {
      const config = CacheConfig();
      final json = config.toJson();
      expect(json.containsKey('ttlMs'), false);
      expect(json.containsKey('keyPrefix'), false);
    });

    test('fromJson/toJson round-trip', () {
      const original = CacheConfig(
        enabled: true,
        ttl: Duration(minutes: 30),
        keyPrefix: 'round_',
        staleWhileRevalidate: true,
        scope: 'global',
      );
      final json = original.toJson();
      final restored = CacheConfig.fromJson(json);
      expect(restored.enabled, original.enabled);
      expect(restored.ttl, original.ttl);
      expect(restored.keyPrefix, original.keyPrefix);
      expect(restored.staleWhileRevalidate, original.staleWhileRevalidate);
      expect(restored.scope, original.scope);
    });

    test('toString contains enabled, ttl, scope', () {
      const config = CacheConfig(
        enabled: true,
        ttl: Duration(hours: 1),
        scope: 'user',
      );
      final str = config.toString();
      expect(str, contains('enabled: true'));
      expect(str, contains('scope: user'));
    });
  });
}
