import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/rubric_exceptions.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

void main() {
  group('RubricException', () {
    test('sets message and default code', () {
      final ex = RubricException('rubric error');
      expect(ex.message, 'rubric error');
      expect(ex.code, 'RUBRIC_ERROR');
    });

    test('accepts optional path and cause', () {
      final cause = Exception('root');
      final ex = RubricException('fail', path: 'rubrics[0]', cause: cause);
      expect(ex.path, 'rubrics[0]');
      expect(ex.cause, same(cause));
    });

    test('extends SkillException', () {
      expect(RubricException('m'), isA<SkillException>());
    });

    test('isRetryable is false', () {
      expect(RubricException('m').isRetryable, isFalse);
    });
  });

  group('RubricNotFoundException', () {
    test('stores rubricId and generates message', () {
      final ex = RubricNotFoundException('rubric-001');
      expect(ex.rubricId, 'rubric-001');
      expect(ex.message, 'Rubric not found: rubric-001');
    });

    test('overrides code to RUBRIC_NOT_FOUND', () {
      expect(RubricNotFoundException('r').code, 'RUBRIC_NOT_FOUND');
    });

    test('extends RubricException', () {
      expect(RubricNotFoundException('r'), isA<RubricException>());
    });
  });

  group('MissingMeasurementException', () {
    test('stores dimensionId and rubricId', () {
      final ex = MissingMeasurementException('accuracy', 'quality-rubric');
      expect(ex.dimensionId, 'accuracy');
      expect(ex.rubricId, 'quality-rubric');
      expect(
        ex.message,
        'Missing measurement for dimension accuracy in rubric quality-rubric',
      );
    });

    test('overrides code to MISSING_MEASUREMENT', () {
      expect(
        MissingMeasurementException('d', 'r').code,
        'MISSING_MEASUREMENT',
      );
    });

    test('extends RubricException', () {
      expect(
        MissingMeasurementException('d', 'r'),
        isA<RubricException>(),
      );
    });
  });

  group('UnknownExtractorException', () {
    test('stores extractorType and generates message', () {
      final ex = UnknownExtractorException('sentiment_v2');
      expect(ex.extractorType, 'sentiment_v2');
      expect(ex.message, 'Unknown extractor type: sentiment_v2');
    });

    test('overrides code to UNKNOWN_EXTRACTOR', () {
      expect(UnknownExtractorException('e').code, 'UNKNOWN_EXTRACTOR');
    });

    test('extends RubricException', () {
      expect(UnknownExtractorException('e'), isA<RubricException>());
    });
  });

  group('RubricValidationException', () {
    test('stores issues list', () {
      final ex = RubricValidationException(
        'validation failed',
        issues: ['missing dimension', 'invalid weight'],
      );
      expect(ex.message, 'validation failed');
      expect(ex.issues, ['missing dimension', 'invalid weight']);
    });

    test('defaults to empty issues list', () {
      final ex = RubricValidationException('m');
      expect(ex.issues, isEmpty);
    });

    test('overrides code to RUBRIC_VALIDATION_ERROR', () {
      expect(
        RubricValidationException('m').code,
        'RUBRIC_VALIDATION_ERROR',
      );
    });

    test('extends RubricException', () {
      expect(RubricValidationException('m'), isA<RubricException>());
    });
  });
}
