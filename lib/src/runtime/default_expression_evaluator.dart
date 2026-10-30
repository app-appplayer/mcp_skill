/// The expression evaluator a procedure uses when the host injects none.
///
/// Conditions, `transform`, `branch`, `loop` and `output` evaluate with the
/// expression language of bundle spec 11. Without an evaluator a condition
/// could only be assumed true, which silently ran every guarded step.
library;

import 'package:mcp_bundle/mcp_bundle.dart'
    show
        renderInterpolatedValue,
        renderInterpolation,
        singleInterpolationExpression;

import '../expression/evaluation_context.dart';
import '../expression/skill_expression_evaluator.dart';
import 'procedure_executor.dart' show ExpressionEvaluator;
import 'skill_context.dart';
import 'skill_result.dart';

/// Evaluates [expression] against the run's inputs, the results of the steps
/// that ran and the run context. A `loop` scope in `context.metadata['loop']`
/// is visible as `loop`.
Future<dynamic> defaultExpressionEvaluator(
  String expression,
  SkillContext context,
  Map<String, StepResult> stepResults,
) {
  final evaluator = SkillExpressionEvaluator(
    context: ExpressionEvaluationContext(
      inputs: context.inputs,
      steps: stepResults,
      skillContext: context,
    ),
    errorStrategy: ExpressionErrorStrategy.failFast,
  );
  return evaluator.evaluate(expression);
}

/// The evaluator used when none is injected.
const ExpressionEvaluator defaultEvaluator = defaultExpressionEvaluator;

/// Whether [value] is truthy under bundle spec 11 §11.8: `false`, `null`, `0`,
/// the empty string, an empty list and an empty map are falsy.
bool isTruthy(dynamic value) {
  if (value == null || value == false) return false;
  if (value is num) return value != 0;
  if (value is String) return value.isNotEmpty;
  if (value is List) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

/// Renders [template] with `${...}` interpolation (bundle spec 11 §11.7).
///
/// Each expression is evaluated with [evaluate]; one that fails renders as the
/// empty string and `null` renders as the empty string. `\$` is a literal
/// dollar sign.
Future<String> renderTemplate(
  String template,
  ExpressionEvaluator evaluate,
  SkillContext context,
  Map<String, StepResult> stepResults,
) =>
    renderInterpolation(
        template, (expression) => evaluate(expression, context, stepResults));

/// Renders a value that may hold templates, at any depth of maps and lists.
///
/// A string that is exactly one `${...}` takes the value of that expression
/// with its type (a number stays a number, a list a list); any other string is
/// rendered as text; non-strings are kept. A single expression that fails
/// yields the empty string, like a failed interpolation (spec 11 §11.9).
Future<dynamic> renderValue(
  dynamic value,
  ExpressionEvaluator evaluate,
  SkillContext context,
  Map<String, StepResult> stepResults,
) =>
    renderInterpolatedValue(
        value, (expression) => evaluate(expression, context, stepResults));

/// The value of an `output` / `loop` / `branch` expression field.
///
/// Text that is exactly one `${...}` yields that expression's typed value;
/// other text containing `${` is rendered as a template; anything else is one
/// expression.
Future<dynamic> evaluateValue(
  String text,
  ExpressionEvaluator evaluate,
  SkillContext context,
  Map<String, StepResult> stepResults,
) async {
  final trimmed = text.trim();
  final single = singleInterpolationExpression(trimmed);
  if (single != null) return evaluate(single, context, stepResults);
  if (trimmed.contains(r'${')) {
    return renderTemplate(trimmed, evaluate, context, stepResults);
  }
  return evaluate(trimmed, context, stepResults);
}
