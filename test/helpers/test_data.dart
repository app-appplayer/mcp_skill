/// Factory functions for creating test data with sensible defaults.
library;

import 'package:mcp_skill/src/bundle/skill_bundle.dart';
import 'package:mcp_skill/src/definition/procedure.dart';
import 'package:mcp_skill/src/definition/step.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';

/// Create a SkillBundle with sensible defaults.
SkillBundle makeSkillBundle({
  String schemaVersion = '0.1.0',
  String id = 'com.test.skill',
  String name = 'Test Skill',
  String version = '1.0.0',
  String provider = 'test-provider',
  String? description,
  List<Procedure>? procedures,
}) {
  return SkillBundle(
    schemaVersion: schemaVersion,
    manifest: SkillManifest(
      id: id,
      name: name,
      version: version,
      provider: provider,
      description: description ?? 'A test skill',
    ),
    procedures: procedures ??
        [
          makeProcedure(),
        ],
  );
}

/// Create a SkillContext with sensible defaults.
SkillContext makeSkillContext({
  String contextId = 'ctx-001',
  String skillId = 'com.test.skill',
  String runId = 'run-001',
  String traceId = 'trace-001',
  String request = 'Analyze the data',
  String workspaceId = 'ws-001',
  DateTime? asOf,
  Map<String, dynamic>? inputs,
  ExecutionBudget? budget,
}) {
  return SkillContext(
    contextId: contextId,
    skillId: skillId,
    runId: runId,
    traceId: traceId,
    request: request,
    workspaceId: workspaceId,
    asOf: asOf ?? DateTime(2025, 1, 1),
    inputs: inputs ?? const {},
    budget: budget,
  );
}

/// Create a SkillResult with sensible defaults.
SkillResult makeSkillResult({
  List<Claim>? claims,
  List<String>? evidenceRefs,
  double confidence = 0.9,
  DateTime? asOf,
  ExecutionMetadata? metadata,
}) {
  return SkillResult(
    claims: claims ?? [makeClaim()],
    evidenceRefs: evidenceRefs ?? ['evidence-001'],
    confidence: confidence,
    asOf: asOf ?? DateTime(2025, 1, 1),
    metadata: metadata ?? makeExecutionMetadata(),
  );
}

/// Create a Claim with sensible defaults.
Claim makeClaim({
  String id = 'claim-001',
  String workspaceId = 'ws-001',
  String text = 'Revenue increased by 15%',
  ClaimType type = ClaimType.fact,
  List<String>? evidenceRefs,
  double confidence = 0.95,
  ClaimStatus status = ClaimStatus.pending,
}) {
  return Claim(
    id: id,
    workspaceId: workspaceId,
    text: text,
    type: type,
    evidenceRefs: evidenceRefs ?? ['evidence-001'],
    confidence: confidence,
    status: status,
  );
}

/// Create a Procedure with sensible defaults.
Procedure makeProcedure({
  String id = 'proc-001',
  String name = 'Test Procedure',
  String? description,
  List<Step>? steps,
}) {
  return Procedure(
    id: id,
    name: name,
    description: description ?? 'A test procedure',
    steps: steps ?? [makeStep()],
  );
}

/// Create a Step with sensible defaults.
Step makeStep({
  String id = 'step-001',
  int order = 1,
  String name = 'Test Step',
  String actionType = 'llm',
  String? prompt,
}) {
  return Step(
    id: id,
    order: order,
    name: name,
    action: StepAction(
      type: actionType,
      prompt: prompt ?? 'Analyze the input data',
    ),
  );
}

/// Create an ExecutionMetadata with sensible defaults.
ExecutionMetadata makeExecutionMetadata({
  String skillId = 'com.test.skill',
  String skillVersion = '1.0.0',
  String procedureId = 'proc-001',
  DateTime? startedAt,
  DateTime? finishedAt,
  int stepsExecuted = 3,
  List<String>? toolsCalled,
}) {
  final start = startedAt ?? DateTime(2025, 1, 1, 10, 0, 0);
  final end = finishedAt ?? DateTime(2025, 1, 1, 10, 0, 5);
  return ExecutionMetadata(
    skillId: skillId,
    skillVersion: skillVersion,
    procedureId: procedureId,
    startedAt: start,
    finishedAt: end,
    duration: end.difference(start),
    stepsExecuted: stepsExecuted,
    toolsCalled: toolsCalled ?? ['llm.complete'],
  );
}
