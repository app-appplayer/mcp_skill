/// Skill definition and structure.
library;

import 'parameter.dart';
import 'step.dart';

/// A skill definition representing an AI capability.
class Skill {
  Skill({
    required this.id,
    required this.name,
    this.description,
    this.version = '1.0.0',
    this.inputs = const [],
    this.output,
    this.steps = const [],
    this.triggers = const [],
    Map<String, dynamic>? metadata,
    List<String>? tags,
  })  : metadata = metadata ?? {},
        tags = tags ?? [];

  /// Unique skill identifier.
  final String id;

  /// Human-readable name.
  final String name;

  /// Skill description.
  final String? description;

  /// Skill version.
  final String version;

  /// Input parameters.
  final List<Parameter> inputs;

  /// Output specification.
  final OutputSpec? output;

  /// Execution steps.
  final List<SkillStep> steps;

  /// Triggers that can invoke this skill.
  final List<SkillTrigger> triggers;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Tags for categorization.
  final List<String> tags;

  /// Get an input parameter by name.
  Parameter? getInput(String name) {
    for (final input in inputs) {
      if (input.name == name) return input;
    }
    return null;
  }

  /// Get a step by ID.
  SkillStep? getStep(String id) {
    for (final step in steps) {
      if (step.id == id) return step;
    }
    return null;
  }

  /// Get the entry step.
  SkillStep? get entryStep => steps.isNotEmpty ? steps.first : null;

  /// Validate input values against parameters.
  List<String> validateInputs(Map<String, dynamic> values) {
    final errors = <String>[];

    for (final param in inputs) {
      final value = values[param.name];

      if (param.required && value == null) {
        errors.add('Required parameter "${param.name}" is missing');
        continue;
      }

      if (value != null) {
        final typeError = param.validateType(value);
        if (typeError != null) {
          errors.add(typeError);
        }

        final constraintErrors = param.validateConstraints(value);
        errors.addAll(constraintErrors);
      }
    }

    return errors;
  }

  /// Create from JSON.
  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      version: json['version'] as String? ?? '1.0.0',
      inputs: (json['inputs'] as List<dynamic>?)
              ?.map((e) => Parameter.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      output: json['output'] != null
          ? OutputSpec.fromJson(json['output'] as Map<String, dynamic>)
          : null,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => SkillStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      triggers: (json['triggers'] as List<dynamic>?)
              ?.map((e) => SkillTrigger.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        'version': version,
        if (inputs.isNotEmpty) 'inputs': inputs.map((i) => i.toJson()).toList(),
        if (output != null) 'output': output!.toJson(),
        if (steps.isNotEmpty) 'steps': steps.map((s) => s.toJson()).toList(),
        if (triggers.isNotEmpty)
          'triggers': triggers.map((t) => t.toJson()).toList(),
        if (metadata.isNotEmpty) 'metadata': metadata,
        if (tags.isNotEmpty) 'tags': tags,
      };

  @override
  String toString() => 'Skill($id: $name v$version)';
}

/// Output specification for a skill.
class OutputSpec {
  OutputSpec({
    required this.type,
    this.description,
    this.schema,
  });

  /// Output type.
  final ParameterType type;

  /// Output description.
  final String? description;

  /// Schema for complex types.
  final Map<String, dynamic>? schema;

  factory OutputSpec.fromJson(Map<String, dynamic> json) {
    return OutputSpec(
      type: ParameterType.fromString(json['type'] as String? ?? 'any'),
      description: json['description'] as String?,
      schema: json['schema'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (description != null) 'description': description,
        if (schema != null) 'schema': schema,
      };
}

/// Skill trigger definition.
class SkillTrigger {
  SkillTrigger({
    required this.type,
    this.config = const {},
    this.condition,
  });

  /// Trigger type.
  final TriggerType type;

  /// Trigger configuration.
  final Map<String, dynamic> config;

  /// Trigger condition expression.
  final String? condition;

  factory SkillTrigger.fromJson(Map<String, dynamic> json) {
    return SkillTrigger(
      type: TriggerType.fromString(json['type'] as String? ?? 'manual'),
      config: json['config'] as Map<String, dynamic>? ?? {},
      condition: json['condition'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (config.isNotEmpty) 'config': config,
        if (condition != null) 'condition': condition,
      };
}

/// Types of skill triggers.
enum TriggerType {
  /// Manual invocation.
  manual,

  /// Scheduled execution.
  schedule,

  /// Event-based trigger.
  event,

  /// Webhook trigger.
  webhook,

  /// Message trigger.
  message,

  /// Unknown trigger.
  unknown;

  static TriggerType fromString(String value) {
    return TriggerType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TriggerType.unknown,
    );
  }
}
