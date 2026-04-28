// Tests for CircuitBreaker state machine and FeatureAvailability.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/circuit_breaker.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker breaker;

    setUp(() {
      breaker = CircuitBreaker(
        failureThreshold: 3,
        resetTimeout: const Duration(milliseconds: 50),
        halfOpenTimeout: const Duration(milliseconds: 10),
      );
    });

    test('starts in closed state', () {
      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.failureCount, equals(0));
    });

    test('allows requests in closed state', () {
      expect(breaker.allowRequest(), isTrue);
    });

    test('remains closed below failure threshold', () {
      breaker.onFailure();
      breaker.onFailure();
      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.failureCount, equals(2));
    });

    test('transitions closed to open after failure threshold', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure();
      }
      expect(breaker.state, equals(CircuitBreakerState.open));
      expect(breaker.failureCount, equals(3));
    });

    test('blocks requests in open state', () {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure();
      }
      expect(breaker.allowRequest(), isFalse);
    });

    test('transitions open to halfOpen after reset timeout', () async {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure();
      }
      expect(breaker.state, equals(CircuitBreakerState.open));

      // Wait well beyond reset timeout to avoid timing flakiness
      await Future.delayed(const Duration(milliseconds: 200));

      // allowRequest should trigger transition to halfOpen
      expect(breaker.allowRequest(), isTrue);
      expect(breaker.state, equals(CircuitBreakerState.halfOpen));
    });

    test('transitions halfOpen to closed on success', () async {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure();
      }
      await Future.delayed(const Duration(milliseconds: 60));
      breaker.allowRequest(); // Triggers halfOpen

      breaker.onSuccess();
      expect(breaker.state, equals(CircuitBreakerState.closed));
      expect(breaker.failureCount, equals(0));
    });

    test('transitions halfOpen to open on failure', () async {
      for (var i = 0; i < 3; i++) {
        breaker.onFailure();
      }
      await Future.delayed(const Duration(milliseconds: 60));
      breaker.allowRequest(); // Triggers halfOpen

      // One failure in halfOpen should re-open (threshold already met)
      for (var i = 0; i < 3; i++) {
        breaker.onFailure();
      }
      expect(breaker.state, equals(CircuitBreakerState.open));
    });

    test('success resets failure count to zero', () {
      breaker.onFailure();
      breaker.onFailure();
      expect(breaker.failureCount, equals(2));

      breaker.onSuccess();
      expect(breaker.failureCount, equals(0));
      expect(breaker.state, equals(CircuitBreakerState.closed));
    });

    group('execute', () {
      test('returns result on success', () async {
        final result = await breaker.execute(() async => 42);
        expect(result, equals(42));
        expect(breaker.state, equals(CircuitBreakerState.closed));
      });

      test('records failure and rethrows on error', () async {
        await expectLater(
          () => breaker.execute(() async => throw Exception('fail')),
          throwsA(isA<Exception>()),
        );
        expect(breaker.failureCount, equals(1));
      });

      test('throws CircuitOpenException when circuit is open', () async {
        for (var i = 0; i < 3; i++) {
          breaker.onFailure();
        }

        expect(
          () => breaker.execute(() async => 'should not run'),
          throwsA(isA<CircuitOpenException>()),
        );
      });
    });
  });

  group('CircuitOpenException', () {
    test('has correct code', () {
      final exception = CircuitOpenException('test');
      expect(exception.code, equals('CIRCUIT_OPEN'));
    });

    test('is not retryable', () {
      final exception = CircuitOpenException('test');
      expect(exception.isRetryable, isFalse);
    });

    test('contains message', () {
      final exception = CircuitOpenException('Circuit is open');
      expect(exception.message, contains('Circuit is open'));
    });
  });

  group('DegradationLevel', () {
    test('has four levels in correct order', () {
      expect(DegradationLevel.values.length, equals(4));
      expect(DegradationLevel.full.index, equals(0));
      expect(DegradationLevel.reduced.index, equals(1));
      expect(DegradationLevel.minimal.index, equals(2));
      expect(DegradationLevel.unavailable.index, equals(3));
    });
  });

  group('FeatureAvailability', () {
    test('full level has all features available', () {
      final availability = FeatureAvailability(DegradationLevel.full);
      expect(availability.llmAvailable, isTrue);
      expect(availability.mcpToolsAvailable, isTrue);
      expect(availability.knowledgeQueryAvailable, isTrue);
      expect(availability.cachedResponsesAvailable, isTrue);
    });

    test('reduced level disables LLM', () {
      final availability = FeatureAvailability(DegradationLevel.reduced);
      expect(availability.llmAvailable, isFalse);
      expect(availability.mcpToolsAvailable, isTrue);
      expect(availability.knowledgeQueryAvailable, isTrue);
      expect(availability.cachedResponsesAvailable, isTrue);
    });

    test('minimal level disables LLM, MCP, and knowledge', () {
      final availability = FeatureAvailability(DegradationLevel.minimal);
      expect(availability.llmAvailable, isFalse);
      expect(availability.mcpToolsAvailable, isFalse);
      expect(availability.knowledgeQueryAvailable, isFalse);
      expect(availability.cachedResponsesAvailable, isTrue);
    });

    test('unavailable level disables everything', () {
      final availability = FeatureAvailability(DegradationLevel.unavailable);
      expect(availability.llmAvailable, isFalse);
      expect(availability.mcpToolsAvailable, isFalse);
      expect(availability.knowledgeQueryAvailable, isFalse);
      expect(availability.cachedResponsesAvailable, isFalse);
    });

    group('getDegradedAction', () {
      test('returns null at full level', () {
        final availability = FeatureAvailability(DegradationLevel.full);
        expect(availability.getDegradedAction('llm'), isNull);
        expect(availability.getDegradedAction('tool'), isNull);
      });

      test('llm degrades to retrieve at reduced level', () {
        final availability = FeatureAvailability(DegradationLevel.reduced);
        expect(availability.getDegradedAction('llm'), equals('retrieve'));
      });

      test('llm degrades to cache at minimal level', () {
        final availability = FeatureAvailability(DegradationLevel.minimal);
        expect(availability.getDegradedAction('llm'), equals('cache'));
      });

      test('tool degrades to cache at minimal level', () {
        final availability = FeatureAvailability(DegradationLevel.minimal);
        expect(availability.getDegradedAction('tool'), equals('cache'));
      });

      test('tool returns null at reduced level', () {
        final availability = FeatureAvailability(DegradationLevel.reduced);
        expect(availability.getDegradedAction('tool'), isNull);
      });

      test('unknown action type returns null', () {
        final availability = FeatureAvailability(DegradationLevel.reduced);
        expect(availability.getDegradedAction('unknown'), isNull);
      });
    });
  });

  group('CircuitBreakerState', () {
    test('has three states', () {
      expect(CircuitBreakerState.values.length, equals(3));
      expect(CircuitBreakerState.values, contains(CircuitBreakerState.closed));
      expect(CircuitBreakerState.values, contains(CircuitBreakerState.open));
      expect(
          CircuitBreakerState.values, contains(CircuitBreakerState.halfOpen));
    });
  });
}
