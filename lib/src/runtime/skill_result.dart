/// Skill Result - Re-export from mcp_bundle.
///
/// All skill result types (SkillResult, SkillAction, ActionStatus,
/// RubricScore, Finding, Conflict, Artifact, ExecutionMetadata, StepResult)
/// are now defined in mcp_bundle (Contract Layer).
///
/// This file re-exports them for backward compatibility.
library;

export 'package:mcp_bundle/src/types/skill_result.dart';
