import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/load_exceptions.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

void main() {
  group('SkillLoadException', () {
    test('sets message and default code', () {
      final ex = SkillLoadException('load failed');
      expect(ex.message, 'load failed');
      expect(ex.code, 'SKILL_LOAD_ERROR');
    });

    test('accepts optional path and cause', () {
      final cause = Exception('inner');
      final ex = SkillLoadException(
        'load failed',
        path: 'bundle.yaml',
        cause: cause,
      );
      expect(ex.path, 'bundle.yaml');
      expect(ex.cause, same(cause));
    });

    test('accepts optional stackTrace', () {
      final trace = StackTrace.current;
      final ex = SkillLoadException('fail', stackTrace: trace);
      expect(ex.stackTrace, same(trace));
    });

    test('extends SkillException', () {
      expect(SkillLoadException('x'), isA<SkillException>());
    });

    test('isRetryable is false', () {
      expect(SkillLoadException('x').isRetryable, isFalse);
    });
  });

  group('SkillNotFoundException', () {
    test('constructs with skillId', () {
      final ex = SkillNotFoundException('my-skill');
      expect(ex.skillId, 'my-skill');
      expect(ex.message, 'Skill not found: my-skill');
      expect(ex.path, 'skills[my-skill]');
    });

    test('overrides code to SKILL_NOT_FOUND', () {
      expect(SkillNotFoundException('s').code, 'SKILL_NOT_FOUND');
    });

    test('extends SkillLoadException', () {
      expect(SkillNotFoundException('s'), isA<SkillLoadException>());
    });
  });

  group('ProcedureNotFoundException', () {
    test('constructs with skillId and procedureId', () {
      final ex = ProcedureNotFoundException('skill-1', 'proc-1');
      expect(ex.skillId, 'skill-1');
      expect(ex.procedureId, 'proc-1');
      expect(ex.message, 'Procedure proc-1 not found in skill skill-1');
    });

    test('overrides code to PROCEDURE_NOT_FOUND', () {
      expect(ProcedureNotFoundException('s', 'p').code, 'PROCEDURE_NOT_FOUND');
    });

    test('extends SkillLoadException', () {
      expect(ProcedureNotFoundException('s', 'p'), isA<SkillLoadException>());
    });
  });

  group('SkillVersionException', () {
    test('constructs with message and version info', () {
      final ex = SkillVersionException(
        'version mismatch',
        requestedVersion: '^2.0.0',
        availableVersion: '1.5.0',
      );
      expect(ex.message, 'version mismatch');
      expect(ex.requestedVersion, '^2.0.0');
      expect(ex.availableVersion, '1.5.0');
    });

    test('overrides code to SKILL_VERSION_ERROR', () {
      expect(SkillVersionException('v').code, 'SKILL_VERSION_ERROR');
    });

    test('accepts optional cause', () {
      final cause = Exception('inner');
      final ex = SkillVersionException('v', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends SkillLoadException', () {
      expect(SkillVersionException('v'), isA<SkillLoadException>());
    });
  });

  group('SkillParseException', () {
    test('constructs with message, path, line, column', () {
      final ex = SkillParseException(
        'unexpected token',
        path: 'bundle.yaml',
        line: 42,
        column: 10,
      );
      expect(ex.message, 'unexpected token');
      expect(ex.path, 'bundle.yaml');
      expect(ex.line, 42);
      expect(ex.column, 10);
    });

    test('overrides code to SKILL_PARSE_ERROR', () {
      expect(SkillParseException('p').code, 'SKILL_PARSE_ERROR');
    });

    test('accepts optional cause', () {
      final cause = FormatException('bad yaml');
      final ex = SkillParseException('p', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends SkillLoadException', () {
      expect(SkillParseException('p'), isA<SkillLoadException>());
    });
  });

  group('SkillRoutingException', () {
    test('constructs with message', () {
      final ex = SkillRoutingException('no route found');
      expect(ex.message, 'no route found');
    });

    test('overrides code to SKILL_ROUTING_ERROR', () {
      expect(SkillRoutingException('r').code, 'SKILL_ROUTING_ERROR');
    });

    test('extends SkillLoadException', () {
      expect(SkillRoutingException('r'), isA<SkillLoadException>());
    });
  });
}
