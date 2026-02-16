/// FactGraph Port - Abstract interface for FactGraph integration.
///
/// Defines contracts for FactGraph operations in skill execution.
/// This is an optional port for skills that need to interact with
/// the fact graph for context, validation, and recording.
library;

/// Port for FactGraph integration (optional).
abstract class FactGraphPort {
  /// Build a context bundle from the graph.
  Future<ContextBundle> buildContextBundle(ContextBundleRequest request);

  /// Validate claims against the fact graph.
  Future<ClaimValidationResult> validateClaims(
    List<Claim> claims, {
    DateTime? asOf,
    String? policyVersion,
  });

  /// Write a skill run record.
  Future<void> writeSkillRun(SkillRunRecord record);

  /// Write claims with evidence links.
  Future<void> writeClaims(List<Claim> claims, List<String> evidenceRefs);

  /// Query facts from the graph.
  Future<List<Fact>> queryFacts(FactQuery query);

  /// Get entity by ID.
  Future<Entity?> getEntity(String entityId);
}

/// Context bundle request.
class ContextBundleRequest {
  /// Query for context retrieval.
  final String query;

  /// Workspace identifier.
  final String workspaceId;

  /// Point in time for the query.
  final DateTime? asOf;

  /// Time period filter.
  final Period? period;

  /// Policy version for filtering.
  final String? policyVersion;

  /// Context budget constraints.
  final ContextBudget? budget;

  const ContextBundleRequest({
    required this.query,
    required this.workspaceId,
    this.asOf,
    this.period,
    this.policyVersion,
    this.budget,
  });

  factory ContextBundleRequest.fromJson(Map<String, dynamic> json) {
    return ContextBundleRequest(
      query: json['query'] as String,
      workspaceId: json['workspaceId'] as String,
      asOf: json['asOf'] != null ? DateTime.parse(json['asOf'] as String) : null,
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      policyVersion: json['policyVersion'] as String?,
      budget: json['budget'] != null
          ? ContextBudget.fromJson(json['budget'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'query': query,
        'workspaceId': workspaceId,
        if (asOf != null) 'asOf': asOf!.toIso8601String(),
        if (period != null) 'period': period!.toJson(),
        if (policyVersion != null) 'policyVersion': policyVersion,
        if (budget != null) 'budget': budget!.toJson(),
      };
}

/// Context budget constraints.
class ContextBudget {
  /// Maximum number of nodes.
  final int? maxNodes;

  /// Maximum number of tokens.
  final int? maxTokens;

  /// Maximum number of sentences.
  final int? maxSentences;

  const ContextBudget({
    this.maxNodes,
    this.maxTokens,
    this.maxSentences,
  });

  factory ContextBudget.fromJson(Map<String, dynamic> json) {
    return ContextBudget(
      maxNodes: json['maxNodes'] as int?,
      maxTokens: json['maxTokens'] as int?,
      maxSentences: json['maxSentences'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (maxNodes != null) 'maxNodes': maxNodes,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (maxSentences != null) 'maxSentences': maxSentences,
      };
}

/// Time period.
class Period {
  /// Period unit: "hours", "days", "weeks", "months".
  final String unit;

  /// Period value.
  final int value;

  /// Start date for absolute periods.
  final DateTime? start;

  /// End date for absolute periods.
  final DateTime? end;

  const Period({
    required this.unit,
    required this.value,
    this.start,
    this.end,
  });

  /// Create a relative period.
  factory Period.relative(String unit, int value) {
    return Period(unit: unit, value: value);
  }

  /// Create an absolute date range.
  factory Period.range(DateTime start, DateTime end) {
    return Period(unit: 'range', value: 0, start: start, end: end);
  }

  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      unit: json['unit'] as String,
      value: json['value'] as int,
      start:
          json['start'] != null ? DateTime.parse(json['start'] as String) : null,
      end: json['end'] != null ? DateTime.parse(json['end'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'unit': unit,
        'value': value,
        if (start != null) 'start': start!.toIso8601String(),
        if (end != null) 'end': end!.toIso8601String(),
      };
}

/// Built context bundle.
class ContextBundle {
  /// Facts included in the bundle.
  final List<dynamic> facts;

  /// Summaries included in the bundle.
  final List<dynamic> summaries;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Open questions.
  final List<dynamic> openQuestions;

  /// Estimated token count.
  final int tokenEstimate;

  /// Point in time for the bundle.
  final DateTime asOf;

  /// Policy version used.
  final String? policyVersion;

  const ContextBundle({
    required this.facts,
    required this.summaries,
    required this.evidenceRefs,
    required this.openQuestions,
    required this.tokenEstimate,
    required this.asOf,
    this.policyVersion,
  });

  factory ContextBundle.fromJson(Map<String, dynamic> json) {
    return ContextBundle(
      facts: json['facts'] as List<dynamic>,
      summaries: json['summaries'] as List<dynamic>,
      evidenceRefs: (json['evidenceRefs'] as List<dynamic>).cast<String>(),
      openQuestions: json['openQuestions'] as List<dynamic>,
      tokenEstimate: json['tokenEstimate'] as int,
      asOf: DateTime.parse(json['asOf'] as String),
      policyVersion: json['policyVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'facts': facts,
        'summaries': summaries,
        'evidenceRefs': evidenceRefs,
        'openQuestions': openQuestions,
        'tokenEstimate': tokenEstimate,
        'asOf': asOf.toIso8601String(),
        if (policyVersion != null) 'policyVersion': policyVersion,
      };
}

/// Claim extracted from LLM response.
class Claim {
  /// Claim identifier.
  final String id;

  /// Claim content.
  final String content;

  /// Claim type: "assertion", "question", "action".
  final String claimType;

  /// Confidence score.
  final double confidence;

  /// Evidence references.
  final List<String> evidenceRefs;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const Claim({
    required this.id,
    required this.content,
    required this.claimType,
    required this.confidence,
    required this.evidenceRefs,
    this.metadata,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'] as String,
      content: json['content'] as String,
      claimType: json['claimType'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      evidenceRefs: (json['evidenceRefs'] as List<dynamic>).cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'claimType': claimType,
        'confidence': confidence,
        'evidenceRefs': evidenceRefs,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Claim validation result.
class ClaimValidationResult {
  /// Whether all claims passed validation.
  final bool passed;

  /// Status for each claim.
  final List<ClaimStatus> claimStatuses;

  /// Validation issues found.
  final List<ValidationIssue> issues;

  const ClaimValidationResult({
    required this.passed,
    required this.claimStatuses,
    required this.issues,
  });

  factory ClaimValidationResult.fromJson(Map<String, dynamic> json) {
    return ClaimValidationResult(
      passed: json['passed'] as bool,
      claimStatuses: (json['claimStatuses'] as List<dynamic>)
          .map((e) => ClaimStatus.fromJson(e as Map<String, dynamic>))
          .toList(),
      issues: (json['issues'] as List<dynamic>)
          .map((e) => ValidationIssue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'claimStatuses': claimStatuses.map((s) => s.toJson()).toList(),
        'issues': issues.map((i) => i.toJson()).toList(),
      };
}

/// Claim validation status.
class ClaimStatus {
  /// Claim identifier.
  final String claimId;

  /// Status: "supported", "unsupported", "conflicting".
  final String status;

  /// Supporting evidence references.
  final List<String> supportingRefs;

  /// Conflict reason if applicable.
  final String? conflictReason;

  const ClaimStatus({
    required this.claimId,
    required this.status,
    required this.supportingRefs,
    this.conflictReason,
  });

  factory ClaimStatus.fromJson(Map<String, dynamic> json) {
    return ClaimStatus(
      claimId: json['claimId'] as String,
      status: json['status'] as String,
      supportingRefs: (json['supportingRefs'] as List<dynamic>).cast<String>(),
      conflictReason: json['conflictReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'claimId': claimId,
        'status': status,
        'supportingRefs': supportingRefs,
        if (conflictReason != null) 'conflictReason': conflictReason,
      };
}

/// Validation issue.
class ValidationIssue {
  /// Issue type.
  final String type;

  /// Severity: "error", "warning", "info".
  final String severity;

  /// Issue description.
  final String description;

  /// Related claim IDs.
  final List<String> relatedClaimIds;

  const ValidationIssue({
    required this.type,
    required this.severity,
    required this.description,
    required this.relatedClaimIds,
  });

  factory ValidationIssue.fromJson(Map<String, dynamic> json) {
    return ValidationIssue(
      type: json['type'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String,
      relatedClaimIds: (json['relatedClaimIds'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'severity': severity,
        'description': description,
        'relatedClaimIds': relatedClaimIds,
      };
}

/// Skill run record.
class SkillRunRecord {
  /// Skill identifier.
  final String skillId;

  /// Skill version.
  final String skillVersion;

  /// Procedure identifier.
  final String procedureId;

  /// Start time.
  final DateTime startedAt;

  /// Finish time.
  final DateTime? finishedAt;

  /// Run status.
  final String status;

  /// Input values.
  final Map<String, dynamic> inputs;

  /// Output values.
  final Map<String, dynamic>? outputs;

  /// Claim IDs generated.
  final List<String> claimIds;

  /// Evidence references used.
  final List<String> evidenceRefs;

  const SkillRunRecord({
    required this.skillId,
    required this.skillVersion,
    required this.procedureId,
    required this.startedAt,
    this.finishedAt,
    required this.status,
    required this.inputs,
    this.outputs,
    required this.claimIds,
    required this.evidenceRefs,
  });

  factory SkillRunRecord.fromJson(Map<String, dynamic> json) {
    return SkillRunRecord(
      skillId: json['skillId'] as String,
      skillVersion: json['skillVersion'] as String,
      procedureId: json['procedureId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
      status: json['status'] as String,
      inputs: json['inputs'] as Map<String, dynamic>,
      outputs: json['outputs'] as Map<String, dynamic>?,
      claimIds: (json['claimIds'] as List<dynamic>).cast<String>(),
      evidenceRefs: (json['evidenceRefs'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'skillId': skillId,
        'skillVersion': skillVersion,
        'procedureId': procedureId,
        'startedAt': startedAt.toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
        'status': status,
        'inputs': inputs,
        if (outputs != null) 'outputs': outputs,
        'claimIds': claimIds,
        'evidenceRefs': evidenceRefs,
      };
}

/// Fact from the graph.
class Fact {
  /// Fact identifier.
  final String id;

  /// Fact type.
  final String type;

  /// Fact content.
  final Map<String, dynamic> content;

  /// Creation time.
  final DateTime createdAt;

  /// Confidence score.
  final double? confidence;

  /// Evidence references.
  final List<String> evidenceRefs;

  const Fact({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    this.confidence,
    required this.evidenceRefs,
  });

  factory Fact.fromJson(Map<String, dynamic> json) {
    return Fact(
      id: json['id'] as String,
      type: json['type'] as String,
      content: json['content'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      confidence: (json['confidence'] as num?)?.toDouble(),
      evidenceRefs: (json['evidenceRefs'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (confidence != null) 'confidence': confidence,
        'evidenceRefs': evidenceRefs,
      };
}

/// Fact query.
class FactQuery {
  /// Fact types to query.
  final List<String>? types;

  /// Time period.
  final Period? period;

  /// Point in time.
  final DateTime? asOf;

  /// Entity ID filter.
  final String? entityId;

  /// Maximum results.
  final int? limit;

  /// Additional filters.
  final Map<String, dynamic>? filters;

  const FactQuery({
    this.types,
    this.period,
    this.asOf,
    this.entityId,
    this.limit,
    this.filters,
  });

  factory FactQuery.fromJson(Map<String, dynamic> json) {
    return FactQuery(
      types: (json['types'] as List<dynamic>?)?.cast<String>(),
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      asOf: json['asOf'] != null ? DateTime.parse(json['asOf'] as String) : null,
      entityId: json['entityId'] as String?,
      limit: json['limit'] as int?,
      filters: json['filters'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (types != null) 'types': types,
        if (period != null) 'period': period!.toJson(),
        if (asOf != null) 'asOf': asOf!.toIso8601String(),
        if (entityId != null) 'entityId': entityId,
        if (limit != null) 'limit': limit,
        if (filters != null) 'filters': filters,
      };
}

/// Entity from the graph.
class Entity {
  /// Entity identifier.
  final String id;

  /// Entity type.
  final String type;

  /// Entity name.
  final String name;

  /// Entity properties.
  final Map<String, dynamic> properties;

  /// Creation time.
  final DateTime createdAt;

  /// Last update time.
  final DateTime? updatedAt;

  const Entity({
    required this.id,
    required this.type,
    required this.name,
    required this.properties,
    required this.createdAt,
    this.updatedAt,
  });

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      properties: json['properties'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        'properties': properties,
        'createdAt': createdAt.toIso8601String(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

/// Stub FactGraph port that throws on use.
class StubFactGraphPort implements FactGraphPort {
  const StubFactGraphPort();

  @override
  Future<ContextBundle> buildContextBundle(ContextBundleRequest request) {
    throw UnimplementedError('FactGraphPort not configured');
  }

  @override
  Future<ClaimValidationResult> validateClaims(
    List<Claim> claims, {
    DateTime? asOf,
    String? policyVersion,
  }) {
    throw UnimplementedError('FactGraphPort not configured');
  }

  @override
  Future<void> writeSkillRun(SkillRunRecord record) {
    throw UnimplementedError('FactGraphPort not configured');
  }

  @override
  Future<void> writeClaims(List<Claim> claims, List<String> evidenceRefs) {
    throw UnimplementedError('FactGraphPort not configured');
  }

  @override
  Future<List<Fact>> queryFacts(FactQuery query) {
    throw UnimplementedError('FactGraphPort not configured');
  }

  @override
  Future<Entity?> getEntity(String entityId) {
    throw UnimplementedError('FactGraphPort not configured');
  }
}
