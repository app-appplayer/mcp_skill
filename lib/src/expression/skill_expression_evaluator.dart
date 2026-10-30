/// Skill Expression Evaluator - Main evaluator for the expression language.
///
/// Provides evaluate(), evaluateCondition(), and interpolate() methods
/// with configurable error strategies and execution limits.
library;

import 'dart:math' as math;

import 'ast.dart';
import 'tokenizer.dart';
import 'parser.dart';
import 'evaluation_context.dart';
import 'function_registry.dart';
import 'expression_exception.dart';
import '../runtime/skill_result.dart' show StepResult;

/// Execution limits for expression evaluation security.
class ExecutionLimits {
  /// Maximum evaluation time.
  final Duration timeout;

  /// Maximum recursion depth.
  final int maxRecursion;

  /// Maximum string length in result.
  final int maxStringLength;

  /// Maximum array length in result.
  final int maxArrayLength;

  /// Maximum number of function calls.
  final int maxFunctionCalls;

  const ExecutionLimits({
    this.timeout = const Duration(milliseconds: 100),
    this.maxRecursion = 50,
    this.maxStringLength = 100000,
    this.maxArrayLength = 10000,
    this.maxFunctionCalls = 1000,
  });
}

/// Error recovery strategies for expression evaluation.
///
/// Maps to canonical YAML strategy names:
///   failFast     = "throw"    - Throw exception immediately
///   returnNull   = "empty"    - Return null on error
///   returnDefault = "default" - Return default value on error
///   logAndContinue = "marker" - Log and continue with null
enum ExpressionErrorStrategy {
  failFast,
  returnNull,
  returnDefault,
  logAndContinue,
}

/// Main expression evaluator for mcp_skill.
class SkillExpressionEvaluator {
  /// Evaluation context with root objects.
  final ExpressionEvaluationContext context;

  /// Execution limits for security.
  final ExecutionLimits limits;

  /// Error handling strategy.
  final ExpressionErrorStrategy errorStrategy;

  /// Default value for returnDefault strategy.
  final dynamic defaultValue;

  /// Function registry.
  final FunctionRegistry functions;

  int _recursionDepth = 0;
  int _functionCallCount = 0;

  SkillExpressionEvaluator({
    required this.context,
    this.limits = const ExecutionLimits(),
    this.errorStrategy = ExpressionErrorStrategy.failFast,
    this.defaultValue,
    FunctionRegistry? functions,
  }) : functions = functions ?? FunctionRegistry.standard();

  /// Evaluate an expression string and return the result.
  Future<dynamic> evaluate(String expression) async {
    _recursionDepth = 0;
    _functionCallCount = 0;

    try {
      return await Future.any([
        _doEvaluate(expression),
        Future.delayed(limits.timeout, () {
          throw ExpressionTimeoutException(limits.timeout);
        }),
      ]);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Evaluate a condition expression, returns boolean.
  Future<bool> evaluateCondition(String condition) async {
    final result = await evaluate(condition);
    return _toBoolean(result);
  }

  /// Interpolate a template string, replacing `${...}` with evaluated values.
  Future<String> interpolate(String template) async {
    final pattern = RegExp(r'\$\{([^}]+)\}');
    final buffer = StringBuffer();
    var lastEnd = 0;

    for (final match in pattern.allMatches(template)) {
      buffer.write(template.substring(lastEnd, match.start));
      final expr = match.group(1)!;
      try {
        final value = await evaluate(expr);
        buffer.write(value?.toString() ?? '');
      } catch (e) {
        buffer.write('');
      }
      lastEnd = match.end;
    }

    buffer.write(template.substring(lastEnd));
    return buffer.toString();
  }

  Future<dynamic> _doEvaluate(String expression) async {
    _checkRecursion();

    final sanitized = _sanitizeExpression(expression);
    final tokens = Tokenizer(sanitized).tokenize();
    final ast = Parser(tokens).parse();
    return _evaluateAst(ast);
  }

  dynamic _evaluateAst(AstNode node) {
    _checkRecursion();

    return switch (node) {
      LiteralExpr n => n.value,
      IdentifierExpr n => _resolveIdentifier(n.name),
      MemberExpr n =>
        n.isOptional ? _evaluateSafeMember(n) : _evaluateMember(n),
      IndexExpr n => _evaluateIndex(n),
      CallExpr n => _evaluateCall(n),
      UnaryExpr n => _evaluateUnary(n),
      BinaryExpr n => _evaluateBinary(n),
      LogicalExpr n => _evaluateLogical(n),
      ConditionalExpr n => _evaluateConditional(n),
      NullCoalesceExpr n => _evaluateNullCoalesce(n),
      GroupingExpr n => _evaluateAst(n.expression),
      InterpolationExpr n => _evaluateInterpolation(n),
      PipeExpr n => _evaluatePipe(n),
      LambdaExpr _ =>
        throw EvaluationException('Lambda cannot be evaluated directly'),
      ArrayExpr n => n.elements.map(_evaluateAst).toList(),
      ObjectExpr n => Map<String, dynamic>.fromEntries(
          n.entries.map((e) => MapEntry(e.key, _evaluateAst(e.value))),
        ),
    };
  }

  dynamic _resolveIdentifier(String name) {
    // Check if it's a known root object
    final resolved = context.resolve(name);
    if (resolved != null) return resolved;

    // Check boolean/null literals
    switch (name) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'null':
        return null;
    }

    // Could be a function name - return as-is for CallExpr to resolve
    return null;
  }

  dynamic _evaluateMember(MemberExpr node) {
    final obj = _evaluateAst(node.object);
    return _getProperty(obj, node.property);
  }

  dynamic _evaluateSafeMember(MemberExpr node) {
    final obj = _evaluateAst(node.object);
    if (obj == null) return null;
    return _getProperty(obj, node.property);
  }

  dynamic _evaluateIndex(IndexExpr node) {
    final obj = _evaluateAst(node.object);
    final index = _evaluateAst(node.index);

    if (obj is List) {
      final i = index is num ? index.toInt() : 0;
      if (i >= 0 && i < obj.length) return obj[i];
      return null;
    }
    if (obj is Map) return obj[index];
    return null;
  }

  dynamic _evaluateCall(CallExpr node) {
    _checkFunctionCalls();

    String functionName;
    if (node.callee is IdentifierExpr) {
      functionName = (node.callee as IdentifierExpr).name;
    } else {
      throw EvaluationException('Cannot call non-function');
    }

    final args = node.arguments.map(_evaluateAst).toList();
    return functions.call(functionName, args);
  }

  dynamic _evaluateUnary(UnaryExpr node) {
    final operand = _evaluateAst(node.operand);

    return switch (node.operator) {
      '!' || 'not' => !_toBoolean(operand),
      '-' => -(operand is num ? operand : 0),
      _ => throw EvaluationException('Unknown unary operator: ${node.operator}'),
    };
  }

  dynamic _evaluateBinary(BinaryExpr node) {
    final left = _evaluateAst(node.left);
    final right = _evaluateAst(node.right);

    return switch (node.operator) {
      '+' => _add(left, right),
      '-' => _toNum(left) - _toNum(right),
      '*' => _toNum(left) * _toNum(right),
      '/' => _toNum(right) != 0 ? _toNum(left) / _toNum(right) : double.infinity,
      '%' => _toNum(right) != 0 ? _toNum(left) % _toNum(right) : 0,
      '**' => math.pow(_toNum(left), _toNum(right)),
      '==' => left == right,
      '!=' => left != right,
      '<' => _toNum(left) < _toNum(right),
      '<=' => _toNum(left) <= _toNum(right),
      '>' => _toNum(left) > _toNum(right),
      '>=' => _toNum(left) >= _toNum(right),
      'in' => _evaluateIn(left, right),
      'matches' => _evaluateMatches(left, right),
      _ => throw EvaluationException('Unknown operator: ${node.operator}'),
    };
  }

  dynamic _evaluateLogical(LogicalExpr node) {
    final left = _evaluateAst(node.left);

    return switch (node.operator) {
      '&&' || 'and' => _toBoolean(left) ? _evaluateAst(node.right) : left,
      '||' || 'or' => _toBoolean(left) ? left : _evaluateAst(node.right),
      _ => throw EvaluationException('Unknown logical operator: ${node.operator}'),
    };
  }

  dynamic _evaluateConditional(ConditionalExpr node) {
    final condition = _evaluateAst(node.condition);
    return _toBoolean(condition)
        ? _evaluateAst(node.thenBranch)
        : _evaluateAst(node.elseBranch);
  }

  dynamic _evaluateNullCoalesce(NullCoalesceExpr node) {
    final left = _evaluateAst(node.left);
    return left ?? _evaluateAst(node.right);
  }

  String _evaluateInterpolation(InterpolationExpr node) {
    return node.parts.map((p) => _evaluateAst(p)?.toString() ?? '').join();
  }

  dynamic _evaluatePipe(PipeExpr node) {
    final value = _evaluateAst(node.value);

    // Pipe target should be a function call
    if (node.transform is IdentifierExpr) {
      final fnName = (node.transform as IdentifierExpr).name;
      return functions.call(fnName, [value]);
    }
    if (node.transform is CallExpr) {
      final call = node.transform as CallExpr;
      if (call.callee is IdentifierExpr) {
        final fnName = (call.callee as IdentifierExpr).name;
        final args = [value, ...call.arguments.map(_evaluateAst)];
        return functions.call(fnName, args);
      }
    }
    throw EvaluationException('Invalid pipe target');
  }

  // ========================================================================
  // HELPERS
  // ========================================================================

  dynamic _getProperty(dynamic obj, String property) {
    if (obj is Map) return obj[property];
    if (obj is StepResultAccessor) return obj.getProperty(property);
    if (obj is StepResult) {
      return switch (property) {
        'stepId' => obj.stepId,
        'result' => obj.result,
        'claims' => obj.claims,
        'evidenceRefs' => obj.evidenceRefs,
        'toolCalled' => obj.toolCalled,
        'metadata' => obj.metadata,
        _ => null,
      };
    }
    return null;
  }

  dynamic _add(dynamic left, dynamic right) {
    if (left is String || right is String) {
      return '${left ?? ''}${right ?? ''}';
    }
    return _toNum(left) + _toNum(right);
  }

  bool _evaluateIn(dynamic left, dynamic right) {
    if (right is List) return right.contains(left);
    if (right is String && left is String) return right.contains(left);
    if (right is Map) return right.containsKey(left);
    return false;
  }

  bool _evaluateMatches(dynamic left, dynamic right) {
    if (left is! String || right is! String) return false;
    return RegExp(right).hasMatch(left);
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    if (value is bool) return value ? 1 : 0;
    return 0;
  }

  bool _toBoolean(dynamic value) {
    return switch (value) {
      null => false,
      bool b => b,
      num n => n != 0,
      String s => s.isNotEmpty && s.toLowerCase() != 'false',
      List l => l.isNotEmpty,
      Map m => m.isNotEmpty,
      _ => true,
    };
  }

  void _checkRecursion() {
    _recursionDepth++;
    if (_recursionDepth > limits.maxRecursion) {
      throw EvaluationException('Maximum recursion depth exceeded');
    }
  }

  void _checkFunctionCalls() {
    _functionCallCount++;
    if (_functionCallCount > limits.maxFunctionCalls) {
      throw EvaluationException('Maximum function call count exceeded');
    }
  }

  String _sanitizeExpression(String expression) {
    if (expression.contains(RegExp(r'__proto__|constructor|prototype'))) {
      throw SecurityException('Potential prototype pollution detected');
    }
    if (expression.length > 10000) {
      throw SecurityException('Expression too long');
    }
    return expression;
  }

  dynamic _handleError(dynamic e) {
    return switch (errorStrategy) {
      ExpressionErrorStrategy.failFast => throw e,
      ExpressionErrorStrategy.returnNull => null,
      ExpressionErrorStrategy.returnDefault => defaultValue,
      ExpressionErrorStrategy.logAndContinue => null,
    };
  }
}

/// Interface for objects that support property access in expressions.
abstract class StepResultAccessor {
  /// Get a property value by name.
  dynamic getProperty(String name);
}
