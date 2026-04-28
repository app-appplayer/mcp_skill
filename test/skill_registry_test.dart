import 'package:test/test.dart';
import 'package:mcp_skill/mcp_skill.dart';

void main() {
  group('SkillRegistry', () {
    late SkillRegistry registry;

    setUp(() {
      registry = SkillRegistry();
    });

    Skill createSkill(String id, {List<String>? tags}) {
      return Skill(
        id: id,
        name: 'Skill $id',
        version: '1.0.0',
        tags: tags ?? [],
      );
    }

    test('register adds skill to registry', () {
      final skill = createSkill('skill-1');
      registry.register(skill);

      expect(registry.has('skill-1'), isTrue);
      expect(registry.count, equals(1));
    });

    test('get retrieves skill by id', () {
      final skill = createSkill('skill-2');
      registry.register(skill);

      final retrieved = registry.get('skill-2');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, equals('skill-2'));
    });

    test('get returns null for missing skill', () {
      expect(registry.get('nonexistent'), isNull);
    });

    test('unregister removes skill', () {
      final skill = createSkill('skill-3');
      registry.register(skill);
      expect(registry.has('skill-3'), isTrue);

      final removed = registry.unregister('skill-3');
      expect(removed, isNotNull);
      expect(registry.has('skill-3'), isFalse);
    });

    test('all returns all skills', () {
      registry.register(createSkill('s1'));
      registry.register(createSkill('s2'));
      registry.register(createSkill('s3'));

      expect(registry.all.length, equals(3));
    });

    test('getByTag returns skills with tag', () {
      registry.register(createSkill('s1', tags: ['api', 'public']));
      registry.register(createSkill('s2', tags: ['api']));
      registry.register(createSkill('s3', tags: ['internal']));

      final apiSkills = registry.getByTag('api');
      expect(apiSkills.length, equals(2));

      final internalSkills = registry.getByTag('internal');
      expect(internalSkills.length, equals(1));

      final emptySkills = registry.getByTag('nonexistent');
      expect(emptySkills, isEmpty);
    });

    test('tags returns all unique tags', () {
      registry.register(createSkill('s1', tags: ['a', 'b']));
      registry.register(createSkill('s2', tags: ['b', 'c']));

      final allTags = registry.tags.toList();
      expect(allTags, containsAll(['a', 'b', 'c']));
    });

    test('find filters skills by predicate', () {
      registry.register(createSkill('important-1', tags: ['important']));
      registry.register(createSkill('important-2', tags: ['important']));
      registry.register(createSkill('other', tags: ['other']));

      final important = registry.find((s) => s.id.startsWith('important'));
      expect(important.length, equals(2));
    });

    test('search finds skills by name', () {
      final skill = Skill(
        id: 's1',
        name: 'Email Sender',
        version: '1.0.0',
        description: 'Sends emails',
      );
      registry.register(skill);

      final results = registry.search('email');
      expect(results.length, equals(1));
      expect(results.first.id, equals('s1'));
    });

    test('search finds skills by description', () {
      final skill = Skill(
        id: 's1',
        name: 'Notifier',
        version: '1.0.0',
        description: 'Sends notifications to users',
      );
      registry.register(skill);

      final results = registry.search('notifications');
      expect(results.length, equals(1));
    });

    test('search finds skills by tag', () {
      registry.register(createSkill('s1', tags: ['automation']));
      registry.register(createSkill('s2', tags: ['manual']));

      final results = registry.search('auto');
      expect(results.length, equals(1));
      expect(results.first.id, equals('s1'));
    });

    test('clear removes all skills', () {
      registry.register(createSkill('s1', tags: ['a']));
      registry.register(createSkill('s2', tags: ['b']));
      expect(registry.count, equals(2));

      registry.clear();
      expect(registry.count, equals(0));
      expect(registry.tags, isEmpty);
    });

    test('loadFromJson loads multiple skills', () {
      final json = [
        {'id': 's1', 'name': 'Skill 1', 'version': '1.0.0'},
        {'id': 's2', 'name': 'Skill 2', 'version': '1.0.0'},
      ];

      registry.loadFromJson(json);
      expect(registry.count, equals(2));
    });

    test('toJson exports all skills', () {
      registry.register(createSkill('s1'));
      registry.register(createSkill('s2'));

      final json = registry.toJson();
      expect(json.length, equals(2));
    });
  });

  group('VersionedSkillRegistry', () {
    late VersionedSkillRegistry registry;

    setUp(() {
      registry = VersionedSkillRegistry();
    });

    test('register adds skill version', () {
      final skill = Skill(id: 's1', name: 'Test', version: '1.0.0');
      registry.register(skill);

      expect(registry.has('s1'), isTrue);
    });

    test('get returns latest version by default', () {
      registry.register(Skill(id: 's1', name: 'Test v1', version: '1.0.0'));
      registry.register(Skill(id: 's1', name: 'Test v2', version: '2.0.0'));

      final latest = registry.get('s1');
      expect(latest!.version, equals('2.0.0'));
    });

    test('get with version returns specific version', () {
      registry.register(Skill(id: 's1', name: 'Test v1', version: '1.0.0'));
      registry.register(Skill(id: 's1', name: 'Test v2', version: '2.0.0'));

      final v1 = registry.get('s1', version: '1.0.0');
      expect(v1!.name, equals('Test v1'));
    });

    test('getVersions returns all versions', () {
      registry.register(Skill(id: 's1', name: 'Test', version: '1.0.0'));
      registry.register(Skill(id: 's1', name: 'Test', version: '1.1.0'));
      registry.register(Skill(id: 's1', name: 'Test', version: '2.0.0'));

      final versions = registry.getVersions('s1');
      expect(versions.length, equals(3));
      expect(versions, containsAll(['1.0.0', '1.1.0', '2.0.0']));
    });

    test('has checks specific version', () {
      registry.register(Skill(id: 's1', name: 'Test', version: '1.0.0'));

      expect(registry.has('s1', version: '1.0.0'), isTrue);
      expect(registry.has('s1', version: '2.0.0'), isFalse);
    });

    test('ids returns all skill ids', () {
      registry.register(Skill(id: 's1', name: 'Test 1', version: '1.0.0'));
      registry.register(Skill(id: 's2', name: 'Test 2', version: '1.0.0'));

      expect(registry.ids, containsAll(['s1', 's2']));
    });

    test('all returns latest versions', () {
      registry.register(Skill(id: 's1', name: 'Test 1 v1', version: '1.0.0'));
      registry.register(Skill(id: 's1', name: 'Test 1 v2', version: '2.0.0'));
      registry.register(Skill(id: 's2', name: 'Test 2', version: '1.0.0'));

      final all = registry.all.toList();
      expect(all.length, equals(2));
    });
  });

  group('SkillGroup', () {
    test('creates group with required fields', () {
      final group = SkillGroup(id: 'g1', name: 'Group 1');

      expect(group.id, equals('g1'));
      expect(group.name, equals('Group 1'));
      expect(group.skillIds, isEmpty);
    });

    test('add adds skill to group', () {
      final group = SkillGroup(id: 'g1', name: 'Group 1');
      group.add('skill-1');

      expect(group.contains('skill-1'), isTrue);
      expect(group.skillIds.length, equals(1));
    });

    test('add does not duplicate skills', () {
      final group = SkillGroup(id: 'g1', name: 'Group 1');
      group.add('skill-1');
      group.add('skill-1');

      expect(group.skillIds.length, equals(1));
    });

    test('remove removes skill from group', () {
      final group = SkillGroup(
        id: 'g1',
        name: 'Group 1',
        skillIds: ['skill-1', 'skill-2'],
      );

      group.remove('skill-1');
      expect(group.contains('skill-1'), isFalse);
      expect(group.skillIds.length, equals(1));
    });

    test('getSkills retrieves skills from registry', () {
      final registry = SkillRegistry();
      registry.register(Skill(id: 's1', name: 'Skill 1', version: '1.0.0'));
      registry.register(Skill(id: 's2', name: 'Skill 2', version: '1.0.0'));

      final group = SkillGroup(
        id: 'g1',
        name: 'Group 1',
        skillIds: ['s1', 's2'],
      );

      final skills = group.getSkills(registry);
      expect(skills.length, equals(2));
    });

    test('serializes and deserializes correctly', () {
      final original = SkillGroup(
        id: 'g1',
        name: 'API Skills',
        description: 'Skills for API operations',
        skillIds: ['api-1', 'api-2'],
      );

      final json = original.toJson();
      final restored = SkillGroup.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.skillIds, equals(original.skillIds));
    });
  });
}
