import 'package:test/test.dart';
import 'package:mcp_skill/src/definition/parameter.dart';

void main() {
  group('ParameterType', () {
    test('has all expected values', () {
      expect(ParameterType.values, contains(ParameterType.string));
      expect(ParameterType.values, contains(ParameterType.number));
      expect(ParameterType.values, contains(ParameterType.integer));
      expect(ParameterType.values, contains(ParameterType.boolean));
      expect(ParameterType.values, contains(ParameterType.array));
      expect(ParameterType.values, contains(ParameterType.object));
      expect(ParameterType.values, contains(ParameterType.any));
    });

    test('fromString returns correct value', () {
      expect(ParameterType.fromString('string'), equals(ParameterType.string));
      expect(ParameterType.fromString('number'), equals(ParameterType.number));
      expect(ParameterType.fromString('integer'), equals(ParameterType.integer));
      expect(ParameterType.fromString('boolean'), equals(ParameterType.boolean));
      expect(ParameterType.fromString('array'), equals(ParameterType.array));
      expect(ParameterType.fromString('object'), equals(ParameterType.object));
      expect(ParameterType.fromString('any'), equals(ParameterType.any));
    });

    test('fromString is case insensitive', () {
      expect(ParameterType.fromString('STRING'), equals(ParameterType.string));
      expect(ParameterType.fromString('Number'), equals(ParameterType.number));
    });

    test('fromString returns any for unknown values', () {
      expect(ParameterType.fromString('unknown'), equals(ParameterType.any));
      expect(ParameterType.fromString(''), equals(ParameterType.any));
    });
  });

  group('Parameter', () {
    test('constructor creates instance with required fields', () {
      final param = Parameter(
        name: 'testParam',
        type: ParameterType.string,
      );

      expect(param.name, equals('testParam'));
      expect(param.type, equals(ParameterType.string));
      expect(param.description, isNull);
      expect(param.required, isTrue);
      expect(param.defaultValue, isNull);
      expect(param.constraints, isEmpty);
      expect(param.metadata, isEmpty);
    });

    test('constructor creates instance with all fields', () {
      final param = Parameter(
        name: 'testParam',
        type: ParameterType.integer,
        description: 'A test parameter',
        required: false,
        defaultValue: 10,
        constraints: {'minimum': 0, 'maximum': 100},
        metadata: {'key': 'value'},
      );

      expect(param.description, equals('A test parameter'));
      expect(param.required, isFalse);
      expect(param.defaultValue, equals(10));
      expect(param.constraints, equals({'minimum': 0, 'maximum': 100}));
      expect(param.metadata, equals({'key': 'value'}));
    });

    group('validateType', () {
      test('returns null for null value', () {
        final param = Parameter(name: 'test', type: ParameterType.string);
        expect(param.validateType(null), isNull);
      });

      test('validates string type', () {
        final param = Parameter(name: 'test', type: ParameterType.string);
        expect(param.validateType('valid'), isNull);
        expect(param.validateType(123), contains('must be a string'));
      });

      test('validates number type', () {
        final param = Parameter(name: 'test', type: ParameterType.number);
        expect(param.validateType(42), isNull);
        expect(param.validateType(3.14), isNull);
        expect(param.validateType('not a number'), contains('must be a number'));
      });

      test('validates integer type', () {
        final param = Parameter(name: 'test', type: ParameterType.integer);
        expect(param.validateType(42), isNull);
        expect(param.validateType(3.14), contains('must be an integer'));
        expect(param.validateType('not an int'), contains('must be an integer'));
      });

      test('validates boolean type', () {
        final param = Parameter(name: 'test', type: ParameterType.boolean);
        expect(param.validateType(true), isNull);
        expect(param.validateType(false), isNull);
        expect(param.validateType('true'), contains('must be a boolean'));
      });

      test('validates array type', () {
        final param = Parameter(name: 'test', type: ParameterType.array);
        expect(param.validateType([1, 2, 3]), isNull);
        expect(param.validateType('not an array'), contains('must be an array'));
      });

      test('validates object type', () {
        final param = Parameter(name: 'test', type: ParameterType.object);
        expect(param.validateType({'key': 'value'}), isNull);
        expect(param.validateType('not an object'), contains('must be an object'));
      });

      test('any type accepts all values', () {
        final param = Parameter(name: 'test', type: ParameterType.any);
        expect(param.validateType('string'), isNull);
        expect(param.validateType(42), isNull);
        expect(param.validateType(true), isNull);
        expect(param.validateType([1, 2]), isNull);
        expect(param.validateType({'a': 'b'}), isNull);
      });
    });

    group('validateConstraints', () {
      test('returns empty list for null value', () {
        final param = Parameter(
          name: 'test',
          type: ParameterType.string,
          constraints: {'minLength': 1},
        );
        expect(param.validateConstraints(null), isEmpty);
      });

      group('string constraints', () {
        test('validates minLength', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.string,
            constraints: {'minLength': 5},
          );
          expect(param.validateConstraints('hello'), isEmpty);
          expect(param.validateConstraints('hi'), hasLength(1));
          expect(param.validateConstraints('hi').first, contains('at least 5'));
        });

        test('validates maxLength', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.string,
            constraints: {'maxLength': 5},
          );
          expect(param.validateConstraints('hi'), isEmpty);
          expect(param.validateConstraints('hello world'), hasLength(1));
          expect(param.validateConstraints('hello world').first, contains('at most 5'));
        });

        test('validates pattern', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.string,
            constraints: {'pattern': r'^[a-z]+$'},
          );
          expect(param.validateConstraints('hello'), isEmpty);
          expect(param.validateConstraints('Hello123'), hasLength(1));
          expect(param.validateConstraints('Hello123').first, contains('pattern'));
        });

        test('validates enum', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.string,
            constraints: {'enum': ['a', 'b', 'c']},
          );
          expect(param.validateConstraints('a'), isEmpty);
          expect(param.validateConstraints('d'), hasLength(1));
          expect(param.validateConstraints('d').first, contains('must be one of'));
        });
      });

      group('number constraints', () {
        test('validates minimum', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.number,
            constraints: {'minimum': 10},
          );
          expect(param.validateConstraints(10), isEmpty);
          expect(param.validateConstraints(15), isEmpty);
          expect(param.validateConstraints(5), hasLength(1));
          expect(param.validateConstraints(5).first, contains('at least 10'));
        });

        test('validates maximum', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.number,
            constraints: {'maximum': 100},
          );
          expect(param.validateConstraints(100), isEmpty);
          expect(param.validateConstraints(50), isEmpty);
          expect(param.validateConstraints(150), hasLength(1));
          expect(param.validateConstraints(150).first, contains('at most 100'));
        });

        test('validates multipleOf', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.number,
            constraints: {'multipleOf': 5},
          );
          expect(param.validateConstraints(10), isEmpty);
          expect(param.validateConstraints(15), isEmpty);
          expect(param.validateConstraints(12), hasLength(1));
          expect(param.validateConstraints(12).first, contains('multiple of 5'));
        });
      });

      group('array constraints', () {
        test('validates minItems', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.array,
            constraints: {'minItems': 2},
          );
          expect(param.validateConstraints([1, 2]), isEmpty);
          expect(param.validateConstraints([1, 2, 3]), isEmpty);
          expect(param.validateConstraints([1]), hasLength(1));
          expect(param.validateConstraints([1]).first, contains('at least 2'));
        });

        test('validates maxItems', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.array,
            constraints: {'maxItems': 3},
          );
          expect(param.validateConstraints([1, 2]), isEmpty);
          expect(param.validateConstraints([1, 2, 3]), isEmpty);
          expect(param.validateConstraints([1, 2, 3, 4]), hasLength(1));
          expect(param.validateConstraints([1, 2, 3, 4]).first, contains('at most 3'));
        });

        test('validates uniqueItems', () {
          final param = Parameter(
            name: 'test',
            type: ParameterType.array,
            constraints: {'uniqueItems': true},
          );
          expect(param.validateConstraints([1, 2, 3]), isEmpty);
          expect(param.validateConstraints([1, 2, 2]), hasLength(1));
          expect(param.validateConstraints([1, 2, 2]).first, contains('unique'));
        });
      });
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'name': 'testParam',
        'type': 'integer',
        'description': 'A test parameter',
        'required': false,
        'default': 42,
        'constraints': {'minimum': 0},
        'metadata': {'key': 'value'},
      };

      final param = Parameter.fromJson(json);

      expect(param.name, equals('testParam'));
      expect(param.type, equals(ParameterType.integer));
      expect(param.description, equals('A test parameter'));
      expect(param.required, isFalse);
      expect(param.defaultValue, equals(42));
      expect(param.constraints, equals({'minimum': 0}));
      expect(param.metadata, equals({'key': 'value'}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final param = Parameter.fromJson(json);

      expect(param.name, equals(''));
      expect(param.type, equals(ParameterType.any));
      expect(param.required, isTrue);
      expect(param.constraints, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      final param = Parameter(
        name: 'testParam',
        type: ParameterType.string,
        description: 'Description',
        required: false,
        defaultValue: 'default',
        constraints: {'minLength': 1},
        metadata: {'key': 'value'},
      );

      final json = param.toJson();

      expect(json['name'], equals('testParam'));
      expect(json['type'], equals('string'));
      expect(json['description'], equals('Description'));
      expect(json['required'], isFalse);
      expect(json['default'], equals('default'));
      expect(json['constraints'], equals({'minLength': 1}));
      expect(json['metadata'], equals({'key': 'value'}));
    });

    test('toJson excludes null and empty fields', () {
      final param = Parameter(
        name: 'testParam',
        type: ParameterType.string,
      );

      final json = param.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('default'), isFalse);
      expect(json.containsKey('constraints'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString returns expected string representation', () {
      final param = Parameter(
        name: 'testParam',
        type: ParameterType.string,
      );

      final str = param.toString();

      expect(str, contains('Parameter'));
      expect(str, contains('testParam'));
      expect(str, contains('string'));
    });
  });
}
