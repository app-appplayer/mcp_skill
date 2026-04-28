import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/tokenizer.dart';
import 'package:mcp_skill/src/expression/parser.dart';
import 'package:mcp_skill/src/expression/ast.dart';
import 'package:mcp_skill/src/expression/expression_exception.dart';

void main() {
  // Helper: parse an expression string to an AST node.
  AstNode parse(String source) {
    final tokens = Tokenizer(source).tokenize();
    return Parser(tokens).parse();
  }

  group('Parser', () {
    // ------------------------------------------------------------------
    // Literal expressions
    // ------------------------------------------------------------------
    group('literals', () {
      test('parses integer literal', () {
        final node = parse('42');
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, equals(42));
      });

      test('parses float literal', () {
        final node = parse('3.14');
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, equals(3.14));
      });

      test('parses string literal (single quotes)', () {
        final node = parse("'hello'");
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, equals('hello'));
      });

      test('parses string literal (double quotes)', () {
        final node = parse('"world"');
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, equals('world'));
      });

      test('parses true', () {
        final node = parse('true');
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, isTrue);
      });

      test('parses false', () {
        final node = parse('false');
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, isFalse);
      });

      test('parses null', () {
        final node = parse('null');
        expect(node, isA<LiteralExpr>());
        expect((node as LiteralExpr).value, isNull);
      });
    });

    // ------------------------------------------------------------------
    // Identifiers
    // ------------------------------------------------------------------
    group('identifiers', () {
      test('parses simple identifier', () {
        final node = parse('inputs');
        expect(node, isA<IdentifierExpr>());
        expect((node as IdentifierExpr).name, equals('inputs'));
      });

      test('parses identifier with underscore', () {
        final node = parse('my_var');
        expect(node, isA<IdentifierExpr>());
        expect((node as IdentifierExpr).name, equals('my_var'));
      });
    });

    // ------------------------------------------------------------------
    // Member access
    // ------------------------------------------------------------------
    group('member access', () {
      test('parses simple member access', () {
        final node = parse('a.b');
        expect(node, isA<MemberExpr>());
        final member = node as MemberExpr;
        expect(member.property, equals('b'));
        expect(member.isOptional, isFalse);
        expect(member.object, isA<IdentifierExpr>());
        expect((member.object as IdentifierExpr).name, equals('a'));
      });

      test('parses chained member access', () {
        final node = parse('a.b.c');
        expect(node, isA<MemberExpr>());
        final outer = node as MemberExpr;
        expect(outer.property, equals('c'));
        expect(outer.object, isA<MemberExpr>());
        final inner = outer.object as MemberExpr;
        expect(inner.property, equals('b'));
      });

      test('parses optional member access', () {
        final node = parse('a?.b');
        expect(node, isA<MemberExpr>());
        final member = node as MemberExpr;
        expect(member.property, equals('b'));
        expect(member.isOptional, isTrue);
      });

      test('parses chained optional member access', () {
        final node = parse('a?.b?.c');
        expect(node, isA<MemberExpr>());
        final outer = node as MemberExpr;
        expect(outer.isOptional, isTrue);
        expect(outer.property, equals('c'));
        final inner = outer.object as MemberExpr;
        expect(inner.isOptional, isTrue);
        expect(inner.property, equals('b'));
      });
    });

    // ------------------------------------------------------------------
    // Index access
    // ------------------------------------------------------------------
    group('index access', () {
      test('parses index access with number', () {
        final node = parse('a[0]');
        expect(node, isA<IndexExpr>());
        final idx = node as IndexExpr;
        expect(idx.object, isA<IdentifierExpr>());
        expect(idx.index, isA<LiteralExpr>());
        expect((idx.index as LiteralExpr).value, equals(0));
      });

      test('parses index access with string key', () {
        final node = parse("a['key']");
        expect(node, isA<IndexExpr>());
        final idx = node as IndexExpr;
        expect((idx.index as LiteralExpr).value, equals('key'));
      });

      test('parses chained index access', () {
        final node = parse('a[0][1]');
        expect(node, isA<IndexExpr>());
        final outer = node as IndexExpr;
        expect(outer.object, isA<IndexExpr>());
      });

      test('parses index after member access', () {
        final node = parse('a.b[0]');
        expect(node, isA<IndexExpr>());
        final idx = node as IndexExpr;
        expect(idx.object, isA<MemberExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Function calls
    // ------------------------------------------------------------------
    group('function calls', () {
      test('parses function call with no arguments', () {
        final node = parse('now()');
        expect(node, isA<CallExpr>());
        final call = node as CallExpr;
        expect(call.callee, isA<IdentifierExpr>());
        expect((call.callee as IdentifierExpr).name, equals('now'));
        expect(call.arguments, isEmpty);
      });

      test('parses function call with one argument', () {
        final node = parse('length(x)');
        expect(node, isA<CallExpr>());
        final call = node as CallExpr;
        expect(call.arguments, hasLength(1));
      });

      test('parses function call with multiple arguments', () {
        final node = parse('min(a, b)');
        expect(node, isA<CallExpr>());
        final call = node as CallExpr;
        expect(call.arguments, hasLength(2));
      });

      test('parses nested function calls', () {
        final node = parse('upper(trim(name))');
        expect(node, isA<CallExpr>());
        final outer = node as CallExpr;
        expect(outer.arguments[0], isA<CallExpr>());
      });

      test('parses function call with expression arguments', () {
        final node = parse('max(a + 1, b * 2)');
        expect(node, isA<CallExpr>());
        final call = node as CallExpr;
        expect(call.arguments, hasLength(2));
        expect(call.arguments[0], isA<BinaryExpr>());
        expect(call.arguments[1], isA<BinaryExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Unary expressions
    // ------------------------------------------------------------------
    group('unary expressions', () {
      test('parses logical not (!)', () {
        final node = parse('!x');
        expect(node, isA<UnaryExpr>());
        final unary = node as UnaryExpr;
        expect(unary.operator, equals('!'));
        expect(unary.operand, isA<IdentifierExpr>());
      });

      test('parses negation (-)', () {
        final node = parse('-5');
        expect(node, isA<UnaryExpr>());
        final unary = node as UnaryExpr;
        expect(unary.operator, equals('-'));
        expect(unary.operand, isA<LiteralExpr>());
      });

      test('parses not keyword', () {
        final node = parse('not x');
        expect(node, isA<UnaryExpr>());
        final unary = node as UnaryExpr;
        expect(unary.operator, equals('not'));
      });

      test('parses double negation', () {
        final node = parse('!!x');
        expect(node, isA<UnaryExpr>());
        final outer = node as UnaryExpr;
        expect(outer.operand, isA<UnaryExpr>());
      });

      test('parses negative expression', () {
        final node = parse('-(a + b)');
        expect(node, isA<UnaryExpr>());
        final unary = node as UnaryExpr;
        expect(unary.operator, equals('-'));
        expect(unary.operand, isA<GroupingExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Arithmetic expressions
    // ------------------------------------------------------------------
    group('arithmetic', () {
      test('parses addition', () {
        final node = parse('1 + 2');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('+'));
        expect((bin.left as LiteralExpr).value, equals(1));
        expect((bin.right as LiteralExpr).value, equals(2));
      });

      test('parses subtraction', () {
        final node = parse('5 - 3');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('-'));
      });

      test('parses multiplication', () {
        final node = parse('2 * 3');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('*'));
      });

      test('parses division', () {
        final node = parse('10 / 2');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('/'));
      });

      test('parses modulo', () {
        final node = parse('10 % 3');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('%'));
      });

      test('parses power', () {
        final node = parse('2 ** 3');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('**'));
      });

      test('respects multiplication precedence over addition', () {
        // 1 + 2 * 3 should be 1 + (2 * 3)
        final node = parse('1 + 2 * 3');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('+'));
        expect(bin.right, isA<BinaryExpr>());
        expect((bin.right as BinaryExpr).operator, equals('*'));
      });

      test('respects left associativity for addition', () {
        // 1 + 2 + 3 should be (1 + 2) + 3
        final node = parse('1 + 2 + 3');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('+'));
        expect(bin.left, isA<BinaryExpr>());
        expect((bin.left as BinaryExpr).operator, equals('+'));
      });

      test('power is right-associative', () {
        // 2 ** 3 ** 2 should be 2 ** (3 ** 2)
        final node = parse('2 ** 3 ** 2');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('**'));
        expect(bin.right, isA<BinaryExpr>());
        expect((bin.right as BinaryExpr).operator, equals('**'));
      });
    });

    // ------------------------------------------------------------------
    // Comparison expressions
    // ------------------------------------------------------------------
    group('comparisons', () {
      test('parses equals', () {
        final node = parse('a == b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('=='));
      });

      test('parses not equals', () {
        final node = parse('a != b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('!='));
      });

      test('parses less than', () {
        final node = parse('a < b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('<'));
      });

      test('parses greater than', () {
        final node = parse('a > b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('>'));
      });

      test('parses less than or equal', () {
        final node = parse('a <= b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('<='));
      });

      test('parses greater than or equal', () {
        final node = parse('a >= b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('>='));
      });

      test('comparison has lower precedence than arithmetic', () {
        // a + 1 > b should be (a + 1) > b
        final node = parse('a + 1 > b');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('>'));
        expect(bin.left, isA<BinaryExpr>());
        expect((bin.left as BinaryExpr).operator, equals('+'));
      });
    });

    // ------------------------------------------------------------------
    // Logical expressions
    // ------------------------------------------------------------------
    group('logical expressions', () {
      test('parses logical AND (&&)', () {
        final node = parse('a && b');
        expect(node, isA<LogicalExpr>());
        expect((node as LogicalExpr).operator, equals('&&'));
      });

      test('parses logical OR (||)', () {
        final node = parse('a || b');
        expect(node, isA<LogicalExpr>());
        expect((node as LogicalExpr).operator, equals('||'));
      });

      test('parses keyword and', () {
        final node = parse('a and b');
        expect(node, isA<LogicalExpr>());
        expect((node as LogicalExpr).operator, equals('and'));
      });

      test('parses keyword or', () {
        final node = parse('a or b');
        expect(node, isA<LogicalExpr>());
        expect((node as LogicalExpr).operator, equals('or'));
      });

      test('AND has higher precedence than OR', () {
        // a || b && c should be a || (b && c)
        final node = parse('a || b && c');
        expect(node, isA<LogicalExpr>());
        final logical = node as LogicalExpr;
        expect(logical.operator, equals('||'));
        expect(logical.right, isA<LogicalExpr>());
        expect((logical.right as LogicalExpr).operator, equals('&&'));
      });

      test('parses chained AND', () {
        // a && b && c should be (a && b) && c
        final node = parse('a && b && c');
        expect(node, isA<LogicalExpr>());
        final outer = node as LogicalExpr;
        expect(outer.left, isA<LogicalExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Membership (in, matches)
    // ------------------------------------------------------------------
    group('membership', () {
      test('parses in expression', () {
        final node = parse('a in b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('in'));
      });

      test('parses matches expression', () {
        final node = parse('a matches b');
        expect(node, isA<BinaryExpr>());
        expect((node as BinaryExpr).operator, equals('matches'));
      });
    });

    // ------------------------------------------------------------------
    // Ternary / Conditional
    // ------------------------------------------------------------------
    group('conditional (ternary)', () {
      test('parses simple ternary', () {
        final node = parse('a ? b : c');
        expect(node, isA<ConditionalExpr>());
        final cond = node as ConditionalExpr;
        expect(cond.condition, isA<IdentifierExpr>());
        expect(cond.thenBranch, isA<IdentifierExpr>());
        expect(cond.elseBranch, isA<IdentifierExpr>());
      });

      test('parses ternary with comparison condition', () {
        final node = parse('x > 0 ? x : 0');
        expect(node, isA<ConditionalExpr>());
        final cond = node as ConditionalExpr;
        expect(cond.condition, isA<BinaryExpr>());
      });

      test('parses nested ternary in else branch', () {
        final node = parse('a ? b : c ? d : e');
        expect(node, isA<ConditionalExpr>());
        final outer = node as ConditionalExpr;
        expect(outer.elseBranch, isA<ConditionalExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Null coalescing
    // ------------------------------------------------------------------
    group('null coalescing', () {
      test('parses simple null coalesce', () {
        final node = parse('a ?? b');
        expect(node, isA<NullCoalesceExpr>());
        final nc = node as NullCoalesceExpr;
        expect(nc.left, isA<IdentifierExpr>());
        expect(nc.right, isA<IdentifierExpr>());
      });

      test('parses chained null coalesce', () {
        // a ?? b ?? c should be (a ?? b) ?? c
        final node = parse('a ?? b ?? c');
        expect(node, isA<NullCoalesceExpr>());
        final outer = node as NullCoalesceExpr;
        expect(outer.left, isA<NullCoalesceExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Pipe
    // ------------------------------------------------------------------
    group('pipe', () {
      test('parses simple pipe', () {
        final node = parse('name | upper');
        expect(node, isA<PipeExpr>());
        final pipe = node as PipeExpr;
        expect(pipe.value, isA<IdentifierExpr>());
        expect(pipe.transform, isA<IdentifierExpr>());
      });

      test('parses chained pipe', () {
        final node = parse('name | trim | upper');
        expect(node, isA<PipeExpr>());
        final outer = node as PipeExpr;
        expect(outer.transform, isA<IdentifierExpr>());
        expect(outer.value, isA<PipeExpr>());
      });

      test('pipe has lower precedence than arithmetic', () {
        // 1 + 2 | abs should be (1 + 2) | abs
        final node = parse('1 + 2 | abs');
        expect(node, isA<PipeExpr>());
        final pipe = node as PipeExpr;
        expect(pipe.value, isA<BinaryExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Lambda
    // ------------------------------------------------------------------
    group('lambda', () {
      test('parses simple lambda', () {
        final node = parse('x => x');
        expect(node, isA<LambdaExpr>());
        final lambda = node as LambdaExpr;
        expect(lambda.parameter, equals('x'));
        expect(lambda.body, isA<IdentifierExpr>());
      });

      test('parses lambda with expression body', () {
        final node = parse('x => x + 1');
        expect(node, isA<LambdaExpr>());
        final lambda = node as LambdaExpr;
        expect(lambda.body, isA<BinaryExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Array literals
    // ------------------------------------------------------------------
    group('array literals', () {
      test('parses empty array', () {
        final node = parse('[]');
        expect(node, isA<ArrayExpr>());
        expect((node as ArrayExpr).elements, isEmpty);
      });

      test('parses array with elements', () {
        final node = parse('[1, 2, 3]');
        expect(node, isA<ArrayExpr>());
        final arr = node as ArrayExpr;
        expect(arr.elements, hasLength(3));
        expect(arr.elements[0], isA<LiteralExpr>());
      });

      test('parses array with mixed types', () {
        final node = parse("[1, 'two', true, null]");
        expect(node, isA<ArrayExpr>());
        expect((node as ArrayExpr).elements, hasLength(4));
      });

      test('parses nested arrays', () {
        final node = parse('[[1, 2], [3, 4]]');
        expect(node, isA<ArrayExpr>());
        final arr = node as ArrayExpr;
        expect(arr.elements, hasLength(2));
        expect(arr.elements[0], isA<ArrayExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Object literals
    // ------------------------------------------------------------------
    group('object literals', () {
      test('parses empty object', () {
        final node = parse('{}');
        expect(node, isA<ObjectExpr>());
        expect((node as ObjectExpr).entries, isEmpty);
      });

      test('parses object with entries', () {
        final node = parse('{a: 1, b: 2}');
        expect(node, isA<ObjectExpr>());
        final obj = node as ObjectExpr;
        expect(obj.entries, hasLength(2));
        expect(obj.entries[0].key, equals('a'));
        expect(obj.entries[1].key, equals('b'));
      });

      test('parses object with expression values', () {
        final node = parse('{x: 1 + 2}');
        expect(node, isA<ObjectExpr>());
        final obj = node as ObjectExpr;
        expect(obj.entries[0].value, isA<BinaryExpr>());
      });

      test('parses nested objects', () {
        final node = parse('{a: {b: 1}}');
        expect(node, isA<ObjectExpr>());
        final obj = node as ObjectExpr;
        expect(obj.entries[0].value, isA<ObjectExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Grouping
    // ------------------------------------------------------------------
    group('grouping', () {
      test('parses grouped expression', () {
        final node = parse('(a)');
        expect(node, isA<GroupingExpr>());
        expect((node as GroupingExpr).expression, isA<IdentifierExpr>());
      });

      test('grouping overrides precedence', () {
        // (1 + 2) * 3 should have addition inside grouping
        final node = parse('(1 + 2) * 3');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('*'));
        expect(bin.left, isA<GroupingExpr>());
      });

      test('parses nested groupings', () {
        final node = parse('((a))');
        expect(node, isA<GroupingExpr>());
        expect((node as GroupingExpr).expression, isA<GroupingExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Complex nested expressions
    // ------------------------------------------------------------------
    group('complex nested expressions', () {
      test('parses member access with function call', () {
        final node = parse('length(inputs.name)');
        expect(node, isA<CallExpr>());
        final call = node as CallExpr;
        expect(call.arguments[0], isA<MemberExpr>());
      });

      test('parses ternary with comparisons and function calls', () {
        final node = parse('length(name) > 0 ? name : "default"');
        expect(node, isA<ConditionalExpr>());
      });

      test('parses complex boolean with member access', () {
        final node = parse('a.x > 0 && b.y < 10');
        expect(node, isA<LogicalExpr>());
      });

      test('parses arithmetic with function calls', () {
        final node = parse('min(a, b) + max(c, d)');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.left, isA<CallExpr>());
        expect(bin.right, isA<CallExpr>());
      });

      test('parses null coalesce with member access', () {
        final node = parse('a?.b ?? c');
        expect(node, isA<NullCoalesceExpr>());
        final nc = node as NullCoalesceExpr;
        expect(nc.left, isA<MemberExpr>());
      });
    });

    // ------------------------------------------------------------------
    // Error recovery
    // ------------------------------------------------------------------
    group('error recovery', () {
      test('throws on empty expression', () {
        expect(() => parse(''), throwsA(isA<SyntaxException>()));
      });

      test('throws on trailing tokens', () {
        expect(() => parse('a b'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing closing paren', () {
        expect(() => parse('(a'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing closing bracket', () {
        expect(() => parse('a[0'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing colon in ternary', () {
        expect(() => parse('a ? b c'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing property after dot', () {
        expect(() => parse('a.'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing colon in object literal', () {
        expect(() => parse('{a 1}'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing closing brace', () {
        expect(() => parse('{a: 1'), throwsA(isA<SyntaxException>()));
      });

      test('throws on missing closing bracket in array', () {
        expect(() => parse('[1, 2'), throwsA(isA<SyntaxException>()));
      });

      test('throws on unexpected token as expression start', () {
        expect(() => parse(')'), throwsA(isA<SyntaxException>()));
      });
    });

    // ------------------------------------------------------------------
    // Precedence integration tests
    // ------------------------------------------------------------------
    group('precedence integration', () {
      test('full precedence chain: ternary > null-coalesce > logical > comparison > arithmetic', () {
        // a + 1 > 2 && b || c ? d ?? e : f
        // Should parse as:
        //   (((a + 1) > 2) && b) || c  ?  (d ?? e)  :  f
        final node = parse('a + 1 > 2 && b || c ? d ?? e : f');
        expect(node, isA<ConditionalExpr>());
        final cond = node as ConditionalExpr;
        // The condition is the OR expression
        expect(cond.condition, isA<LogicalExpr>());
        // The then branch is the null-coalesce
        expect(cond.thenBranch, isA<NullCoalesceExpr>());
      });

      test('unary has higher precedence than binary', () {
        // -a + b should be (-a) + b
        final node = parse('-a + b');
        expect(node, isA<BinaryExpr>());
        final bin = node as BinaryExpr;
        expect(bin.operator, equals('+'));
        expect(bin.left, isA<UnaryExpr>());
      });

      test('postfix has highest precedence', () {
        // -a.b should be -(a.b), not (-a).b
        final node = parse('-a.b');
        expect(node, isA<UnaryExpr>());
        final unary = node as UnaryExpr;
        expect(unary.operand, isA<MemberExpr>());
      });
    });
  });
}
