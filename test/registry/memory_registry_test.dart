import 'package:test/test.dart';
import 'package:mcp_skill/src/registry/memory_registry.dart';
import 'package:mcp_skill/src/registry/skill_registry.dart';

import '../helpers/test_data.dart';

void main() {
  group('MemorySkillRegistry', () {
    late MemorySkillRegistry registry;

    setUp(() {
      registry = MemorySkillRegistry();
    });

    group('registerSkill', () {
      test('registers a bundle successfully', () async {
        final bundle = makeSkillBundle(id: 'com.test.skill');
        await registry.registerSkill(bundle);

        expect(registry.count, equals(1));
        expect(registry.has('com.test.skill'), isTrue);
      });

      test('registers multiple bundles', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-c'));

        expect(registry.count, equals(3));
      });

      test('overwrites bundle with same id', () async {
        await registry.registerSkill(
          makeSkillBundle(id: 'skill-a', name: 'Original'),
        );
        await registry.registerSkill(
          makeSkillBundle(id: 'skill-a', name: 'Updated'),
        );

        expect(registry.count, equals(1));
        final retrieved = await registry.getSkill('skill-a');
        expect(retrieved!.manifest.name, equals('Updated'));
      });

      test('skill is enabled by default after registration', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));

        final enabled = await registry.isEnabled('skill-a');
        expect(enabled, isTrue);
      });

      test('does not reset enabled state on re-registration', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', false);
        // Re-register same id
        await registry.registerSkill(
          makeSkillBundle(id: 'skill-a', name: 'Updated'),
        );

        // putIfAbsent preserves the existing false
        final enabled = await registry.isEnabled('skill-a');
        expect(enabled, isFalse);
      });
    });

    group('getSkill', () {
      test('returns bundle when it exists', () async {
        final bundle = makeSkillBundle(id: 'skill-a', name: 'Skill A');
        await registry.registerSkill(bundle);

        final retrieved = await registry.getSkill('skill-a');

        expect(retrieved, isNotNull);
        expect(retrieved!.manifest.id, equals('skill-a'));
        expect(retrieved.manifest.name, equals('Skill A'));
      });

      test('returns null when bundle does not exist', () async {
        final retrieved = await registry.getSkill('non-existent');

        expect(retrieved, isNull);
      });
    });

    group('listSkills', () {
      test('returns empty list when no skills registered', () async {
        final skills = await registry.listSkills();

        expect(skills, isEmpty);
      });

      test('returns all registered skills when no workspace filter', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));

        final skills = await registry.listSkills();

        expect(skills, hasLength(2));
      });

      test('filters by workspace enablement', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));

        // Enable skill-a for workspace 'ws-1'
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');
        // Do not enable skill-b for workspace 'ws-1'

        final skills = await registry.listSkills(workspaceId: 'ws-1');

        // skill-a has workspace override, skill-b falls back to global (true)
        expect(skills, hasLength(2));
      });

      test('workspace filter excludes disabled skills', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));

        // Disable skill-b globally
        await registry.setEnabled('skill-b', false);

        // Enable skill-a for workspace, do not set workspace override for skill-b
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');

        final skills = await registry.listSkills(workspaceId: 'ws-1');

        // skill-a: has workspace override (enabled)
        // skill-b: no workspace override, falls back to global (false)
        final ids = skills.map((s) => s.manifest.id).toList();
        expect(ids, contains('skill-a'));
        expect(ids, isNot(contains('skill-b')));
      });
    });

    group('unregisterSkill', () {
      test('removes a registered bundle', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.unregisterSkill('skill-a');

        expect(registry.count, equals(0));
        expect(registry.has('skill-a'), isFalse);
        final retrieved = await registry.getSkill('skill-a');
        expect(retrieved, isNull);
      });

      test('removes enabled state along with bundle', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.unregisterSkill('skill-a');

        final enabled = await registry.isEnabled('skill-a');
        expect(enabled, isFalse);
      });

      test('removes workspace enablement along with bundle', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');
        await registry.unregisterSkill('skill-a');

        // After unregister, workspace enablement should also be removed
        final enabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(enabled, isFalse);
      });

      test('does not throw when unregistering non-existent skill', () async {
        await expectLater(
          registry.unregisterSkill('non-existent'),
          completes,
        );
      });

      test('does not affect other registered skills', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));
        await registry.unregisterSkill('skill-a');

        expect(registry.count, equals(1));
        expect(registry.has('skill-b'), isTrue);
      });
    });

    group('isEnabled', () {
      test('returns false for unregistered skill', () async {
        final enabled = await registry.isEnabled('non-existent');
        expect(enabled, isFalse);
      });

      test('returns true for newly registered skill', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        final enabled = await registry.isEnabled('skill-a');
        expect(enabled, isTrue);
      });

      test('returns workspace-specific enablement when workspaceId given',
          () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');

        final enabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(enabled, isTrue);
      });

      test('falls back to global when no workspace override exists', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        // No workspace override set; global default is true
        final enabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(enabled, isTrue);
      });

      test('workspace override supersedes global setting', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        // Global: enabled (default)
        // Workspace ws-1: explicitly disabled
        await registry.setEnabled('skill-a', false, workspaceId: 'ws-1');

        // Workspace query should use the override, not the global
        // But here, setEnabled with false removes from the workspace set
        // And _isEnabledForWorkspace checks if the workspace set exists
        // then returns workspaceSet.contains(workspaceId)
        // Since we created the set via setEnabled(true) first? No -
        // putIfAbsent creates the set, then enabled=false removes from it
        // So the set exists but is empty, meaning .contains('ws-1') = false
        final wsEnabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(wsEnabled, isFalse);

        // Global still enabled
        final globalEnabled = await registry.isEnabled('skill-a');
        expect(globalEnabled, isTrue);
      });
    });

    group('setEnabled', () {
      test('enables a skill globally', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', false);
        expect(await registry.isEnabled('skill-a'), isFalse);

        await registry.setEnabled('skill-a', true);
        expect(await registry.isEnabled('skill-a'), isTrue);
      });

      test('disables a skill globally', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', false);

        final enabled = await registry.isEnabled('skill-a');
        expect(enabled, isFalse);
      });

      test('enables a skill for a specific workspace', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');

        final enabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(enabled, isTrue);
      });

      test('disables a skill for a specific workspace', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');
        await registry.setEnabled('skill-a', false, workspaceId: 'ws-1');

        final enabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(enabled, isFalse);
      });

      test('workspace settings are independent between workspaces', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');
        await registry.setEnabled('skill-a', false, workspaceId: 'ws-2');

        expect(
          await registry.isEnabled('skill-a', workspaceId: 'ws-1'),
          isTrue,
        );
        expect(
          await registry.isEnabled('skill-a', workspaceId: 'ws-2'),
          isFalse,
        );
      });

      test('workspace and global enablement are independent', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        // Disable globally
        await registry.setEnabled('skill-a', false);
        // Enable for specific workspace
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');

        expect(await registry.isEnabled('skill-a'), isFalse);
        expect(
          await registry.isEnabled('skill-a', workspaceId: 'ws-1'),
          isTrue,
        );
      });
    });

    group('count', () {
      test('returns 0 for empty registry', () {
        expect(registry.count, equals(0));
      });

      test('increments as skills are registered', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        expect(registry.count, equals(1));

        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));
        expect(registry.count, equals(2));
      });

      test('decrements as skills are unregistered', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));
        await registry.unregisterSkill('skill-a');

        expect(registry.count, equals(1));
      });
    });

    group('has', () {
      test('returns false for non-existent skill', () {
        expect(registry.has('non-existent'), isFalse);
      });

      test('returns true for registered skill', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        expect(registry.has('skill-a'), isTrue);
      });

      test('returns false after skill is unregistered', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.unregisterSkill('skill-a');
        expect(registry.has('skill-a'), isFalse);
      });
    });

    group('clear', () {
      test('removes all bundles', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.registerSkill(makeSkillBundle(id: 'skill-b'));
        registry.clear();

        expect(registry.count, equals(0));
        expect(registry.has('skill-a'), isFalse);
        expect(registry.has('skill-b'), isFalse);
      });

      test('clears enabled state', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        registry.clear();

        final enabled = await registry.isEnabled('skill-a');
        expect(enabled, isFalse);
      });

      test('clears workspace enablement state', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        await registry.setEnabled('skill-a', true, workspaceId: 'ws-1');
        registry.clear();

        final enabled =
            await registry.isEnabled('skill-a', workspaceId: 'ws-1');
        expect(enabled, isFalse);
      });

      test('returns empty list from listSkills after clear', () async {
        await registry.registerSkill(makeSkillBundle(id: 'skill-a'));
        registry.clear();

        final skills = await registry.listSkills();
        expect(skills, isEmpty);
      });
    });

    group('SkillBundleRegistry interface', () {
      test('implements SkillBundleRegistry', () {
        expect(registry, isA<SkillBundleRegistry>());
      });
    });
  });
}
