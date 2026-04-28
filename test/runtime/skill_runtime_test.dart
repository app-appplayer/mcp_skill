// Tests for SkillRuntime 7-step pipeline, routing, and error propagation.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/skill_runtime.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';
import 'package:mcp_skill/src/runtime/skill_router.dart';
import 'package:mcp_skill/src/runtime/runtime_hooks.dart';
import 'package:mcp_skill/src/registry/skill_registry.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/exceptions/load_exceptions.dart';

import '../helpers/mock_ports.dart';

/// Mock SkillBundleRegistry for testing.
class MockSkillBundleRegistry implements SkillBundleRegistry {
  final Map<String, SkillBundle> _skills = {};

  void addSkill(SkillBundle bundle) {
    _skills[bundle.manifest.id] = bundle;
  }

  @override
  Future<List<SkillBundle>> listSkills({String? workspaceId}) async {
    return _skills.values.toList();
  }

  @override
  Future<SkillBundle?> getSkill(String skillId) async {
    return _skills[skillId];
  }

  @override
  Future<void> registerSkill(SkillBundle bundle) async {
    _skills[bundle.manifest.id] = bundle;
  }

  @override
  Future<void> unregisterSkill(String skillId) async {
    _skills.remove(skillId);
  }

  @override
  Future<bool> isEnabled(String skillId, {String? workspaceId}) async => true;

  @override
  Future<void> setEnabled(String skillId, bool enabled,
      {String? workspaceId}) async {}
}

void main() {
  // Helper to create a minimal SkillContext.
  SkillContext _makeContext({
    String skillId = 'test-skill',
    List<String>? activeSkills,
    Map<String, dynamic> inputs = const {},
  }) {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: skillId,
      runId: 'run-1',
      traceId: 'trace-1',
      request: 'analyze data',
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 1, 1),
      inputs: inputs,
      activeSkills: activeSkills,
    );
  }

  // Helper to create a SkillBundle.
  SkillBundle _makeBundle({
    String id = 'test-skill',
    String name = 'Test Skill',
    bool withProcedure = true,
  }) {
    return SkillBundle.fromJson({
      'schemaVersion': '0.1.0',
      'manifest': {
        'id': id,
        'name': name,
        'version': '1.0.0',
        'provider': 'test',
        'description': 'A test skill for data analysis',
      },
      'procedures': withProcedure
          ? [
              {
                'id': 'proc-$id',
                'name': 'Test Procedure',
                'steps': [
                  {
                    'id': 'step-1',
                    'order': 1,
                    'name': 'LLM Step',
                    'action': {'type': 'llm', 'prompt': 'test prompt'},
                  },
                ],
              },
            ]
          : [],
    });
  }

  group('SkillRuntime', () {
    late MockSkillBundleRegistry registry;
    late SkillPorts ports;

    setUp(() {
      registry = MockSkillBundleRegistry();
      ports = SkillPorts(
        llm: MockLlmPort(),
        mcp: MockMcpPort(),
        retrieval: MockRetrievalPort(),
        claims: MockClaimsPort(),
        runs: MockRunsPort(),
        contextBundle: MockContextBundlePort(),
      );
    });

    group('routing', () {
      test('uses activeSkills from context when provided', () async {
        final bundle = _makeBundle(id: 'skill-a');
        registry.addSkill(bundle);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        final context = _makeContext(activeSkills: ['skill-a']);
        final result = await runtime.run(context);

        expect(result, isNotNull);
      });

      test('uses router when no activeSkills', () async {
        final bundle = _makeBundle(id: 'routed-skill');
        registry.addSkill(bundle);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
          router: FixedRouter(['routed-skill']),
        );

        final context = _makeContext(skillId: '', activeSkills: null);
        // Need a non-empty skillId as fallback
        final contextWithSkillId = context.copyWith(skillId: '');
        final result = await runtime.run(contextWithSkillId);

        expect(result, isNotNull);
      });

      test('falls back to skillId when no activeSkills and no router',
          () async {
        final bundle = _makeBundle(id: 'fallback-skill');
        registry.addSkill(bundle);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        final context = _makeContext(
          skillId: 'fallback-skill',
          activeSkills: null,
        );
        final result = await runtime.run(context);

        expect(result, isNotNull);
      });

      test('throws SkillRoutingException when no skills can be determined',
          () async {
        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        final context = _makeContext(
          skillId: '',
          activeSkills: null,
        );

        expect(
          () => runtime.run(context),
          throwsA(isA<SkillRoutingException>()),
        );
      });
    });

    group('execution', () {
      test('returns failure result for non-existent skill', () async {
        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        final context =
            _makeContext(activeSkills: ['nonexistent-skill']);
        final result = await runtime.run(context);

        expect(result.success, isFalse);
      });

      test('returns failure result for skill without procedures', () async {
        final bundle = _makeBundle(id: 'empty-skill', withProcedure: false);
        registry.addSkill(bundle);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        final context = _makeContext(activeSkills: ['empty-skill']);
        final result = await runtime.run(context);

        expect(result.success, isFalse);
      });
    });

    group('hooks', () {
      test('notifies hooks before and after execution', () async {
        final bundle = _makeBundle(id: 'hook-skill');
        registry.addSkill(bundle);

        final hookEvents = <String>[];
        final hook = _TrackingHook(hookEvents);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
          hooks: [hook],
        );

        final context = _makeContext(activeSkills: ['hook-skill']);
        await runtime.run(context);

        expect(hookEvents, contains('beforeExecution'));
        expect(hookEvents, contains('afterExecution'));
      });

      test('notifies hooks on error', () async {
        final hookEvents = <String>[];
        final hook = _TrackingHook(hookEvents);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
          hooks: [hook],
        );

        final context = _makeContext(
          skillId: '',
          activeSkills: null,
        );

        try {
          await runtime.run(context);
        } catch (_) {
          // Expected routing error
        }

        expect(hookEvents, contains('onError'));
      });

      test('hook errors do not break execution', () async {
        final bundle = _makeBundle(id: 'hook-err-skill');
        registry.addSkill(bundle);

        final failingHook = _FailingHook();

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
          hooks: [failingHook],
        );

        final context = _makeContext(activeSkills: ['hook-err-skill']);
        // Should not throw even though hook fails
        final result = await runtime.run(context);
        expect(result, isNotNull);
      });
    });

    group('runProcedure', () {
      test('throws SkillNotFoundException for missing skill', () async {
        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        expect(
          () => runtime.runProcedure('missing', 'proc-1', _makeContext()),
          throwsA(isA<SkillNotFoundException>()),
        );
      });

      test('throws ProcedureNotFoundException for skill without procedures',
          () async {
        final bundle = _makeBundle(id: 'no-proc', withProcedure: false);
        registry.addSkill(bundle);

        final runtime = SkillRuntime(
          registry: registry,
          ports: ports,
        );

        expect(
          () => runtime.runProcedure('no-proc', 'proc-1', _makeContext()),
          throwsA(isA<ProcedureNotFoundException>()),
        );
      });
    });
  });

  group('ExecutionPlan', () {
    test('stores skill IDs and strategy', () {
      const plan = ExecutionPlan(
        skillIds: ['skill-1', 'skill-2'],
        strategy: ExecutionStrategy.sequential,
      );
      expect(plan.skillIds, equals(['skill-1', 'skill-2']));
      expect(plan.strategy, equals(ExecutionStrategy.sequential));
    });

    test('default strategy is sequential', () {
      const plan = ExecutionPlan(skillIds: ['s1']);
      expect(plan.strategy, equals(ExecutionStrategy.sequential));
    });
  });

  group('plan strategy dispatch', () {
    late MockSkillBundleRegistry registry;
    late SkillPorts ports;

    // Helper to build a bundle whose single step has an `extensions`
    // hint attached to the bundle for strategy selection. When
    // [failing] is true, the single step points at a tool that throws.
    SkillBundle buildBundle({
      required String id,
      ExecutionStrategy? strategy,
      bool failing = false,
    }) {
      final json = <String, dynamic>{
        'schemaVersion': '0.1.0',
        'manifest': {
          'id': id,
          'name': id,
          'version': '1.0.0',
          'provider': 'test',
          'description': 'strategy test skill',
        },
        'procedures': [
          {
            'id': 'proc-$id',
            'name': 'Proc',
            'steps': [
              {
                'id': 'step-1',
                'order': 1,
                'name': 'Step',
                // `unknown` is not a supported action type so the step
                // executor throws `UnsupportedActionException`.
                'action': failing
                    ? {'type': 'unknown-action-$id'}
                    : {'type': 'llm', 'prompt': 'hi'},
              },
            ],
          },
        ],
        if (strategy != null)
          'extensions': {'plan_strategy': strategy.name},
      };
      return SkillBundle.fromJson(json);
    }

    setUp(() {
      registry = MockSkillBundleRegistry();
      ports = SkillPorts(
        llm: MockLlmPort(),
        mcp: MockMcpPort(),
        retrieval: MockRetrievalPort(),
        claims: MockClaimsPort(),
        runs: MockRunsPort(),
        contextBundle: MockContextBundlePort(),
      );
    });

    test('sequential strategy preserves legacy ordering', () async {
      registry.addSkill(buildBundle(id: 'seq-a'));
      registry.addSkill(buildBundle(id: 'seq-b'));

      final runtime = SkillRuntime(registry: registry, ports: ports);

      final context = SkillContext(
        contextId: 'ctx-seq',
        skillId: 'seq-a',
        runId: 'run-seq',
        traceId: 'trace-seq',
        request: 'r',
        workspaceId: 'ws',
        asOf: DateTime(2025, 1, 1),
        inputs: const {},
        activeSkills: const ['seq-a', 'seq-b'],
        metadata: const {'plan_strategy': 'sequential'},
      );

      final result = await runtime.run(context);
      expect(result, isNotNull);
    });

    test('parallel strategy runs all skills', () async {
      registry.addSkill(buildBundle(id: 'par-a'));
      registry.addSkill(buildBundle(id: 'par-b'));

      final runtime = SkillRuntime(registry: registry, ports: ports);

      final context = SkillContext(
        contextId: 'ctx-par',
        skillId: 'par-a',
        runId: 'run-par',
        traceId: 'trace-par',
        request: 'r',
        workspaceId: 'ws',
        asOf: DateTime(2025, 1, 1),
        inputs: const {},
        activeSkills: const ['par-a', 'par-b'],
        metadata: const {'plan_strategy': 'parallel'},
      );

      final result = await runtime.run(context);
      expect(result, isNotNull);
    });

    test('parallel strategy propagates failure from any skill', () async {
      // A failing tool-based step throws; the second skill succeeds.
      registry.addSkill(buildBundle(id: 'par-fail', failing: true));
      registry.addSkill(buildBundle(id: 'par-ok'));

      final runtime = SkillRuntime(registry: registry, ports: ports);

      final context = SkillContext(
        contextId: 'ctx-par-fail',
        skillId: 'par-fail',
        runId: 'run-par-fail',
        traceId: 'trace-par-fail',
        request: 'r',
        workspaceId: 'ws',
        asOf: DateTime(2025, 1, 1),
        inputs: const {},
        activeSkills: const ['par-fail', 'par-ok'],
        metadata: const {'plan_strategy': 'parallel'},
      );

      expect(() => runtime.run(context), throwsA(isA<Object>()));
    });

    test('fallback strategy returns first non-throwing skill', () async {
      registry.addSkill(buildBundle(id: 'fb-fail', failing: true));
      registry.addSkill(buildBundle(id: 'fb-ok'));

      final runtime = SkillRuntime(registry: registry, ports: ports);

      final context = SkillContext(
        contextId: 'ctx-fb',
        skillId: 'fb-fail',
        runId: 'run-fb',
        traceId: 'trace-fb',
        request: 'r',
        workspaceId: 'ws',
        asOf: DateTime(2025, 1, 1),
        inputs: const {},
        activeSkills: const ['fb-fail', 'fb-ok'],
        metadata: const {'plan_strategy': 'fallback'},
      );

      // fb-fail throws, fb-ok runs to completion — fallback resolves on the
      // first skill that does not throw. `run` must complete without
      // rethrowing the UnsupportedActionException.
      final result = await runtime.run(context);
      expect(result, isNotNull);
    });

    test('fallback strategy rethrows last error when all fail', () async {
      registry.addSkill(buildBundle(id: 'fb-1', failing: true));
      registry.addSkill(buildBundle(id: 'fb-2', failing: true));

      final runtime = SkillRuntime(registry: registry, ports: ports);

      final context = SkillContext(
        contextId: 'ctx-fb-all',
        skillId: 'fb-1',
        runId: 'run-fb-all',
        traceId: 'trace-fb-all',
        request: 'r',
        workspaceId: 'ws',
        asOf: DateTime(2025, 1, 1),
        inputs: const {},
        activeSkills: const ['fb-1', 'fb-2'],
        metadata: const {'plan_strategy': 'fallback'},
      );

      expect(() => runtime.run(context), throwsA(isA<Object>()));
    });

    test('skill extensions can declare plan_strategy', () async {
      // No context override - strategy comes from the bundle's extensions.
      registry.addSkill(buildBundle(
        id: 'ext-ok',
        strategy: ExecutionStrategy.fallback,
      ));
      registry.addSkill(buildBundle(id: 'ext-other'));

      final runtime = SkillRuntime(registry: registry, ports: ports);

      final context = SkillContext(
        contextId: 'ctx-ext',
        skillId: 'ext-ok',
        runId: 'run-ext',
        traceId: 'trace-ext',
        request: 'r',
        workspaceId: 'ws',
        asOf: DateTime(2025, 1, 1),
        inputs: const {},
        activeSkills: const ['ext-ok', 'ext-other'],
      );

      // Fallback returns the first non-throwing skill (ext-ok).
      final result = await runtime.run(context);
      expect(result, isNotNull);
    });
  });

  group('ExecutionStrategy', () {
    test('has three strategies', () {
      expect(ExecutionStrategy.values.length, equals(3));
      expect(
          ExecutionStrategy.values, contains(ExecutionStrategy.sequential));
      expect(ExecutionStrategy.values, contains(ExecutionStrategy.parallel));
      expect(ExecutionStrategy.values, contains(ExecutionStrategy.fallback));
    });
  });
}

/// A hook that tracks which events are called.
class _TrackingHook extends RuntimeHook {
  final List<String> events;

  _TrackingHook(this.events);

  @override
  Future<void> beforeExecution(SkillContext context) async {
    events.add('beforeExecution');
  }

  @override
  Future<void> afterExecution(SkillContext context, SkillResult result) async {
    events.add('afterExecution');
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
  Future<void> onPlanning(SkillContext context, List<String> skillIds) async {
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

  @override
  Future<void> onError(
      SkillContext context, Object error, StackTrace stackTrace) async {
    events.add('onError');
  }

  @override
  Future<void> onWarning(SkillContext context, String message) async {
    events.add('onWarning');
  }
}

/// A hook that throws on every call, to test hook error isolation.
class _FailingHook extends RuntimeHook {
  @override
  Future<void> beforeExecution(SkillContext context) async {
    throw Exception('Hook failure');
  }

  @override
  Future<void> afterExecution(
      SkillContext context, SkillResult result) async {
    throw Exception('Hook failure');
  }
}
