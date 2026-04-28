/// Tokenizer for the expression language.
///
/// Converts an expression string into a list of tokens.
library;

import 'expression_exception.dart';

/// Token types for the expression language.
enum TokenType {
  // Literals
  number,
  string,
  boolTrue,
  boolFalse,
  nullLiteral,

  // Identifiers and keywords
  identifier,
  and,
  or,
  not,
  inKeyword,
  matches,

  // Operators
  plus,
  minus,
  star,
  slash,
  percent,
  power,
  bang,
  equal,
  notEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
  ampAmp,
  pipePipe,
  questionQuestion,
  question,
  colon,
  arrow,
  pipe,
  dot,
  optionalDot,

  // Delimiters
  leftParen,
  rightParen,
  leftBracket,
  rightBracket,
  leftBrace,
  rightBrace,
  comma,

  // Interpolation
  dollarBrace,

  // End
  eof,
}

/// A single token from the tokenizer.
class Token {
  /// Token type.
  final TokenType type;

  /// Token lexeme (raw text).
  final String lexeme;

  /// Position in the source expression.
  final int position;

  /// Literal value (for number/string tokens).
  final dynamic literal;

  const Token(this.type, this.lexeme, this.position, {this.literal});

  @override
  String toString() => 'Token($type, "$lexeme", $position)';
}

/// Tokenizes an expression string into a list of tokens.
class Tokenizer {
  final String _source;
  final List<Token> _tokens = [];
  int _start = 0;
  int _current = 0;

  Tokenizer(this._source);

  /// Tokenize the source string.
  List<Token> tokenize() {
    while (!_isAtEnd()) {
      _start = _current;
      _scanToken();
    }

    _tokens.add(Token(TokenType.eof, '', _current));
    return _tokens;
  }

  void _scanToken() {
    final c = _advance();
    switch (c) {
      case '(':
        _addToken(TokenType.leftParen);
      case ')':
        _addToken(TokenType.rightParen);
      case '[':
        _addToken(TokenType.leftBracket);
      case ']':
        _addToken(TokenType.rightBracket);
      case '{':
        _addToken(TokenType.leftBrace);
      case '}':
        _addToken(TokenType.rightBrace);
      case ',':
        _addToken(TokenType.comma);
      case '+':
        _addToken(TokenType.plus);
      case '-':
        _addToken(TokenType.minus);
      case '*':
        if (_match('*')) {
          _addToken(TokenType.power);
        } else {
          _addToken(TokenType.star);
        }
      case '/':
        _addToken(TokenType.slash);
      case '%':
        _addToken(TokenType.percent);
      case '.':
        _addToken(TokenType.dot);
      case ':':
        _addToken(TokenType.colon);
      case '?':
        if (_match('?')) {
          _addToken(TokenType.questionQuestion);
        } else if (_match('.')) {
          _addToken(TokenType.optionalDot);
        } else {
          _addToken(TokenType.question);
        }
      case '!':
        if (_match('=')) {
          _addToken(TokenType.notEqual);
        } else {
          _addToken(TokenType.bang);
        }
      case '=':
        if (_match('=')) {
          _addToken(TokenType.equal);
        } else if (_match('>')) {
          _addToken(TokenType.arrow);
        }
      case '<':
        if (_match('=')) {
          _addToken(TokenType.lessEqual);
        } else {
          _addToken(TokenType.less);
        }
      case '>':
        if (_match('=')) {
          _addToken(TokenType.greaterEqual);
        } else {
          _addToken(TokenType.greater);
        }
      case '&':
        if (_match('&')) {
          _addToken(TokenType.ampAmp);
        }
      case '|':
        if (_match('|')) {
          _addToken(TokenType.pipePipe);
        } else {
          _addToken(TokenType.pipe);
        }
      case '\$':
        if (_match('{')) {
          _addToken(TokenType.dollarBrace);
        }
      case "'":
        _string("'");
      case '"':
        _string('"');
      case ' ':
      case '\t':
      case '\r':
      case '\n':
        // Skip whitespace
        break;
      default:
        if (_isDigit(c)) {
          _number();
        } else if (_isAlpha(c)) {
          _identifier();
        } else {
          throw SyntaxException(
              _source, _start, 'Unexpected character: $c');
        }
    }
  }

  void _string(String quote) {
    while (!_isAtEnd() && _peek() != quote) {
      if (_peek() == '\\') {
        _advance(); // Skip escape character
      }
      _advance();
    }

    if (_isAtEnd()) {
      throw SyntaxException(_source, _start, 'Unterminated string');
    }

    _advance(); // Closing quote
    final value = _source.substring(_start + 1, _current - 1);
    final unescaped = _unescape(value);
    _addToken(TokenType.string, literal: unescaped);
  }

  void _number() {
    while (!_isAtEnd() && _isDigit(_peek())) {
      _advance();
    }

    // Decimal part
    if (!_isAtEnd() &&
        _peek() == '.' &&
        _current + 1 < _source.length &&
        _isDigit(_source[_current + 1])) {
      _advance(); // Consume '.'
      while (!_isAtEnd() && _isDigit(_peek())) {
        _advance();
      }
    }

    final value = num.parse(_source.substring(_start, _current));
    _addToken(TokenType.number, literal: value);
  }

  void _identifier() {
    while (!_isAtEnd() && _isAlphaNumeric(_peek())) {
      _advance();
    }

    final text = _source.substring(_start, _current);
    final type = switch (text) {
      'true' => TokenType.boolTrue,
      'false' => TokenType.boolFalse,
      'null' => TokenType.nullLiteral,
      'and' => TokenType.and,
      'or' => TokenType.or,
      'not' => TokenType.not,
      'in' => TokenType.inKeyword,
      'matches' => TokenType.matches,
      _ => TokenType.identifier,
    };
    _addToken(type);
  }

  String _advance() {
    return _source[_current++];
  }

  bool _match(String expected) {
    if (_isAtEnd() || _source[_current] != expected) return false;
    _current++;
    return true;
  }

  String _peek() => _source[_current];

  bool _isAtEnd() => _current >= _source.length;
  bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  bool _isAlpha(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        c == '_';
  }

  bool _isAlphaNumeric(String c) => _isAlpha(c) || _isDigit(c);

  void _addToken(TokenType type, {dynamic literal}) {
    final text = _source.substring(_start, _current);
    _tokens.add(Token(type, text, _start, literal: literal));
  }

  String _unescape(String value) {
    return value
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\\', '\\');
  }
}
