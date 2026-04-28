// Tests for SkillRouter implementations and RouterBuilder.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/skill_router.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/registry/skill_registry.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart';
import 'package:mcp_skill/src/ports/llm_port.dart';

import '../helpers/mock_ports.dart';

/// Mock SkillBundleRegistry for router tests.
class _MockRegistry implements SkillBundleRegistry {
  final List<SkillBundle> _bundles;

  _MockRegistry(this._bundles);

  @override
  Future<List<SkillBundle>> listSkills({String? workspaceId}) async =>
      _bundles;

  @override
  Future<SkillBundle?> getSkill(String skillId) async {
    for (final b in _bundles) {
      if (b.manifest.id == skillId) return b;
    }
    return null;
  }

  @override
  Future<void> registerSkill(SkillBundle bundle) async {}

  @override
  Future<void> unregisterSkill(String skillId) async {}

  @override
  Future<bool> isEnabled(String skillId, {String? workspaceId}) async => true;

  @override
  Future<void> setEnabled(String skillId, bool enabled,
      {String? workspaceId}) async {}
}

void main() {
  // Helper to create a minimal SkillContext.
  SkillContext _makeContext({String request = 'analyze data'}) {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: '',
      runId: 'run-1',
      traceId: 'trace-1',
      request: request,
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 1, 1),
    );
  }

  // Helper to create a SkillBundle.
  SkillBundle _makeBundle({
    required String id,
    required String name,
    String? description,
    List<String>? capabilities,
  }) {
    return SkillBundle(
      schemaVersion: '0.1.0',
      manifest: SkillManifest(
        id: id,
        name: name,
        version: '1.0.0',
        provider: 'test',
        description: description,
        capabilities: capabilities,
      ),
      procedures: [],
    );
  }

  group('FixedRouter', () {
    test('returns fixed list of skill IDs', () async {
      final router = FixedRouter(['skill-a', 'skill-b']);
      final result = await router.route(_makeContext());

      expect(result, equals(['skill-a', 'skill-b']));
    });

    test('returns empty list when constructed with empty list', () async {
      final router = FixedRouter([]);
      final result = await router.route(_makeContext());

      expect(result, isEmpty);
    });

    test('ignores context completely', () async {
      final router = FixedRouter(['fixed-skill']);

      final result1 = await router.route(_makeContext(request: 'foo'));
      final result2 = await router.route(_makeContext(request: 'bar'));

      expect(result1, equals(result2));
    });
  });

  group('CapabilityRouter', () {
    test('matches skill by name keyword', () async {
      final registry = _MockRegistry([
        _makeBundle(id: 'analyzer', name: 'Data Analyzer'),
        _makeBundle(id: 'writer', name: 'Report Writer'),
      ]);

      final router = CapabilityRouter(registry: registry);
      final result = await router.route(_makeContext(request: 'analyzer'));

      expect(result, contains('analyzer'));
      expect(result, isNot(contains('writer')));
    });

    test('matches skill by description keyword', () async {
      final registry = _MockRegistry([
        _makeBundle(
          id: 'fin-skill',
          name: 'Financial Skill',
          description: 'Performs financial analysis on data',
        ),
        _makeBundle(
          id: 'art-skill',
          name: 'Art Skill',
          description: 'Creates artwork',
        ),
      ]);

      final router = CapabilityRouter(registry: registry);
      final result =
          await router.route(_makeContext(request: 'financial'));

      expect(result, contains('fin-skill'));
    });

    test('returns empty list when no match', () async {
      final registry = _MockRegistry([
        _makeBundle(id: 'skill-1', name: 'Skill One'),
      ]);

      final router = CapabilityRouter(registry: registry);
      final result = await router.route(
          _makeContext(request: 'completely-unrelated'));

      expect(result, isEmpty);
    });

    test('returns multiple matches', () async {
      final registry = _MockRegistry([
        _makeBundle(id: 's1', name: 'Data Analysis'),
        _makeBundle(id: 's2', name: 'Data Processing'),
        _makeBundle(id: 's3', name: 'Image Generation'),
      ]);

      final router = CapabilityRouter(registry: registry);
      final result = await router.route(_makeContext(request: 'data'));

      expect(result.length, equals(2));
      expect(result, contains('s1'));
      expect(result, contains('s2'));
    });
  });

  group('LlmRouter', () {
    test('uses LLM to route and parses response', () async {
      final mockLlm = MockLlmPort(
        response: const LlmResponse(
          content: '["skill-a", "skill-b"]',
          usage: LlmUsage(inputTokens: 50, outputTokens: 20),
        ),
      );

      final registry = _MockRegistry([
        _makeBundle(id: 'skill-a', name: 'Skill A'),
        _makeBundle(id: 'skill-b', name: 'Skill B'),
      ]);

      final router = LlmRouter(registry: registry, llmPort: mockLlm);
      final result = await router.route(_makeContext());

      expect(result, contains('skill-a'));
      expect(result, contains('skill-b'));
      expect(mockLlm.completeCalls.length, equals(1));
    });

    test('returns empty list when no skills available', () async {
      final mockLlm = MockLlmPort();
      final registry = _MockRegistry([]);

      final router = LlmRouter(registry: registry, llmPort: mockLlm);
      final result = await router.route(_makeContext());

      expect(result, isEmpty);
      // Should not call LLM when no skills
      expect(mockLlm.completeCalls, isEmpty);
    });

    test('falls back to first skill on LLM error', () async {
      final mockLlm = MockLlmPort();
      mockLlm.nextError = Exception('LLM unavailable');

      final registry = _MockRegistry([
        _makeBundle(id: 'fallback', name: 'Fallback Skill'),
      ]);

      final router = LlmRouter(registry: registry, llmPort: mockLlm);
      final result = await router.route(_makeContext());

      expect(result, equals(['fallback']));
    });

    test('handles malformed LLM response gracefully', () async {
      final mockLlm = MockLlmPort(
        response: const LlmResponse(
          content: 'I think you should use skill-a.',
          usage: LlmUsage(inputTokens: 50, outputTokens: 20),
        ),
      );

      final registry = _MockRegistry([
        _makeBundle(id: 'skill-a', name: 'Skill A'),
      ]);

      final router = LlmRouter(registry: registry, llmPort: mockLlm);
      final result = await router.route(_makeContext());

      // Should return empty or parsed result - no crash
      expect(result, isA<List<String>>());
    });
  });

  group('CompositeRouter', () {
    test('returns result from first router that matches', () async {
      final router = CompositeRouter([
        FixedRouter([]), // Returns empty
        FixedRouter(['skill-from-second']),
        FixedRouter(['should-not-reach']),
      ]);

      final result = await router.route(_makeContext());

      expect(result, equals(['skill-from-second']));
    });

    test('returns empty when all routers return empty', () async {
      final router = CompositeRouter([
        FixedRouter([]),
        FixedRouter([]),
      ]);

      final result = await router.route(_makeContext());

      expect(result, isEmpty);
    });

    test('uses first non-empty result', () async {
      final router = CompositeRouter([
        FixedRouter(['first-match']),
        FixedRouter(['second-match']),
      ]);

      final result = await router.route(_makeContext());

      expect(result, equals(['first-match']));
    });
  });

  group('ConditionalRouter', () {
    test('uses router for matching condition', () async {
      final router = ConditionalRouter(
        conditions: {
          (ctx) => ctx.request.contains('analyze'):
              FixedRouter(['analyzer']),
          (ctx) => ctx.request.contains('generate'):
              FixedRouter(['generator']),
        },
      );

      final result =
          await router.route(_makeContext(request: 'analyze this'));

      expect(result, equals(['analyzer']));
    });

    test('uses default router when no conditions match', () async {
      final router = ConditionalRouter(
        conditions: {
          (ctx) => ctx.request.contains('xyz'):
              FixedRouter(['xyz-skill']),
        },
        defaultRouter: FixedRouter(['default-skill']),
      );

      final result =
          await router.route(_makeContext(request: 'abc'));

      expect(result, equals(['default-skill']));
    });

    test('returns empty when no conditions match and no default', () async {
      final router = ConditionalRouter(
        conditions: {
          (ctx) => false: FixedRouter(['never']),
        },
      );

      final result = await router.route(_makeContext());

      expect(result, isEmpty);
    });

    test('evaluates conditions in order, uses first match', () async {
      final router = ConditionalRouter(
        conditions: {
          (ctx) => true: FixedRouter(['first']),
          (ctx) => true: FixedRouter(['second']),
        },
      );

      final result = await router.route(_makeContext());

      expect(result, equals(['first']));
    });
  });

  group('RouterBuilder', () {
    test('builds single router directly', () {
      final registry = _MockRegistry([]);

      final router = (RouterBuilder()
            ..withCapabilityRouting(registry))
          .build();

      expect(router, isA<CapabilityRouter>());
    });

    test('builds composite router for multiple routers', () {
      final registry = _MockRegistry([]);
      final mockLlm = MockLlmPort();

      final router = (RouterBuilder()
            ..withCapabilityRouting(registry)
            ..withLlmRouting(registry: registry, llmPort: mockLlm)
            ..withFallback(['default']))
          .build();

      expect(router, isA<CompositeRouter>());
    });

    test('throws when building with no routers', () {
      expect(
        () => RouterBuilder().build(),
        throwsA(isA<StateError>()),
      );
    });

    test('withCustom adds custom router', () {
      final custom = FixedRouter(['custom']);
      final router = (RouterBuilder()..withCustom(custom)).build();

      expect(router, isA<FixedRouter>());
    });

    test('fluent API chains correctly', () {
      final registry = _MockRegistry([]);

      final builder = RouterBuilder()
          .withCapabilityRouting(registry)
          .withFallback(['fallback']);

      expect(builder, isA<RouterBuilder>());
      final router = builder.build();
      expect(router, isA<CompositeRouter>());
    });
  });
}
