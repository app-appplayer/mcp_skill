// Tests for RuntimeHook implementations - LoggingHook, MetricsHook,
// TracingHook, CompositeHook, and BudgetCheckResult.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/runtime_hooks.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';

void main() {
  // Helper to create a minimal SkillContext.
  SkillContext _makeContext({
    String runId = 'run-1',
    String skillId = 'test-skill',
  }) {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: skillId,
      runId: runId,
      traceId: 'trace-1',
      request: 'test request',
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 1, 1),
    );
  }

  // Helper to create a SkillResult.
  SkillResult _makeResult({
    bool success = true,
    int claimCount = 0,
  }) {
    return SkillResult(
      claims: List.generate(
        claimCount,
        (i) => Claim(
          id: 'claim-$i',
          workspaceId: 'ws-1',
          type: ClaimType.fact,
          text: 'Claim $i',
          evidenceRefs: const [],
          confidence: 0.9,
        ),
      ),
      evidenceRefs: const [],
      confidence: success ? 0.9 : 0.0,
      asOf: DateTime(2025, 1, 1),
      metadata: ExecutionMetadata(
        skillId: 'test-skill',
        skillVersion: '1.0.0',
        procedureId: 'proc-1',
        startedAt: DateTime(2025, 1, 1),
        finishedAt: DateTime(2025, 1, 1, 0, 0, 1),
        duration: const Duration(seconds: 1),
        stepsExecuted: 2,
        toolsCalled: [],
      ),
    );
  }

  group('BudgetCheckResult', () {
    test('stores passed flag and usage', () {
      const result = BudgetCheckResult(
        passed: true,
        usage: {'tokensUsed': 500},
      );
      expect(result.passed, isTrue);
      expect(result.usage['tokensUsed'], equals(500));
      expect(result.reason, isNull);
    });

    test('stores reason when not passed', () {
      const result = BudgetCheckResult(
        passed: false,
        reason: 'Token limit exceeded',
        usage: {'tokensUsed': 10001},
      );
      expect(result.passed, isFalse);
      expect(result.reason, equals('Token limit exceeded'));
    });
  });

  group('LoggingHook', () {
    late List<_LogEntry> logEntries;
    late LoggingHook hook;

    setUp(() {
      logEntries = [];
      hook = LoggingHook(
        logger: (level, message) {
          logEntries.add(_LogEntry(level, message));
        },
      );
    });

    test('logs before execution', () async {
      await hook.beforeExecution(_makeContext(runId: 'run-42'));

      expect(logEntries.length, equals(1));
      expect(logEntries.first.level, equals('INFO'));
      expect(logEntries.first.message, contains('run-42'));
      expect(logEntries.first.message, contains('Starting execution'));
    });

    test('logs after execution with status', () async {
      final context = _makeContext();
      final result = _makeResult(success: true, claimCount: 3);

      await hook.afterExecution(context, result);

      expect(logEntries.length, equals(1));
      expect(logEntries.first.message, contains('SUCCESS'));
      expect(logEntries.first.message, contains('3 claims'));
    });

    test('logs failure status after execution', () async {
      final context = _makeContext();
      final result = _makeResult(success: false);

      await hook.afterExecution(context, result);

      expect(logEntries.first.message, contains('FAILURE'));
    });

    test('logs errors', () async {
      final context = _makeContext();
      await hook.onError(
        context,
        Exception('test error'),
        StackTrace.current,
      );

      expect(logEntries.length, equals(1));
      expect(logEntries.first.level, equals('ERROR'));
      expect(logEntries.first.message, contains('test error'));
    });

    test('logs warnings', () async {
      final context = _makeContext();
      await hook.onWarning(context, 'something wrong');

      expect(logEntries.length, equals(1));
      expect(logEntries.first.level, equals('WARN'));
      expect(logEntries.first.message, contains('something wrong'));
    });

    group('verbose mode', () {
      test('logs step start in verbose mode', () async {
        final verboseHook = LoggingHook(
          logger: (level, message) {
            logEntries.add(_LogEntry(level, message));
          },
          verbose: true,
        );

        await verboseHook.onStepStart(
          _makeContext(),
          'step-1',
          {'input': 'data'},
        );

        expect(logEntries.length, equals(1));
        expect(logEntries.first.level, equals('DEBUG'));
        expect(logEntries.first.message, contains('step-1'));
      });

      test('logs step complete in verbose mode', () async {
        final verboseHook = LoggingHook(
          logger: (level, message) {
            logEntries.add(_LogEntry(level, message));
          },
          verbose: true,
        );

        await verboseHook.onStepComplete(
          _makeContext(),
          'step-2',
          {'result': 'done'},
        );

        expect(logEntries.length, equals(1));
        expect(logEntries.first.message, contains('step-2'));
      });

      test('does not log step events in non-verbose mode', () async {
        await hook.onStepStart(_makeContext(), 'step-1', {});
        await hook.onStepComplete(_makeContext(), 'step-1', {});

        expect(logEntries, isEmpty);
      });
    });
  });

  group('MetricsHook', () {
    late MetricsHook hook;

    setUp(() {
      hook = MetricsHook();
    });

    test('increments execution started counter', () async {
      await hook.beforeExecution(_makeContext());
      await hook.beforeExecution(_makeContext());

      final metrics = hook.getMetrics();
      final counters = metrics['counters'] as Map<String, int>;
      expect(counters['executions.started'], equals(2));
    });

    test('tracks successful and failed executions', () async {
      await hook.beforeExecution(_makeContext());
      await hook.afterExecution(
          _makeContext(), _makeResult(success: true, claimCount: 2));

      await hook.beforeExecution(_makeContext());
      await hook.afterExecution(
          _makeContext(), _makeResult(success: false));

      final metrics = hook.getMetrics();
      final counters = metrics['counters'] as Map<String, int>;
      expect(counters['executions.succeeded'], equals(1));
      expect(counters['executions.failed'], equals(1));
    });

    test('counts extracted claims', () async {
      await hook.beforeExecution(_makeContext());
      await hook.afterExecution(
          _makeContext(), _makeResult(success: true, claimCount: 5));

      final metrics = hook.getMetrics();
      final counters = metrics['counters'] as Map<String, int>;
      expect(counters['claims.extracted'], equals(5));
    });

    test('records execution duration', () async {
      await hook.beforeExecution(_makeContext());
      // Small delay to ensure duration > 0
      await Future.delayed(const Duration(milliseconds: 5));
      await hook.afterExecution(
          _makeContext(), _makeResult(success: true));

      final metrics = hook.getMetrics();
      final durations = metrics['durations'] as Map<String, dynamic>;
      expect(durations.containsKey('execution.total'), isTrue);

      final durationStats =
          durations['execution.total'] as Map<String, dynamic>;
      expect(durationStats['count'], equals(1));
      expect(durationStats['min'], isA<int>());
      expect(durationStats['max'], isA<int>());
    });

    test('computes percentiles with multiple durations', () async {
      for (var i = 0; i < 10; i++) {
        await hook.beforeExecution(_makeContext());
        await hook.afterExecution(
            _makeContext(), _makeResult(success: true));
      }

      final metrics = hook.getMetrics();
      final durations = metrics['durations'] as Map<String, dynamic>;
      final stats =
          durations['execution.total'] as Map<String, dynamic>;

      expect(stats['count'], equals(10));
      expect(stats.containsKey('p50'), isTrue);
      expect(stats.containsKey('p95'), isTrue);
      expect(stats.containsKey('p99'), isTrue);
      expect(stats.containsKey('avg'), isTrue);
    });

    test('tracks error types', () async {
      await hook.onError(
        _makeContext(),
        StateError('bad state'),
        StackTrace.current,
      );

      final metrics = hook.getMetrics();
      final counters = metrics['counters'] as Map<String, int>;
      expect(counters['errors.total'], equals(1));
      expect(counters['errors.StateError'], equals(1));
    });

    test('reset clears all metrics', () async {
      await hook.beforeExecution(_makeContext());
      await hook.afterExecution(
          _makeContext(), _makeResult(success: true));
      await hook.onError(
          _makeContext(), Exception('e'), StackTrace.current);

      hook.reset();

      final metrics = hook.getMetrics();
      final counters = metrics['counters'] as Map<String, int>;
      final durations = metrics['durations'] as Map<String, dynamic>;
      expect(counters, isEmpty);
      expect(durations, isEmpty);
    });
  });

  group('TracingHook', () {
    late List<_SpanRecord> spans;
    late TracingHook hook;

    setUp(() {
      spans = [];
      hook = TracingHook(
        recordSpan: (traceId, spanId, name, tags) {
          spans.add(_SpanRecord(traceId, spanId, name, tags));
        },
      );
    });

    test('records span on beforeExecution', () async {
      final context = _makeContext();
      await hook.beforeExecution(context);

      expect(spans.length, equals(1));
      expect(spans.first.traceId, equals('trace-1'));
      expect(spans.first.name, equals('skill.execution'));
      expect(spans.first.tags['skill.id'], equals('test-skill'));
      expect(spans.first.tags['run.id'], equals('run-1'));
    });

    test('records span on step start', () async {
      final context = _makeContext();
      await hook.beforeExecution(context);
      await hook.onStepStart(context, 'step-1', {});

      expect(spans.length, equals(2));
      expect(spans.last.name, equals('skill.step'));
      expect(spans.last.tags['step.id'], equals('step-1'));
    });
  });

  group('CompositeHook', () {
    test('delegates beforeExecution to all hooks', () async {
      final events1 = <String>[];
      final events2 = <String>[];

      final hook = CompositeHook([
        _SimpleTrackingHook(events1),
        _SimpleTrackingHook(events2),
      ]);

      await hook.beforeExecution(_makeContext());

      expect(events1, contains('beforeExecution'));
      expect(events2, contains('beforeExecution'));
    });

    test('delegates afterExecution to all hooks', () async {
      final events1 = <String>[];
      final events2 = <String>[];

      final hook = CompositeHook([
        _SimpleTrackingHook(events1),
        _SimpleTrackingHook(events2),
      ]);

      await hook.afterExecution(_makeContext(), _makeResult());

      expect(events1, contains('afterExecution'));
      expect(events2, contains('afterExecution'));
    });

    test('delegates onError to all hooks', () async {
      final events1 = <String>[];
      final events2 = <String>[];

      final hook = CompositeHook([
        _SimpleTrackingHook(events1),
        _SimpleTrackingHook(events2),
      ]);

      await hook.onError(
        _makeContext(),
        Exception('err'),
        StackTrace.current,
      );

      expect(events1, contains('onError'));
      expect(events2, contains('onError'));
    });

    test('delegates onWarning to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onWarning(_makeContext(), 'test warning');
      expect(events, contains('onWarning'));
    });

    test('delegates onStepStart to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onStepStart(_makeContext(), 'step-1', {});
      expect(events, contains('onStepStart'));
    });

    test('delegates onStepComplete to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onStepComplete(_makeContext(), 'step-1', {});
      expect(events, contains('onStepComplete'));
    });

    test('delegates onRouting to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onRouting(_makeContext());
      expect(events, contains('onRouting'));
    });

    test('delegates onContextBuilding to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onContextBuilding(_makeContext());
      expect(events, contains('onContextBuilding'));
    });

    test('delegates onPlanning to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onPlanning(_makeContext(), ['skill-1']);
      expect(events, contains('onPlanning'));
    });

    test('delegates onExecutionStart to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onExecutionStart(_makeContext());
      expect(events, contains('onExecutionStart'));
    });

    test('delegates onValidation to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onValidation(_makeContext());
      expect(events, contains('onValidation'));
    });

    test('delegates onPersistence to all hooks', () async {
      final events = <String>[];
      final hook = CompositeHook([_SimpleTrackingHook(events)]);

      await hook.onPersistence(_makeContext());
      expect(events, contains('onPersistence'));
    });
  });
}

/// Simple log entry for testing.
class _LogEntry {
  final String level;
  final String message;
  _LogEntry(this.level, this.message);
}

/// Span record for tracing tests.
class _SpanRecord {
  final String traceId;
  final String spanId;
  final String name;
  final Map<String, dynamic> tags;
  _SpanRecord(this.traceId, this.spanId, this.name, this.tags);
}

/// Simple tracking hook for CompositeHook tests.
class _SimpleTrackingHook extends RuntimeHook {
  final List<String> events;
  _SimpleTrackingHook(this.events);

  @override
  Future<void> beforeExecution(SkillContext context) async {
    events.add('beforeExecution');
  }

  @override
  Future<void> afterExecution(
      SkillContext context, SkillResult result) async {
    events.add('afterExecution');
  }

  @override
  Future<void> onError(
      SkillContext context, Object error, StackTrace stackTrace) async {
    events.add('onError');
  }

  @override
  Future<void> onWarning(SkillContext context, String message) async {
    events.add('onWarning');
  }

  @override
  Future<void> onStepStart(SkillContext context, String stepId,
      Map<String, dynamic> inputs) async {
    events.add('onStepStart');
  }

  @override
  Future<void> onStepComplete(SkillContext context, String stepId,
      Map<String, dynamic> output) async {
    events.add('onStepComplete');
  }

  @override
  Future<void> onRouting(SkillContext context) async {
    events.add('onRouting');
  }

  @override
  Future<void> onContextBuilding(SkillContext context) async {
    events.add('onContextBuilding');
  }

  @override
  Future<void> onPlanning(
      SkillContext context, List<String> skillIds) async {
    events.add('onPlanning');
  }

  @override
  Future<void> onExecutionStart(SkillContext context) async {
    events.add('onExecutionStart');
  }

  @override
  Future<void> onValidation(SkillContext context) async {
    events.add('onValidation');
  }

  @override
  Future<void> onPersistence(SkillContext context) async {
    events.add('onPersistence');
  }
}
