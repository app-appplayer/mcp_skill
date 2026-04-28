import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/validation_exceptions.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

void main() {
  group('SkillValidationException', () {
    test('sets message and default code', () {
      final ex = SkillValidationException('invalid input');
      expect(ex.message, 'invalid input');
      expect(ex.code, 'VALIDATION_ERROR');
    });

    test('stores errors list', () {
      final ex = SkillValidationException(
        'validation failed',
        errors: ['field required', 'type mismatch'],
      );
      expect(ex.errors, ['field required', 'type mismatch']);
    });

    test('defaults to empty errors list', () {
      final ex = SkillValidationException('m');
      expect(ex.errors, isEmpty);
    });

    test('accepts optional path and cause', () {
      final cause = Exception('root');
      final ex = SkillValidationException(
        'm',
        path: 'inputs.name',
        cause: cause,
      );
      expect(ex.path, 'inputs.name');
      expect(ex.cause, same(cause));
    });

    test('toJson includes errors when non-empty', () {
      final ex = SkillValidationException(
        'fail',
        errors: ['err1', 'err2'],
      );
      final json = ex.toJson();
      expect(json['code'], 'VALIDATION_ERROR');
      expect(json['message'], 'fail');
      expect(json['errors'], ['err1', 'err2']);
      expect(json['isRetryable'], isFalse);
    });

    test('toJson omits errors when empty', () {
      final ex = SkillValidationException('m');
      final json = ex.toJson();
      expect(json.containsKey('errors'), isFalse);
    });

    test('extends SkillException', () {
      expect(SkillValidationException('m'), isA<SkillException>());
    });
  });

  group('InputValidationException', () {
    test('stores parameterName', () {
      final ex = InputValidationException(
        'name is required',
        parameterName: 'name',
      );
      expect(ex.parameterName, 'name');
      expect(ex.message, 'name is required');
    });

    test('overrides code to INPUT_VALIDATION_ERROR', () {
      expect(InputValidationException('m').code, 'INPUT_VALIDATION_ERROR');
    });

    test('inherits errors list', () {
      final ex = InputValidationException(
        'm',
        errors: ['too short'],
        path: 'inputs.name',
      );
      expect(ex.errors, ['too short']);
      expect(ex.path, 'inputs.name');
    });

    test('extends SkillValidationException', () {
      expect(
        InputValidationException('m'),
        isA<SkillValidationException>(),
      );
    });
  });

  group('OutputValidationException', () {
    test('sets message and errors', () {
      final ex = OutputValidationException(
        'bad output',
        errors: ['missing field'],
        path: 'outputs.result',
      );
      expect(ex.message, 'bad output');
      expect(ex.errors, ['missing field']);
      expect(ex.path, 'outputs.result');
    });

    test('overrides code to OUTPUT_VALIDATION_ERROR', () {
      expect(OutputValidationException('m').code, 'OUTPUT_VALIDATION_ERROR');
    });

    test('extends SkillValidationException', () {
      expect(
        OutputValidationException('m'),
        isA<SkillValidationException>(),
      );
    });
  });

  group('SchemaValidationException', () {
    test('stores schemaPath', () {
      final ex = SchemaValidationException(
        'schema error',
        schemaPath: '#/properties/name',
        errors: ['type mismatch'],
        path: 'inputs',
      );
      expect(ex.schemaPath, '#/properties/name');
      expect(ex.errors, ['type mismatch']);
      expect(ex.path, 'inputs');
    });

    test('overrides code to SCHEMA_VALIDATION_ERROR', () {
      expect(SchemaValidationException('m').code, 'SCHEMA_VALIDATION_ERROR');
    });

    test('extends SkillValidationException', () {
      expect(
        SchemaValidationException('m'),
        isA<SkillValidationException>(),
      );
    });
  });
}
