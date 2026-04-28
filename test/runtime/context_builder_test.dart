import 'package:mcp_bundle/mcp_bundle.dart' as bundle
    show ContextBundlePort, ContextBundle;
import 'package:mcp_bundle/src/ports/context_bundle_port.dart' as bundle
    show ContextBundleRequest;
import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/context_builder.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';

void main() {
  group('SkillContextBuilder', () {
    group('builder pattern', () {
      test('builds SkillContext with all explicitly set fields', () {
        final asOf = DateTime(2025, 6, 1);
        final budget = const ExecutionBudget(maxTokens: 5000);
        final retryConfig = const RetryConfig(maxRetries: 2);
        final cacheConfig = const CacheConfig(enabled: true);

        final context = (SkillContextBuilder()
              ..contextId('ctx-100')
              ..skillId('skill-abc')
              ..runId('run-200')
              ..traceId('trace-300')
              ..parentContextId('parent-ctx')
              ..request('Analyze this')
              ..workspaceId('ws-1')
              ..asOf(asOf)
              ..policyVersion('v2.0')
              ..activeSkills(['s1', 's2'])
              ..inputs({'key': 'value', 'num': 42})
              ..budget(budget)
              ..userId('user-1')
              ..retryConfig(retryConfig)
              ..cacheConfig(cacheConfig)
              ..metadata({'tag': 'test'}))
            .build();

        expect(context.contextId, 'ctx-100');
        expect(context.skillId, 'skill-abc');
        expect(context.runId, 'run-200');
        expect(context.traceId, 'trace-300');
        expect(context.parentContextId, 'parent-ctx');
        expect(context.request, 'Analyze this');
        expect(context.workspaceId, 'ws-1');
        expect(context.asOf, asOf);
        expect(context.policyVersion, 'v2.0');
        expect(context.activeSkills, ['s1', 's2']);
        expect(context.inputs, {'key': 'value', 'num': 42});
        expect(context.budget, budget);
        expect(context.userId, 'user-1');
        expect(context.retryConfig, retryConfig);
        expect(context.cacheConfig, cacheConfig);
        expect(context.metadata, {'tag': 'test'});
      });

      test('returns this from each setter for fluent chaining', () {
        final builder = SkillContextBuilder();

        expect(builder.contextId('c'), same(builder));
        expect(builder.skillId('s'), same(builder));
        expect(builder.runId('r'), same(builder));
        expect(builder.traceId('t'), same(builder));
        expect(builder.parentContextId('p'), same(builder));
        expect(builder.request('q'), same(builder));
        expect(builder.workspaceId('w'), same(builder));
        expect(builder.asOf(DateTime.now()), same(builder));
        expect(builder.period(null), same(builder));
        expect(builder.policyVersion('v'), same(builder));
        expect(builder.activeSkills(['a']), same(builder));
        expect(builder.inputs({}), same(builder));
        expect(builder.input('k', 'v'), same(builder));
        expect(builder.contextBundle(null), same(builder));
        expect(builder.budget(null), same(builder));
        expect(builder.userId('u'), same(builder));
        expect(builder.retryConfig(null), same(builder));
        expect(builder.cacheConfig(null), same(builder));
        expect(builder.metadata(null), same(builder));
      });
    });

    group('auto-generated IDs', () {
      test('generates contextId when not set', () {
        final context = (SkillContextBuilder()
              ..skillId('skill-1')
              ..request('test'))
            .build();

        expect(context.contextId, startsWith('ctx_'));
        expect(context.contextId.length, greaterThan(4));
      });

      test('generates runId when not set', () {
        final context = (SkillContextBuilder()
              ..skillId('skill-1')
              ..request('test'))
            .build();

        expect(context.runId, startsWith('run_'));
        expect(context.runId.length, greaterThan(4));
      });

      test('generates traceId when not set', () {
        final context = (SkillContextBuilder()
              ..skillId('skill-1')
              ..request('test'))
            .build();

        expect(context.traceId, startsWith('trace_'));
        expect(context.traceId.length, greaterThan(6));
      });

      test('uses provided IDs when explicitly set', () {
        final context = (SkillContextBuilder()
              ..contextId('my-ctx')
              ..skillId('skill-1')
              ..runId('my-run')
              ..traceId('my-trace')
              ..request('test'))
            .build();

        expect(context.contextId, 'my-ctx');
        expect(context.runId, 'my-run');
        expect(context.traceId, 'my-trace');
      });

      test('auto-generated IDs contain microsecond timestamp', () {
        final before = DateTime.now().microsecondsSinceEpoch;
        final context = (SkillContextBuilder()
              ..skillId('skill-1')
              ..request('test'))
            .build();
        final after = DateTime.now().microsecondsSinceEpoch;

        // Extract the numeric portion after the prefix
        final ctxTimestamp =
            int.parse(context.contextId.replaceFirst('ctx_', ''));
        expect(ctxTimestamp, greaterThanOrEqualTo(before));
        expect(ctxTimestamp, lessThanOrEqualTo(after));

        final runTimestamp =
            int.parse(context.runId.replaceFirst('run_', ''));
        expect(runTimestamp, greaterThanOrEqualTo(before));
        expect(runTimestamp, lessThanOrEqualTo(after));
      });
    });

    group('default values', () {
      test('uses empty string for unset skillId', () {
        final context = SkillContextBuilder().build();

        expect(context.skillId, '');
      });

      test('uses empty string for unset request', () {
        final context = SkillContextBuilder().build();

        expect(context.request, '');
      });

      test('uses empty string for unset workspaceId', () {
        final context = SkillContextBuilder().build();

        expect(context.workspaceId, '');
      });

      test('sets asOf to approximately now when not set', () {
        final before = DateTime.now();
        final context = SkillContextBuilder().build();
        final after = DateTime.now();

        expect(
          context.asOf.millisecondsSinceEpoch,
          greaterThanOrEqualTo(before.millisecondsSinceEpoch),
        );
        expect(
          context.asOf.millisecondsSinceEpoch,
          lessThanOrEqualTo(after.millisecondsSinceEpoch),
        );
      });

      test('optional fields default to null', () {
        final context = SkillContextBuilder().build();

        expect(context.parentContextId, isNull);
        expect(context.period, isNull);
        expect(context.policyVersion, isNull);
        expect(context.activeSkills, isNull);
        expect(context.contextBundle, isNull);
        expect(context.budget, isNull);
        expect(context.userId, isNull);
        expect(context.retryConfig, isNull);
        expect(context.cacheConfig, isNull);
        expect(context.metadata, isNull);
      });

      test('inputs defaults to empty map', () {
        final context = SkillContextBuilder().build();

        expect(context.inputs, isEmpty);
      });
    });

    group('input method', () {
      test('adds a single input parameter', () {
        final context = (SkillContextBuilder()
              ..input('key1', 'value1')
              ..input('key2', 42))
            .build();

        expect(context.inputs, {'key1': 'value1', 'key2': 42});
      });

      test('input overwrites existing key', () {
        final context = (SkillContextBuilder()
              ..input('key', 'first')
              ..input('key', 'second'))
            .build();

        expect(context.inputs['key'], 'second');
      });

      test('input and inputs can be combined', () {
        final context = (SkillContextBuilder()
              ..inputs({'a': 1})
              ..input('b', 2))
            .build();

        // inputs() replaces the internal map, then input() adds to it
        expect(context.inputs, {'a': 1, 'b': 2});
      });

      test('inputs replaces all previously set input values', () {
        final context = (SkillContextBuilder()
              ..input('old_key', 'old_value')
              ..inputs({'new_key': 'new_value'}))
            .build();

        expect(context.inputs.containsKey('old_key'), isFalse);
        expect(context.inputs['new_key'], 'new_value');
      });
    });

    group('nullable setters', () {
      test('parentContextId can be set to null', () {
        final context = (SkillContextBuilder()
              ..parentContextId('parent-1')
              ..parentContextId(null))
            .build();

        expect(context.parentContextId, isNull);
      });

      test('period can be set to null', () {
        final context = (SkillContextBuilder()..period(null)).build();

        expect(context.period, isNull);
      });

      test('policyVersion can be set to null', () {
        final context =
            (SkillContextBuilder()..policyVersion(null)).build();

        expect(context.policyVersion, isNull);
      });

      test('activeSkills can be set to null', () {
        final context =
            (SkillContextBuilder()..activeSkills(null)).build();

        expect(context.activeSkills, isNull);
      });
    });
  });

  group('ContextBuildingService', () {
    late ContextBuildingService service;

    setUp(() {
      service = ContextBuildingService();
    });

    test(
        'buildFromContextBundle returns builder context when port is null',
        () async {
      final builder = SkillContextBuilder()
        ..skillId('skill-1')
        ..request('test request')
        ..workspaceId('ws-1');

      final context = await service.buildFromContextBundle(
        builder: builder,
        contextBundlePort: null,
      );

      expect(context.skillId, 'skill-1');
      expect(context.request, 'test request');
      expect(context.workspaceId, 'ws-1');
      expect(context.contextBundle, isNull);
    });

    test(
        'buildFromContextBundle enriches context when port is provided',
        () async {
      final builder = SkillContextBuilder()
        ..skillId('skill-2')
        ..request('analyze')
        ..workspaceId('ws-2');

      final port = _RecordingContextBundlePort();
      final context = await service.buildFromContextBundle(
        builder: builder,
        contextBundlePort: port,
      );

      expect(context.contextBundle, isNotNull);
      expect(context.contextBundle!.id, equals('mock-ws-2'));
      expect(port.buildCalls, hasLength(1));
      expect(port.buildCalls.first.workspaceId, equals('ws-2'));
      expect(port.buildCalls.first.query, equals('analyze'));
    });

    test(
        'buildFromContextBundle falls back to base context when port throws',
        () async {
      final builder = SkillContextBuilder()
        ..skillId('skill-3')
        ..request('query')
        ..workspaceId('ws-3');

      final port = _ThrowingContextBundlePort();
      final context = await service.buildFromContextBundle(
        builder: builder,
        contextBundlePort: port,
        workspaceId: 'ws-override',
        query: 'SELECT *',
        asOf: DateTime(2025, 1, 1),
      );

      expect(context.contextBundle, isNull);
      expect(context.skillId, equals('skill-3'));
    });

    test('buildFromContextBundle produces valid SkillContext with auto-IDs',
        () async {
      final builder = SkillContextBuilder()..skillId('skill-4');

      final context = await service.buildFromContextBundle(
        builder: builder,
        contextBundlePort: null,
      );

      expect(context.contextId, startsWith('ctx_'));
      expect(context.runId, startsWith('run_'));
      expect(context.traceId, startsWith('trace_'));
    });
  });
}

class _RecordingContextBundlePort implements bundle.ContextBundlePort {
  final List<bundle.ContextBundleRequest> buildCalls = [];

  @override
  Future<bundle.ContextBundle> buildContextBundle(
    bundle.ContextBundleRequest request,
  ) async {
    buildCalls.add(request);
    return bundle.ContextBundle(
      id: 'mock-${request.workspaceId}',
      createdAt: request.asOf ?? DateTime.now(),
    );
  }
}

class _ThrowingContextBundlePort implements bundle.ContextBundlePort {
  @override
  Future<bundle.ContextBundle> buildContextBundle(
    bundle.ContextBundleRequest request,
  ) async {
    throw StateError('port failure');
  }
}
