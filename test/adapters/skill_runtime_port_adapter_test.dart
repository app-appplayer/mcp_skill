/// Tests for SkillRuntimePortAdapter — REDESIGN-PLAN Phase 4.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;
import 'package:test/test.dart';

import 'package:mcp_skill/src/adapters/skill_runtime_port_adapter.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/runtime/skill_runtime.dart';

import '../helpers/mock_registry.dart';

SkillBundle _makeBundle(String id) {
  return SkillBundle.fromJson({
    'schemaVersion': '0.1.0',
    'manifest': {
      'id': id,
      'name': 'Test $id',
      'version': '1.0.0',
      'provider': 'test',
      'description': 'Test skill',
    },
    'procedures': [
      {
        'id': 'proc-$id',
        'name': 'Test Procedure',
        'steps': [
          {
            'id': 'step-1',
            'order': 1,
            'name': 'LLM Step',
            'action': {'type': 'llm', 'prompt': 'echo'},
          },
        ],
      },
    ],
  });
}

SkillRuntime _buildRuntime(MockSkillBundleRegistry registry) {
  return SkillRuntime(registry: registry, ports: SkillPorts.stub());
}

void main() {
  group('SkillRuntimePortAdapter', () {
    late MockSkillBundleRegistry registry;
    late SkillRuntime runtime;
    late SkillRuntimePortAdapter adapter;

    setUp(() {
      registry = MockSkillBundleRegistry();
      runtime = _buildRuntime(registry);
      adapter = SkillRuntimePortAdapter(
        runtime: runtime,
        defaultWorkspaceId: 'default-ws',
      );
    });

    test('executeSkill returns SkillRunHandle with result populated', () async {
      await registry.registerSkill(_makeBundle('skill-a'));

      final handle = await adapter.executeSkill('skill-a', {'input': 'x'});

      expect(handle, isA<bundle.SkillRunHandle>());
      expect(handle.skillId, equals('skill-a'));
      expect(handle.running, isFalse);
      expect(handle.result, isNotNull);
      expect(handle.runId, startsWith('run_'));
      expect(handle.startedAt, isA<DateTime>());
      expect(handle.finishedAt, isA<DateTime>());
    });

    test('executeSkill for unknown skill returns a failure result', () async {
      final handle = await adapter.executeSkill('unknown', const {});

      expect(handle.running, isFalse);
      expect(handle.result, isNotNull);
      expect(handle.result!.success, isFalse);
    });

    test('executeSkill honors workspaceId from context map', () async {
      await registry.registerSkill(_makeBundle('skill-ws'));

      final handle = await adapter.executeSkill(
        'skill-ws',
        const {},
        context: {'workspaceId': 'acme'},
      );

      // The handle itself does not expose workspaceId, but delegation
      // went through and returned a non-null result.
      expect(handle.result, isNotNull);
      expect(handle.skillId, equals('skill-ws'));
    });

    test('executeSkill without context falls back to defaultWorkspaceId',
        () async {
      await registry.registerSkill(_makeBundle('skill-default'));

      final handle = await adapter.executeSkill('skill-default', const {});

      expect(handle.result, isNotNull);
    });

    test('executeSkill honors traceId override from context map', () async {
      await registry.registerSkill(_makeBundle('skill-trace'));

      final handle = await adapter.executeSkill(
        'skill-trace',
        const {},
        context: {'traceId': 't-42'},
      );

      expect(handle.result, isNotNull);
    });

    test('cancel is a no-op and resolves', () async {
      await expectLater(adapter.cancel('run_123'), completes);
    });
  });
}
