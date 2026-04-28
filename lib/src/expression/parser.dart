/// Recursive descent parser for the expression language.
///
/// Parses a token list into an AST following 14-level operator precedence.
library;

import 'ast.dart';
import 'tokenizer.dart';
import 'expression_exception.dart';

/// Parses tokens into an AST.
class Parser {
  final List<Token> _tokens;
  int _current = 0;

  Parser(this._tokens);

  /// Parse the token stream into a single AST node.
  AstNode parse() {
    final expr = _expression();
    if (!_isAtEnd()) {
      throw SyntaxException('', _peek().position,
          'Unexpected token: ${_peek().lexeme}');
    }
    return expr;
  }

  // Level 14 (lowest): Lambda
  AstNode _expression() {
    // Check for lambda: identifier => body
    if (_check(TokenType.identifier) && _peekNext()?.type == TokenType.arrow) {
      final param = _advance();
      _advance(); // consume =>
      final body = _expression();
      return LambdaExpr(param.lexeme, body);
    }
    return _conditional();
  }

  // Level 13: Conditional (ternary)
  AstNode _conditional() {
    var expr = _nullCoalesce();

    if (_match([TokenType.question])) {
      final thenBranch = _expression();
      _consume(TokenType.colon, "Expected ':' in conditional expression");
      final elseBranch = _expression();
      expr = ConditionalExpr(expr, thenBranch, elseBranch);
    }

    return expr;
  }

  // Level 12: Null coalescing
  AstNode _nullCoalesce() {
    var expr = _logicalOr();

    while (_match([TokenType.questionQuestion])) {
      final right = _logicalOr();
      expr = NullCoalesceExpr(expr, right);
    }

    return expr;
  }

  // Level 11: Logical OR
  AstNode _logicalOr() {
    var expr = _logicalAnd();

    while (_match([TokenType.pipePipe, TokenType.or])) {
      final op = _previous().lexeme;
      final right = _logicalAnd();
      expr = LogicalExpr(expr, op, right);
    }

    return expr;
  }

  // Level 10: Logical AND
  AstNode _logicalAnd() {
    var expr = _membership();

    while (_match([TokenType.ampAmp, TokenType.and])) {
      final op = _previous().lexeme;
      final right = _membership();
      expr = LogicalExpr(expr, op, right);
    }

    return expr;
  }

  // Level 8: Membership (in, matches)
  AstNode _membership() {
    var expr = _equality();

    if (_match([TokenType.inKeyword, TokenType.matches])) {
      final op = _previous().lexeme;
      final right = _equality();
      expr = BinaryExpr(expr, op, right);
    }

    return expr;
  }

  // Level 9: Equality
  AstNode _equality() {
    var expr = _comparison();

    while (_match([TokenType.equal, TokenType.notEqual])) {
      final op = _previous().lexeme;
      final right = _comparison();
      expr = BinaryExpr(expr, op, right);
    }

    return expr;
  }

  // Level 7: Comparison
  AstNode _comparison() {
    var expr = _pipe();

    while (_match(
        [TokenType.less, TokenType.lessEqual, TokenType.greater, TokenType.greaterEqual])) {
      final op = _previous().lexeme;
      final right = _pipe();
      expr = BinaryExpr(expr, op, right);
    }

    return expr;
  }

  // Level 6: Pipe
  AstNode _pipe() {
    var expr = _additive();

    while (_match([TokenType.pipe])) {
      final right = _additive();
      expr = PipeExpr(expr, right);
    }

    return expr;
  }

  // Level 5: Additive
  AstNode _additive() {
    var expr = _multiplicative();

    while (_match([TokenType.plus, TokenType.minus])) {
      final op = _previous().lexeme;
      final right = _multiplicative();
      expr = BinaryExpr(expr, op, right);
    }

    return expr;
  }

  // Level 4: Multiplicative
  AstNode _multiplicative() {
    var expr = _power();

    while (_match([TokenType.star, TokenType.slash, TokenType.percent])) {
      final op = _previous().lexeme;
      final right = _power();
      expr = BinaryExpr(expr, op, right);
    }

    return expr;
  }

  // Level 3: Power (right-associative)
  AstNode _power() {
    var expr = _unary();

    if (_match([TokenType.power])) {
      final right = _power(); // Right-associative
      expr = BinaryExpr(expr, '**', right);
    }

    return expr;
  }

  // Level 2: Unary
  AstNode _unary() {
    if (_match([TokenType.bang, TokenType.minus, TokenType.not])) {
      final op = _previous().lexeme;
      final operand = _unary();
      return UnaryExpr(op, operand);
    }

    return _postfix();
  }

  // Level 1 (highest): Postfix (calls, indexing, member access)
  AstNode _postfix() {
    var expr = _primary();

    while (true) {
      if (_match([TokenType.leftParen])) {
        // Function call
        final args = <AstNode>[];
        if (!_check(TokenType.rightParen)) {
          do {
            args.add(_expression());
          } while (_match([TokenType.comma]));
        }
        _consume(TokenType.rightParen, "Expected ')' after arguments");
        expr = CallExpr(expr, args);
      } else if (_match([TokenType.leftBracket])) {
        // Index access
        final index = _expression();
        _consume(TokenType.rightBracket, "Expected ']' after index");
        expr = IndexExpr(expr, index);
      } else if (_match([TokenType.dot])) {
        // Member access
        final name = _consume(TokenType.identifier, "Expected property name after '.'");
        expr = MemberExpr(expr, name.lexeme);
      } else if (_match([TokenType.optionalDot])) {
        // Optional member access
        final name = _consume(TokenType.identifier, "Expected property name after '?.'");
        expr = MemberExpr(expr, name.lexeme, isOptional: true);
      } else {
        break;
      }
    }

    return expr;
  }

  // Primary expressions
  AstNode _primary() {
    // Literals
    if (_match([TokenType.number, TokenType.string])) {
      return LiteralExpr(_previous().literal);
    }
    if (_match([TokenType.boolTrue])) return const LiteralExpr(true);
    if (_match([TokenType.boolFalse])) return const LiteralExpr(false);
    if (_match([TokenType.nullLiteral])) return const LiteralExpr(null);

    // Identifier
    if (_match([TokenType.identifier])) {
      return IdentifierExpr(_previous().lexeme);
    }

    // Grouping
    if (_match([TokenType.leftParen])) {
      final expr = _expression();
      _consume(TokenType.rightParen, "Expected ')' after expression");
      return GroupingExpr(expr);
    }

    // Array literal
    if (_match([TokenType.leftBracket])) {
      final elements = <AstNode>[];
      if (!_check(TokenType.rightBracket)) {
        do {
          elements.add(_expression());
        } while (_match([TokenType.comma]));
      }
      _consume(TokenType.rightBracket, "Expected ']' after array");
      return ArrayExpr(elements);
    }

    // Object literal
    if (_match([TokenType.leftBrace])) {
      final entries = <ObjectEntry>[];
      if (!_check(TokenType.rightBrace)) {
        do {
          final key =
              _consume(TokenType.identifier, "Expected property name in object")
                  .lexeme;
          _consume(TokenType.colon, "Expected ':' after property name");
          final value = _expression();
          entries.add(ObjectEntry(key, value));
        } while (_match([TokenType.comma]));
      }
      _consume(TokenType.rightBrace, "Expected '}' after object");
      return ObjectExpr(entries);
    }

    throw SyntaxException(
        '', _peek().position, 'Expected expression, got: ${_peek().lexeme}');
  }

  // Helper methods

  bool _match(List<TokenType> types) {
    for (final type in types) {
      if (_check(type)) {
        _advance();
        return true;
      }
    }
    return false;
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _previous();
  }

  Token _peek() => _tokens[_current];

  Token? _peekNext() {
    if (_current + 1 >= _tokens.length) return null;
    return _tokens[_current + 1];
  }

  Token _previous() => _tokens[_current - 1];

  bool _isAtEnd() => _peek().type == TokenType.eof;

  Token _consume(TokenType type, String message) {
    if (_check(type)) return _advance();
    throw SyntaxException('', _peek().position, message);
  }
}
