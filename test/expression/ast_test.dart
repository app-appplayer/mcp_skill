import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/ast.dart';

void main() {
  group('LiteralExpr', () {
    test('stores number value', () {
      const expr = LiteralExpr(42);
      expect(expr.value, equals(42));
    });

    test('stores string value', () {
      const expr = LiteralExpr('hello');
      expect(expr.value, equals('hello'));
    });

    test('stores boolean value', () {
      const expr = LiteralExpr(true);
      expect(expr.value, isTrue);
    });

    test('stores null value', () {
      const expr = LiteralExpr(null);
      expect(expr.value, isNull);
    });

    test('stores double value', () {
      const expr = LiteralExpr(3.14);
      expect(expr.value, equals(3.14));
    });

    test('is an AstNode', () {
      const expr = LiteralExpr(1);
      expect(expr, isA<AstNode>());
    });
  });

  group('IdentifierExpr', () {
    test('stores name', () {
      const expr = IdentifierExpr('inputs');
      expect(expr.name, equals('inputs'));
    });

    test('is an AstNode', () {
      const expr = IdentifierExpr('x');
      expect(expr, isA<AstNode>());
    });
  });

  group('MemberExpr', () {
    test('stores object and property', () {
      const expr = MemberExpr(
        IdentifierExpr('obj'),
        'field',
      );

      expect(expr.object, isA<IdentifierExpr>());
      expect((expr.object as IdentifierExpr).name, equals('obj'));
      expect(expr.property, equals('field'));
      expect(expr.isOptional, isFalse);
    });

    test('supports optional chaining', () {
      const expr = MemberExpr(
        IdentifierExpr('obj'),
        'field',
        isOptional: true,
      );

      expect(expr.isOptional, isTrue);
    });
  });

  group('IndexExpr', () {
    test('stores object and index', () {
      const expr = IndexExpr(
        IdentifierExpr('arr'),
        LiteralExpr(0),
      );

      expect((expr.object as IdentifierExpr).name, equals('arr'));
      expect((expr.index as LiteralExpr).value, equals(0));
    });
  });

  group('CallExpr', () {
    test('stores callee and arguments', () {
      const expr = CallExpr(
        IdentifierExpr('length'),
        [IdentifierExpr('str')],
      );

      expect((expr.callee as IdentifierExpr).name, equals('length'));
      expect(expr.arguments.length, equals(1));
    });

    test('supports zero arguments', () {
      const expr = CallExpr(IdentifierExpr('now'), []);

      expect(expr.arguments, isEmpty);
    });

    test('supports multiple arguments', () {
      const expr = CallExpr(
        IdentifierExpr('substring'),
        [IdentifierExpr('str'), LiteralExpr(0), LiteralExpr(5)],
      );

      expect(expr.arguments.length, equals(3));
    });
  });

  group('UnaryExpr', () {
    test('stores operator and operand', () {
      const expr = UnaryExpr('!', LiteralExpr(true));

      expect(expr.operator, equals('!'));
      expect((expr.operand as LiteralExpr).value, isTrue);
    });

    test('supports negation operator', () {
      const expr = UnaryExpr('-', LiteralExpr(5));

      expect(expr.operator, equals('-'));
      expect((expr.operand as LiteralExpr).value, equals(5));
    });

    test('supports not keyword', () {
      const expr = UnaryExpr('not', IdentifierExpr('flag'));

      expect(expr.operator, equals('not'));
    });
  });

  group('BinaryExpr', () {
    test('stores left, operator, and right', () {
      const expr = BinaryExpr(
        LiteralExpr(1),
        '+',
        LiteralExpr(2),
      );

      expect((expr.left as LiteralExpr).value, equals(1));
      expect(expr.operator, equals('+'));
      expect((expr.right as LiteralExpr).value, equals(2));
    });

    test('supports comparison operators', () {
      const expr = BinaryExpr(
        IdentifierExpr('x'),
        '>',
        LiteralExpr(10),
      );

      expect(expr.operator, equals('>'));
    });

    test('supports arithmetic operators', () {
      for (final op in ['+', '-', '*', '/', '%']) {
        final expr = BinaryExpr(LiteralExpr(1), op, LiteralExpr(2));
        expect(expr.operator, equals(op));
      }
    });
  });

  group('LogicalExpr', () {
    test('stores left, operator, and right', () {
      const expr = LogicalExpr(
        LiteralExpr(true),
        '&&',
        LiteralExpr(false),
      );

      expect((expr.left as LiteralExpr).value, isTrue);
      expect(expr.operator, equals('&&'));
      expect((expr.right as LiteralExpr).value, isFalse);
    });

    test('supports OR operator', () {
      const expr = LogicalExpr(
        IdentifierExpr('a'),
        '||',
        IdentifierExpr('b'),
      );

      expect(expr.operator, equals('||'));
    });
  });

  group('ConditionalExpr', () {
    test('stores condition, thenBranch, and elseBranch', () {
      const expr = ConditionalExpr(
        IdentifierExpr('flag'),
        LiteralExpr('yes'),
        LiteralExpr('no'),
      );

      expect((expr.condition as IdentifierExpr).name, equals('flag'));
      expect((expr.thenBranch as LiteralExpr).value, equals('yes'));
      expect((expr.elseBranch as LiteralExpr).value, equals('no'));
    });
  });

  group('NullCoalesceExpr', () {
    test('stores left and right', () {
      const expr = NullCoalesceExpr(
        IdentifierExpr('value'),
        LiteralExpr('default'),
      );

      expect((expr.left as IdentifierExpr).name, equals('value'));
      expect((expr.right as LiteralExpr).value, equals('default'));
    });
  });

  group('GroupingExpr', () {
    test('stores inner expression', () {
      const expr = GroupingExpr(
        BinaryExpr(LiteralExpr(1), '+', LiteralExpr(2)),
      );

      expect(expr.expression, isA<BinaryExpr>());
    });
  });

  group('InterpolationExpr', () {
    test('stores parts list', () {
      const expr = InterpolationExpr([
        LiteralExpr('Hello, '),
        IdentifierExpr('name'),
        LiteralExpr('!'),
      ]);

      expect(expr.parts.length, equals(3));
      expect(expr.parts[0], isA<LiteralExpr>());
      expect(expr.parts[1], isA<IdentifierExpr>());
      expect(expr.parts[2], isA<LiteralExpr>());
    });

    test('supports empty parts', () {
      const expr = InterpolationExpr([]);

      expect(expr.parts, isEmpty);
    });
  });

  group('PipeExpr', () {
    test('stores value and transform', () {
      const expr = PipeExpr(
        IdentifierExpr('data'),
        IdentifierExpr('uppercase'),
      );

      expect((expr.value as IdentifierExpr).name, equals('data'));
      expect((expr.transform as IdentifierExpr).name, equals('uppercase'));
    });
  });

  group('LambdaExpr', () {
    test('stores parameter and body', () {
      const expr = LambdaExpr(
        'x',
        BinaryExpr(IdentifierExpr('x'), '+', LiteralExpr(1)),
      );

      expect(expr.parameter, equals('x'));
      expect(expr.body, isA<BinaryExpr>());
    });
  });

  group('ArrayExpr', () {
    test('stores elements', () {
      const expr = ArrayExpr([
        LiteralExpr(1),
        LiteralExpr(2),
        LiteralExpr(3),
      ]);

      expect(expr.elements.length, equals(3));
    });

    test('supports empty array', () {
      const expr = ArrayExpr([]);

      expect(expr.elements, isEmpty);
    });

    test('supports mixed element types', () {
      const expr = ArrayExpr([
        LiteralExpr(1),
        LiteralExpr('two'),
        LiteralExpr(true),
      ]);

      expect(expr.elements.length, equals(3));
    });
  });

  group('ObjectExpr', () {
    test('stores entries', () {
      const expr = ObjectExpr([
        ObjectEntry('name', LiteralExpr('John')),
        ObjectEntry('age', LiteralExpr(30)),
      ]);

      expect(expr.entries.length, equals(2));
      expect(expr.entries[0].key, equals('name'));
      expect(expr.entries[1].key, equals('age'));
    });

    test('supports empty object', () {
      const expr = ObjectExpr([]);

      expect(expr.entries, isEmpty);
    });
  });

  group('ObjectEntry', () {
    test('stores key and value', () {
      const entry = ObjectEntry('key', LiteralExpr('value'));

      expect(entry.key, equals('key'));
      expect((entry.value as LiteralExpr).value, equals('value'));
    });

    test('supports expression values', () {
      const entry = ObjectEntry(
        'computed',
        BinaryExpr(LiteralExpr(1), '+', LiteralExpr(2)),
      );

      expect(entry.value, isA<BinaryExpr>());
    });
  });

  group('AstNode sealed class', () {
    test('all node types are AstNode subtypes', () {
      final nodes = <AstNode>[
        const LiteralExpr(1),
        const IdentifierExpr('x'),
        const MemberExpr(IdentifierExpr('a'), 'b'),
        const IndexExpr(IdentifierExpr('a'), LiteralExpr(0)),
        const CallExpr(IdentifierExpr('f'), []),
        const UnaryExpr('-', LiteralExpr(1)),
        const BinaryExpr(LiteralExpr(1), '+', LiteralExpr(2)),
        const LogicalExpr(LiteralExpr(true), '&&', LiteralExpr(false)),
        const ConditionalExpr(
            LiteralExpr(true), LiteralExpr(1), LiteralExpr(0)),
        const NullCoalesceExpr(IdentifierExpr('x'), LiteralExpr(0)),
        const GroupingExpr(LiteralExpr(1)),
        const InterpolationExpr([]),
        const PipeExpr(IdentifierExpr('x'), IdentifierExpr('f')),
        const LambdaExpr('x', IdentifierExpr('x')),
        const ArrayExpr([]),
        const ObjectExpr([]),
      ];

      for (final node in nodes) {
        expect(node, isA<AstNode>());
      }
      expect(nodes.length, equals(16));
    });
  });
}
