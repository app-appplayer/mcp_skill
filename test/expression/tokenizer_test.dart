import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/tokenizer.dart';
import 'package:mcp_skill/src/expression/expression_exception.dart';

void main() {
  // Helper to tokenize and return the token list (excluding EOF).
  List<Token> tokenize(String source) {
    final tokens = Tokenizer(source).tokenize();
    // Remove trailing EOF for easier assertions
    return tokens.where((t) => t.type != TokenType.eof).toList();
  }

  // Helper to get just the types from tokens (excluding EOF).
  List<TokenType> types(String source) =>
      tokenize(source).map((t) => t.type).toList();

  group('Tokenizer', () {
    // ------------------------------------------------------------------
    // Number literals
    // ------------------------------------------------------------------
    group('numbers', () {
      test('tokenizes integer literals', () {
        final tokens = tokenize('42');
        expect(tokens, hasLength(1));
        expect(tokens[0].type, equals(TokenType.number));
        expect(tokens[0].literal, equals(42));
        expect(tokens[0].lexeme, equals('42'));
      });

      test('tokenizes zero', () {
        final tokens = tokenize('0');
        expect(tokens[0].literal, equals(0));
      });

      test('tokenizes multi-digit integers', () {
        final tokens = tokenize('12345');
        expect(tokens[0].literal, equals(12345));
      });

      test('tokenizes floating-point numbers', () {
        final tokens = tokenize('3.14');
        expect(tokens, hasLength(1));
        expect(tokens[0].type, equals(TokenType.number));
        expect(tokens[0].literal, equals(3.14));
      });

      test('tokenizes float with leading digits', () {
        final tokens = tokenize('100.5');
        expect(tokens[0].literal, equals(100.5));
      });

      test('tokenizes number followed by dot as separate tokens when no digit after dot', () {
        // 42. followed by a non-digit should parse as number 42 then dot
        final tokens = tokenize('42.foo');
        expect(tokens[0].type, equals(TokenType.number));
        expect(tokens[0].literal, equals(42));
        expect(tokens[1].type, equals(TokenType.dot));
        expect(tokens[2].type, equals(TokenType.identifier));
        expect(tokens[2].lexeme, equals('foo'));
      });
    });

    // ------------------------------------------------------------------
    // String literals
    // ------------------------------------------------------------------
    group('strings', () {
      test('tokenizes single-quoted strings', () {
        final tokens = tokenize("'hello'");
        expect(tokens, hasLength(1));
        expect(tokens[0].type, equals(TokenType.string));
        expect(tokens[0].literal, equals('hello'));
      });

      test('tokenizes double-quoted strings', () {
        final tokens = tokenize('"world"');
        expect(tokens, hasLength(1));
        expect(tokens[0].type, equals(TokenType.string));
        expect(tokens[0].literal, equals('world'));
      });

      test('tokenizes empty strings', () {
        final tokens = tokenize("''");
        expect(tokens[0].literal, equals(''));
      });

      test('tokenizes strings with escape sequences - newline', () {
        final tokens = tokenize(r"'hello\nworld'");
        expect(tokens[0].literal, equals('hello\nworld'));
      });

      test('tokenizes strings with escape sequences - tab', () {
        final tokens = tokenize(r"'col1\tcol2'");
        expect(tokens[0].literal, equals('col1\tcol2'));
      });

      test('tokenizes strings with escaped single quotes', () {
        final tokens = tokenize(r"'it\'s'");
        expect(tokens[0].literal, equals("it's"));
      });

      test('tokenizes strings with escaped double quotes', () {
        final tokens = tokenize(r'"say \"hi\""');
        expect(tokens[0].literal, equals('say "hi"'));
      });

      test('tokenizes strings with escaped backslash', () {
        final tokens = tokenize(r"'path\\dir'");
        expect(tokens[0].literal, equals('path\\dir'));
      });

      test('throws on unterminated single-quoted string', () {
        expect(
          () => Tokenizer("'hello").tokenize(),
          throwsA(isA<SyntaxException>()),
        );
      });

      test('throws on unterminated double-quoted string', () {
        expect(
          () => Tokenizer('"hello').tokenize(),
          throwsA(isA<SyntaxException>()),
        );
      });

      test('unterminated string exception has position info', () {
        try {
          Tokenizer("'oops").tokenize();
          fail('Expected SyntaxException');
        } on SyntaxException catch (e) {
          expect(e.position, equals(0));
          expect(e.message, contains('Unterminated string'));
        }
      });
    });

    // ------------------------------------------------------------------
    // Identifiers and keywords
    // ------------------------------------------------------------------
    group('identifiers and keywords', () {
      test('tokenizes simple identifiers', () {
        final tokens = tokenize('foo');
        expect(tokens[0].type, equals(TokenType.identifier));
        expect(tokens[0].lexeme, equals('foo'));
      });

      test('tokenizes identifiers with underscores', () {
        final tokens = tokenize('my_var');
        expect(tokens[0].type, equals(TokenType.identifier));
        expect(tokens[0].lexeme, equals('my_var'));
      });

      test('tokenizes identifiers starting with underscore', () {
        final tokens = tokenize('_private');
        expect(tokens[0].type, equals(TokenType.identifier));
      });

      test('tokenizes identifiers with digits', () {
        final tokens = tokenize('var2');
        expect(tokens[0].type, equals(TokenType.identifier));
        expect(tokens[0].lexeme, equals('var2'));
      });

      test('tokenizes keyword true', () {
        expect(types('true'), equals([TokenType.boolTrue]));
      });

      test('tokenizes keyword false', () {
        expect(types('false'), equals([TokenType.boolFalse]));
      });

      test('tokenizes keyword null', () {
        expect(types('null'), equals([TokenType.nullLiteral]));
      });

      test('tokenizes keyword and', () {
        expect(types('and'), equals([TokenType.and]));
      });

      test('tokenizes keyword or', () {
        expect(types('or'), equals([TokenType.or]));
      });

      test('tokenizes keyword not', () {
        expect(types('not'), equals([TokenType.not]));
      });

      test('tokenizes keyword in', () {
        expect(types('in'), equals([TokenType.inKeyword]));
      });

      test('tokenizes keyword matches', () {
        expect(types('matches'), equals([TokenType.matches]));
      });

      test('does not treat partial keyword as keyword', () {
        // "trueish" should be an identifier, not boolTrue
        final tokens = tokenize('trueish');
        expect(tokens[0].type, equals(TokenType.identifier));
        expect(tokens[0].lexeme, equals('trueish'));
      });
    });

    // ------------------------------------------------------------------
    // Arithmetic operators
    // ------------------------------------------------------------------
    group('arithmetic operators', () {
      test('tokenizes plus', () {
        expect(types('+'), equals([TokenType.plus]));
      });

      test('tokenizes minus', () {
        expect(types('-'), equals([TokenType.minus]));
      });

      test('tokenizes star (multiply)', () {
        expect(types('*'), equals([TokenType.star]));
      });

      test('tokenizes slash (divide)', () {
        expect(types('/'), equals([TokenType.slash]));
      });

      test('tokenizes percent (modulo)', () {
        expect(types('%'), equals([TokenType.percent]));
      });

      test('tokenizes power operator **', () {
        expect(types('**'), equals([TokenType.power]));
      });

      test('tokenizes full arithmetic expression', () {
        final result = types('1 + 2 * 3');
        expect(result, equals([
          TokenType.number,
          TokenType.plus,
          TokenType.number,
          TokenType.star,
          TokenType.number,
        ]));
      });
    });

    // ------------------------------------------------------------------
    // Comparison operators
    // ------------------------------------------------------------------
    group('comparison operators', () {
      test('tokenizes equality ==', () {
        expect(types('=='), equals([TokenType.equal]));
      });

      test('tokenizes inequality !=', () {
        expect(types('!='), equals([TokenType.notEqual]));
      });

      test('tokenizes less than <', () {
        expect(types('<'), equals([TokenType.less]));
      });

      test('tokenizes greater than >', () {
        expect(types('>'), equals([TokenType.greater]));
      });

      test('tokenizes less than or equal <=', () {
        expect(types('<='), equals([TokenType.lessEqual]));
      });

      test('tokenizes greater than or equal >=', () {
        expect(types('>='), equals([TokenType.greaterEqual]));
      });
    });

    // ------------------------------------------------------------------
    // Logical operators
    // ------------------------------------------------------------------
    group('logical operators', () {
      test('tokenizes && (ampAmp)', () {
        expect(types('&&'), equals([TokenType.ampAmp]));
      });

      test('tokenizes || (pipePipe)', () {
        expect(types('||'), equals([TokenType.pipePipe]));
      });

      test('tokenizes ! (bang)', () {
        expect(types('!'), equals([TokenType.bang]));
      });
    });

    // ------------------------------------------------------------------
    // Null and optional operators
    // ------------------------------------------------------------------
    group('null and optional operators', () {
      test('tokenizes ? (question)', () {
        expect(types('?'), equals([TokenType.question]));
      });

      test('tokenizes ?? (questionQuestion)', () {
        expect(types('??'), equals([TokenType.questionQuestion]));
      });

      test('tokenizes ?. (optionalDot)', () {
        expect(types('?.'), equals([TokenType.optionalDot]));
      });
    });

    // ------------------------------------------------------------------
    // Other operators
    // ------------------------------------------------------------------
    group('other operators', () {
      test('tokenizes dot', () {
        expect(types('.'), equals([TokenType.dot]));
      });

      test('tokenizes pipe |', () {
        expect(types('|'), equals([TokenType.pipe]));
      });

      test('tokenizes arrow =>', () {
        expect(types('=>'), equals([TokenType.arrow]));
      });

      test('tokenizes colon', () {
        expect(types(':'), equals([TokenType.colon]));
      });
    });

    // ------------------------------------------------------------------
    // Delimiters
    // ------------------------------------------------------------------
    group('delimiters', () {
      test('tokenizes left paren', () {
        expect(types('('), equals([TokenType.leftParen]));
      });

      test('tokenizes right paren', () {
        expect(types(')'), equals([TokenType.rightParen]));
      });

      test('tokenizes left bracket', () {
        expect(types('['), equals([TokenType.leftBracket]));
      });

      test('tokenizes right bracket', () {
        expect(types(']'), equals([TokenType.rightBracket]));
      });

      test('tokenizes left brace', () {
        expect(types('{'), equals([TokenType.leftBrace]));
      });

      test('tokenizes right brace', () {
        expect(types('}'), equals([TokenType.rightBrace]));
      });

      test('tokenizes comma', () {
        expect(types(','), equals([TokenType.comma]));
      });

      test('tokenizes matched parens', () {
        final result = types('(a)');
        expect(result, equals([
          TokenType.leftParen,
          TokenType.identifier,
          TokenType.rightParen,
        ]));
      });
    });

    // ------------------------------------------------------------------
    // Template literal / Interpolation
    // ------------------------------------------------------------------
    group('interpolation', () {
      test('tokenizes dollar-brace', () {
        expect(types(r'${'), equals([TokenType.dollarBrace]));
      });

      test('tokenizes interpolation expression', () {
        final result = types(r'${name}');
        expect(result, equals([
          TokenType.dollarBrace,
          TokenType.identifier,
          TokenType.rightBrace,
        ]));
      });

      test('tokenizes nested interpolation expression', () {
        final result = types(r'${a + b}');
        expect(result, equals([
          TokenType.dollarBrace,
          TokenType.identifier,
          TokenType.plus,
          TokenType.identifier,
          TokenType.rightBrace,
        ]));
      });
    });

    // ------------------------------------------------------------------
    // Whitespace handling
    // ------------------------------------------------------------------
    group('whitespace', () {
      test('skips spaces', () {
        final tokens = tokenize('  42  ');
        expect(tokens, hasLength(1));
        expect(tokens[0].literal, equals(42));
      });

      test('skips tabs', () {
        final tokens = tokenize('\t42\t');
        expect(tokens, hasLength(1));
      });

      test('skips newlines and carriage returns', () {
        final tokens = tokenize('\r\n42\n');
        expect(tokens, hasLength(1));
      });

      test('skips mixed whitespace between tokens', () {
        final tokens = tokenize('  a  +  b  ');
        expect(tokens, hasLength(3));
      });
    });

    // ------------------------------------------------------------------
    // Error handling
    // ------------------------------------------------------------------
    group('error handling', () {
      test('throws SyntaxException on unexpected character', () {
        expect(
          () => Tokenizer('@').tokenize(),
          throwsA(isA<SyntaxException>()),
        );
      });

      test('error includes character info', () {
        try {
          Tokenizer('~').tokenize();
          fail('Expected SyntaxException');
        } on SyntaxException catch (e) {
          expect(e.message, contains('Unexpected character'));
          expect(e.position, equals(0));
        }
      });

      test('error position is correct for mid-expression unexpected character', () {
        try {
          Tokenizer('a + @').tokenize();
          fail('Expected SyntaxException');
        } on SyntaxException catch (e) {
          expect(e.position, equals(4));
        }
      });
    });

    // ------------------------------------------------------------------
    // Complex expressions
    // ------------------------------------------------------------------
    group('complex expressions', () {
      test('tokenizes function call', () {
        final result = types('length(name)');
        expect(result, equals([
          TokenType.identifier,
          TokenType.leftParen,
          TokenType.identifier,
          TokenType.rightParen,
        ]));
      });

      test('tokenizes member access chain', () {
        final result = types('inputs.user.name');
        expect(result, equals([
          TokenType.identifier,
          TokenType.dot,
          TokenType.identifier,
          TokenType.dot,
          TokenType.identifier,
        ]));
      });

      test('tokenizes ternary expression', () {
        final result = types('a ? b : c');
        expect(result, equals([
          TokenType.identifier,
          TokenType.question,
          TokenType.identifier,
          TokenType.colon,
          TokenType.identifier,
        ]));
      });

      test('tokenizes null-coalesce expression', () {
        final result = types('a ?? b');
        expect(result, equals([
          TokenType.identifier,
          TokenType.questionQuestion,
          TokenType.identifier,
        ]));
      });

      test('tokenizes optional chaining expression', () {
        final result = types('a?.b?.c');
        expect(result, equals([
          TokenType.identifier,
          TokenType.optionalDot,
          TokenType.identifier,
          TokenType.optionalDot,
          TokenType.identifier,
        ]));
      });

      test('tokenizes array literal', () {
        final result = types('[1, 2, 3]');
        expect(result, equals([
          TokenType.leftBracket,
          TokenType.number,
          TokenType.comma,
          TokenType.number,
          TokenType.comma,
          TokenType.number,
          TokenType.rightBracket,
        ]));
      });

      test('tokenizes object literal', () {
        final result = types('{a: 1, b: 2}');
        expect(result, equals([
          TokenType.leftBrace,
          TokenType.identifier,
          TokenType.colon,
          TokenType.number,
          TokenType.comma,
          TokenType.identifier,
          TokenType.colon,
          TokenType.number,
          TokenType.rightBrace,
        ]));
      });

      test('tokenizes lambda expression', () {
        final result = types('x => x + 1');
        expect(result, equals([
          TokenType.identifier,
          TokenType.arrow,
          TokenType.identifier,
          TokenType.plus,
          TokenType.number,
        ]));
      });

      test('tokenizes pipe expression', () {
        final result = types('name | upper');
        expect(result, equals([
          TokenType.identifier,
          TokenType.pipe,
          TokenType.identifier,
        ]));
      });

      test('tokenizes complex boolean expression', () {
        final result = types('a > 0 && b < 10 || c == true');
        expect(result, equals([
          TokenType.identifier,
          TokenType.greater,
          TokenType.number,
          TokenType.ampAmp,
          TokenType.identifier,
          TokenType.less,
          TokenType.number,
          TokenType.pipePipe,
          TokenType.identifier,
          TokenType.equal,
          TokenType.boolTrue,
        ]));
      });

      test('tokenizes index access', () {
        final result = types('arr[0]');
        expect(result, equals([
          TokenType.identifier,
          TokenType.leftBracket,
          TokenType.number,
          TokenType.rightBracket,
        ]));
      });

      test('tokenizes function call with multiple args', () {
        final result = types("substring('hello', 1, 3)");
        expect(result, equals([
          TokenType.identifier,
          TokenType.leftParen,
          TokenType.string,
          TokenType.comma,
          TokenType.number,
          TokenType.comma,
          TokenType.number,
          TokenType.rightParen,
        ]));
      });
    });

    // ------------------------------------------------------------------
    // Token position tracking
    // ------------------------------------------------------------------
    group('position tracking', () {
      test('tracks position of first token', () {
        final tokens = tokenize('abc');
        expect(tokens[0].position, equals(0));
      });

      test('tracks position after whitespace', () {
        final tokens = tokenize('  abc');
        expect(tokens[0].position, equals(2));
      });

      test('tracks positions of multiple tokens', () {
        final tokens = tokenize('a + b');
        expect(tokens[0].position, equals(0)); // a
        expect(tokens[1].position, equals(2)); // +
        expect(tokens[2].position, equals(4)); // b
      });
    });

    // ------------------------------------------------------------------
    // EOF token
    // ------------------------------------------------------------------
    group('EOF', () {
      test('empty input produces only EOF', () {
        final tokens = Tokenizer('').tokenize();
        expect(tokens, hasLength(1));
        expect(tokens[0].type, equals(TokenType.eof));
      });

      test('last token is always EOF', () {
        final tokens = Tokenizer('42').tokenize();
        expect(tokens.last.type, equals(TokenType.eof));
      });

      test('EOF position matches source length', () {
        const src = 'abc';
        final tokens = Tokenizer(src).tokenize();
        expect(tokens.last.position, equals(src.length));
      });
    });

    // ------------------------------------------------------------------
    // Token toString
    // ------------------------------------------------------------------
    group('Token toString', () {
      test('produces readable representation', () {
        final token = Token(TokenType.number, '42', 0, literal: 42);
        expect(token.toString(), contains('number'));
        expect(token.toString(), contains('42'));
      });
    });
  });
}
