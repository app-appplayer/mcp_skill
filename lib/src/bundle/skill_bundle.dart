/// Skill Bundle - Loading and managing skill bundles.
///
/// Provides utilities for loading skills from bundles.
library;

import '../definition/skill.dart';
import '../definition/parameter.dart' show Parameter;
import '../definition/step.dart' show SkillStep;

/// A bundle of skills.
class SkillBundle {
  /// Bundle ID.
  final String bundleId;

  /// Bundle name.
  final String name;

  /// Bundle version.
  final String version;

  /// Skills in the bundle.
  final List<Skill> skills;

  /// Bundle metadata.
  final Map<String, dynamic> metadata;

  const SkillBundle({
    required this.bundleId,
    required this.name,
    this.version = '1.0.0',
    this.skills = const [],
    this.metadata = const {},
  });

  /// Create from JSON.
  factory SkillBundle.fromJson(Map<String, dynamic> json) {
    return SkillBundle(
      bundleId: json['bundleId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '1.0.0',
      skills: (json['skills'] as List<dynamic>?)
              ?.map((e) => Skill.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() {
    return {
      'bundleId': bundleId,
      'name': name,
      'version': version,
      if (skills.isNotEmpty) 'skills': skills.map((s) => s.toJson()).toList(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  /// Get skill by ID.
  Skill? getSkill(String skillId) {
    for (final skill in skills) {
      if (skill.id == skillId) return skill;
    }
    return null;
  }

  /// Get skills by tag.
  List<Skill> getSkillsByTag(String tag) {
    return skills.where((s) => s.tags.contains(tag)).toList();
  }
}

/// Loader for skill bundles.
class SkillBundleLoader {
  /// Load bundle from JSON.
  SkillBundle loadFromJson(Map<String, dynamic> json) {
    return SkillBundle.fromJson(json);
  }

  /// Load skills from MCP bundle skills section.
  List<Skill> loadFromMcpBundle(Map<String, dynamic> skillsSection) {
    final skills = <Skill>[];

    final modules = skillsSection['modules'] as List<dynamic>? ?? [];
    for (final module in modules) {
      final moduleMap = module as Map<String, dynamic>;
      final procedures = moduleMap['procedures'] as List<dynamic>? ?? [];

      for (final proc in procedures) {
        final procMap = proc as Map<String, dynamic>;
        skills.add(_procedureToSkill(procMap, moduleMap));
      }
    }

    return skills;
  }

  Skill _procedureToSkill(
    Map<String, dynamic> procedure,
    Map<String, dynamic> module,
  ) {
    return Skill(
      id: procedure['id'] as String? ?? '',
      name: procedure['name'] as String? ?? '',
      description: procedure['description'] as String?,
      version: module['version'] as String? ?? '1.0.0',
      inputs: _parseInputs(procedure['inputs'] as List<dynamic>?),
      steps: _parseSteps(procedure['steps'] as List<dynamic>?),
      metadata: {
        'moduleId': module['id'],
        'moduleName': module['name'],
      },
    );
  }

  List<Parameter> _parseInputs(List<dynamic>? inputs) {
    if (inputs == null) return [];
    return inputs
        .map((e) => Parameter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<SkillStep> _parseSteps(List<dynamic>? steps) {
    if (steps == null) return [];
    return steps
        .map((e) => SkillStep.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Skill bundle validator.
class SkillBundleValidator {
  /// Validate a skill bundle.
  ValidationResult validate(SkillBundle bundle) {
    final errors = <String>[];
    final warnings = <String>[];

    if (bundle.bundleId.isEmpty) {
      errors.add('Bundle ID is required');
    }

    if (bundle.name.isEmpty) {
      errors.add('Bundle name is required');
    }

    // Validate each skill
    for (final skill in bundle.skills) {
      final skillErrors = _validateSkill(skill);
      errors.addAll(skillErrors);
    }

    // Check for duplicate skill IDs
    final ids = <String>{};
    for (final skill in bundle.skills) {
      if (ids.contains(skill.id)) {
        errors.add('Duplicate skill ID: ${skill.id}');
      }
      ids.add(skill.id);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  List<String> _validateSkill(Skill skill) {
    final errors = <String>[];

    if (skill.id.isEmpty) {
      errors.add('Skill ID is required');
    }

    if (skill.name.isEmpty) {
      errors.add('Skill name is required for ${skill.id}');
    }

    return errors;
  }
}

/// Validation result.
class ValidationResult {
  /// Whether validation passed.
  final bool isValid;

  /// Error messages.
  final List<String> errors;

  /// Warning messages.
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}
