/// Expression Interpolator - Template string interpolation using expression evaluator.
///
/// Provides all 10 root objects for expression evaluation within skill execution.
library;

import 'skill_context.dart';
import 'skill_result.dart';
import 'context_types.dart';
import '../expression/evaluation_context.dart';
import '../expression/skill_expression_evaluator.dart';

/// Interpolates template strings using the full expression evaluation context.
///
/// Supports 10 root objects:
/// - inputs, context, steps, state, config, bundle, facts, claims, metrics, runtime
class ExpressionInterpolator {
  /// Skill execution context.
  final SkillContext skillContext;

  /// Previous step results.
  final Map<String, StepResult> stepResults;

  /// Mutable execution state.
  final ContextState state;

  /// Skill configuration.
  final SkillConfig config;

  /// Claims from execution.
  final List<dynamic>? claims;

  /// Metrics (from mcp_profile).
  final Map<String, dynamic>? metrics;

  /// Expression evaluator instance.
  late final SkillExpressionEvaluator _evaluator;

  ExpressionInterpolator({
    required this.skillContext,
    this.stepResults = const {},
    ContextState? state,
    SkillConfig? config,
    this.claims,
    this.metrics,
    ExpressionErrorStrategy errorStrategy = ExpressionErrorStrategy.failFast,
  })  : state = state ?? ContextState(),
        config = config ?? const SkillConfig.empty() {
    _evaluator = SkillExpressionEvaluator(
      context: ExpressionEvaluationContext(
        inputs: skillContext.inputs,
        steps: stepResults,
        skillContext: skillContext,
        state: this.state.toMap(),
        config: this.config.toMap(),
        bundle: skillContext.contextBundle,
        facts: null,
        claims: claims,
        metrics: metrics,
      ),
      errorStrategy: errorStrategy,
    );
  }

  /// Interpolate a template string.
  Future<String> interpolate(String template) async {
    return _evaluator.interpolate(template);
  }

  /// Evaluate an expression and return the raw result.
  Future<dynamic> evaluate(String expression) async {
    return _evaluator.evaluate(expression);
  }

  /// Evaluate a condition expression (returns boolean).
  Future<bool> evaluateCondition(String condition) async {
    return _evaluator.evaluateCondition(condition);
  }

  /// Interpolate all string values in a map.
  Future<Map<String, dynamic>> interpolateMap(
      Map<String, dynamic> template) async {
    final result = <String, dynamic>{};
    for (final entry in template.entries) {
      if (entry.value is String) {
        result[entry.key] = await interpolate(entry.value as String);
      } else if (entry.value is Map<String, dynamic>) {
        result[entry.key] =
            await interpolateMap(entry.value as Map<String, dynamic>);
      } else {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
}
