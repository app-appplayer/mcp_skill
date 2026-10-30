/// Conversion of a bundle skill module into a runnable skill bundle.
///
/// A bundle writes a procedure as a graph (`next[]`, `onError`) and names its
/// model step `prompt`; the runtime walks the steps once, front to back, and
/// jumps forward by `onSuccess` / `onFailure`. This is the one place that
/// turns the first into the second and the one place that refuses what the
/// runtime does not execute (bundle spec 03 §3.5.1), so a host never has to
/// guess and a procedure is never run in a different order than written.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as mb;

import '../definition/procedure.dart';
import '../exceptions/execution_exceptions.dart';
import 'skill_bundle.dart';

/// Action types a procedure step may have.
const Set<String> _stepTypes = {
  'prompt',
  'tool',
  'retrieve',
  'validate',
  'transform',
  'branch',
  'loop',
  'output',
};

/// Builds a runnable [SkillBundle] from [module].
///
/// [id] is the identifier the skill is registered under (default: the module
/// id); [provider] is used when the module names none. Throws
/// [InvalidProcedureException] naming the procedure and step for anything the
/// runtime does not execute.
SkillBundle skillBundleFromModule(
  mb.SkillModule module, {
  String? id,
  String? provider,
}) {
  final procedures = [
    for (final procedure in module.procedures)
      procedureFromBundle(procedure),
  ];
  return SkillBundle(
    schemaVersion: '0.1.0',
    manifest: SkillManifest(
      id: id ?? module.id,
      name: module.name,
      version: module.version,
      provider: module.provider ?? provider ?? module.id,
      description: module.description,
      capabilities: module.capabilities.isEmpty ? null : module.capabilities,
    ),
    procedures: procedures,
  );
}

/// Converts one bundle procedure. See [skillBundleFromModule] for the errors.
Procedure procedureFromBundle(mb.SkillProcedure procedure) {
  final steps = [for (final step in procedure.steps) step.toJson()];
  final entry = procedure.entryPoint;
  if (entry != null && steps.isNotEmpty && entry != steps.first['id']) {
    throw InvalidProcedureException(
      'entryPoint "$entry" is not the first step; a procedure always starts '
      'at its first step',
      procedureId: procedure.id,
    );
  }
  return Procedure.fromJson({
    'id': procedure.id,
    'name': procedure.name,
    if (procedure.description != null) 'description': procedure.description,
    'steps': _convertSteps(steps, procedure.id, inLoop: false),
  });
}

List<Map<String, dynamic>> _convertSteps(
  List<Map<String, dynamic>> steps,
  String procedureId, {
  required bool inLoop,
}) {
  InvalidProcedureException refuse(String message, String? stepId) =>
      InvalidProcedureException(message,
          procedureId: procedureId, stepId: stepId);

  final ids = <String>[];
  for (final step in steps) {
    final id = step['id'];
    if (id is! String || id.isEmpty) {
      throw refuse('a step has no id', null);
    }
    if (ids.contains(id)) {
      throw refuse('step id "$id" is used twice', id);
    }
    ids.add(id);
  }

  // Index of the later step named [target], or an error naming [what].
  int later(String target, int from, String what, String stepId) {
    final to = ids.indexOf(target);
    if (to < 0) {
      throw refuse('$what "$target" is not a step', stepId);
    }
    if (to <= from) {
      throw refuse(
          '$what "$target" is not a later step; the runtime only moves '
          'forward',
          stepId);
    }
    return to;
  }

  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    final id = ids[i];
    final action = Map<String, dynamic>.from(
        (step['action'] as Map?) ?? const <String, dynamic>{});
    // Synonyms the bundle form allows: the spec example writes a prompt as
    // `template`, and a tool may be named `tool`. The runtime reads `prompt`
    // and `toolRef`.
    if (action['prompt'] == null && action['template'] != null) {
      action['prompt'] = action['template'];
    }
    action.remove('template');
    if (action['toolRef'] == null && action['tool'] != null) {
      action['toolRef'] = action['tool'];
    }
    action.remove('tool');

    final type = action['type'];
    if (type is! String || !_stepTypes.contains(type)) {
      throw refuse('step type "$type" is not executed by the skill runtime', id);
    }

    final next = [
      for (final n in (step['next'] as List? ?? const [])) n.toString(),
    ];
    if (next.length > 1) {
      throw refuse('several next steps are not executed (use a branch)', id);
    }
    final converted = <String, dynamic>{
      'id': id,
      'order': i + 1,
      'name': (step['name'] as String?) ?? id,
      if (step['condition'] != null) 'condition': step['condition'],
    };
    if (next.isNotEmpty) {
      final to = later(next.first, i, 'next', id);
      if (to != i + 1) converted['onSuccess'] = next.first;
    }
    final onError = step['onError'];
    if (onError is String && onError.isNotEmpty) {
      later(onError, i, 'onError', id);
      converted['onFailure'] = onError;
    }

    switch (type) {
      case 'prompt':
        final extract = action['extractClaims'];
        if (extract != null &&
            !const {'none', 'rules', 'llm', 'hybrid'}.contains(extract)) {
          throw refuse(
              'extractClaims "$extract" is not one of none, rules, llm, '
              'hybrid',
              id);
        }
      case 'branch':
        final cases = action['cases'];
        final fallback = action['default'];
        if (cases is! List && fallback == null) {
          throw refuse('a branch needs cases or a default', id);
        }
        for (final c in (cases as List? ?? const [])) {
          final map = c is Map ? c : const {};
          final when = map['when'];
          final goto = map['goto'];
          if (when is! String || when.isEmpty || goto is! String) {
            throw refuse('each branch case needs "when" and "goto"', id);
          }
          later(goto, i, 'goto', id);
        }
        if (fallback != null) {
          if (fallback is! String) {
            throw refuse('a branch "default" must name a step', id);
          }
          later(fallback, i, 'default', id);
        }
      case 'loop':
        if (inLoop) {
          throw refuse('a loop may not contain a loop', id);
        }
        final hasOver = action['over'] != null;
        final hasWhile = action['while'] != null;
        if (hasOver == hasWhile) {
          throw refuse('a loop needs exactly one of "over" and "while"', id);
        }
        final max = action['maxIterations'];
        if (max != null && (max is! int || max < 1)) {
          throw refuse('"maxIterations" must be a positive integer', id);
        }
        if (hasWhile && max == null) {
          throw refuse('a loop with "while" needs "maxIterations"', id);
        }
        final body = action['steps'];
        if (body is! List || body.isEmpty) {
          throw refuse('a loop needs a non-empty "steps" body', id);
        }
        action['steps'] = _convertSteps(
          [for (final b in body) Map<String, dynamic>.from(b as Map)],
          procedureId,
          inLoop: true,
        );
    }

    converted['action'] = action;
    out.add(converted);
  }
  return out;
}
