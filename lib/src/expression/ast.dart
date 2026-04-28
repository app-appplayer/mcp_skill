/// AST (Abstract Syntax Tree) node definitions for the expression language.
library;

/// Base class for all AST nodes.
sealed class AstNode {
  const AstNode();
}

/// Literal value (number, string, boolean, null).
class LiteralExpr extends AstNode {
  final dynamic value;
  const LiteralExpr(this.value);
}

/// Identifier reference (e.g., `inputs`, `steps`).
class IdentifierExpr extends AstNode {
  final String name;
  const IdentifierExpr(this.name);
}

/// Member access (e.g., `obj.field` or `obj?.field`).
class MemberExpr extends AstNode {
  final AstNode object;
  final String property;
  final bool isOptional;
  const MemberExpr(this.object, this.property, {this.isOptional = false});
}

/// Index access (e.g., `arr[0]`).
class IndexExpr extends AstNode {
  final AstNode object;
  final AstNode index;
  const IndexExpr(this.object, this.index);
}

/// Function call (e.g., `length(str)`).
class CallExpr extends AstNode {
  final AstNode callee;
  final List<AstNode> arguments;
  const CallExpr(this.callee, this.arguments);
}

/// Unary operation (e.g., `!x`, `-x`, `not x`).
class UnaryExpr extends AstNode {
  final String operator;
  final AstNode operand;
  const UnaryExpr(this.operator, this.operand);
}

/// Binary operation (e.g., `a + b`, `a * b`).
class BinaryExpr extends AstNode {
  final AstNode left;
  final String operator;
  final AstNode right;
  const BinaryExpr(this.left, this.operator, this.right);
}

/// Logical operation (e.g., `a && b`, `a || b`).
class LogicalExpr extends AstNode {
  final AstNode left;
  final String operator;
  final AstNode right;
  const LogicalExpr(this.left, this.operator, this.right);
}

/// Conditional/ternary (e.g., `a ? b : c`).
class ConditionalExpr extends AstNode {
  final AstNode condition;
  final AstNode thenBranch;
  final AstNode elseBranch;
  const ConditionalExpr(this.condition, this.thenBranch, this.elseBranch);
}

/// Null coalescing (e.g., `a ?? b`).
class NullCoalesceExpr extends AstNode {
  final AstNode left;
  final AstNode right;
  const NullCoalesceExpr(this.left, this.right);
}

/// Grouping/parenthesized expression.
class GroupingExpr extends AstNode {
  final AstNode expression;
  const GroupingExpr(this.expression);
}

/// String interpolation segment.
class InterpolationExpr extends AstNode {
  final List<AstNode> parts;
  const InterpolationExpr(this.parts);
}

/// Pipe expression (e.g., `value | transform`).
class PipeExpr extends AstNode {
  final AstNode value;
  final AstNode transform;
  const PipeExpr(this.value, this.transform);
}

/// Lambda expression (e.g., `x => x + 1`).
class LambdaExpr extends AstNode {
  final String parameter;
  final AstNode body;
  const LambdaExpr(this.parameter, this.body);
}

/// Array literal (e.g., `[1, 2, 3]`).
class ArrayExpr extends AstNode {
  final List<AstNode> elements;
  const ArrayExpr(this.elements);
}

/// Object literal (e.g., `{key: value}`).
class ObjectExpr extends AstNode {
  final List<ObjectEntry> entries;
  const ObjectExpr(this.entries);
}

/// Key-value pair in object literal.
class ObjectEntry {
  final String key;
  final AstNode value;
  const ObjectEntry(this.key, this.value);
}
