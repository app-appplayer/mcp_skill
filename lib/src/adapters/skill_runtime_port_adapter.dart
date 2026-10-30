/// SkillRuntimePortAdapter - Implements mcp_bundle's SkillRuntimePort.
///
/// Exposes `mcp_skill`'s `SkillRuntime` as a `SkillRuntimePort` (the
/// capability-named standard port defined in `mcp_bundle`). Added as
/// part of REDESIGN-PLAN Phase 4 §3.1.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;

import '../runtime/skill_runtime.dart';
import '../runtime/skill_context.dart';
import '../id_generator.dart';

/// Adapter that implements [bundle.SkillRuntimePort] by delegating to a
/// concrete `mcp_skill` [SkillRuntime].
class SkillRuntimePortAdapter implements bundle.SkillRuntimePort {
  final SkillRuntime _runtime;
  final String _defaultWorkspaceId;

  SkillRuntimePortAdapter({
    required SkillRuntime runtime,
    String defaultWorkspaceId = 'default',
  })  : _runtime = runtime,
        _defaultWorkspaceId = defaultWorkspaceId;

  @override
  Future<bundle.SkillRunHandle> executeSkill(
    String skillId,
    Map<String, dynamic> inputs, {
    Map<String, dynamic>? context,
  }) async {
    final now = DateTime.now();
    final runId = generateId('run');

    final skillContext = SkillContext(
      contextId: 'ctx_$runId',
      skillId: skillId,
      runId: runId,
      traceId: context?['traceId'] as String? ?? 'trace_$runId',
      parentContextId: context?['parentContextId'] as String?,
      request: context?['request'] as String? ?? skillId,
      workspaceId: context?['workspaceId'] as String? ?? _defaultWorkspaceId,
      asOf: now,
      inputs: inputs,
      activeSkills: [skillId],
    );

    final result = await _runtime.run(skillContext);

    return bundle.SkillRunHandle(
      runId: runId,
      skillId: skillId,
      running: false,
      result: result,
      startedAt: now,
      finishedAt: DateTime.now(),
    );
  }

  @override
  Future<void> cancel(String runId) async {
    // `SkillRuntime` does not yet expose a cancellation API. Cancellation
    // support will be wired through `RuntimeHook.onCancel` once the
    // runtime exposes a cooperative cancellation signal.
  }
}
