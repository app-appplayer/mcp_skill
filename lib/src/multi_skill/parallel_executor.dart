/// Parallel Executor - Parallel execution with result aggregation.
library;

import '../runtime/skill_context.dart';
import '../runtime/skill_result.dart';
import '../registry/skill_registry.dart';
import '../runtime/procedure_executor.dart';
import '../ports/skill_ports.dart';
import 'multi_skill_types.dart';
import 'multi_skill_result.dart';

/// Executes skills in parallel with configurable aggregation.
class ParallelExecutor {
  final SkillBundleRegistry _registry;
  final SkillPorts _ports;

  ParallelExecutor({
    required SkillBundleRegistry registry,
    required SkillPorts ports,
  })  : _registry = registry,
        _ports = ports;

  /// Execute skills in parallel and aggregate results.
  Future<ParallelResult> execute(
    MultiSkillConfig config,
    SkillContext context,
  ) async {
    final startTime = DateTime.now();
    final maxConcurrency = config.parallelConfig?.maxConcurrency ?? 5;
    final outcomes = <ParallelOutcome>[];

    // Execute with concurrency limit
    final skills = config.skills;
    for (var i = 0; i < skills.length; i += maxConcurrency) {
      final batch = skills.skip(i).take(maxConcurrency);
      final futures = batch.map((skillRef) {
        return _executeSkill(skillRef, context);
      });

      final batchResults = await Future.wait(futures);
      outcomes.addAll(batchResults);
    }

    final successCount = outcomes.where((o) => o.success).length;
    final failureCount = outcomes.where((o) => !o.success).length;
    final successResults =
        outcomes.where((o) => o.result != null).map((o) => o.result!).toList();

    // Check minimum success ratio
    final minSuccessRatio = config.parallelConfig?.minSuccessRatio ?? 0.5;
    final actualRatio =
        outcomes.isEmpty ? 0.0 : successCount / outcomes.length;

    if (actualRatio < minSuccessRatio) {
      return ParallelResult(
        result: SkillResult.failure(
          skillId: 'parallel',
          error: 'Success ratio $actualRatio below minimum $minSuccessRatio',
        ),
        individualResults: successResults,
        totalDuration: DateTime.now().difference(startTime),
        outcomes: outcomes,
        successCount: successCount,
        failureCount: failureCount,
      );
    }

    // Aggregate results
    final aggregated = _aggregate(
      successResults,
      config.parallelConfig?.aggregation ?? AggregationStrategy.mergeClaims,
    );

    return ParallelResult(
      result: aggregated,
      individualResults: successResults,
      totalDuration: DateTime.now().difference(startTime),
      outcomes: outcomes,
      successCount: successCount,
      failureCount: failureCount,
    );
  }

  Future<ParallelOutcome> _executeSkill(
    SkillRef skillRef,
    SkillContext context,
  ) async {
    final stepStart = DateTime.now();

    try {
      final bundle = await _registry.getSkill(skillRef.skillId);
      if (bundle == null) {
        return ParallelOutcome(
          skillId: skillRef.skillId,
          success: false,
          duration: DateTime.now().difference(stepStart),
          error: 'Skill not found',
        );
      }

      final defProc = bundle.procedures.firstOrNull;
      if (defProc == null) {
        return ParallelOutcome(
          skillId: skillRef.skillId,
          success: false,
          duration: DateTime.now().difference(stepStart),
          error: 'No procedures',
        );
      }

      final procedure = Procedure.fromJson(defProc.toJson());

      final skillContext = context.copyWith(
        skillId: skillRef.skillId,
        inputs: {
          ...context.inputs,
          ...?skillRef.inputOverrides,
        },
      );

      final executor = ProcedureExecutor(ports: _ports);
      final result = await executor.execute(procedure, skillContext);

      return ParallelOutcome(
        skillId: skillRef.skillId,
        result: result,
        success: result.isSuccess,
        duration: DateTime.now().difference(stepStart),
      );
    } catch (e) {
      return ParallelOutcome(
        skillId: skillRef.skillId,
        success: false,
        duration: DateTime.now().difference(stepStart),
        error: e.toString(),
      );
    }
  }

  SkillResult _aggregate(
    List<SkillResult> results,
    AggregationStrategy strategy,
  ) {
    if (results.isEmpty) return SkillResult.empty();
    if (results.length == 1) return results.first;

    return switch (strategy) {
      AggregationStrategy.mergeClaims => _mergeClaims(results),
      AggregationStrategy.unionEvidence => _mergeClaims(results),
      AggregationStrategy.weightedMerge => _weightedMerge(results),
      AggregationStrategy.custom => results.first,
    };
  }

  SkillResult _mergeClaims(List<SkillResult> results) {
    final allClaims = results.expand((r) => r.claims).toList();
    final allEvidence = results.expand((r) => r.evidenceRefs).toSet().toList();
    final avgConfidence = results.isEmpty
        ? 0.0
        : results.map((r) => r.confidence).reduce((a, b) => a + b) /
            results.length;

    return SkillResult(
      claims: allClaims,
      evidenceRefs: allEvidence,
      confidence: avgConfidence,
      asOf: results.first.asOf,
      policyVersion: results.first.policyVersion,
      metadata: results.first.metadata,
    );
  }

  SkillResult _weightedMerge(List<SkillResult> results) {
    final allClaims = results.expand((r) => r.claims).toList();

    final totalConfidence =
        results.map((r) => r.confidence).reduce((a, b) => a + b);
    final weightedConfidence =
        totalConfidence > 0 ? totalConfidence / results.length : 0.0;

    return SkillResult(
      claims: allClaims,
      evidenceRefs: results.expand((r) => r.evidenceRefs).toSet().toList(),
      confidence: weightedConfidence,
      asOf: results.first.asOf,
      policyVersion: results.first.policyVersion,
      metadata: results.first.metadata,
    );
  }
}

extension _ProcListExt<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
