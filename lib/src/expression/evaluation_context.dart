/// Evaluation context for expression language.
///
/// Provides the 9 root objects available during expression evaluation.
library;

import '../runtime/skill_context.dart';
import '../runtime/skill_result.dart';

/// Context for expression evaluation with 9 root objects.
class ExpressionEvaluationContext {
  /// Skill input parameters.
  final Map<String, dynamic> inputs;

  /// Previous step results.
  final Map<String, StepResult> steps;

  /// Skill execution context.
  final SkillContext? skillContext;

  /// Shared mutable state.
  final Map<String, dynamic> state;

  /// Skill configuration.
  final Map<String, dynamic> config;

  /// Context bundle from FactGraph.
  final dynamic bundle;

  /// FactGraph query results.
  final dynamic facts;

  /// Claims from skill/FactGraph.
  final List<dynamic>? claims;

  /// Appraisal metrics (optional, from mcp_profile).
  final Map<String, dynamic>? metrics;

  ExpressionEvaluationContext({
    this.inputs = const {},
    this.steps = const {},
    this.skillContext,
    this.state = const {},
    this.config = const {},
    this.bundle,
    this.facts,
    this.claims,
    this.metrics,
  });

  /// Resolve a root object by name.
  dynamic resolve(String root) {
    return switch (root) {
      'inputs' => inputs,
      'steps' => steps,
      'context' => _contextMap(),
      'state' => state,
      'config' => config,
      'bundle' => bundle,
      'facts' => facts,
      'claims' => claims,
      'metrics' => metrics,
      _ => null,
    };
  }

  /// Build a map representation of the skill context.
  Map<String, dynamic>? _contextMap() {
    final ctx = skillContext;
    if (ctx == null) return null;
    return {
      'contextId': ctx.contextId,
      'skillId': ctx.skillId,
      'runId': ctx.runId,
      'traceId': ctx.traceId,
      'request': ctx.request,
      'workspaceId': ctx.workspaceId,
      'userId': ctx.userId,
      'asOf': ctx.asOf.toIso8601String(),
      'policyVersion': ctx.policyVersion,
    };
  }
}
