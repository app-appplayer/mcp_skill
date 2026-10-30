/// Function registry for the expression language.
///
/// Provides 60+ built-in functions across 6 categories.
library;

import 'dart:math' as math;

import 'package:mcp_bundle/mcp_bundle.dart' show parseJsonValue;

import 'expression_exception.dart';

/// Type for expression functions.
typedef ExpressionFunction = dynamic Function(List<dynamic> args);

/// Registry of functions available in expressions.
class FunctionRegistry {
  final Map<String, ExpressionFunction> _functions = {};

  FunctionRegistry();

  /// Create a registry with all standard built-in functions.
  factory FunctionRegistry.standard() {
    final registry = FunctionRegistry();
    registry._registerStringFunctions();
    registry._registerMathFunctions();
    registry._registerArrayFunctions();
    registry._registerDateFunctions();
    registry._registerTypeFunctions();
    registry._registerObjectFunctions();
    return registry;
  }

  /// Register a function.
  void register(String name, ExpressionFunction fn) {
    _functions[name] = fn;
  }

  /// Check if a function is registered.
  bool has(String name) => _functions.containsKey(name);

  /// Call a registered function.
  dynamic call(String name, List<dynamic> args) {
    final fn = _functions[name];
    if (fn == null) {
      throw UnknownFunctionException(name);
    }
    return fn(args);
  }

  // ========================================================================
  // STRING FUNCTIONS
  // ========================================================================

  void _registerStringFunctions() {
    register('length', (args) {
      final val = args[0];
      if (val is String) return val.length;
      if (val is List) return val.length;
      if (val is Map) return val.length;
      return 0;
    });

    register('substring', (args) {
      final str = args[0]?.toString() ?? '';
      final start = _toInt(args[1]);
      final end = args.length > 2 ? _toInt(args[2]) : str.length;
      return str.substring(
        start.clamp(0, str.length),
        end.clamp(start, str.length),
      );
    });

    register('lower', (args) => args[0]?.toString().toLowerCase() ?? '');
    register('upper', (args) => args[0]?.toString().toUpperCase() ?? '');
    register('trim', (args) => args[0]?.toString().trim() ?? '');

    register('startsWith', (args) {
      return (args[0]?.toString() ?? '').startsWith(args[1]?.toString() ?? '');
    });

    register('endsWith', (args) {
      return (args[0]?.toString() ?? '').endsWith(args[1]?.toString() ?? '');
    });

    register('contains', (args) {
      final val = args[0];
      final search = args[1];
      if (val is String) return val.contains(search?.toString() ?? '');
      if (val is List) return val.contains(search);
      return false;
    });

    register('replace', (args) {
      return (args[0]?.toString() ?? '')
          .replaceFirst(args[1]?.toString() ?? '', args[2]?.toString() ?? '');
    });

    register('split', (args) {
      return (args[0]?.toString() ?? '').split(args[1]?.toString() ?? ',');
    });

    register('parseJson', (args) {
      try {
        return parseJsonValue(args.firstOrNull);
      } on FormatException catch (e) {
        throw EvaluationException(e.message);
      }
    });

    register('join', (args) {
      final list = args[0];
      final delimiter = args.length > 1 ? args[1]?.toString() ?? '' : '';
      if (list is List) return list.map((e) => e?.toString() ?? '').join(delimiter);
      return '';
    });
  }

  // ========================================================================
  // MATH FUNCTIONS
  // ========================================================================

  void _registerMathFunctions() {
    register('min', (args) {
      final a = _toNum(args[0]);
      final b = _toNum(args[1]);
      return math.min(a, b);
    });

    register('max', (args) {
      final a = _toNum(args[0]);
      final b = _toNum(args[1]);
      return math.max(a, b);
    });

    register('abs', (args) => _toNum(args[0]).abs());
    register('round', (args) => _toNum(args[0]).round());
    register('floor', (args) => _toNum(args[0]).floor());
    register('ceil', (args) => _toNum(args[0]).ceil());

    register('clamp', (args) {
      return _toNum(args[0]).clamp(_toNum(args[1]), _toNum(args[2]));
    });

    register('sqrt', (args) => math.sqrt(_toNum(args[0]).toDouble()));
    register('pow', (args) {
      return math.pow(_toNum(args[0]), _toNum(args[1]));
    });
    register('log', (args) => math.log(_toNum(args[0]).toDouble()));
  }

  // ========================================================================
  // ARRAY FUNCTIONS
  // ========================================================================

  void _registerArrayFunctions() {
    register('first', (args) {
      final list = _toList(args[0]);
      return list.isEmpty ? null : list.first;
    });

    register('last', (args) {
      final list = _toList(args[0]);
      return list.isEmpty ? null : list.last;
    });

    register('at', (args) {
      final list = _toList(args[0]);
      final index = _toInt(args[1]);
      if (index < 0 || index >= list.length) return null;
      return list[index];
    });

    register('slice', (args) {
      final list = _toList(args[0]);
      final start = _toInt(args[1]).clamp(0, list.length);
      final end =
          args.length > 2 ? _toInt(args[2]).clamp(start, list.length) : list.length;
      return list.sublist(start, end);
    });

    register('reverse', (args) {
      return _toList(args[0]).reversed.toList();
    });

    register('unique', (args) {
      return _toList(args[0]).toSet().toList();
    });

    register('flatten', (args) {
      final list = _toList(args[0]);
      final result = <dynamic>[];
      for (final item in list) {
        if (item is List) {
          result.addAll(item);
        } else {
          result.add(item);
        }
      }
      return result;
    });

    register('sort', (args) {
      final list = List<dynamic>.from(_toList(args[0]));
      list.sort((a, b) {
        if (a is Comparable<dynamic> && b is Comparable<dynamic>) {
          return Comparable.compare(a, b);
        }
        return a.toString().compareTo(b.toString());
      });
      return list;
    });

    register('map', (args) {
      // Simplified: expects a lambda function or key path
      final list = _toList(args[0]);
      if (args.length < 2 || args[1] == null) return list;
      final key = args[1].toString();
      if (key.startsWith(r'$.')) {
        final field = key.substring(2);
        return list.map((item) {
          if (item is Map) return item[field];
          return null;
        }).toList();
      }
      return list;
    });

    register('filter', (args) {
      final list = _toList(args[0]);
      if (args.length < 2 || args[1] == null) return list;
      final key = args[1].toString();
      if (key.startsWith(r'$.')) {
        final field = key.substring(2);
        return list.where((item) {
          if (item is Map) {
            final val = item[field];
            return val != null && val != false && val != 0 && val != '';
          }
          return false;
        }).toList();
      }
      return list;
    });

    register('find', (args) {
      final list = _toList(args[0]);
      if (args.length < 2 || args[1] == null) return null;
      final key = args[1].toString();
      if (key.startsWith(r'$.')) {
        final field = key.substring(2);
        for (final item in list) {
          if (item is Map) {
            final val = item[field];
            if (val != null && val != false) return item;
          }
        }
      }
      return null;
    });

    register('every', (args) {
      final list = _toList(args[0]);
      if (args.length < 2 || args[1] == null) return false;
      final key = args[1].toString();
      if (key.startsWith(r'$.')) {
        final field = key.substring(2);
        return list.every((item) {
          if (item is Map) {
            final val = item[field];
            return val != null && val != false;
          }
          return false;
        });
      }
      return false;
    });

    register('some', (args) {
      final list = _toList(args[0]);
      if (args.length < 2 || args[1] == null) return false;
      final key = args[1].toString();
      if (key.startsWith(r'$.')) {
        final field = key.substring(2);
        return list.any((item) {
          if (item is Map) {
            final val = item[field];
            return val != null && val != false;
          }
          return false;
        });
      }
      return false;
    });

    register('reduce', (args) {
      final list = _toList(args[0]);
      if (list.isEmpty) return args.length > 2 ? args[2] : null;
      var acc = args.length > 2 ? args[2] : list.first;
      final startIndex = args.length > 2 ? 0 : 1;
      for (var i = startIndex; i < list.length; i++) {
        final accVal = acc;
        final listVal = list[i];
        if (accVal is num && listVal is num) {
          acc = accVal + listVal;
        }
      }
      return acc;
    });
  }

  // ========================================================================
  // DATE FUNCTIONS
  // ========================================================================

  void _registerDateFunctions() {
    register('now', (args) => DateTime.now().toIso8601String());

    register('formatDate', (args) {
      final date = _toDateTime(args[0]);
      if (date == null) return '';
      // Simple format: just return ISO string (full formatting requires intl)
      return date.toIso8601String();
    });

    register('parseDate', (args) {
      return DateTime.tryParse(args[0]?.toString() ?? '')?.toIso8601String();
    });

    register('addDays', (args) {
      final date = _toDateTime(args[0]);
      if (date == null) return null;
      return date.add(Duration(days: _toInt(args[1]))).toIso8601String();
    });

    register('addHours', (args) {
      final date = _toDateTime(args[0]);
      if (date == null) return null;
      return date.add(Duration(hours: _toInt(args[1]))).toIso8601String();
    });

    register('diffDays', (args) {
      final d1 = _toDateTime(args[0]);
      final d2 = _toDateTime(args[1]);
      if (d1 == null || d2 == null) return 0;
      return d1.difference(d2).inDays;
    });

    register('diffHours', (args) {
      final d1 = _toDateTime(args[0]);
      final d2 = _toDateTime(args[1]);
      if (d1 == null || d2 == null) return 0;
      return d1.difference(d2).inHours;
    });

    register('isBefore', (args) {
      final d1 = _toDateTime(args[0]);
      final d2 = _toDateTime(args[1]);
      if (d1 == null || d2 == null) return false;
      return d1.isBefore(d2);
    });

    register('isAfter', (args) {
      final d1 = _toDateTime(args[0]);
      final d2 = _toDateTime(args[1]);
      if (d1 == null || d2 == null) return false;
      return d1.isAfter(d2);
    });

    register('age', (args) {
      final date = _toDateTime(args[0]);
      if (date == null) return 0;
      return DateTime.now().difference(date).inSeconds;
    });

    register('duration', (args) {
      final d1 = _toDateTime(args[0]);
      final d2 = _toDateTime(args[1]);
      if (d1 == null || d2 == null) return 0;
      return d1.difference(d2).inSeconds.abs();
    });
  }

  // ========================================================================
  // TYPE FUNCTIONS
  // ========================================================================

  void _registerTypeFunctions() {
    register('type', (args) {
      final val = args[0];
      if (val == null) return 'null';
      if (val is bool) return 'boolean';
      if (val is num) return 'number';
      if (val is String) return 'string';
      if (val is List) return 'array';
      if (val is Map) return 'object';
      return val.runtimeType.toString();
    });

    register('isNull', (args) => args[0] == null);
    register('isNumber', (args) => args[0] is num);
    register('isString', (args) => args[0] is String);
    register('isBool', (args) => args[0] is bool);
    register('isArray', (args) => args[0] is List);
    register('isObject', (args) => args[0] is Map);

    register('isEmpty', (args) {
      final val = args[0];
      if (val == null) return true;
      if (val is String) return val.isEmpty;
      if (val is List) return val.isEmpty;
      if (val is Map) return val.isEmpty;
      return false;
    });

    register('coalesce', (args) {
      for (final arg in args) {
        if (arg != null) return arg;
      }
      return null;
    });

    register('defaultVal', (args) {
      return args[0] ?? (args.length > 1 ? args[1] : null);
    });

    register('toNumber', (args) {
      final val = args[0];
      if (val is num) return val;
      if (val is String) return num.tryParse(val) ?? 0;
      if (val is bool) return val ? 1 : 0;
      return 0;
    });

    register('toStr', (args) => args[0]?.toString() ?? '');

    register('toBool', (args) {
      final val = args[0];
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val != 0;
      if (val is String) return val.isNotEmpty && val.toLowerCase() != 'false';
      return true;
    });
  }

  // ========================================================================
  // OBJECT FUNCTIONS
  // ========================================================================

  void _registerObjectFunctions() {
    register('keys', (args) {
      final val = args[0];
      if (val is Map) return val.keys.toList();
      return <String>[];
    });

    register('values', (args) {
      final val = args[0];
      if (val is Map) return val.values.toList();
      return [];
    });

    register('entries', (args) {
      final val = args[0];
      if (val is Map) {
        return val.entries
            .map((e) => {'key': e.key, 'value': e.value})
            .toList();
      }
      return [];
    });

    register('has', (args) {
      final val = args[0];
      final key = args[1]?.toString();
      if (val is Map && key != null) return val.containsKey(key);
      return false;
    });

    register('get', (args) {
      dynamic current = args[0];
      final path = args[1]?.toString() ?? '';
      final defaultVal = args.length > 2 ? args[2] : null;

      for (final part in path.split('.')) {
        if (current is Map) {
          current = current[part];
        } else {
          return defaultVal;
        }
      }
      return current ?? defaultVal;
    });

    register('merge', (args) {
      final obj1 = args[0];
      final obj2 = args[1];
      if (obj1 is Map && obj2 is Map) {
        return {...obj1, ...obj2};
      }
      return obj1;
    });
  }

  // ========================================================================
  // HELPER METHODS
  // ========================================================================

  static num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    if (value is bool) return value ? 1 : 0;
    return 0;
  }

  static int _toInt(dynamic value) => _toNum(value).toInt();

  static List<dynamic> _toList(dynamic value) {
    if (value is List) return value;
    if (value == null) return [];
    return [value];
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
