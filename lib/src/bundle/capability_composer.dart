/// Capability composer for composing capabilities from multiple skills.
library;

import 'capability_types.dart';

/// Composed capabilities from multiple skills.
class CompositeCapabilities {
  final ProvidedCapabilities provided;
  final RequiredCapabilities required;
  final PermissionCapabilities permissions;
  final List<CapabilityConflict> conflicts;

  const CompositeCapabilities({
    required this.provided,
    required this.required,
    required this.permissions,
    this.conflicts = const [],
  });

  /// Whether there are any conflicts in the composed capabilities.
  bool get hasConflicts => conflicts.isNotEmpty;
}

/// A conflict between capabilities.
class CapabilityConflict {
  final String description;
  final String sourceSkillId;
  final String targetSkillId;
  final CapabilityConflictType type;

  const CapabilityConflict({
    required this.description,
    required this.sourceSkillId,
    required this.targetSkillId,
    required this.type,
  });
}

/// Types of capability conflicts.
enum CapabilityConflictType { permissionConflict, portConflict, capabilityOverlap }

/// Composes capabilities from multiple skills.
class CapabilityComposer {
  /// Compose capabilities from multiple skill bundles.
  CompositeCapabilities compose(
    Map<String, ProvidedCapabilities> provided,
    Map<String, RequiredCapabilities> required,
    Map<String, PermissionCapabilities> permissions,
  ) {
    final allProvided = <SkillCapability>[];
    final allTags = <String>{};
    final allPorts = <PortRequirement>[];
    final allSkillDeps = <String>{};
    final allPortPerms = <PortPermission>[];
    final allDataPerms = <DataPermission>[];

    for (final p in provided.values) {
      allProvided.addAll(p.capabilities);
      allTags.addAll(p.tags);
    }
    for (final r in required.values) {
      allPorts.addAll(r.ports);
      allSkillDeps.addAll(r.skills);
    }
    for (final p in permissions.values) {
      allPortPerms.addAll(p.portPermissions);
      allDataPerms.addAll(p.dataPermissions);
    }

    final conflicts = ConflictDetector().detect(provided, permissions);

    return CompositeCapabilities(
      provided: ProvidedCapabilities(
        capabilities: allProvided,
        tags: allTags.toList(),
      ),
      required: RequiredCapabilities(
        ports: allPorts,
        skills: allSkillDeps.toList(),
      ),
      permissions: PermissionCapabilities(
        portPermissions: allPortPerms,
        dataPermissions: allDataPerms,
      ),
      conflicts: conflicts,
    );
  }
}

/// Detects conflicts between capability declarations.
class ConflictDetector {
  /// Detect conflicts between skill capabilities.
  List<CapabilityConflict> detect(
    Map<String, ProvidedCapabilities> provided,
    Map<String, PermissionCapabilities> permissions,
  ) {
    final conflicts = <CapabilityConflict>[];

    // Check for duplicate capability names across skills
    final capabilityOwners = <String, String>{};
    for (final entry in provided.entries) {
      for (final cap in entry.value.capabilities) {
        if (capabilityOwners.containsKey(cap.name)) {
          conflicts.add(CapabilityConflict(
            description:
                'Capability "${cap.name}" provided by both '
                '${capabilityOwners[cap.name]} and ${entry.key}',
            sourceSkillId: capabilityOwners[cap.name]!,
            targetSkillId: entry.key,
            type: CapabilityConflictType.capabilityOverlap,
          ));
        } else {
          capabilityOwners[cap.name] = entry.key;
        }
      }
    }

    return conflicts;
  }
}
