/// Skill Result - Standard result types for skill execution.
///
/// Provides result types including claims, actions, evidence references,
/// rubric scores, and execution metadata.
library;

import '../ports/llm_port.dart';

/// Standard result from skill execution.
class SkillResult {
  /// Claims/conclusions from the skill.
  final List<Claim> claims;

  /// Actions to take.
  final List<SkillAction>? actions;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Rubric scores (if evaluated).
  final List<RubricScore>? rubricScores;

  /// Conflicts detected.
  final List<Conflict>? conflicts;

  /// Overall confidence.
  final double confidence;

  /// Point-in-time.
  final DateTime asOf;

  /// Policy version used.
  final String? policyVersion;

  /// UI to display (mcp_ui_dsl).
  final Map<String, dynamic>? ui;

  /// Generated artifacts.
  final List<Artifact>? artifacts;

  /// Execution metadata.
  final ExecutionMetadata metadata;

  const SkillResult({
    required this.claims,
    this.actions,
    required this.evidenceRefs,
    this.rubricScores,
    this.conflicts,
    required this.confidence,
    required this.asOf,
    this.policyVersion,
    this.ui,
    this.artifacts,
    required this.metadata,
  });

  /// Create a success result.
  factory SkillResult.success({
    required List<Claim> claims,
    required List<String> evidenceRefs,
    required ExecutionMetadata metadata,
    List<SkillAction>? actions,
    List<RubricScore>? rubricScores,
    double confidence = 1.0,
    DateTime? asOf,
    String? policyVersion,
    Map<String, dynamic>? ui,
    List<Artifact>? artifacts,
  }) {
    return SkillResult(
      claims: claims,
      evidenceRefs: evidenceRefs,
      metadata: metadata,
      actions: actions,
      rubricScores: rubricScores,
      confidence: confidence,
      asOf: asOf ?? DateTime.now(),
      policyVersion: policyVersion,
      ui: ui,
      artifacts: artifacts,
    );
  }

  /// Create an error result.
  factory SkillResult.error({
    required String error,
    required ExecutionMetadata metadata,
    DateTime? asOf,
  }) {
    return SkillResult(
      claims: [
        Claim(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          type: ClaimType.conclusion,
          text: error,
          evidenceRefs: const [],
          confidence: 1.0,
        ),
      ],
      evidenceRefs: const [],
      confidence: 0.0,
      asOf: asOf ?? DateTime.now(),
      metadata: metadata,
    );
  }

  /// Create from JSON.
  factory SkillResult.fromJson(Map<String, dynamic> json) {
    return SkillResult(
      claims: (json['claims'] as List<dynamic>?)
              ?.map((e) => Claim.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      actions: (json['actions'] as List<dynamic>?)
          ?.map((e) => SkillAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      evidenceRefs:
          (json['evidenceRefs'] as List<dynamic>?)?.cast<String>() ?? [],
      rubricScores: (json['rubricScores'] as List<dynamic>?)
          ?.map((e) => RubricScore.fromJson(e as Map<String, dynamic>))
          .toList(),
      conflicts: (json['conflicts'] as List<dynamic>?)
          ?.map((e) => Conflict.fromJson(e as Map<String, dynamic>))
          .toList(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      asOf: json['asOf'] != null
          ? DateTime.parse(json['asOf'] as String)
          : DateTime.now(),
      policyVersion: json['policyVersion'] as String?,
      ui: json['ui'] as Map<String, dynamic>?,
      artifacts: (json['artifacts'] as List<dynamic>?)
          ?.map((e) => Artifact.fromJson(e as Map<String, dynamic>))
          .toList(),
      metadata:
          ExecutionMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'claims': claims.map((e) => e.toJson()).toList(),
        if (actions != null) 'actions': actions!.map((e) => e.toJson()).toList(),
        'evidenceRefs': evidenceRefs,
        if (rubricScores != null)
          'rubricScores': rubricScores!.map((e) => e.toJson()).toList(),
        if (conflicts != null)
          'conflicts': conflicts!.map((e) => e.toJson()).toList(),
        'confidence': confidence,
        'asOf': asOf.toIso8601String(),
        if (policyVersion != null) 'policyVersion': policyVersion,
        if (ui != null) 'ui': ui,
        if (artifacts != null)
          'artifacts': artifacts!.map((e) => e.toJson()).toList(),
        'metadata': metadata.toJson(),
      };

  /// Check if result represents success.
  bool get isSuccess => confidence > 0;

  /// Get primary claim text.
  String? get primaryClaimText => claims.isNotEmpty ? claims.first.text : null;

  @override
  String toString() =>
      'SkillResult(claims: ${claims.length}, confidence: $confidence, evidenceRefs: ${evidenceRefs.length})';
}

/// Claim from skill execution.
class Claim {
  /// Claim ID.
  final String id;

  /// Claim type.
  final ClaimType type;

  /// Claim text.
  final String text;

  /// Claim value (structured data).
  final dynamic value;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Confidence score (0-1).
  final double confidence;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const Claim({
    required this.id,
    required this.type,
    required this.text,
    this.value,
    required this.evidenceRefs,
    required this.confidence,
    this.metadata,
  });

  /// Create from JSON.
  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'] as String? ?? '',
      type: ClaimType.fromString(json['type'] as String? ?? 'fact'),
      text: json['text'] as String? ?? '',
      value: json['value'],
      evidenceRefs:
          (json['evidenceRefs'] as List<dynamic>?)?.cast<String>() ?? [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'text': text,
        if (value != null) 'value': value,
        'evidenceRefs': evidenceRefs,
        'confidence': confidence,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() =>
      'Claim(id: $id, type: ${type.name}, confidence: $confidence)';
}

/// Types of claims.
enum ClaimType {
  /// Factual assertion.
  fact,

  /// Logical conclusion.
  conclusion,

  /// Observation.
  observation,

  /// Prediction about the future.
  prediction,

  /// Recommendation for action.
  recommendation,

  /// Speculative statement.
  speculation;

  static ClaimType fromString(String value) {
    return ClaimType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ClaimType.fact,
    );
  }
}

/// Action from skill execution.
class SkillAction {
  /// Action type.
  final String type;

  /// Action description.
  final String description;

  /// Tool reference.
  final String? toolRef;

  /// Action arguments.
  final Map<String, dynamic>? args;

  /// Action status.
  final ActionStatus status;

  /// Result of the action (if executed).
  final dynamic result;

  /// Error message (if failed).
  final String? error;

  const SkillAction({
    required this.type,
    required this.description,
    this.toolRef,
    this.args,
    required this.status,
    this.result,
    this.error,
  });

  /// Create a pending action.
  factory SkillAction.pending({
    required String type,
    required String description,
    String? toolRef,
    Map<String, dynamic>? args,
  }) {
    return SkillAction(
      type: type,
      description: description,
      toolRef: toolRef,
      args: args,
      status: ActionStatus.pending,
    );
  }

  /// Create from JSON.
  factory SkillAction.fromJson(Map<String, dynamic> json) {
    return SkillAction(
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      toolRef: json['toolRef'] as String?,
      args: json['args'] as Map<String, dynamic>?,
      status: ActionStatus.fromString(json['status'] as String? ?? 'pending'),
      result: json['result'],
      error: json['error'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        if (toolRef != null) 'toolRef': toolRef,
        if (args != null) 'args': args,
        'status': status.name,
        if (result != null) 'result': result,
        if (error != null) 'error': error,
      };

  /// Create a copy with updated status.
  SkillAction copyWithStatus(ActionStatus newStatus, {dynamic result, String? error}) {
    return SkillAction(
      type: type,
      description: description,
      toolRef: toolRef,
      args: args,
      status: newStatus,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }

  @override
  String toString() => 'SkillAction(type: $type, status: ${status.name})';
}

/// Action execution status.
enum ActionStatus {
  /// Action is pending.
  pending,

  /// Action was executed successfully.
  executed,

  /// Action failed.
  failed,

  /// Action was skipped.
  skipped;

  static ActionStatus fromString(String value) {
    return ActionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ActionStatus.pending,
    );
  }
}

/// Rubric score from evaluation.
class RubricScore {
  /// Rubric ID.
  final String rubricId;

  /// Dimension scores.
  final Map<String, double> dimensionScores;

  /// Total/aggregate score.
  final double totalScore;

  /// Grade/classification.
  final String grade;

  /// Findings from evaluation.
  final List<Finding>? findings;

  const RubricScore({
    required this.rubricId,
    required this.dimensionScores,
    required this.totalScore,
    required this.grade,
    this.findings,
  });

  /// Create from JSON.
  factory RubricScore.fromJson(Map<String, dynamic> json) {
    return RubricScore(
      rubricId: json['rubricId'] as String? ?? '',
      dimensionScores: (json['dimensionScores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},
      totalScore: (json['totalScore'] as num?)?.toDouble() ?? 0.0,
      grade: json['grade'] as String? ?? '',
      findings: (json['findings'] as List<dynamic>?)
          ?.map((e) => Finding.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'rubricId': rubricId,
        'dimensionScores': dimensionScores,
        'totalScore': totalScore,
        'grade': grade,
        if (findings != null)
          'findings': findings!.map((e) => e.toJson()).toList(),
      };

  /// Check if evaluation passed.
  bool get passed => totalScore >= 60;

  @override
  String toString() =>
      'RubricScore(rubricId: $rubricId, totalScore: $totalScore, grade: $grade)';
}

/// Finding from rubric evaluation.
class Finding {
  /// Finding type (strength, weakness, suggestion).
  final String type;

  /// Dimension ID.
  final String dimensionId;

  /// Description.
  final String description;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Impact score (0-1).
  final double? impact;

  const Finding({
    required this.type,
    required this.dimensionId,
    required this.description,
    this.evidenceRefs = const [],
    this.impact,
  });

  /// Create from JSON.
  factory Finding.fromJson(Map<String, dynamic> json) {
    return Finding(
      type: json['type'] as String? ?? '',
      dimensionId: json['dimensionId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      evidenceRefs:
          (json['evidenceRefs'] as List<dynamic>?)?.cast<String>() ?? [],
      impact: (json['impact'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        'dimensionId': dimensionId,
        'description': description,
        if (evidenceRefs.isNotEmpty) 'evidenceRefs': evidenceRefs,
        if (impact != null) 'impact': impact,
      };
}

/// Conflict detected during execution.
class Conflict {
  /// Conflict ID.
  final String id;

  /// Conflict type.
  final String type;

  /// Description.
  final String description;

  /// Conflicting claim IDs.
  final List<String> claimIds;

  /// Severity (low, medium, high).
  final String severity;

  /// Resolution (if any).
  final String? resolution;

  const Conflict({
    required this.id,
    required this.type,
    required this.description,
    required this.claimIds,
    required this.severity,
    this.resolution,
  });

  /// Create from JSON.
  factory Conflict.fromJson(Map<String, dynamic> json) {
    return Conflict(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      claimIds: (json['claimIds'] as List<dynamic>?)?.cast<String>() ?? [],
      severity: json['severity'] as String? ?? 'medium',
      resolution: json['resolution'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'description': description,
        'claimIds': claimIds,
        'severity': severity,
        if (resolution != null) 'resolution': resolution,
      };
}

/// Generated artifact from skill execution.
class Artifact {
  /// Artifact ID.
  final String id;

  /// Artifact type.
  final String type;

  /// Content (could be string, bytes ref, etc).
  final dynamic content;

  /// MIME type.
  final String? mimeType;

  /// File name.
  final String? fileName;

  /// Metadata.
  final Map<String, dynamic>? metadata;

  const Artifact({
    required this.id,
    required this.type,
    required this.content,
    this.mimeType,
    this.fileName,
    this.metadata,
  });

  /// Create from JSON.
  factory Artifact.fromJson(Map<String, dynamic> json) {
    return Artifact(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      content: json['content'],
      mimeType: json['mimeType'] as String?,
      fileName: json['fileName'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
        if (mimeType != null) 'mimeType': mimeType,
        if (fileName != null) 'fileName': fileName,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Execution metadata.
class ExecutionMetadata {
  /// Skill ID.
  final String skillId;

  /// Skill version.
  final String skillVersion;

  /// Procedure ID.
  final String procedureId;

  /// When execution started.
  final DateTime startedAt;

  /// When execution finished.
  final DateTime finishedAt;

  /// Total duration.
  final Duration duration;

  /// Number of steps executed.
  final int stepsExecuted;

  /// LLM usage statistics.
  final LlmUsage? llmUsage;

  /// Tools called during execution.
  final List<String> toolsCalled;

  /// Custom metadata.
  final Map<String, dynamic>? custom;

  const ExecutionMetadata({
    required this.skillId,
    required this.skillVersion,
    required this.procedureId,
    required this.startedAt,
    required this.finishedAt,
    required this.duration,
    required this.stepsExecuted,
    this.llmUsage,
    required this.toolsCalled,
    this.custom,
  });

  /// Create with computed duration.
  factory ExecutionMetadata.create({
    required String skillId,
    required String skillVersion,
    required String procedureId,
    required DateTime startedAt,
    DateTime? finishedAt,
    required int stepsExecuted,
    LlmUsage? llmUsage,
    List<String>? toolsCalled,
    Map<String, dynamic>? custom,
  }) {
    final finished = finishedAt ?? DateTime.now();
    return ExecutionMetadata(
      skillId: skillId,
      skillVersion: skillVersion,
      procedureId: procedureId,
      startedAt: startedAt,
      finishedAt: finished,
      duration: finished.difference(startedAt),
      stepsExecuted: stepsExecuted,
      llmUsage: llmUsage,
      toolsCalled: toolsCalled ?? [],
      custom: custom,
    );
  }

  /// Create from JSON.
  factory ExecutionMetadata.fromJson(Map<String, dynamic> json) {
    return ExecutionMetadata(
      skillId: json['skillId'] as String? ?? '',
      skillVersion: json['skillVersion'] as String? ?? '',
      procedureId: json['procedureId'] as String? ?? '',
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : DateTime.now(),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      stepsExecuted: json['stepsExecuted'] as int? ?? 0,
      llmUsage: json['llmUsage'] != null
          ? LlmUsage.fromJson(json['llmUsage'] as Map<String, dynamic>)
          : null,
      toolsCalled:
          (json['toolsCalled'] as List<dynamic>?)?.cast<String>() ?? [],
      custom: json['custom'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'skillVersion': skillVersion,
        'procedureId': procedureId,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt.toIso8601String(),
        'durationMs': duration.inMilliseconds,
        'stepsExecuted': stepsExecuted,
        if (llmUsage != null) 'llmUsage': llmUsage!.toJson(),
        'toolsCalled': toolsCalled,
        if (custom != null) 'custom': custom,
      };

  @override
  String toString() =>
      'ExecutionMetadata(skillId: $skillId, duration: $duration, steps: $stepsExecuted)';
}

/// Result from a single step execution.
class StepResult {
  /// Step ID.
  final String stepId;

  /// Step result value.
  final dynamic result;

  /// Claims from this step.
  final List<Claim> claims;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Tool called (if any).
  final String? toolCalled;

  /// Step metadata.
  final Map<String, dynamic>? metadata;

  const StepResult({
    required this.stepId,
    required this.result,
    this.claims = const [],
    this.evidenceRefs = const [],
    this.toolCalled,
    this.metadata,
  });

  /// Create from JSON.
  factory StepResult.fromJson(Map<String, dynamic> json) {
    return StepResult(
      stepId: json['stepId'] as String? ?? '',
      result: json['result'],
      claims: (json['claims'] as List<dynamic>?)
              ?.map((e) => Claim.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      evidenceRefs:
          (json['evidenceRefs'] as List<dynamic>?)?.cast<String>() ?? [],
      toolCalled: json['toolCalled'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'stepId': stepId,
        'result': result,
        if (claims.isNotEmpty)
          'claims': claims.map((e) => e.toJson()).toList(),
        if (evidenceRefs.isNotEmpty) 'evidenceRefs': evidenceRefs,
        if (toolCalled != null) 'toolCalled': toolCalled,
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() =>
      'StepResult(stepId: $stepId, claims: ${claims.length}, evidenceRefs: ${evidenceRefs.length})';
}
