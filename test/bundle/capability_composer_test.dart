import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/capability_composer.dart';
import 'package:mcp_skill/src/bundle/capability_types.dart';

void main() {
  group('CapabilityComposer', () {
    late CapabilityComposer composer;

    setUp(() {
      composer = CapabilityComposer();
    });

    group('compose', () {
      test('merges capabilities from multiple provided sources', () {
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'analyze')],
            tags: ['ai'],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'summarize')],
            tags: ['text'],
          ),
        };
        final required = <String, RequiredCapabilities>{};
        final permissions = <String, PermissionCapabilities>{};

        final result = composer.compose(provided, required, permissions);

        expect(result.provided.capabilities, hasLength(2));
        expect(
          result.provided.capabilities.map((c) => c.name),
          containsAll(['analyze', 'summarize']),
        );
      });

      test('merges tags from multiple sources with deduplication', () {
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [],
            tags: ['ai', 'shared-tag'],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [],
            tags: ['text', 'shared-tag'],
          ),
        };

        final result = composer.compose(
          provided,
          <String, RequiredCapabilities>{},
          <String, PermissionCapabilities>{},
        );

        // Tags are stored via a Set, so duplicates are removed
        expect(result.provided.tags, hasLength(3));
        expect(
          result.provided.tags,
          containsAll(['ai', 'text', 'shared-tag']),
        );
      });

      test('merges port requirements from multiple required sources', () {
        final required = {
          'skill-a': const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.llm)],
            skills: ['dep-1'],
          ),
          'skill-b': const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.knowledge)],
            skills: ['dep-2'],
          ),
        };

        final result = composer.compose(
          <String, ProvidedCapabilities>{},
          required,
          <String, PermissionCapabilities>{},
        );

        expect(result.required.ports, hasLength(2));
        expect(
          result.required.ports.map((p) => p.type),
          containsAll([PortType.llm, PortType.knowledge]),
        );
      });

      test('deduplicates skill dependencies from multiple sources', () {
        final required = {
          'skill-a': const RequiredCapabilities(
            ports: [],
            skills: ['shared-dep', 'dep-a'],
          ),
          'skill-b': const RequiredCapabilities(
            ports: [],
            skills: ['shared-dep', 'dep-b'],
          ),
        };

        final result = composer.compose(
          <String, ProvidedCapabilities>{},
          required,
          <String, PermissionCapabilities>{},
        );

        // Skills are stored via a Set, so duplicates are removed
        expect(result.required.skills, hasLength(3));
        expect(
          result.required.skills,
          containsAll(['shared-dep', 'dep-a', 'dep-b']),
        );
      });

      test('merges port permissions from multiple permission sources', () {
        final permissions = {
          'skill-a': const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.llm, operations: ['complete']),
            ],
            dataPermissions: [
              DataPermission(scope: 'profile', operations: ['read']),
            ],
          ),
          'skill-b': const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.mcp, operations: ['callTool']),
            ],
            dataPermissions: [
              DataPermission(scope: 'workspace', operations: ['read', 'write']),
            ],
          ),
        };

        final result = composer.compose(
          <String, ProvidedCapabilities>{},
          <String, RequiredCapabilities>{},
          permissions,
        );

        expect(result.permissions.portPermissions, hasLength(2));
        expect(result.permissions.dataPermissions, hasLength(2));
      });

      test('returns empty collections when no sources provided', () {
        final result = composer.compose(
          <String, ProvidedCapabilities>{},
          <String, RequiredCapabilities>{},
          <String, PermissionCapabilities>{},
        );

        expect(result.provided.capabilities, isEmpty);
        expect(result.provided.tags, isEmpty);
        expect(result.required.ports, isEmpty);
        expect(result.required.skills, isEmpty);
        expect(result.permissions.portPermissions, isEmpty);
        expect(result.permissions.dataPermissions, isEmpty);
        expect(result.conflicts, isEmpty);
        expect(result.hasConflicts, isFalse);
      });

      test('detects conflicts via ConflictDetector', () {
        // Both skills provide a capability with the same name
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'shared-cap')],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'shared-cap')],
          ),
        };

        final result = composer.compose(
          provided,
          <String, RequiredCapabilities>{},
          <String, PermissionCapabilities>{},
        );

        expect(result.hasConflicts, isTrue);
        expect(result.conflicts, hasLength(1));
        expect(
          result.conflicts.first.type,
          equals(CapabilityConflictType.capabilityOverlap),
        );
      });

      test('compose with single source returns its data unchanged', () {
        final provided = {
          'skill-only': const ProvidedCapabilities(
            capabilities: [
              SkillCapability(name: 'cap1'),
              SkillCapability(name: 'cap2'),
            ],
            tags: ['tag-a', 'tag-b'],
          ),
        };
        final required = {
          'skill-only': const RequiredCapabilities(
            ports: [PortRequirement(type: PortType.factGraph)],
            skills: ['helper-skill'],
          ),
        };
        final permissions = {
          'skill-only': const PermissionCapabilities(
            portPermissions: [
              PortPermission(port: PortType.factGraph, readOnly: true),
            ],
          ),
        };

        final result = composer.compose(provided, required, permissions);

        expect(result.provided.capabilities, hasLength(2));
        expect(result.provided.tags, hasLength(2));
        expect(result.required.ports, hasLength(1));
        expect(result.required.skills, hasLength(1));
        expect(result.permissions.portPermissions, hasLength(1));
        expect(result.hasConflicts, isFalse);
      });
    });
  });

  group('ConflictDetector', () {
    late ConflictDetector detector;

    setUp(() {
      detector = ConflictDetector();
    });

    group('detect', () {
      test('returns empty list when no conflicts', () {
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'cap-a')],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'cap-b')],
          ),
        };

        final conflicts = detector.detect(
          provided,
          <String, PermissionCapabilities>{},
        );

        expect(conflicts, isEmpty);
      });

      test('detects duplicate capability name across two skills', () {
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'overlap')],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'overlap')],
          ),
        };

        final conflicts = detector.detect(
          provided,
          <String, PermissionCapabilities>{},
        );

        expect(conflicts, hasLength(1));
        expect(conflicts.first.sourceSkillId, equals('skill-a'));
        expect(conflicts.first.targetSkillId, equals('skill-b'));
        expect(
          conflicts.first.type,
          equals(CapabilityConflictType.capabilityOverlap),
        );
        expect(conflicts.first.description, contains('overlap'));
        expect(conflicts.first.description, contains('skill-a'));
        expect(conflicts.first.description, contains('skill-b'));
      });

      test('detects multiple overlapping capabilities', () {
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [
              SkillCapability(name: 'cap-x'),
              SkillCapability(name: 'cap-y'),
            ],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [
              SkillCapability(name: 'cap-x'),
              SkillCapability(name: 'cap-y'),
            ],
          ),
        };

        final conflicts = detector.detect(
          provided,
          <String, PermissionCapabilities>{},
        );

        expect(conflicts, hasLength(2));
      });

      test('handles three skills with pairwise overlap', () {
        final provided = {
          'skill-a': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'shared')],
          ),
          'skill-b': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'shared')],
          ),
          'skill-c': const ProvidedCapabilities(
            capabilities: [SkillCapability(name: 'shared')],
          ),
        };

        final conflicts = detector.detect(
          provided,
          <String, PermissionCapabilities>{},
        );

        // skill-b conflicts with skill-a, skill-c conflicts with skill-a
        expect(conflicts, hasLength(2));
      });

      test('returns empty for single skill with no conflicts', () {
        final provided = {
          'skill-only': const ProvidedCapabilities(
            capabilities: [
              SkillCapability(name: 'cap-1'),
              SkillCapability(name: 'cap-2'),
            ],
          ),
        };

        final conflicts = detector.detect(
          provided,
          <String, PermissionCapabilities>{},
        );

        expect(conflicts, isEmpty);
      });

      test('returns empty for empty input', () {
        final conflicts = detector.detect(
          <String, ProvidedCapabilities>{},
          <String, PermissionCapabilities>{},
        );

        expect(conflicts, isEmpty);
      });
    });
  });

  group('CompositeCapabilities', () {
    test('hasConflicts returns false when conflicts list is empty', () {
      const composite = CompositeCapabilities(
        provided: ProvidedCapabilities(),
        required: RequiredCapabilities(),
        permissions: PermissionCapabilities(),
        conflicts: [],
      );

      expect(composite.hasConflicts, isFalse);
    });

    test('hasConflicts returns true when conflicts list is non-empty', () {
      const composite = CompositeCapabilities(
        provided: ProvidedCapabilities(),
        required: RequiredCapabilities(),
        permissions: PermissionCapabilities(),
        conflicts: [
          CapabilityConflict(
            description: 'test',
            sourceSkillId: 'a',
            targetSkillId: 'b',
            type: CapabilityConflictType.capabilityOverlap,
          ),
        ],
      );

      expect(composite.hasConflicts, isTrue);
    });
  });
}
