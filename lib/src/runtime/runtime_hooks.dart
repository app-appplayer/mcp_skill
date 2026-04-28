/// Runtime Hooks - Observability and lifecycle hooks for skill execution.
///
/// Implements the hook system for monitoring and extending runtime behavior.
library;

import 'skill_context.dart';
import 'skill_result.dart';

/// Runtime hook for observability and lifecycle events.
abstract class RuntimeHook {
  /// Called before skill execution starts.
  Future<void> beforeExecution(SkillContext context) async {}

  /// Called after skill execution completes.
  Future<void> afterExecution(
      SkillContext context, SkillResult result) async {}

  /// Called when routing phase starts.
  Future<void> onRouting(SkillContext context) async {}

  /// Called when context building phase starts.
  Future<void> onContextBuilding(SkillContext context) async {}

  /// Called when planning phase starts.
  Future<void> onPlanning(SkillContext context, List<String> skillIds) async {}

  /// Called when execution phase starts.
  Future<void> onExecutionStart(SkillContext context) async {}

  /// Called when validation phase starts.
  Future<void> onValidation(SkillContext context) async {}

  /// Called when persistence phase starts.
  Future<void> onPersistence(SkillContext context) async {}

  /// Called when an error occurs.
  Future<void> onError(
      SkillContext context, Object error, StackTrace stackTrace) async {}

  /// Called for non-fatal warnings.
  Future<void> onWarning(SkillContext context, String message) async {}

  /// Called when a step starts executing.
  Future<void> onStepStart(
      SkillContext context, String stepId, Map<String, dynamic> inputs) async {}

  /// Called when a step completes.
  Future<void> onStepComplete(
      SkillContext context, String stepId, Map<String, dynamic> output) async {}

  /// Called when a step fails.
  Future<void> onStepFailure(
      SkillContext context, String stepId, Object error) async {}

  /// Called when budget is checked.
  Future<void> onBudgetCheck(
      SkillContext context, BudgetCheckResult result) async {}

  /// Called when claims are extracted.
  Future<void> onClaimsExtracted(
      SkillContext context, List<dynamic> claims) async {}
}

/// Logging hook - logs events to console/logger.
class LoggingHook extends RuntimeHook {
  final void Function(String level, String message) _logger;
  final bool verbose;

  LoggingHook({
    required void Function(String level, String message) logger,
    this.verbose = false,
  }) : _logger = logger;

  @override
  Future<void> beforeExecution(SkillContext context) async {
    _logger('INFO',
        '[${context.runId}] Starting execution for skill ${context.skillId}');
  }

  @override
  Future<void> afterExecution(
      SkillContext context, SkillResult result) async {
    final status = result.success ? 'SUCCESS' : 'FAILURE';
    _logger('INFO',
        '[${context.runId}] Execution completed: $status (${result.claims.length} claims)');
  }

  @override
  Future<void> onError(
      SkillContext context, Object error, StackTrace stackTrace) async {
    _logger('ERROR', '[${context.runId}] Error: $error\n$stackTrace');
  }

  @override
  Future<void> onWarning(SkillContext context, String message) async {
    _logger('WARN', '[${context.runId}] Warning: $message');
  }

  @override
  Future<void> onStepStart(SkillContext context, String stepId,
      Map<String, dynamic> inputs) async {
    if (verbose) {
      _logger('DEBUG', '[${context.runId}] Step $stepId started');
    }
  }

  @override
  Future<void> onStepComplete(SkillContext context, String stepId,
      Map<String, dynamic> output) async {
    if (verbose) {
      _logger('DEBUG', '[${context.runId}] Step $stepId completed');
    }
  }
}

/// Metrics hook - tracks performance metrics.
class MetricsHook extends RuntimeHook {
  final Map<String, List<Duration>> _durations = {};
  final Map<String, int> _counters = {};

  DateTime? _executionStart;

  @override
  Future<void> beforeExecution(SkillContext context) async {
    _executionStart = DateTime.now();
    _incrementCounter('executions.started');
  }

  @override
  Future<void> afterExecution(
      SkillContext context, SkillResult result) async {
    if (_executionStart != null) {
      final duration = DateTime.now().difference(_executionStart!);
      _recordDuration('execution.total', duration);
    }

    if (result.success) {
      _incrementCounter('executions.succeeded');
    } else {
      _incrementCounter('executions.failed');
    }

    _incrementCounter('claims.extracted', result.claims.length);
  }

  @override
  Future<void> onError(
      SkillContext context, Object error, StackTrace stackTrace) async {
    _incrementCounter('errors.total');
    _incrementCounter('errors.${error.runtimeType}');
  }

  void _recordDuration(String metric, Duration duration) {
    _durations.putIfAbsent(metric, () => []).add(duration);
  }

  void _incrementCounter(String metric, [int by = 1]) {
    _counters[metric] = (_counters[metric] ?? 0) + by;
  }

  /// Get metrics summary.
  Map<String, dynamic> getMetrics() {
    final metrics = <String, dynamic>{};

    // Counters
    metrics['counters'] = Map<String, int>.from(_counters);

    // Durations (with percentiles)
    final durations = <String, dynamic>{};
    for (final entry in _durations.entries) {
      final sorted = List<Duration>.from(entry.value)
        ..sort((a, b) => a.compareTo(b));
      final count = sorted.length;

      durations[entry.key] = {
        'count': count,
        'min': sorted.first.inMilliseconds,
        'max': sorted.last.inMilliseconds,
        'avg': sorted.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/
            count,
        'p50': sorted[count ~/ 2].inMilliseconds,
        'p95': sorted[(count * 0.95).toInt()].inMilliseconds,
        'p99': sorted[(count * 0.99).toInt()].inMilliseconds,
      };
    }
    metrics['durations'] = durations;

    return metrics;
  }

  /// Reset all metrics.
  void reset() {
    _durations.clear();
    _counters.clear();
  }
}

/// Tracing hook - adds distributed tracing support.
class TracingHook extends RuntimeHook {
  final void Function(String traceId, String spanId, String name,
      Map<String, dynamic> tags) _recordSpan;

  String? _currentSpanId;

  TracingHook({
    required void Function(String traceId, String spanId, String name,
            Map<String, dynamic> tags)
        recordSpan,
  }) : _recordSpan = recordSpan;

  @override
  Future<void> beforeExecution(SkillContext context) async {
    _currentSpanId = _generateSpanId();
    _recordSpan(
      context.traceId,
      _currentSpanId!,
      'skill.execution',
      {
        'skill.id': context.skillId,
        'run.id': context.runId,
        'workspace.id': context.workspaceId,
      },
    );
  }

  @override
  Future<void> onStepStart(SkillContext context, String stepId,
      Map<String, dynamic> inputs) async {
    final spanId = _generateSpanId();
    _recordSpan(
      context.traceId,
      spanId,
      'skill.step',
      {
        'step.id': stepId,
        'parent.span.id': _currentSpanId,
      },
    );
  }

  String _generateSpanId() {
    return DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  }
}

/// Budget check result.
class BudgetCheckResult {
  final bool passed;
  final String? reason;
  final Map<String, dynamic> usage;

  const BudgetCheckResult({
    required this.passed,
    this.reason,
    required this.usage,
  });
}

/// Composite hook - combines multiple hooks.
class CompositeHook extends RuntimeHook {
  final List<RuntimeHook> hooks;

  CompositeHook(this.hooks);

  @override
  Future<void> beforeExecution(SkillContext context) async {
    for (final hook in hooks) {
      await hook.beforeExecution(context);
    }
  }

  @override
  Future<void> afterExecution(
      SkillContext context, SkillResult result) async {
    for (final hook in hooks) {
      await hook.afterExecution(context, result);
    }
  }

  @override
  Future<void> onError(
      SkillContext context, Object error, StackTrace stackTrace) async {
    for (final hook in hooks) {
      await hook.onError(context, error, stackTrace);
    }
  }

  @override
  Future<void> onWarning(SkillContext context, String message) async {
    for (final hook in hooks) {
      await hook.onWarning(context, message);
    }
  }

  @override
  Future<void> onStepStart(SkillContext context, String stepId,
      Map<String, dynamic> inputs) async {
    for (final hook in hooks) {
      await hook.onStepStart(context, stepId, inputs);
    }
  }

  @override
  Future<void> onStepComplete(SkillContext context, String stepId,
      Map<String, dynamic> output) async {
    for (final hook in hooks) {
      await hook.onStepComplete(context, stepId, output);
    }
  }

  @override
  Future<void> onRouting(SkillContext context) async {
    for (final hook in hooks) {
      await hook.onRouting(context);
    }
  }

  @override
  Future<void> onContextBuilding(SkillContext context) async {
    for (final hook in hooks) {
      await hook.onContextBuilding(context);
    }
  }

  @override
  Future<void> onPlanning(SkillContext context, List<String> skillIds) async {
    for (final hook in hooks) {
      await hook.onPlanning(context, skillIds);
    }
  }

  @override
  Future<void> onExecutionStart(SkillContext context) async {
    for (final hook in hooks) {
      await hook.onExecutionStart(context);
    }
  }

  @override
  Future<void> onValidation(SkillContext context) async {
    for (final hook in hooks) {
      await hook.onValidation(context);
    }
  }

  @override
  Future<void> onPersistence(SkillContext context) async {
    for (final hook in hooks) {
      await hook.onPersistence(context);
    }
  }
}
