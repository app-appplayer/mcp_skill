import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/function_registry.dart';
import 'package:mcp_skill/src/expression/expression_exception.dart';

void main() {
  late FunctionRegistry registry;

  setUp(() {
    registry = FunctionRegistry.standard();
  });

  group('FunctionRegistry', () {
    // ------------------------------------------------------------------
    // Registration and invocation
    // ------------------------------------------------------------------
    group('registration', () {
      test('standard factory registers all built-in functions', () {
        // Spot-check representative functions from each category
        expect(registry.has('length'), isTrue);
        expect(registry.has('min'), isTrue);
        expect(registry.has('first'), isTrue);
        expect(registry.has('now'), isTrue);
        expect(registry.has('type'), isTrue);
        expect(registry.has('keys'), isTrue);
      });

      test('empty registry has no functions', () {
        final empty = FunctionRegistry();
        expect(empty.has('length'), isFalse);
      });

      test('register adds a custom function', () {
        final custom = FunctionRegistry();
        custom.register('double', (args) => (args[0] as num) * 2);
        expect(custom.has('double'), isTrue);
        expect(custom.call('double', [5]), equals(10));
      });

      test('call throws UnknownFunctionException for unregistered function', () {
        expect(
          () => registry.call('nonexistent', []),
          throwsA(isA<UnknownFunctionException>()),
        );
      });

      test('UnknownFunctionException contains function name', () {
        try {
          registry.call('fakeFn', []);
          fail('Expected UnknownFunctionException');
        } on UnknownFunctionException catch (e) {
          expect(e.functionName, equals('fakeFn'));
          expect(e.message, contains('fakeFn'));
        }
      });
    });

    // ------------------------------------------------------------------
    // STRING FUNCTIONS
    // ------------------------------------------------------------------
    group('string functions', () {
      test('length returns string length', () {
        expect(registry.call('length', ['hello']), equals(5));
      });

      test('length returns list length', () {
        expect(registry.call('length', [[1, 2, 3]]), equals(3));
      });

      test('length returns map length', () {
        expect(registry.call('length', [{'a': 1, 'b': 2}]), equals(2));
      });

      test('length returns 0 for non-collection types', () {
        expect(registry.call('length', [42]), equals(0));
      });

      test('upper converts to uppercase', () {
        expect(registry.call('upper', ['hello']), equals('HELLO'));
      });

      test('upper handles null', () {
        expect(registry.call('upper', [null]), equals(''));
      });

      test('lower converts to lowercase', () {
        expect(registry.call('lower', ['HELLO']), equals('hello'));
      });

      test('lower handles null', () {
        expect(registry.call('lower', [null]), equals(''));
      });

      test('trim removes whitespace', () {
        expect(registry.call('trim', ['  hello  ']), equals('hello'));
      });

      test('trim handles null', () {
        expect(registry.call('trim', [null]), equals(''));
      });

      test('contains checks string containment', () {
        expect(registry.call('contains', ['hello world', 'world']), isTrue);
        expect(registry.call('contains', ['hello', 'xyz']), isFalse);
      });

      test('contains checks list containment', () {
        expect(registry.call('contains', [[1, 2, 3], 2]), isTrue);
        expect(registry.call('contains', [[1, 2, 3], 5]), isFalse);
      });

      test('contains returns false for non-collection', () {
        expect(registry.call('contains', [42, 4]), isFalse);
      });

      test('startsWith checks string prefix', () {
        expect(registry.call('startsWith', ['hello', 'he']), isTrue);
        expect(registry.call('startsWith', ['hello', 'lo']), isFalse);
      });

      test('endsWith checks string suffix', () {
        expect(registry.call('endsWith', ['hello', 'lo']), isTrue);
        expect(registry.call('endsWith', ['hello', 'he']), isFalse);
      });

      test('substring extracts range', () {
        expect(registry.call('substring', ['hello', 1, 3]), equals('el'));
      });

      test('substring with only start index', () {
        expect(registry.call('substring', ['hello', 2]), equals('llo'));
      });

      test('substring clamps out-of-range indices', () {
        // Should not throw, should clamp
        expect(registry.call('substring', ['hi', 0, 100]), equals('hi'));
        expect(registry.call('substring', ['hi', -5, 2]), equals('hi'));
      });

      test('replace replaces first occurrence', () {
        expect(registry.call('replace', ['hello world', 'world', 'dart']),
            equals('hello dart'));
      });

      test('split splits string', () {
        expect(
            registry.call('split', ['a,b,c', ',']), equals(['a', 'b', 'c']));
      });

      test('join joins list elements', () {
        expect(registry.call('join', [
          ['a', 'b', 'c'],
          '-'
        ]), equals('a-b-c'));
      });

      test('join with no delimiter', () {
        expect(registry.call('join', [
          ['a', 'b']
        ]), equals('ab'));
      });

      test('join returns empty string for non-list', () {
        expect(registry.call('join', ['not-a-list']), equals(''));
      });
    });

    // ------------------------------------------------------------------
    // MATH FUNCTIONS
    // ------------------------------------------------------------------
    group('math functions', () {
      test('abs returns absolute value', () {
        expect(registry.call('abs', [-5]), equals(5));
        expect(registry.call('abs', [3]), equals(3));
        expect(registry.call('abs', [0]), equals(0));
      });

      test('ceil rounds up', () {
        expect(registry.call('ceil', [3.2]), equals(4));
        expect(registry.call('ceil', [3.9]), equals(4));
        expect(registry.call('ceil', [4.0]), equals(4));
      });

      test('floor rounds down', () {
        expect(registry.call('floor', [3.9]), equals(3));
        expect(registry.call('floor', [3.1]), equals(3));
        expect(registry.call('floor', [4.0]), equals(4));
      });

      test('round rounds to nearest', () {
        expect(registry.call('round', [3.4]), equals(3));
        expect(registry.call('round', [3.5]), equals(4));
        expect(registry.call('round', [3.6]), equals(4));
      });

      test('min returns minimum', () {
        expect(registry.call('min', [3, 7]), equals(3));
        expect(registry.call('min', [10, 2]), equals(2));
        expect(registry.call('min', [5, 5]), equals(5));
      });

      test('max returns maximum', () {
        expect(registry.call('max', [3, 7]), equals(7));
        expect(registry.call('max', [10, 2]), equals(10));
      });

      test('pow computes exponentiation', () {
        expect(registry.call('pow', [2, 3]), equals(8));
        expect(registry.call('pow', [3, 2]), equals(9));
        expect(registry.call('pow', [5, 0]), equals(1));
      });

      test('sqrt computes square root', () {
        expect(registry.call('sqrt', [9]), equals(3.0));
        expect(registry.call('sqrt', [16]), equals(4.0));
        expect(registry.call('sqrt', [0]), equals(0.0));
      });

      test('log computes natural logarithm', () {
        final result = registry.call('log', [1]) as double;
        expect(result, closeTo(0.0, 0.001));
      });

      test('clamp restricts value to range', () {
        expect(registry.call('clamp', [5, 1, 10]), equals(5));
        expect(registry.call('clamp', [-5, 1, 10]), equals(1));
        expect(registry.call('clamp', [15, 1, 10]), equals(10));
      });

      test('math functions handle string numeric input', () {
        expect(registry.call('abs', ['-5']), equals(5));
        expect(registry.call('min', ['3', '7']), equals(3));
      });

      test('math functions handle bool input', () {
        // true -> 1, false -> 0
        expect(registry.call('abs', [true]), equals(1));
        expect(registry.call('abs', [false]), equals(0));
      });

      test('math functions handle null/non-numeric as zero', () {
        expect(registry.call('abs', [null]), equals(0));
      });
    });

    // ------------------------------------------------------------------
    // ARRAY FUNCTIONS
    // ------------------------------------------------------------------
    group('array functions', () {
      test('first returns first element', () {
        expect(registry.call('first', [[10, 20, 30]]), equals(10));
      });

      test('first returns null for empty list', () {
        expect(registry.call('first', [<int>[]]), isNull);
      });

      test('last returns last element', () {
        expect(registry.call('last', [[10, 20, 30]]), equals(30));
      });

      test('last returns null for empty list', () {
        expect(registry.call('last', [<int>[]]), isNull);
      });

      test('at returns element at index', () {
        expect(registry.call('at', [[10, 20, 30], 1]), equals(20));
      });

      test('at returns null for out-of-range index', () {
        expect(registry.call('at', [[10, 20], 5]), isNull);
        expect(registry.call('at', [[10, 20], -1]), isNull);
      });

      test('slice returns sublist', () {
        expect(registry.call('slice', [[1, 2, 3, 4, 5], 1, 3]), equals([2, 3]));
      });

      test('slice with only start index', () {
        expect(
            registry.call('slice', [[1, 2, 3, 4, 5], 2]), equals([3, 4, 5]));
      });

      test('slice clamps out-of-range indices', () {
        expect(registry.call('slice', [[1, 2, 3], 0, 100]), equals([1, 2, 3]));
      });

      test('reverse returns reversed list', () {
        expect(registry.call('reverse', [[1, 2, 3]]), equals([3, 2, 1]));
      });

      test('reverse returns empty list for empty input', () {
        expect(registry.call('reverse', [<int>[]]), isEmpty);
      });

      test('unique removes duplicates', () {
        final result = registry.call('unique', [[1, 2, 2, 3, 3, 3]]) as List;
        expect(result, containsAll([1, 2, 3]));
        expect(result, hasLength(3));
      });

      test('flatten flattens nested lists one level', () {
        expect(
          registry.call('flatten', [
            [
              [1, 2],
              [3, 4],
              5
            ]
          ]),
          equals([1, 2, 3, 4, 5]),
        );
      });

      test('flatten leaves non-list items intact', () {
        expect(
          registry.call('flatten', [
            [1, 2, 3]
          ]),
          equals([1, 2, 3]),
        );
      });

      test('sort sorts comparable elements', () {
        expect(registry.call('sort', [[3, 1, 2]]), equals([1, 2, 3]));
      });

      test('sort sorts strings', () {
        expect(
            registry.call('sort', [
              ['c', 'a', 'b']
            ]),
            equals(['a', 'b', 'c']));
      });

      test('sort does not mutate original list', () {
        final original = [3, 1, 2];
        registry.call('sort', [original]);
        expect(original, equals([3, 1, 2]));
      });

      test('map with key path extracts field values', () {
        final items = [
          {'name': 'Alice'},
          {'name': 'Bob'},
        ];
        final result = registry.call('map', [items, r'$.name']);
        expect(result, equals(['Alice', 'Bob']));
      });

      test('map returns list as-is when no function provided', () {
        expect(registry.call('map', [[1, 2, 3]]), equals([1, 2, 3]));
      });

      test('map returns list as-is for non key-path string', () {
        expect(registry.call('map', [[1, 2, 3], 'nonKeyPath']), equals([1, 2, 3]));
      });

      test('filter with key path filters by truthy field', () {
        final items = [
          {'name': 'Alice', 'active': true},
          {'name': 'Bob', 'active': false},
          {'name': 'Carol', 'active': true},
        ];
        final result = registry.call('filter', [items, r'$.active']) as List;
        expect(result, hasLength(2));
      });

      test('filter excludes items with null, false, 0, empty string fields', () {
        final items = [
          {'val': null},
          {'val': false},
          {'val': 0},
          {'val': ''},
          {'val': 'ok'},
        ];
        final result = registry.call('filter', [items, r'$.val']) as List;
        expect(result, hasLength(1));
      });

      test('find returns first matching item', () {
        final items = [
          {'name': 'Alice', 'active': false},
          {'name': 'Bob', 'active': true},
          {'name': 'Carol', 'active': true},
        ];
        final result = registry.call('find', [items, r'$.active']);
        expect(result, isA<Map>());
        expect((result as Map)['name'], equals('Bob'));
      });

      test('find returns null when no match', () {
        final items = [
          {'active': false},
          {'active': false},
        ];
        expect(registry.call('find', [items, r'$.active']), isNull);
      });

      test('every returns true when all items match', () {
        final items = [
          {'valid': true},
          {'valid': true},
        ];
        expect(registry.call('every', [items, r'$.valid']), isTrue);
      });

      test('every returns false when any item does not match', () {
        final items = [
          {'valid': true},
          {'valid': false},
        ];
        expect(registry.call('every', [items, r'$.valid']), isFalse);
      });

      test('some returns true when at least one item matches', () {
        final items = [
          {'ok': false},
          {'ok': true},
        ];
        expect(registry.call('some', [items, r'$.ok']), isTrue);
      });

      test('some returns false when no item matches', () {
        final items = [
          {'ok': false},
          {'ok': null},
        ];
        expect(registry.call('some', [items, r'$.ok']), isFalse);
      });

      test('reduce sums numeric list', () {
        expect(registry.call('reduce', [[1, 2, 3, 4]]), equals(10));
      });

      test('reduce with initial value', () {
        expect(registry.call('reduce', [[1, 2, 3], null, 10]), equals(16));
      });

      test('reduce returns initial value for empty list', () {
        expect(registry.call('reduce', [<int>[], null, 0]), equals(0));
      });

      test('reduce returns null for empty list with no initial value', () {
        expect(registry.call('reduce', [<int>[]]), isNull);
      });

      test('non-list input treated as single-element list', () {
        // _toList wraps non-list, non-null in a single-element list
        expect(registry.call('first', [42]), equals(42));
        expect(registry.call('length', [null]), equals(0));
      });
    });

    // ------------------------------------------------------------------
    // DATE FUNCTIONS
    // ------------------------------------------------------------------
    group('date functions', () {
      test('now returns ISO 8601 string', () {
        final result = registry.call('now', []) as String;
        // Should be parseable as DateTime
        expect(DateTime.tryParse(result), isNotNull);
      });

      test('parseDate parses valid ISO date', () {
        final result = registry.call('parseDate', ['2024-01-15T10:30:00.000']);
        expect(result, isNotNull);
        expect(result, isA<String>());
      });

      test('parseDate returns null for invalid date', () {
        expect(registry.call('parseDate', ['not-a-date']), isNull);
      });

      test('formatDate formats a date', () {
        final result = registry.call('formatDate', ['2024-06-15T10:30:00.000']);
        expect(result, isA<String>());
        expect(result, isNotEmpty);
      });

      test('formatDate returns empty string for invalid input', () {
        expect(registry.call('formatDate', ['invalid']), equals(''));
      });

      test('addDays adds days to date', () {
        final result = registry.call('addDays', ['2024-01-15T00:00:00.000', 5]) as String;
        final parsed = DateTime.parse(result);
        expect(parsed.day, equals(20));
      });

      test('addDays returns null for invalid date', () {
        expect(registry.call('addDays', ['invalid', 5]), isNull);
      });

      test('addHours adds hours to date', () {
        final result =
            registry.call('addHours', ['2024-01-15T10:00:00.000', 3]) as String;
        final parsed = DateTime.parse(result);
        expect(parsed.hour, equals(13));
      });

      test('diffDays computes day difference', () {
        final result = registry.call(
            'diffDays', ['2024-01-20T00:00:00.000', '2024-01-15T00:00:00.000']);
        expect(result, equals(5));
      });

      test('diffDays returns 0 for invalid dates', () {
        expect(registry.call('diffDays', ['invalid', '2024-01-01']), equals(0));
      });

      test('diffHours computes hour difference', () {
        final result = registry.call(
            'diffHours', ['2024-01-15T15:00:00.000', '2024-01-15T10:00:00.000']);
        expect(result, equals(5));
      });

      test('isBefore returns true when first date is before second', () {
        expect(
          registry.call('isBefore',
              ['2024-01-10T00:00:00.000', '2024-01-15T00:00:00.000']),
          isTrue,
        );
      });

      test('isBefore returns false when first date is after second', () {
        expect(
          registry.call('isBefore',
              ['2024-01-20T00:00:00.000', '2024-01-15T00:00:00.000']),
          isFalse,
        );
      });

      test('isBefore returns false for invalid dates', () {
        expect(registry.call('isBefore', ['invalid', '2024-01-01']), isFalse);
      });

      test('isAfter returns true when first date is after second', () {
        expect(
          registry.call('isAfter',
              ['2024-01-20T00:00:00.000', '2024-01-15T00:00:00.000']),
          isTrue,
        );
      });

      test('isAfter returns false for invalid dates', () {
        expect(registry.call('isAfter', ['invalid', '2024-01-01']), isFalse);
      });

      test('age returns seconds since date', () {
        // Use a recent date to get a meaningful result
        final pastDate =
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();
        final result = registry.call('age', [pastDate]) as int;
        // Should be approximately 3600 seconds
        expect(result, greaterThan(3500));
        expect(result, lessThan(3700));
      });

      test('age returns 0 for invalid date', () {
        expect(registry.call('age', ['invalid']), equals(0));
      });

      test('duration returns absolute seconds between dates', () {
        final result = registry.call('duration',
            ['2024-01-15T10:00:00.000', '2024-01-15T11:00:00.000']);
        expect(result, equals(3600));
      });

      test('duration is always positive', () {
        final result = registry.call('duration',
            ['2024-01-15T11:00:00.000', '2024-01-15T10:00:00.000']);
        expect(result, equals(3600));
      });
    });

    // ------------------------------------------------------------------
    // TYPE FUNCTIONS
    // ------------------------------------------------------------------
    group('type functions', () {
      test('type returns null for null', () {
        expect(registry.call('type', [null]), equals('null'));
      });

      test('type returns boolean for bool', () {
        expect(registry.call('type', [true]), equals('boolean'));
        expect(registry.call('type', [false]), equals('boolean'));
      });

      test('type returns number for num/int/double', () {
        expect(registry.call('type', [42]), equals('number'));
        expect(registry.call('type', [3.14]), equals('number'));
      });

      test('type returns string for String', () {
        expect(registry.call('type', ['hello']), equals('string'));
      });

      test('type returns array for List', () {
        expect(registry.call('type', [[1, 2]]), equals('array'));
      });

      test('type returns object for Map', () {
        expect(registry.call('type', [{'a': 1}]), equals('object'));
      });

      test('isNull checks for null', () {
        expect(registry.call('isNull', [null]), isTrue);
        expect(registry.call('isNull', [0]), isFalse);
        expect(registry.call('isNull', ['']), isFalse);
      });

      test('isNumber checks for numeric type', () {
        expect(registry.call('isNumber', [42]), isTrue);
        expect(registry.call('isNumber', [3.14]), isTrue);
        expect(registry.call('isNumber', ['42']), isFalse);
        expect(registry.call('isNumber', [null]), isFalse);
      });

      test('isString checks for string type', () {
        expect(registry.call('isString', ['hello']), isTrue);
        expect(registry.call('isString', [42]), isFalse);
      });

      test('isBool checks for boolean type', () {
        expect(registry.call('isBool', [true]), isTrue);
        expect(registry.call('isBool', [false]), isTrue);
        expect(registry.call('isBool', [1]), isFalse);
      });

      test('isArray checks for List type', () {
        expect(registry.call('isArray', [[1, 2]]), isTrue);
        expect(registry.call('isArray', [<int>[]]), isTrue);
        expect(registry.call('isArray', ['not array']), isFalse);
      });

      test('isObject checks for Map type', () {
        expect(registry.call('isObject', [{'a': 1}]), isTrue);
        expect(registry.call('isObject', [<String, dynamic>{}]), isTrue);
        expect(registry.call('isObject', [[1]]), isFalse);
      });

      test('isEmpty checks various types', () {
        expect(registry.call('isEmpty', [null]), isTrue);
        expect(registry.call('isEmpty', ['']), isTrue);
        expect(registry.call('isEmpty', [<int>[]]), isTrue);
        expect(registry.call('isEmpty', [<String, dynamic>{}]), isTrue);
        expect(registry.call('isEmpty', ['hello']), isFalse);
        expect(registry.call('isEmpty', [[1]]), isFalse);
        expect(registry.call('isEmpty', [{'a': 1}]), isFalse);
        // Non-collection, non-null returns false
        expect(registry.call('isEmpty', [42]), isFalse);
      });

      test('coalesce returns first non-null value', () {
        expect(registry.call('coalesce', [null, null, 'found']), equals('found'));
        expect(registry.call('coalesce', ['first', null, 'third']), equals('first'));
        expect(registry.call('coalesce', [null, null, null]), isNull);
      });

      test('defaultVal returns value if non-null, otherwise default', () {
        expect(registry.call('defaultVal', [42, 0]), equals(42));
        expect(registry.call('defaultVal', [null, 0]), equals(0));
        expect(registry.call('defaultVal', [null]), isNull);
      });

      test('toNumber converts various types', () {
        expect(registry.call('toNumber', [42]), equals(42));
        expect(registry.call('toNumber', ['3.14']), equals(3.14));
        expect(registry.call('toNumber', [true]), equals(1));
        expect(registry.call('toNumber', [false]), equals(0));
        expect(registry.call('toNumber', ['not-a-number']), equals(0));
        expect(registry.call('toNumber', [null]), equals(0));
      });

      test('toStr converts to string', () {
        expect(registry.call('toStr', [42]), equals('42'));
        expect(registry.call('toStr', [true]), equals('true'));
        expect(registry.call('toStr', [null]), equals(''));
        expect(registry.call('toStr', ['already']), equals('already'));
      });

      test('toBool converts various types', () {
        // null -> false
        expect(registry.call('toBool', [null]), isFalse);
        // bool passthrough
        expect(registry.call('toBool', [true]), isTrue);
        expect(registry.call('toBool', [false]), isFalse);
        // num: 0 -> false, non-zero -> true
        expect(registry.call('toBool', [0]), isFalse);
        expect(registry.call('toBool', [1]), isTrue);
        expect(registry.call('toBool', [-1]), isTrue);
        // string: empty and 'false' -> false, others -> true
        expect(registry.call('toBool', ['']), isFalse);
        expect(registry.call('toBool', ['false']), isFalse);
        expect(registry.call('toBool', ['FALSE']), isFalse);
        expect(registry.call('toBool', ['hello']), isTrue);
        // other: non-null -> true
        expect(registry.call('toBool', [[1]]), isTrue);
      });
    });

    // ------------------------------------------------------------------
    // OBJECT FUNCTIONS
    // ------------------------------------------------------------------
    group('object functions', () {
      test('keys returns map keys', () {
        expect(
            registry.call('keys', [
              {'a': 1, 'b': 2, 'c': 3}
            ]),
            equals(['a', 'b', 'c']));
      });

      test('keys returns empty list for non-map', () {
        expect(registry.call('keys', [42]), isEmpty);
      });

      test('values returns map values', () {
        expect(
            registry.call('values', [
              {'a': 1, 'b': 2}
            ]),
            equals([1, 2]));
      });

      test('values returns empty list for non-map', () {
        expect(registry.call('values', ['not-map']), isEmpty);
      });

      test('entries returns list of key-value maps', () {
        final result = registry.call('entries', [
          {'a': 1, 'b': 2}
        ]) as List;
        expect(result, hasLength(2));
        expect(result[0], equals({'key': 'a', 'value': 1}));
        expect(result[1], equals({'key': 'b', 'value': 2}));
      });

      test('entries returns empty list for non-map', () {
        expect(registry.call('entries', [42]), isEmpty);
      });

      test('has checks if map contains key', () {
        expect(
            registry.call('has', [
              {'name': 'Alice'},
              'name'
            ]),
            isTrue);
        expect(
            registry.call('has', [
              {'name': 'Alice'},
              'age'
            ]),
            isFalse);
      });

      test('has returns false for non-map', () {
        expect(registry.call('has', [42, 'key']), isFalse);
      });

      test('get retrieves nested value by path', () {
        final obj = {
          'a': {
            'b': {
              'c': 42,
            },
          },
        };
        expect(registry.call('get', [obj, 'a.b.c']), equals(42));
      });

      test('get returns default value when path not found', () {
        final obj = {'a': 1};
        expect(registry.call('get', [obj, 'b.c', 'default']), equals('default'));
      });

      test('get returns null when path not found and no default', () {
        final obj = {'a': 1};
        expect(registry.call('get', [obj, 'x.y']), isNull);
      });

      test('get handles simple single-level path', () {
        final obj = {'name': 'Alice'};
        expect(registry.call('get', [obj, 'name']), equals('Alice'));
      });

      test('merge combines two maps', () {
        final result = registry.call('merge', [
          {'a': 1, 'b': 2},
          {'b': 3, 'c': 4}
        ]) as Map;
        expect(result, equals({'a': 1, 'b': 3, 'c': 4}));
      });

      test('merge second map overwrites first', () {
        final result = registry.call('merge', [
          {'x': 'old'},
          {'x': 'new'}
        ]) as Map;
        expect(result['x'], equals('new'));
      });

      test('merge returns first arg if types are not both maps', () {
        final result = registry.call('merge', [42, 'string']);
        expect(result, equals(42));
      });
    });
  });
}
