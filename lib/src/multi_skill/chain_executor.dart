/// Chain Executor - Sequential multi-skill execution with output mapping.
library;

import '../runtime/skill_context.dart';
import '../runtime/skill_result.dart';
import '../registry/skill_registry.dart';
import '../runtime/procedure_executor.dart';
import '../ports/skill_ports.dart';
import 'multi_skill_types.dart';
import 'multi_skill_result.dart';

/// Executes skills sequentially, passing outputs as inputs to the next skill.
class ChainExecutor {
  final SkillBundleRegistry _registry;
  final SkillPorts _ports;

  ChainExecutor({
    required SkillBundleRegistry registry,
    required SkillPorts ports,
  })  : _registry = registry,
        _ports = ports;

  /// Execute a chain of skills.
  Future<ChainResult> execute(
    MultiSkillConfig config,
    SkillContext context,
  ) async {
    final startTime = DateTime.now();
    final chainSteps = <ChainStepResult>[];
    final allResults = <SkillResult>[];
    var currentInputs = Map<String, dynamic>.from(context.inputs);

    for (final skillRef in config.skills) {
      final stepStart = DateTime.now();

      // Apply input overrides
      if (skillRef.inputOverrides != null) {
        currentInputs.addAll(skillRef.inputOverrides!);
      }

      // Get skill bundle
      final bundle = await _registry.getSkill(skillRef.skillId);
      if (bundle == null) {
        final failResult = SkillResult.failure(
          skillId: skillRef.skillId,
          error: 'Skill not found: ${skillRef.skillId}',
        );
        allResults.add(failResult);

        if (config.chainConfig?.stopOnFailure ?? true) break;
        continue;
      }

      // Get first procedure and convert to runtime format
      final defProc = bundle.procedures.firstOrNull;
      if (defProc == null) {
        final failResult = SkillResult.failure(
          skillId: skillRef.skillId,
          error: 'No procedures in skill',
        );
        allResults.add(failResult);

        if (config.chainConfig?.stopOnFailure ?? true) break;
        continue;
      }

      // Convert definition Procedure to runtime Procedure
      final procedure = Procedure.fromJson(defProc.toJson());

      // Execute
      try {
        final stepContext = context.copyWith(
          skillId: skillRef.skillId,
          inputs: currentInputs,
        );

        final executor = ProcedureExecutor(ports: _ports);
        final result = await executor.execute(procedure, stepContext);
        allResults.add(result);

        chainSteps.add(ChainStepResult(
          skillId: skillRef.skillId,
          result: result,
          duration: DateTime.now().difference(stepStart),
          inputs: currentInputs,
        ));

        // Map outputs to next inputs
        if (config.chainConfig?.outputMappings.isNotEmpty ?? false) {
          currentInputs = _applyOutputMappings(
            result,
            currentInputs,
            config.chainConfig!.outputMappings,
          );
        } else {
          currentInputs['previousResult'] = result.toJson();
        }
      } catch (e) {
        final failResult = SkillResult.failure(
          skillId: skillRef.skillId,
          error: e.toString(),
        );
        allResults.add(failResult);

        if (config.chainConfig?.stopOnFailure ?? true) break;
      }
    }

    final finalResult =
        allResults.isNotEmpty ? allResults.last : SkillResult.empty();

    return ChainResult(
      result: finalResult,
      individualResults: allResults,
      totalDuration: DateTime.now().difference(startTime),
      chainSteps: chainSteps,
    );
  }

  Map<String, dynamic> _applyOutputMappings(
    SkillResult result,
    Map<String, dynamic> currentInputs,
    List<OutputMapping> mappings,
  ) {
    final newInputs = Map<String, dynamic>.from(currentInputs);
    final resultJson = result.toJson();

    for (final mapping in mappings) {
      dynamic value = resultJson;
      for (final part in mapping.source.split('.')) {
        if (value is Map) {
          value = value[part];
        } else {
          value = null;
          break;
        }
      }
      newInputs[mapping.target] = value;
    }

    return newInputs;
  }
}

extension _ListFirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
