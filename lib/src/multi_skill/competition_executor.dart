/// Competition Executor - Parallel execution with best result selection.
library;

import '../runtime/skill_context.dart';
import '../runtime/skill_result.dart';
import '../registry/skill_registry.dart';
import '../runtime/procedure_executor.dart';
import '../ports/skill_ports.dart';
import 'multi_skill_types.dart';
import 'multi_skill_result.dart';

/// Executes skills in parallel and selects the best result.
class CompetitionExecutor {
  final SkillBundleRegistry _registry;
  final SkillPorts _ports;

  CompetitionExecutor({
    required SkillBundleRegistry registry,
    required SkillPorts ports,
  })  : _registry = registry,
        _ports = ports;

  /// Execute all skills in competition and select the winner.
  Future<CompetitionResult> execute(
    MultiSkillConfig config,
    SkillContext context,
  ) async {
    final startTime = DateTime.now();

    final futures = config.skills.map((skillRef) {
      return _executeSkill(skillRef, context);
    });

    final entries = await Future.wait(futures);

    // Score each result
    final criteria =
        config.competitionConfig?.criteria ?? SelectionCriteria.highestConfidence;
    final outcomes = <CompetitorOutcome>[];
    String? winnerId;
    double bestScore = double.negativeInfinity;

    for (final entry in entries) {
      final score = _scoreResult(entry.result, criteria);
      final isCurrentBest = score > bestScore;

      if (isCurrentBest && entry.result != null) {
        bestScore = score;
        winnerId = entry.skillId;
      }

      outcomes.add(CompetitorOutcome(
        skillId: entry.skillId,
        result: entry.result,
        score: score,
        isWinner: false,
        error: entry.error,
      ));
    }

    // Mark winner
    final finalOutcomes = outcomes.map((o) {
      if (o.skillId == winnerId) {
        return CompetitorOutcome(
          skillId: o.skillId,
          result: o.result,
          score: o.score,
          isWinner: true,
          error: o.error,
        );
      }
      return o;
    }).toList();

    final winnerResult = entries
        .where((e) => e.skillId == winnerId && e.result != null)
        .map((e) => e.result!)
        .firstOrNull;

    return CompetitionResult(
      result: winnerResult ?? SkillResult.empty(),
      individualResults:
          entries.where((e) => e.result != null).map((e) => e.result!).toList(),
      totalDuration: DateTime.now().difference(startTime),
      winnerId: winnerId ?? '',
      outcomes: finalOutcomes,
    );
  }

  Future<_CompetitorEntry> _executeSkill(
    SkillRef skillRef,
    SkillContext context,
  ) async {
    try {
      final bundle = await _registry.getSkill(skillRef.skillId);
      if (bundle == null) {
        return _CompetitorEntry(
          skillId: skillRef.skillId,
          error: 'Skill not found',
        );
      }

      final defProc = bundle.procedures.firstOrNull;
      if (defProc == null) {
        return _CompetitorEntry(
          skillId: skillRef.skillId,
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

      return _CompetitorEntry(
        skillId: skillRef.skillId,
        result: result,
      );
    } catch (e) {
      return _CompetitorEntry(
        skillId: skillRef.skillId,
        error: e.toString(),
      );
    }
  }

  double _scoreResult(SkillResult? result, SelectionCriteria criteria) {
    if (result == null || !result.isSuccess) return -1.0;

    return switch (criteria) {
      SelectionCriteria.highestConfidence => result.confidence,
      SelectionCriteria.mostEvidence => result.evidenceRefs.length.toDouble(),
      SelectionCriteria.rubricScore => result.confidence,
      SelectionCriteria.custom => result.confidence,
    };
  }
}

class _CompetitorEntry {
  final String skillId;
  final SkillResult? result;
  final String? error;

  _CompetitorEntry({required this.skillId, this.result, this.error});
}

extension _ListFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
