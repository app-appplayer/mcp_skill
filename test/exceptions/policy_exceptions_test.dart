import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/policy_exceptions.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

void main() {
  group('PolicyException', () {
    test('sets message and default code', () {
      final ex = PolicyException('policy error');
      expect(ex.message, 'policy error');
      expect(ex.code, 'POLICY_ERROR');
    });

    test('accepts optional path and cause', () {
      final cause = Exception('inner');
      final ex = PolicyException('fail', path: 'policy.rules', cause: cause);
      expect(ex.path, 'policy.rules');
      expect(ex.cause, same(cause));
    });

    test('extends SkillException', () {
      expect(PolicyException('m'), isA<SkillException>());
    });

    test('isRetryable is false', () {
      expect(PolicyException('m').isRetryable, isFalse);
    });
  });

  group('PolicyViolationException', () {
    test('stores policyRule and policyVersion', () {
      final ex = PolicyViolationException(
        'data retention violated',
        policyRule: 'data-retention-30d',
        policyVersion: '2.1.0',
      );
      expect(ex.message, 'data retention violated');
      expect(ex.policyRule, 'data-retention-30d');
      expect(ex.policyVersion, '2.1.0');
    });

    test('overrides code to POLICY_VIOLATION', () {
      expect(PolicyViolationException('m').code, 'POLICY_VIOLATION');
    });

    test('extends PolicyException', () {
      expect(PolicyViolationException('m'), isA<PolicyException>());
    });

    test('isRetryable is false', () {
      expect(PolicyViolationException('m').isRetryable, isFalse);
    });
  });

  group('PermissionDeniedException', () {
    test('stores requiredPermission and resource', () {
      final ex = PermissionDeniedException(
        'access denied',
        requiredPermission: 'admin:write',
        resource: 'users/123',
      );
      expect(ex.message, 'access denied');
      expect(ex.requiredPermission, 'admin:write');
      expect(ex.resource, 'users/123');
    });

    test('overrides code to PERMISSION_DENIED', () {
      expect(PermissionDeniedException('m').code, 'PERMISSION_DENIED');
    });

    test('extends PolicyException', () {
      expect(PermissionDeniedException('m'), isA<PolicyException>());
    });

    test('isRetryable is false', () {
      expect(PermissionDeniedException('m').isRetryable, isFalse);
    });
  });

  group('RateLimitException', () {
    test('stores limit and window', () {
      final ex = RateLimitException(
        'rate limit exceeded',
        limit: 100,
        window: const Duration(minutes: 1),
      );
      expect(ex.message, 'rate limit exceeded');
      expect(ex.limit, 100);
      expect(ex.window, const Duration(minutes: 1));
    });

    test('overrides code to RATE_LIMIT_EXCEEDED', () {
      expect(RateLimitException('m').code, 'RATE_LIMIT_EXCEEDED');
    });

    test('isRetryable is true', () {
      expect(RateLimitException('m').isRetryable, isTrue);
    });

    test('retryDelay defaults to 30s when resetsAt is null', () {
      final ex = RateLimitException('m');
      expect(ex.retryDelay, const Duration(seconds: 30));
    });

    test('retryDelay computes from resetsAt in the future', () {
      // Use a time far enough in the future that the delay is positive
      final futureTime = DateTime.now().add(const Duration(seconds: 60));
      final ex = RateLimitException('m', resetsAt: futureTime);
      final delay = ex.retryDelay!;
      // Should be roughly 60 seconds, allow some tolerance for test execution
      expect(delay.inSeconds, greaterThan(55));
      expect(delay.inSeconds, lessThanOrEqualTo(61));
    });

    test('retryDelay is at least 1s when resetsAt is in the past', () {
      final pastTime = DateTime.now().subtract(const Duration(seconds: 10));
      final ex = RateLimitException('m', resetsAt: pastTime);
      expect(ex.retryDelay, const Duration(seconds: 1));
    });

    test('extends PolicyException', () {
      expect(RateLimitException('m'), isA<PolicyException>());
    });
  });
}
