import 'package:test/test.dart';
import 'package:mcp_skill/src/bundle/bundle_validator.dart';
import 'package:mcp_skill/src/bundle/skill_bundle.dart' hide BundleValidator;
import 'package:mcp_skill/src/definition/procedure.dart';
import 'package:mcp_skill/src/definition/step.dart';

import '../helpers/test_data.dart';

void main() {
  group('DefaultBundleValidator', () {
    late DefaultBundleValidator validator;

    setUp(() {
      validator = DefaultBundleValidator();
    });

    group('validate', () {
      test('returns valid result for well-formed bundle', () async {
        final bundle = makeSkillBundle();
        final result = await validator.validate(bundle);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('detects empty manifest id', () async {
        final bundle = makeSkillBundle(id: '');
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
        expect(
          result.errors.any((e) => e.code == 'MISSING_ID'),
          isTrue,
        );
        expect(
          result.errors.firstWhere((e) => e.code == 'MISSING_ID').path,
          equals('manifest.id'),
        );
      });

      test('detects empty manifest name', () async {
        final bundle = makeSkillBundle(name: '');
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'MISSING_NAME'),
          isTrue,
        );
        expect(
          result.errors.firstWhere((e) => e.code == 'MISSING_NAME').path,
          equals('manifest.name'),
        );
      });

      test('detects empty manifest version', () async {
        final bundle = makeSkillBundle(version: '');
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'MISSING_VERSION'),
          isTrue,
        );
        expect(
          result.errors.firstWhere((e) => e.code == 'MISSING_VERSION').path,
          equals('manifest.version'),
        );
      });

      test('detects empty procedures list', () async {
        final bundle = makeSkillBundle(procedures: []);
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'NO_PROCEDURES'),
          isTrue,
        );
        expect(
          result.errors.firstWhere((e) => e.code == 'NO_PROCEDURES').path,
          equals('procedures'),
        );
      });

      test('accumulates multiple errors at once', () async {
        final bundle = SkillBundle(
          schemaVersion: '0.1.0',
          manifest: const SkillManifest(
            id: '',
            name: '',
            version: '',
            provider: 'test',
          ),
          procedures: [],
        );
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        // Should have errors for id, name, version, and procedures
        expect(result.errors.length, greaterThanOrEqualTo(4));

        final errorCodes = result.errors.map((e) => e.code).toSet();
        expect(errorCodes, contains('MISSING_ID'));
        expect(errorCodes, contains('MISSING_NAME'));
        expect(errorCodes, contains('MISSING_VERSION'));
        expect(errorCodes, contains('NO_PROCEDURES'));
      });

      test('detects empty procedure id', () async {
        final bundle = makeSkillBundle(
          procedures: [
            const Procedure(
              id: '',
              name: 'Proc with empty ID',
              steps: [
                Step(
                  id: 's1',
                  order: 1,
                  name: 'Step 1',
                  action: StepAction(type: 'llm'),
                ),
              ],
            ),
          ],
        );
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'MISSING_PROC_ID'),
          isTrue,
        );
        expect(
          result.errors.firstWhere((e) => e.code == 'MISSING_PROC_ID').path,
          equals('procedures[0].id'),
        );
      });

      test('procedure with no steps is still valid', () async {
        final bundle = makeSkillBundle(
          procedures: [
            const Procedure(
              id: 'proc-empty',
              name: 'Empty Procedure',
              steps: [],
            ),
          ],
        );
        final result = await validator.validate(bundle);

        // No errors means valid result is returned
        // (warnings are only included in invalid results)
        expect(result.isValid, isTrue);
      });

      test('validates multiple procedures and indexes errors correctly',
          () async {
        final bundle = makeSkillBundle(
          procedures: [
            makeProcedure(id: 'valid-proc'),
            const Procedure(id: '', name: 'Bad Proc', steps: []),
          ],
        );
        final result = await validator.validate(bundle);

        expect(result.isValid, isFalse);
        // The empty-id error should reference procedures[1]
        final procError =
            result.errors.firstWhere((e) => e.code == 'MISSING_PROC_ID');
        expect(procError.path, equals('procedures[1].id'));
      });

      test('accumulates errors and warnings for the same bundle', () async {
        final bundle = SkillBundle(
          schemaVersion: '0.1.0',
          manifest: const SkillManifest(
            id: '',
            name: 'Test',
            version: '1.0.0',
            provider: 'test',
          ),
          procedures: [
            const Procedure(id: 'p1', name: 'P1', steps: []),
          ],
        );
        final result = await validator.validate(bundle);

        // id is empty => error; procedure has no steps => warning
        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.code == 'MISSING_ID'), isTrue);
        expect(result.warnings.any((e) => e.code == 'NO_STEPS'), isTrue);
      });

      test('valid bundle with multiple procedures and steps passes', () async {
        final bundle = makeSkillBundle(
          procedures: [
            makeProcedure(id: 'proc-a', name: 'Proc A'),
            makeProcedure(id: 'proc-b', name: 'Proc B'),
          ],
        );
        final result = await validator.validate(bundle);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
      });
    });

    group('validateJson', () {
      test('returns valid for well-formed JSON', () async {
        final json = <String, dynamic>{
          'manifest': {
            'id': 'com.test.skill',
            'name': 'Test',
            'version': '1.0.0',
            'provider': 'test',
          },
          'procedures': [
            {
              'id': 'proc-1',
              'name': 'Proc 1',
              'steps': [
                {
                  'id': 's1',
                  'order': 1,
                  'name': 'S1',
                  'action': {'type': 'llm'},
                },
              ],
            },
          ],
        };
        final result = await validator.validateJson(json);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('detects missing manifest key', () async {
        final json = <String, dynamic>{
          'procedures': [
            {
              'id': 'p1',
              'name': 'P1',
              'steps': [
                {
                  'id': 's1',
                  'order': 1,
                  'name': 'S1',
                  'action': {'type': 'llm'},
                },
              ],
            },
          ],
        };
        final result = await validator.validateJson(json);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'MISSING_MANIFEST'),
          isTrue,
        );
      });

      test('detects missing procedures key', () async {
        final json = <String, dynamic>{
          'manifest': {
            'id': 'com.test',
            'name': 'Test',
            'version': '1.0.0',
            'provider': 'test',
          },
        };
        final result = await validator.validateJson(json);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'MISSING_PROCEDURES'),
          isTrue,
        );
      });

      test('detects both missing manifest and procedures keys', () async {
        final json = <String, dynamic>{};
        final result = await validator.validateJson(json);

        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(2));
        final codes = result.errors.map((e) => e.code).toSet();
        expect(codes, contains('MISSING_MANIFEST'));
        expect(codes, contains('MISSING_PROCEDURES'));
      });

      test('performs structural validation after key check passes', () async {
        final json = <String, dynamic>{
          'manifest': {
            'id': '',
            'name': '',
            'version': '',
            'provider': 'test',
          },
          'procedures': <dynamic>[],
        };
        final result = await validator.validateJson(json);

        expect(result.isValid, isFalse);
        // Should show field-level errors after parsing succeeds
        final codes = result.errors.map((e) => e.code).toSet();
        expect(codes, contains('MISSING_ID'));
        expect(codes, contains('MISSING_NAME'));
        expect(codes, contains('MISSING_VERSION'));
        expect(codes, contains('NO_PROCEDURES'));
      });

      test('returns PARSE_ERROR when JSON structure is unparseable', () async {
        // manifest present but with wrong type causes a parse error
        final json = <String, dynamic>{
          'manifest': 'not-a-map',
          'procedures': [],
        };
        final result = await validator.validateJson(json);

        expect(result.isValid, isFalse);
        expect(
          result.errors.any((e) => e.code == 'PARSE_ERROR'),
          isTrue,
        );
      });

      test('returns early with missing keys before attempting parse',
          () async {
        // Only 'manifest' missing -> returns immediately with that error
        // and does not try to parse
        final json = <String, dynamic>{
          'procedures': [
            {
              'id': 'p1',
              'name': 'P1',
              'steps': [],
            },
          ],
        };
        final result = await validator.validateJson(json);

        expect(result.isValid, isFalse);
        // Should only have the MISSING_MANIFEST error, not field-level errors
        expect(
          result.errors.every(
              (e) => e.code == 'MISSING_MANIFEST' || e.code == 'PARSE_ERROR'),
          isTrue,
        );
      });
    });

    group('BundleValidationResult', () {
      test('factory valid creates a valid result', () {
        final result = BundleValidationResult.valid();

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
      });

      test('factory invalid creates an invalid result', () {
        final errors = [
          const BundleValidationError(
            code: 'TEST',
            message: 'Test error',
          ),
        ];
        final result = BundleValidationResult.invalid(errors);

        expect(result.isValid, isFalse);
        expect(result.errors, hasLength(1));
        expect(result.warnings, isEmpty);
      });

      test('factory invalid supports warnings parameter', () {
        final errors = [
          const BundleValidationError(code: 'ERR', message: 'Error'),
        ];
        final warnings = [
          const BundleValidationError(
            code: 'WARN',
            message: 'Warning',
            severity: BundleValidationSeverity.warning,
          ),
        ];
        final result =
            BundleValidationResult.invalid(errors, warnings: warnings);

        expect(result.isValid, isFalse);
        expect(result.errors, hasLength(1));
        expect(result.warnings, hasLength(1));
      });
    });

    group('BundleValidationError', () {
      test('toJson includes all fields', () {
        const error = BundleValidationError(
          code: 'TEST_CODE',
          message: 'Test message',
          path: 'test.path',
          severity: BundleValidationSeverity.error,
        );
        final json = error.toJson();

        expect(json['code'], equals('TEST_CODE'));
        expect(json['message'], equals('Test message'));
        expect(json['path'], equals('test.path'));
        expect(json['severity'], equals('error'));
      });

      test('toJson excludes null path', () {
        const error = BundleValidationError(
          code: 'TEST',
          message: 'Test',
        );
        final json = error.toJson();

        expect(json.containsKey('path'), isFalse);
      });

      test('default severity is error', () {
        const error = BundleValidationError(
          code: 'TEST',
          message: 'Test',
        );

        expect(error.severity, equals(BundleValidationSeverity.error));
      });
    });

    group('BundleValidator abstract interface', () {
      test('DefaultBundleValidator is a BundleValidator', () {
        expect(validator, isA<BundleValidator>());
      });
    });
  });
}
