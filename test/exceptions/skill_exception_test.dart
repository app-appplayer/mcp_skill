import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

/// Concrete subclass of SkillException for testing the abstract base.
class _TestException extends SkillException {
  final bool _retryable;
  final Duration? _retryDelay;

  _TestException({
    required super.message,
    required super.code,
    super.path,
    super.cause,
    super.stackTrace,
    bool retryable = false,
    Duration? retryDelay,
  })  : _retryable = retryable,
        _retryDelay = retryDelay;

  @override
  bool get isRetryable => _retryable;

  @override
  Duration? get retryDelay => _retryDelay;
}

void main() {
  group('SkillException', () {
    test('stores message and code', () {
      final ex = _TestException(message: 'boom', code: 'TEST_ERR');
      expect(ex.message, 'boom');
      expect(ex.code, 'TEST_ERR');
    });

    test('stores optional path', () {
      final ex = _TestException(
        message: 'bad field',
        code: 'E',
        path: 'inputs.name',
      );
      expect(ex.path, 'inputs.name');
    });

    test('stores optional cause', () {
      final cause = FormatException('inner');
      final ex = _TestException(message: 'm', code: 'E', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('stores optional stackTrace', () {
      final trace = StackTrace.current;
      final ex = _TestException(message: 'm', code: 'E', stackTrace: trace);
      expect(ex.stackTrace, same(trace));
    });

    test('isRetryable defaults to false', () {
      final ex = _TestException(message: 'm', code: 'E');
      expect(ex.isRetryable, isFalse);
    });

    test('retryDelay defaults to null', () {
      final ex = _TestException(message: 'm', code: 'E');
      expect(ex.retryDelay, isNull);
    });

    test('isRetryable and retryDelay can be overridden', () {
      final ex = _TestException(
        message: 'm',
        code: 'E',
        retryable: true,
        retryDelay: const Duration(seconds: 5),
      );
      expect(ex.isRetryable, isTrue);
      expect(ex.retryDelay, const Duration(seconds: 5));
    });

    test('toString includes code and message', () {
      final ex = _TestException(message: 'oops', code: 'MY_ERR');
      expect(ex.toString(), 'SkillException[MY_ERR]: oops');
    });

    test('toJson includes code, message, isRetryable', () {
      final ex = _TestException(
        message: 'fail',
        code: 'CODE_1',
        path: 'a.b',
      );
      final json = ex.toJson();
      expect(json['code'], 'CODE_1');
      expect(json['message'], 'fail');
      expect(json['path'], 'a.b');
      expect(json['isRetryable'], isFalse);
    });

    test('toJson omits path when null', () {
      final ex = _TestException(message: 'm', code: 'E');
      final json = ex.toJson();
      expect(json.containsKey('path'), isFalse);
    });

    test('implements Exception', () {
      final ex = _TestException(message: 'm', code: 'E');
      expect(ex, isA<Exception>());
    });
  });
}
