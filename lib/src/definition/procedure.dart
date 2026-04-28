/// Procedure definitions - Skill execution logic.
///
/// Implements the Procedure schema as defined in docs/spec/04-execution-schema.md
library;

import 'parameter.dart';
import 'step.dart';

/// A procedure defines the execution steps of a skill.
class Procedure {
  /// Procedure identifier.
  final String id;

  /// Procedure name.
  final String name;

  /// Procedure description.
  final String? description;

  /// Procedure version.
  final String? version;

  // === INPUT/OUTPUT ===
  /// Input parameters.
  final List<Parameter>? inputs;

  /// Output parameters.
  final List<Parameter>? outputs;

  // === STEPS ===
  /// Execution steps.
  final List<Step> steps;

  // === QUALITY GATES ===
  /// Quality gates for validation.
  final List<QualityGate>? qualityGates;

  // === RETRIEVER REFS ===
  /// Default retrievers for this procedure.
  final List<String>? retrieverRefs;

  const Procedure({
    required this.id,
    required this.name,
    this.description,
    this.version,
    this.inputs,
    this.outputs,
    required this.steps,
    this.qualityGates,
    this.retrieverRefs,
  });

  /// Create from JSON.
  factory Procedure.fromJson(Map<String, dynamic> json) {
    return Procedure(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      version: json['version'] as String?,
      inputs: (json['inputs'] as List<dynamic>?)
          ?.map((e) => Parameter.fromJson(e as Map<String, dynamic>))
          .toList(),
      outputs: (json['outputs'] as List<dynamic>?)
          ?.map((e) => Parameter.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => Step.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      qualityGates: (json['qualityGates'] as List<dynamic>?)
          ?.map((e) => QualityGate.fromJson(e as Map<String, dynamic>))
          .toList(),
      retrieverRefs: (json['retrieverRefs'] as List<dynamic>?)?.cast<String>(),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
        if (version != null) 'version': version,
        if (inputs != null) 'inputs': inputs!.map((e) => e.toJson()).toList(),
        if (outputs != null)
          'outputs': outputs!.map((e) => e.toJson()).toList(),
        'steps': steps.map((e) => e.toJson()).toList(),
        if (qualityGates != null)
          'qualityGates': qualityGates!.map((e) => e.toJson()).toList(),
        if (retrieverRefs != null) 'retrieverRefs': retrieverRefs,
      };

  @override
  String toString() => 'Procedure($id: $name v${version ?? "1.0.0"})';
}

/// Quality gate for procedure validation.
class QualityGate {
  /// Gate identifier.
  final String id;

  /// Gate type (rubric, validator, threshold).
  final String type;

  /// Gate configuration.
  final Map<String, dynamic> config;

  /// Whether this gate blocks execution on failure.
  final bool blocking;

  const QualityGate({
    required this.id,
    required this.type,
    this.config = const {},
    this.blocking = true,
  });

  /// Create from JSON.
  factory QualityGate.fromJson(Map<String, dynamic> json) {
    return QualityGate(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'threshold',
      config: json['config'] as Map<String, dynamic>? ?? {},
      blocking: json['blocking'] as bool? ?? true,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (config.isNotEmpty) 'config': config,
        'blocking': blocking,
      };

  @override
  String toString() => 'QualityGate($id: $type${blocking ? " [blocking]" : ""})';
}
