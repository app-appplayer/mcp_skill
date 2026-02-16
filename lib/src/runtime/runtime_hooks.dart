/// Runtime Hooks - Event handling for skill execution lifecycle.
///
/// Provides hooks for monitoring and extending skill execution
/// including logging, metrics, and custom event handling.
library;

import 'skill_context.dart';
import 'skill_result.dart';
import 'procedure_executor.dart';
import '../bundle/skill_bundle.dart';

/// Hook for runtime events.
///
/// Implement this interface to receive notifications about
/// skill execution lifecycle events.
abstract class RuntimeHook {
  /// Called when skill execution starts.
  Future<void> onSkillStart(SkillContext context, SkillBundle bundle);

  /// Called when a step starts.
  Future<void> onStepStart(ProcedureStep step);

  /// Called when a step completes successfully.
  Future<void> onStepComplete(ProcedureStep step, StepResult result);

  /// Called when skill execution completes.
  Future<void> onSkillComplete(SkillResult result);

  /// Called when an error occurs.
  Future<void> onError(Object error, StackTrace stackTrace);
}

/// Logging hook for runtime events.
///
/// Logs skill execution events. In production, would use a proper
/// logging system instead of print statements.
class LoggingHook implements RuntimeHook {
  /// Log level.
  final LogLevel level;

  /// Custom logger callback.
  final void Function(LogLevel level, String message)? logger;

  LoggingHook({
    this.level = LogLevel.info,
    this.logger,
  });

  @override
  Future<void> onSkillStart(SkillContext context, SkillBundle bundle) async {
    _log(LogLevel.info, 'Skill started: ${bundle.bundleId} - ${context.request}');
  }

  @override
  Future<void> onStepStart(ProcedureStep step) async {
    _log(LogLevel.debug, 'Step started: ${step.id} (${step.name})');
  }

  @override
  Future<void> onStepComplete(ProcedureStep step, StepResult result) async {
    _log(LogLevel.debug, 'Step completed: ${step.id} - claims: ${result.claims.length}');
  }

  @override
  Future<void> onSkillComplete(SkillResult result) async {
    _log(
      LogLevel.info,
      'Skill completed: ${result.metadata.skillId} - confidence: ${result.confidence}',
    );
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    _log(LogLevel.error, 'Error: $error\n$stackTrace');
  }

  void _log(LogLevel logLevel, String message) {
    if (logLevel.index >= level.index) {
      if (logger != null) {
        logger!(logLevel, message);
      }
      // Would use proper logging in production
    }
  }
}

/// Log levels.
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Metrics hook for tracking execution statistics.
class MetricsHook implements RuntimeHook {
  /// Metrics collector callback.
  final void Function(String metricName, double value, Map<String, String> tags)?
      collector;

  /// Tracked metrics.
  final _metrics = <String, _MetricEntry>{};

  MetricsHook({this.collector});

  @override
  Future<void> onSkillStart(SkillContext context, SkillBundle bundle) async {
    final key = '${bundle.bundleId}_${DateTime.now().millisecondsSinceEpoch}';
    _metrics[key] = _MetricEntry(
      skillId: bundle.bundleId,
      startTime: DateTime.now(),
    );
    _emit('skill.started', 1, {'skill_id': bundle.bundleId});
  }

  @override
  Future<void> onStepStart(ProcedureStep step) async {
    _emit('step.started', 1, {'step_id': step.id, 'step_type': step.action.type});
  }

  @override
  Future<void> onStepComplete(ProcedureStep step, StepResult result) async {
    _emit('step.completed', 1, {
      'step_id': step.id,
      'claims_count': result.claims.length.toString(),
    });
  }

  @override
  Future<void> onSkillComplete(SkillResult result) async {
    final entry = _metrics.values.firstWhere(
      (e) => e.skillId == result.metadata.skillId,
      orElse: () => _MetricEntry(skillId: result.metadata.skillId, startTime: DateTime.now()),
    );

    final duration = DateTime.now().difference(entry.startTime);

    _emit('skill.completed', 1, {
      'skill_id': result.metadata.skillId,
      'confidence': result.confidence.toString(),
    });
    _emit('skill.duration_ms', duration.inMilliseconds.toDouble(), {
      'skill_id': result.metadata.skillId,
    });
    _emit('skill.claims_count', result.claims.length.toDouble(), {
      'skill_id': result.metadata.skillId,
    });
    _emit('skill.steps_count', result.metadata.stepsExecuted.toDouble(), {
      'skill_id': result.metadata.skillId,
    });
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    _emit('skill.error', 1, {'error_type': error.runtimeType.toString()});
  }

  void _emit(String name, double value, Map<String, String> tags) {
    collector?.call(name, value, tags);
  }

  /// Get collected metrics summary.
  Map<String, dynamic> getSummary() {
    return {
      'entries': _metrics.length,
    };
  }
}

class _MetricEntry {
  final String skillId;
  final DateTime startTime;

  _MetricEntry({required this.skillId, required this.startTime});
}

/// Composite hook that delegates to multiple hooks.
class CompositeHook implements RuntimeHook {
  /// Inner hooks.
  final List<RuntimeHook> hooks;

  CompositeHook(this.hooks);

  @override
  Future<void> onSkillStart(SkillContext context, SkillBundle bundle) async {
    for (final hook in hooks) {
      await hook.onSkillStart(context, bundle);
    }
  }

  @override
  Future<void> onStepStart(ProcedureStep step) async {
    for (final hook in hooks) {
      await hook.onStepStart(step);
    }
  }

  @override
  Future<void> onStepComplete(ProcedureStep step, StepResult result) async {
    for (final hook in hooks) {
      await hook.onStepComplete(step, result);
    }
  }

  @override
  Future<void> onSkillComplete(SkillResult result) async {
    for (final hook in hooks) {
      await hook.onSkillComplete(result);
    }
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    for (final hook in hooks) {
      await hook.onError(error, stackTrace);
    }
  }
}

/// No-op hook that does nothing.
class NoOpHook implements RuntimeHook {
  const NoOpHook();

  @override
  Future<void> onSkillStart(SkillContext context, SkillBundle bundle) async {}

  @override
  Future<void> onStepStart(ProcedureStep step) async {}

  @override
  Future<void> onStepComplete(ProcedureStep step, StepResult result) async {}

  @override
  Future<void> onSkillComplete(SkillResult result) async {}

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {}
}

/// Hook that records execution history.
class HistoryHook implements RuntimeHook {
  /// Maximum history entries to keep.
  final int maxEntries;

  /// Recorded history.
  final List<HistoryEntry> _history = [];

  HistoryHook({this.maxEntries = 1000});

  /// Get recorded history.
  List<HistoryEntry> get history => List.unmodifiable(_history);

  /// Clear history.
  void clear() => _history.clear();

  @override
  Future<void> onSkillStart(SkillContext context, SkillBundle bundle) async {
    _record(HistoryEntry(
      type: HistoryEntryType.skillStart,
      timestamp: DateTime.now(),
      data: {
        'skillId': bundle.bundleId,
        'request': context.request,
      },
    ));
  }

  @override
  Future<void> onStepStart(ProcedureStep step) async {
    _record(HistoryEntry(
      type: HistoryEntryType.stepStart,
      timestamp: DateTime.now(),
      data: {
        'stepId': step.id,
        'stepName': step.name,
        'actionType': step.action.type,
      },
    ));
  }

  @override
  Future<void> onStepComplete(ProcedureStep step, StepResult result) async {
    _record(HistoryEntry(
      type: HistoryEntryType.stepComplete,
      timestamp: DateTime.now(),
      data: {
        'stepId': step.id,
        'claimsCount': result.claims.length,
        'evidenceCount': result.evidenceRefs.length,
      },
    ));
  }

  @override
  Future<void> onSkillComplete(SkillResult result) async {
    _record(HistoryEntry(
      type: HistoryEntryType.skillComplete,
      timestamp: DateTime.now(),
      data: {
        'skillId': result.metadata.skillId,
        'confidence': result.confidence,
        'claimsCount': result.claims.length,
        'durationMs': result.metadata.duration.inMilliseconds,
      },
    ));
  }

  @override
  Future<void> onError(Object error, StackTrace stackTrace) async {
    _record(HistoryEntry(
      type: HistoryEntryType.error,
      timestamp: DateTime.now(),
      data: {
        'error': error.toString(),
        'stackTrace': stackTrace.toString(),
      },
    ));
  }

  void _record(HistoryEntry entry) {
    _history.add(entry);
    while (_history.length > maxEntries) {
      _history.removeAt(0);
    }
  }
}

/// History entry.
class HistoryEntry {
  /// Entry type.
  final HistoryEntryType type;

  /// Timestamp.
  final DateTime timestamp;

  /// Entry data.
  final Map<String, dynamic> data;

  const HistoryEntry({
    required this.type,
    required this.timestamp,
    required this.data,
  });

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };
}

/// History entry types.
enum HistoryEntryType {
  skillStart,
  stepStart,
  stepComplete,
  skillComplete,
  error,
}
