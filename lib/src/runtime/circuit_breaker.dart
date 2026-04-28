/// Circuit Breaker - Protection pattern for external service calls.
///
/// Prevents cascading failures by tracking failure rates and
/// temporarily blocking requests when failure threshold is reached.
library;

import '../exceptions/exceptions.dart';

/// Circuit breaker for external service calls.
class CircuitBreaker {
  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// Duration to wait before allowing test requests.
  final Duration resetTimeout;

  /// Duration for half-open test period.
  final Duration halfOpenTimeout;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(minutes: 1),
    this.halfOpenTimeout = const Duration(seconds: 10),
  });

  /// Execute operation with circuit breaker protection.
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (!allowRequest()) {
      throw CircuitOpenException('Circuit is open, request blocked');
    }

    try {
      final result = await operation();
      onSuccess();
      return result;
    } catch (e) {
      onFailure();
      rethrow;
    }
  }

  /// Whether a request is allowed based on circuit state.
  bool allowRequest() {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;

      case CircuitBreakerState.open:
        if (_lastFailureTime != null &&
            DateTime.now().difference(_lastFailureTime!) >= resetTimeout) {
          _state = CircuitBreakerState.halfOpen;
          return true;
        }
        return false;

      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  /// Record a successful operation.
  void onSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
  }

  /// Record a failed operation.
  void onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
    }
  }

  /// Current circuit state.
  CircuitBreakerState get state => _state;

  /// Current failure count.
  int get failureCount => _failureCount;
}

/// Circuit breaker states.
enum CircuitBreakerState { closed, open, halfOpen }

/// Exception thrown when a circuit breaker is open.
class CircuitOpenException extends SkillExecutionException {
  CircuitOpenException(String message) : super(message);

  @override
  String get code => 'CIRCUIT_OPEN';

  @override
  bool get isRetryable => false;
}

/// Service degradation levels.
enum DegradationLevel {
  /// Full functionality.
  full,

  /// Reduced functionality (e.g., no LLM features).
  reduced,

  /// Minimal functionality (e.g., cached responses only).
  minimal,

  /// Service unavailable.
  unavailable,
}

/// Feature availability based on degradation level.
class FeatureAvailability {
  /// Current degradation level.
  final DegradationLevel level;

  FeatureAvailability(this.level);

  /// Whether LLM is available.
  bool get llmAvailable => level == DegradationLevel.full;

  /// Whether MCP tools are available.
  bool get mcpToolsAvailable =>
      level.index <= DegradationLevel.reduced.index;

  /// Whether knowledge queries are available.
  bool get knowledgeQueryAvailable =>
      level.index <= DegradationLevel.reduced.index;

  /// Whether cached responses are available.
  bool get cachedResponsesAvailable =>
      level.index <= DegradationLevel.minimal.index;

  /// Get degraded action type for a given action type.
  String? getDegradedAction(String actionType) {
    if (level == DegradationLevel.full) return null;

    switch (actionType) {
      case 'llm':
        return level == DegradationLevel.reduced ? 'retrieve' : 'cache';
      case 'tool':
        return level == DegradationLevel.minimal ? 'cache' : null;
      default:
        return null;
    }
  }
}
