import 'package:test/test.dart';
import 'package:mcp_skill/src/definition/skill.dart';
import 'package:mcp_skill/src/definition/parameter.dart';
import 'package:mcp_skill/src/definition/step.dart';

void main() {
  group('TriggerType', () {
    test('has all expected values', () {
      expect(TriggerType.values, contains(TriggerType.manual));
      expect(TriggerType.values, contains(TriggerType.schedule));
      expect(TriggerType.values, contains(TriggerType.event));
      expect(TriggerType.values, contains(TriggerType.webhook));
      expect(TriggerType.values, contains(TriggerType.message));
      expect(TriggerType.values, contains(TriggerType.unknown));
    });

    test('fromString returns correct value', () {
      expect(TriggerType.fromString('manual'), equals(TriggerType.manual));
      expect(TriggerType.fromString('schedule'), equals(TriggerType.schedule));
      expect(TriggerType.fromString('event'), equals(TriggerType.event));
      expect(TriggerType.fromString('webhook'), equals(TriggerType.webhook));
      expect(TriggerType.fromString('message'), equals(TriggerType.message));
    });

    test('fromString returns unknown for invalid values', () {
      expect(TriggerType.fromString('invalid'), equals(TriggerType.unknown));
      expect(TriggerType.fromString(''), equals(TriggerType.unknown));
    });
  });

  group('SkillTrigger', () {
    test('constructor creates instance with required fields', () {
      final trigger = SkillTrigger(type: TriggerType.manual);

      expect(trigger.type, equals(TriggerType.manual));
      expect(trigger.config, isEmpty);
      expect(trigger.condition, isNull);
    });

    test('constructor creates instance with all fields', () {
      final trigger = SkillTrigger(
        type: TriggerType.schedule,
        config: {'cron': '0 0 * * *'},
        condition: 'env.production',
      );

      expect(trigger.type, equals(TriggerType.schedule));
      expect(trigger.config, equals({'cron': '0 0 * * *'}));
      expect(trigger.condition, equals('env.production'));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'type': 'webhook',
        'config': {'path': '/api/trigger', 'method': 'POST'},
        'condition': 'request.valid',
      };

      final trigger = SkillTrigger.fromJson(json);

      expect(trigger.type, equals(TriggerType.webhook));
      expect(trigger.config, equals({'path': '/api/trigger', 'method': 'POST'}));
      expect(trigger.condition, equals('request.valid'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final trigger = SkillTrigger.fromJson(json);

      expect(trigger.type, equals(TriggerType.manual));
      expect(trigger.config, isEmpty);
      expect(trigger.condition, isNull);
    });

    test('toJson converts instance to JSON', () {
      final trigger = SkillTrigger(
        type: TriggerType.event,
        config: {'event': 'user.created'},
        condition: 'event.user.active',
      );

      final json = trigger.toJson();

      expect(json['type'], equals('event'));
      expect(json['config'], equals({'event': 'user.created'}));
      expect(json['condition'], equals('event.user.active'));
    });

    test('toJson excludes empty config and null condition', () {
      final trigger = SkillTrigger(type: TriggerType.manual);

      final json = trigger.toJson();

      expect(json.containsKey('config'), isFalse);
      expect(json.containsKey('condition'), isFalse);
    });
  });

  group('OutputSpec', () {
    test('constructor creates instance with required fields', () {
      final output = OutputSpec(type: ParameterType.string);

      expect(output.type, equals(ParameterType.string));
      expect(output.description, isNull);
      expect(output.schema, isNull);
    });

    test('constructor creates instance with all fields', () {
      final output = OutputSpec(
        type: ParameterType.object,
        description: 'Result object',
        schema: {'properties': {'id': {'type': 'string'}}},
      );

      expect(output.type, equals(ParameterType.object));
      expect(output.description, equals('Result object'));
      expect(output.schema, equals({'properties': {'id': {'type': 'string'}}}));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'type': 'array',
        'description': 'List of results',
        'schema': {'items': {'type': 'string'}},
      };

      final output = OutputSpec.fromJson(json);

      expect(output.type, equals(ParameterType.array));
      expect(output.description, equals('List of results'));
      expect(output.schema, equals({'items': {'type': 'string'}}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final output = OutputSpec.fromJson(json);

      expect(output.type, equals(ParameterType.any));
      expect(output.description, isNull);
      expect(output.schema, isNull);
    });

    test('toJson converts instance to JSON', () {
      final output = OutputSpec(
        type: ParameterType.number,
        description: 'Calculated value',
        schema: {'minimum': 0},
      );

      final json = output.toJson();

      expect(json['type'], equals('number'));
      expect(json['description'], equals('Calculated value'));
      expect(json['schema'], equals({'minimum': 0}));
    });

    test('toJson excludes null fields', () {
      final output = OutputSpec(type: ParameterType.boolean);

      final json = output.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('schema'), isFalse);
    });
  });

  group('Skill', () {
    test('constructor creates instance with required fields', () {
      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
      );

      expect(skill.id, equals('skill1'));
      expect(skill.name, equals('Test Skill'));
      expect(skill.description, isNull);
      expect(skill.version, equals('1.0.0'));
      expect(skill.inputs, isEmpty);
      expect(skill.output, isNull);
      expect(skill.steps, isEmpty);
      expect(skill.triggers, isEmpty);
      expect(skill.metadata, isEmpty);
      expect(skill.tags, isEmpty);
    });

    test('constructor creates instance with all fields', () {
      final input = Parameter(name: 'message', type: ParameterType.string);
      final output = OutputSpec(type: ParameterType.boolean);
      final step = SkillStep(id: 'step1', type: StepType.action);
      final trigger = SkillTrigger(type: TriggerType.manual);

      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
        description: 'A test skill',
        version: '2.0.0',
        inputs: [input],
        output: output,
        steps: [step],
        triggers: [trigger],
        metadata: {'author': 'Test'},
        tags: ['test', 'example'],
      );

      expect(skill.description, equals('A test skill'));
      expect(skill.version, equals('2.0.0'));
      expect(skill.inputs, hasLength(1));
      expect(skill.output, isNotNull);
      expect(skill.steps, hasLength(1));
      expect(skill.triggers, hasLength(1));
      expect(skill.metadata, equals({'author': 'Test'}));
      expect(skill.tags, equals(['test', 'example']));
    });

    test('getInput returns input by name', () {
      final input1 = Parameter(name: 'input1', type: ParameterType.string);
      final input2 = Parameter(name: 'input2', type: ParameterType.number);

      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
        inputs: [input1, input2],
      );

      expect(skill.getInput('input1'), equals(input1));
      expect(skill.getInput('input2'), equals(input2));
      expect(skill.getInput('missing'), isNull);
    });

    test('getStep returns step by id', () {
      final step1 = SkillStep(id: 'step1', type: StepType.action);
      final step2 = SkillStep(id: 'step2', type: StepType.output);

      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
        steps: [step1, step2],
      );

      expect(skill.getStep('step1'), equals(step1));
      expect(skill.getStep('step2'), equals(step2));
      expect(skill.getStep('missing'), isNull);
    });

    test('entryStep returns first step', () {
      final step1 = SkillStep(id: 'step1', type: StepType.action);
      final step2 = SkillStep(id: 'step2', type: StepType.output);

      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
        steps: [step1, step2],
      );

      expect(skill.entryStep, equals(step1));
    });

    test('entryStep returns null for empty steps', () {
      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
      );

      expect(skill.entryStep, isNull);
    });

    group('validateInputs', () {
      test('returns empty list for valid inputs', () {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'name', type: ParameterType.string),
            Parameter(name: 'count', type: ParameterType.integer),
          ],
        );

        final errors = skill.validateInputs({'name': 'Test', 'count': 5});
        expect(errors, isEmpty);
      });

      test('returns error for missing required input', () {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'required', type: ParameterType.string, required: true),
          ],
        );

        final errors = skill.validateInputs({});
        expect(errors, hasLength(1));
        expect(errors.first, contains('required'));
        expect(errors.first, contains('missing'));
      });

      test('allows missing optional input', () {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'optional', type: ParameterType.string, required: false),
          ],
        );

        final errors = skill.validateInputs({});
        expect(errors, isEmpty);
      });

      test('returns error for invalid type', () {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'count', type: ParameterType.integer),
          ],
        );

        final errors = skill.validateInputs({'count': 'not an integer'});
        expect(errors, hasLength(1));
        expect(errors.first, contains('must be an integer'));
      });

      test('returns errors for constraint violations', () {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(
              name: 'value',
              type: ParameterType.number,
              constraints: {'minimum': 0, 'maximum': 100},
            ),
          ],
        );

        final errors = skill.validateInputs({'value': 150});
        expect(errors, hasLength(1));
        expect(errors.first, contains('at most 100'));
      });

      test('accumulates multiple errors', () {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'required1', type: ParameterType.string, required: true),
            Parameter(name: 'required2', type: ParameterType.string, required: true),
          ],
        );

        final errors = skill.validateInputs({});
        expect(errors, hasLength(2));
      });
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'id': 'skill1',
        'name': 'Test Skill',
        'description': 'A test skill',
        'version': '2.0.0',
        'inputs': [
          {'name': 'input1', 'type': 'string'},
        ],
        'output': {'type': 'boolean'},
        'steps': [
          {'id': 'step1', 'type': 'action'},
        ],
        'triggers': [
          {'type': 'manual'},
        ],
        'metadata': {'author': 'Test'},
        'tags': ['test'],
      };

      final skill = Skill.fromJson(json);

      expect(skill.id, equals('skill1'));
      expect(skill.name, equals('Test Skill'));
      expect(skill.description, equals('A test skill'));
      expect(skill.version, equals('2.0.0'));
      expect(skill.inputs, hasLength(1));
      expect(skill.inputs.first.name, equals('input1'));
      expect(skill.output, isNotNull);
      expect(skill.steps, hasLength(1));
      expect(skill.triggers, hasLength(1));
      expect(skill.metadata, equals({'author': 'Test'}));
      expect(skill.tags, equals(['test']));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final skill = Skill.fromJson(json);

      expect(skill.id, equals(''));
      expect(skill.name, equals(''));
      expect(skill.version, equals('1.0.0'));
      expect(skill.inputs, isEmpty);
      expect(skill.steps, isEmpty);
      expect(skill.triggers, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
        description: 'Description',
        version: '1.5.0',
        inputs: [Parameter(name: 'input1', type: ParameterType.string)],
        output: OutputSpec(type: ParameterType.boolean),
        steps: [SkillStep(id: 'step1', type: StepType.action)],
        triggers: [SkillTrigger(type: TriggerType.manual)],
        metadata: {'key': 'value'},
        tags: ['tag1'],
      );

      final json = skill.toJson();

      expect(json['id'], equals('skill1'));
      expect(json['name'], equals('Test Skill'));
      expect(json['description'], equals('Description'));
      expect(json['version'], equals('1.5.0'));
      expect(json['inputs'], isA<List>());
      expect(json['output'], isA<Map>());
      expect(json['steps'], isA<List>());
      expect(json['triggers'], isA<List>());
      expect(json['metadata'], equals({'key': 'value'}));
      expect(json['tags'], equals(['tag1']));
    });

    test('toJson excludes null and empty fields', () {
      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
      );

      final json = skill.toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('inputs'), isFalse);
      expect(json.containsKey('output'), isFalse);
      expect(json.containsKey('steps'), isFalse);
      expect(json.containsKey('triggers'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json.containsKey('tags'), isFalse);
    });

    test('toString returns expected string representation', () {
      final skill = Skill(
        id: 'skill1',
        name: 'Test Skill',
        version: '2.0.0',
      );

      final str = skill.toString();

      expect(str, contains('Skill'));
      expect(str, contains('skill1'));
      expect(str, contains('Test Skill'));
      expect(str, contains('2.0.0'));
    });
  });
}
