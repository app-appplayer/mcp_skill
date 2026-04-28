/// Expression language exception types.
library;

/// Base exception for expression evaluation errors.
sealed class ExpressionException implements Exception {
  /// Human-readable error message.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Syntax error in expression.
class SyntaxException extends ExpressionException {
  /// The expression that failed to parse.
  final String expression;

  /// Position in expression where error occurred.
  final int position;

  @override
  final String message;

  SyntaxException(this.expression, this.position, this.message);
}

/// Runtime evaluation error.
class EvaluationException extends ExpressionException {
  @override
  final String message;

  /// Path in the expression where error occurred.
  final String? path;

  EvaluationException(this.message, {this.path});
}

/// Type coercion failure.
class TypeCoercionException extends ExpressionException {
  /// Source type name.
  final String sourceType;

  /// Target type name.
  final String targetType;

  @override
  final String message;

  TypeCoercionException(this.sourceType, this.targetType)
      : message = 'Cannot coerce $sourceType to $targetType';
}

/// Expression evaluation timeout.
class ExpressionTimeoutException extends ExpressionException {
  /// The timeout duration.
  final Duration timeout;

  @override
  final String message;

  ExpressionTimeoutException(this.timeout)
      : message =
            'Expression evaluation timed out after ${timeout.inMilliseconds}ms';
}

/// Unknown function referenced.
class UnknownFunctionException extends ExpressionException {
  /// The function name that was not found.
  final String functionName;

  @override
  final String message;

  UnknownFunctionException(this.functionName)
      : message = 'Unknown function: $functionName';
}

/// Security violation in expression.
class SecurityException extends ExpressionException {
  @override
  final String message;

  SecurityException(this.message);
}
