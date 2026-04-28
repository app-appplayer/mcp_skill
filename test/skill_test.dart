import 'package:test/test.dart';
import 'package:mcp_skill/mcp_skill.dart';

void main() {
  group('Skill', () {
    test('creates skill with required fields', () {
      final skill = Skill(
        id: 'skill-1',
        name: 'Test Skill',
      );

      expect(skill.id, equals('skill-1'));
      expect(skill.name, equals('Test Skill'));
      expect(skill.version, equals('1.0.0'));
      expect(skill.inputs, isEmpty);
      expect(skill.steps, isEmpty);
    });

    test('creates skill with all fields', () {
      final skill = Skill(
        id: 'skill-2',
        name: 'Full Skill',
        description: 'A complete skill definition',
        version: '2.0.0',
        inputs: [
          Parameter(name: 'query', type: ParameterType.string, required: true),
        ],
        tags: ['ai', 'search'],
        metadata: {'author': 'test'},
      );

      expect(skill.description, equals('A complete skill definition'));
      expect(skill.version, equals('2.0.0'));
      expect(skill.inputs.length, equals(1));
      expect(skill.tags, containsAll(['ai', 'search']));
    });

    test('getInput finds parameter by name', () {
      final skill = Skill(
        id: 'skill-3',
        name: 'Test',
        inputs: [
          Parameter(name: 'query', type: ParameterType.string),
          Parameter(name: 'limit', type: ParameterType.number),
        ],
      );

      expect(skill.getInput('query'), isNotNull);
      expect(skill.getInput('query')!.name, equals('query'));
      expect(skill.getInput('missing'), isNull);
    });

    test('validateInputs checks required parameters', () {
      final skill = Skill(
        id: 'skill-4',
        name: 'Test',
        inputs: [
          Parameter(name: 'required', type: ParameterType.string, required: true),
          Parameter(name: 'optional', type: ParameterType.string, required: false),
        ],
      );

      final errors = skill.validateInputs({});
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('required')), isTrue);
    });

    test('serializes and deserializes correctly', () {
      final original = Skill(
        id: 'skill-5',
        name: 'Serializable Skill',
        description: 'Test description',
        version: '1.2.3',
      );

      final json = original.toJson();
      final restored = Skill.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.version, equals(original.version));
    });
  });

  group('Parameter', () {
    test('creates parameter with required fields', () {
      final param = Parameter(
        name: 'test',
        type: ParameterType.string,
      );

      expect(param.name, equals('test'));
      expect(param.type, equals(ParameterType.string));
      expect(param.required, isTrue);
    });

    test('creates required parameter', () {
      final param = Parameter(
        name: 'required_param',
        type: ParameterType.number,
        required: true,
        description: 'A required number',
      );

      expect(param.required, isTrue);
      expect(param.description, equals('A required number'));
    });

    test('validates type correctly', () {
      final stringParam = Parameter(name: 'str', type: ParameterType.string);
      final numberParam = Parameter(name: 'num', type: ParameterType.number);
      final boolParam = Parameter(name: 'bool', type: ParameterType.boolean);

      expect(stringParam.validateType('hello'), isNull);
      expect(stringParam.validateType(123), isNotNull);

      expect(numberParam.validateType(42), isNull);
      expect(numberParam.validateType(3.14), isNull);
      expect(numberParam.validateType('hello'), isNotNull);

      expect(boolParam.validateType(true), isNull);
      expect(boolParam.validateType('true'), isNotNull);
    });

    test('serializes and deserializes correctly', () {
      final original = Parameter(
        name: 'test',
        type: ParameterType.array,
        required: true,
        description: 'Test param',
      );

      final json = original.toJson();
      final restored = Parameter.fromJson(json);

      expect(restored.name, equals(original.name));
      expect(restored.type, equals(original.type));
      expect(restored.required, equals(original.required));
    });
  });

  group('ParameterType', () {
    test('fromString parses correctly', () {
      expect(ParameterType.fromString('string'), equals(ParameterType.string));
      expect(ParameterType.fromString('number'), equals(ParameterType.number));
      expect(ParameterType.fromString('boolean'), equals(ParameterType.boolean));
      expect(ParameterType.fromString('array'), equals(ParameterType.array));
      expect(ParameterType.fromString('object'), equals(ParameterType.object));
    });
  });

  group('SkillTrigger', () {
    test('creates manual trigger', () {
      final trigger = SkillTrigger(type: TriggerType.manual);

      expect(trigger.type, equals(TriggerType.manual));
      expect(trigger.config, isEmpty);
    });

    test('creates schedule trigger with config', () {
      final trigger = SkillTrigger(
        type: TriggerType.schedule,
        config: {'cron': '0 * * * *'},
      );

      expect(trigger.type, equals(TriggerType.schedule));
      expect(trigger.config['cron'], equals('0 * * * *'));
    });

    test('serializes and deserializes correctly', () {
      final original = SkillTrigger(
        type: TriggerType.event,
        config: {'event': 'user.login'},
        condition: 'user.active == true',
      );

      final json = original.toJson();
      final restored = SkillTrigger.fromJson(json);

      expect(restored.type, equals(original.type));
      expect(restored.config['event'], equals(original.config['event']));
      expect(restored.condition, equals(original.condition));
    });
  });

  group('TriggerType', () {
    test('fromString parses correctly', () {
      expect(TriggerType.fromString('manual'), equals(TriggerType.manual));
      expect(TriggerType.fromString('schedule'), equals(TriggerType.schedule));
      expect(TriggerType.fromString('event'), equals(TriggerType.event));
      expect(TriggerType.fromString('webhook'), equals(TriggerType.webhook));
    });

    test('fromString returns unknown for invalid', () {
      expect(TriggerType.fromString('invalid'), equals(TriggerType.unknown));
    });
  });
}
