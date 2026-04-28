library;

/// Configuration for FactGraph persistence behavior.
class PersistenceConfig {
  /// Whether to persist claims.
  final bool persistClaims;
  /// Whether to link evidence.
  final bool linkEvidence;
  /// Whether to record evaluation runs.
  final bool recordEvaluation;
  /// Whether to emit claim signals.
  final bool emitSignals;
  
  const PersistenceConfig({this.persistClaims = true, this.linkEvidence = true, this.recordEvaluation = true, this.emitSignals = false});
  
  static const PersistenceConfig defaultConfig = PersistenceConfig();
  static const PersistenceConfig minimal = PersistenceConfig(linkEvidence: false, recordEvaluation: false);
}

/// Result of a persistence operation.
class PersistenceResult {
  final bool success;
  final String? runId;
  final int claimsPersisted;
  final int evidenceLinked;
  final String? error;
  
  const PersistenceResult({required this.success, this.runId, this.claimsPersisted = 0, this.evidenceLinked = 0, this.error});
  
  factory PersistenceResult.success({required String runId, int claimsPersisted = 0, int evidenceLinked = 0}) => PersistenceResult(success: true, runId: runId, claimsPersisted: claimsPersisted, evidenceLinked: evidenceLinked);
  factory PersistenceResult.failure(String error) => PersistenceResult(success: false, error: error);
  
  Map<String, dynamic> toJson() => {'success': success, if (runId != null) 'runId': runId, 'claimsPersisted': claimsPersisted, 'evidenceLinked': evidenceLinked, if (error != null) 'error': error};
}

/// Query parameters for retrieving skill results.
class SkillResultQuery {
  final String? skillId;
  final String? version;
  final String? workspaceId;
  final DateTime? from;
  final DateTime? to;
  final List<String>? claimTypes;
  final double? minConfidence;
  final int? limit;
  final int? offset;
  
  const SkillResultQuery({this.skillId, this.version, this.workspaceId, this.from, this.to, this.claimTypes, this.minConfidence, this.limit, this.offset});
  
  Map<String, dynamic> toJson() => {if (skillId != null) 'skillId': skillId, if (version != null) 'version': version, if (workspaceId != null) 'workspaceId': workspaceId, if (from != null) 'from': from!.toIso8601String(), if (to != null) 'to': to!.toIso8601String(), if (claimTypes != null) 'claimTypes': claimTypes, if (minConfidence != null) 'minConfidence': minConfidence, if (limit != null) 'limit': limit, if (offset != null) 'offset': offset};
}

/// A skill run with its associated claims.
class SkillRunWithClaims {
  final String runId;
  final String skillId;
  final String workspaceId;
  final DateTime startedAt;
  final DateTime completedAt;
  final String status;
  final List<dynamic> claims;
  final Map<String, dynamic>? metadata;
  
  const SkillRunWithClaims({required this.runId, required this.skillId, required this.workspaceId, required this.startedAt, required this.completedAt, required this.status, this.claims = const [], this.metadata});
}

/// An edge in the FactGraph connecting entities.
class GraphEdge {
  final String fromId;
  final String toId;
  final EdgeType type;
  final Map<String, dynamic>? metadata;
  
  const GraphEdge({required this.fromId, required this.toId, required this.type, this.metadata});
  
  Map<String, dynamic> toJson() => {'fromId': fromId, 'toId': toId, 'type': type.name, if (metadata != null) 'metadata': metadata};
}

/// Types of edges in the FactGraph.
enum EdgeType { producedBy, supports, refutes, relatedTo, derivedFrom }

/// Validation mode for claims.
enum ClaimValidationMode { strict, lenient, disabled }
