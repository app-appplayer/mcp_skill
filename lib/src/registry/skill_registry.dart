/// Skill registry for managing skill definitions.
library;

import '../definition/skill.dart';

/// Registry for managing skill definitions.
class SkillRegistry {
  SkillRegistry();

  final Map<String, Skill> _skills = {};
  final Map<String, List<String>> _tags = {};

  /// Register a skill.
  void register(Skill skill) {
    _skills[skill.id] = skill;

    // Index by tags
    for (final tag in skill.tags) {
      _tags.putIfAbsent(tag, () => []).add(skill.id);
    }
  }

  /// Unregister a skill.
  Skill? unregister(String id) {
    final skill = _skills.remove(id);
    if (skill != null) {
      for (final tag in skill.tags) {
        _tags[tag]?.remove(id);
      }
    }
    return skill;
  }

  /// Get a skill by ID.
  Skill? get(String id) => _skills[id];

  /// Check if a skill exists.
  bool has(String id) => _skills.containsKey(id);

  /// Get all skills.
  Iterable<Skill> get all => _skills.values;

  /// Get skill count.
  int get count => _skills.length;

  /// Get skills by tag.
  List<Skill> getByTag(String tag) {
    final ids = _tags[tag] ?? [];
    return ids.map((id) => _skills[id]).nonNulls.toList();
  }

  /// Get all tags.
  Iterable<String> get tags => _tags.keys;

  /// Find skills matching a predicate.
  List<Skill> find(bool Function(Skill) predicate) {
    return _skills.values.where(predicate).toList();
  }

  /// Search skills by name or description.
  List<Skill> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _skills.values.where((skill) {
      if (skill.name.toLowerCase().contains(lowerQuery)) return true;
      if (skill.description?.toLowerCase().contains(lowerQuery) ?? false) {
        return true;
      }
      return skill.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Clear all skills.
  void clear() {
    _skills.clear();
    _tags.clear();
  }

  /// Load skills from JSON list.
  void loadFromJson(List<dynamic> json) {
    for (final item in json) {
      if (item is Map<String, dynamic>) {
        register(Skill.fromJson(item));
      }
    }
  }

  /// Export all skills to JSON.
  List<Map<String, dynamic>> toJson() {
    return _skills.values.map((s) => s.toJson()).toList();
  }
}

/// A versioned skill registry with history.
class VersionedSkillRegistry {
  VersionedSkillRegistry();

  final Map<String, Map<String, Skill>> _versions = {};
  final Map<String, String> _latest = {};

  /// Register a skill version.
  void register(Skill skill) {
    final versions = _versions.putIfAbsent(skill.id, () => {});
    versions[skill.version] = skill;
    _latest[skill.id] = skill.version;
  }

  /// Get a specific version of a skill.
  Skill? get(String id, {String? version}) {
    final versions = _versions[id];
    if (versions == null) return null;

    final targetVersion = version ?? _latest[id];
    if (targetVersion == null) return null;

    return versions[targetVersion];
  }

  /// Get the latest version of a skill.
  Skill? getLatest(String id) => get(id);

  /// Get all versions of a skill.
  List<String> getVersions(String id) {
    return _versions[id]?.keys.toList() ?? [];
  }

  /// Check if a skill exists.
  bool has(String id, {String? version}) {
    if (version != null) {
      return _versions[id]?.containsKey(version) ?? false;
    }
    return _versions.containsKey(id);
  }

  /// Get all skill IDs.
  Iterable<String> get ids => _versions.keys;

  /// Get all latest skills.
  Iterable<Skill> get all {
    return _latest.entries.map((e) => _versions[e.key]?[e.value]).nonNulls;
  }
}

/// Skill group for organizing related skills.
class SkillGroup {
  SkillGroup({
    required this.id,
    required this.name,
    this.description,
    List<String>? skillIds,
  }) : skillIds = skillIds ?? [];

  /// Group identifier.
  final String id;

  /// Group name.
  final String name;

  /// Group description.
  final String? description;

  /// Skill IDs in this group.
  final List<String> skillIds;

  /// Add a skill to the group.
  void add(String skillId) {
    if (!skillIds.contains(skillId)) {
      skillIds.add(skillId);
    }
  }

  /// Remove a skill from the group.
  void remove(String skillId) {
    skillIds.remove(skillId);
  }

  /// Check if group contains a skill.
  bool contains(String skillId) => skillIds.contains(skillId);

  /// Get skills from a registry.
  List<Skill> getSkills(SkillRegistry registry) {
    return skillIds.map((id) => registry.get(id)).nonNulls.toList();
  }

  factory SkillGroup.fromJson(Map<String, dynamic> json) {
    return SkillGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      skillIds: (json['skillIds'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'skillIds': skillIds,
      };
}
