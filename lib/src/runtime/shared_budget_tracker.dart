/// Shared Budget Tracker - Thread-safe budget tracking for parallel execution.
///
/// Implements atomic budget tracking with reservation system for concurrent operations.
library;

import 'dart:async';
import 'skill_context.dart';

/// Thread-safe budget tracking for parallel execution.
///
/// Uses mutex-like locking to ensure atomic budget checks and updates
/// when multiple steps execute concurrently.
class SharedBudgetTracker {
  final ExecutionBudget budget;
  final _lock = _AsyncLock();

  int _tokensUsed = 0;
  int _stepsExecuted = 0;
  int _llmCallsMade = 0;
  int _mcpCallsMade = 0;
  final DateTime _startTime = DateTime.now();

  final List<BudgetReservation> _activeReservations = [];

  SharedBudgetTracker(this.budget);

  /// Atomically check and reserve budget.
  ///
  /// Returns a reservation if budget is available, null otherwise.
  Future<BudgetReservation?> tryReserve(BudgetCost cost) async {
    return await _lock.synchronized(() {
      // Check if reservation is possible
      final totalTokens = _tokensUsed +
          _activeReservations.fold(0, (sum, r) => sum + r.reserved.estimatedTokens);
      final totalSteps = _stepsExecuted +
          _activeReservations.fold(0, (sum, r) => sum + r.reserved.steps);
      final totalLlm = _llmCallsMade +
          _activeReservations.fold(0, (sum, r) => sum + r.reserved.llmCalls);
      final totalMcp = _mcpCallsMade +
          _activeReservations.fold(0, (sum, r) => sum + r.reserved.mcpCalls);

      if (totalTokens + cost.estimatedTokens > budget.maxTokens ||
          totalSteps + cost.steps > budget.maxSteps ||
          (budget.maxLlmCalls > 0 && totalLlm + cost.llmCalls > budget.maxLlmCalls) ||
          (budget.maxMcpCalls > 0 && totalMcp + cost.mcpCalls > budget.maxMcpCalls)) {
        return null; // Budget exceeded
      }

      // Create reservation
      final reservation = BudgetReservation(
        reservationId: _generateReservationId(),
        reserved: cost,
        tracker: this,
      );

      _activeReservations.add(reservation);
      return reservation;
    });
  }

  /// Commit a reservation with actual usage.
  Future<void> _commit(BudgetReservation reservation, BudgetCost actual) async {
    await _lock.synchronized(() {
      _activeReservations.remove(reservation);

      _tokensUsed += actual.estimatedTokens;
      _stepsExecuted += actual.steps;
      _llmCallsMade += actual.llmCalls;
      _mcpCallsMade += actual.mcpCalls;
      return null;
    });
  }

  /// Release a reservation without committing.
  Future<void> _release(BudgetReservation reservation) async {
    await _lock.synchronized(() {
      _activeReservations.remove(reservation);
      return null;
    });
  }

  /// Check if operation would fit in budget.
  Future<bool> canAfford(BudgetCost cost) async {
    return await _lock.synchronized(() {
      return _tokensUsed + cost.estimatedTokens <= budget.maxTokens &&
          _stepsExecuted + cost.steps <= budget.maxSteps &&
          _llmCallsMade + cost.llmCalls <= budget.maxLlmCalls &&
          _mcpCallsMade + cost.mcpCalls <= budget.maxMcpCalls;
    });
  }

  /// Get current usage.
  Future<Map<String, dynamic>> getUsage() async {
    return await _lock.synchronized(() {
      return {
        'tokensUsed': _tokensUsed,
        'stepsExecuted': _stepsExecuted,
        'llmCallsMade': _llmCallsMade,
        'mcpCallsMade': _mcpCallsMade,
        'elapsedMs': DateTime.now().difference(_startTime).inMilliseconds,
        'activeReservations': _activeReservations.length,
      };
    });
  }

  /// Check if budget is exceeded.
  Future<bool> isExceeded() async {
    return await _lock.synchronized(() {
      return !budget.isWithinTokenBudget(_tokensUsed) ||
          !budget.isWithinStepBudget(_stepsExecuted) ||
          !budget.isWithinDurationBudget(DateTime.now().difference(_startTime)) ||
          (budget.maxLlmCalls > 0 && _llmCallsMade > budget.maxLlmCalls) ||
          (budget.maxMcpCalls > 0 && _mcpCallsMade > budget.maxMcpCalls);
    });
  }

  String _generateReservationId() {
    return 'res_${DateTime.now().microsecondsSinceEpoch}_${_activeReservations.length}';
  }
}

/// Budget cost estimate for an operation.
class BudgetCost {
  final int estimatedTokens;
  final int steps;
  final int llmCalls;
  final int mcpCalls;

  /// Estimated duration of the operation.
  final Duration? estimatedDuration;

  const BudgetCost({
    this.estimatedTokens = 0,
    this.steps = 1,
    this.llmCalls = 0,
    this.mcpCalls = 0,
    this.estimatedDuration,
  });

  /// Cost for an LLM call.
  factory BudgetCost.llm({int estimatedTokens = 1000}) {
    return BudgetCost(
      estimatedTokens: estimatedTokens,
      steps: 1,
      llmCalls: 1,
    );
  }

  /// Cost for an MCP tool call.
  factory BudgetCost.mcp() {
    return const BudgetCost(
      steps: 1,
      mcpCalls: 1,
    );
  }

  /// Cost for a simple step.
  factory BudgetCost.step() {
    return const BudgetCost(steps: 1);
  }
}

/// Reservation handle for budget.
class BudgetReservation {
  final String reservationId;
  final BudgetCost reserved;
  final SharedBudgetTracker _tracker;

  bool _released = false;

  BudgetReservation({
    required this.reservationId,
    required this.reserved,
    required SharedBudgetTracker tracker,
  }) : _tracker = tracker;

  /// Commit the reservation with actual usage.
  Future<void> commit(BudgetCost actual) async {
    if (_released) {
      throw StateError('Reservation already released: $reservationId');
    }
    _released = true;
    await _tracker._commit(this, actual);
  }

  /// Release the reservation without using budget.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _tracker._release(this);
  }
}

/// Simple async lock implementation.
class _AsyncLock {
  Completer<void>? _completer;

  Future<T> synchronized<T>(T Function() action) async {
    // Wait for previous lock to release
    while (_completer != null) {
      await _completer!.future;
    }

    // Acquire lock
    _completer = Completer<void>();

    try {
      return await action();
    } finally {
      // Release lock
      final completer = _completer;
      _completer = null;
      completer?.complete();
    }
  }
}
