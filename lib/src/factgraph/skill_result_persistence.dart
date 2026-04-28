/// Skill result persistence via capability-named ports.
///
/// Persists completed skill results by writing a [RunRecord] through
/// [RunsPort] and optional claims through [ClaimsPort]. Supersedes the
/// legacy `FactGraphPort`-based implementation removed in REDESIGN-PLAN
/// Phase 4.
library;

import 'package:mcp_bundle/mcp_bundle.dart'
    show ClaimsPort, RunsPort, RunRecord, RunStatus;

import '../runtime/skill_result.dart';
import '../runtime/skill_context.dart';
import 'persistence_types.dart';

/// Contract for persisting skill results.
abstract class SkillResultPersistenceContract {
  /// Persist a skill result.
  Future<PersistenceResult> persist(
    SkillResult result,
    SkillContext context, {
    PersistenceConfig config = PersistenceConfig.defaultConfig,
  });

  /// Retrieve skill results matching a query.
  Future<List<SkillRunWithClaims>> retrieve(SkillResultQuery query);
}

/// Default implementation of skill result persistence.
///
/// Writes runs through [RunsPort] and claims through [ClaimsPort]. Both
/// ports are optional — when absent, persistence is a no-op for that
/// channel.
class SkillResultPersistence implements SkillResultPersistenceContract {
  final RunsPort? _runsPort;
  final ClaimsPort? _claimsPort;

  SkillResultPersistence({
    RunsPort? runsPort,
    ClaimsPort? claimsPort,
  })  : _runsPort = runsPort,
        _claimsPort = claimsPort;

  @override
  Future<PersistenceResult> persist(
    SkillResult result,
    SkillContext context, {
    PersistenceConfig config = PersistenceConfig.defaultConfig,
  }) async {
    try {
      int claimsPersisted = 0;
      int evidenceLinked = 0;

      if (_runsPort != null) {
        final record = SkillRunMapper.toRunRecord(result, context);
        await _runsPort!.writeRun(record);
      }

      if (config.persistClaims &&
          result.claims.isNotEmpty &&
          _claimsPort != null) {
        await _claimsPort!.writeClaims(
          result.claims,
          evidenceRefs: result.evidenceRefs,
        );
        claimsPersisted = result.claims.length;
      }

      if (config.linkEvidence && result.evidenceRefs.isNotEmpty) {
        evidenceLinked = result.evidenceRefs.length;
      }

      return PersistenceResult.success(
        runId: context.runId,
        claimsPersisted: claimsPersisted,
        evidenceLinked: evidenceLinked,
      );
    } catch (e) {
      return PersistenceResult.failure('Persistence failed: $e');
    }
  }

  @override
  Future<List<SkillRunWithClaims>> retrieve(SkillResultQuery query) async {
    // Retrieval against the new standard ports requires a query
    // composition over RunsPort/ClaimsPort — deferred until the query
    // shape is ratified. Returning empty preserves legacy behavior.
    return [];
  }
}

/// Maps between skill-domain types and canonical run records.
class SkillRunMapper {
  /// Convert a [SkillResult] + [SkillContext] pair to a canonical
  /// [RunRecord] suitable for [RunsPort.writeRun].
  static RunRecord toRunRecord(SkillResult result, SkillContext context) {
    return RunRecord(
      id: context.runId,
      workspaceId: context.workspaceId,
      producerId: result.metadata.skillId,
      producerKind: 'skill',
      producerVersion: result.metadata.skillVersion,
      startedAt: result.metadata.startedAt,
      finishedAt: result.metadata.finishedAt,
      status: result.isSuccess ? RunStatus.completed : RunStatus.failed,
      inputs: context.inputs,
      claimIds: result.claims.map((c) => c.id).toList(),
      evidenceRefs: result.evidenceRefs,
    );
  }
}
