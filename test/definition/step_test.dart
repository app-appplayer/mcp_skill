import 'package:test/test.dart';
import 'package:mcp_skill/src/definition/step.dart';

void main() {
  group('StepType', () {
    test('has all expected values', () {
      expect(StepType.values, contains(StepType.action));
      expect(StepType.values, contains(StepType.condition));
      expect(StepType.values, contains(StepType.loop));
      expect(StepType.values, contains(StepType.parallel));
      expect(StepType.values, contains(StepType.wait));
      expect(StepType.values, contains(StepType.transform));
      expect(StepType.values, contains(StepType.call));
      expect(StepType.values, contains(StepType.setVar));
      expect(StepType.values, contains(StepType.output));
      expect(StepType.values, contains(StepType.log));
      expect(StepType.values, contains(StepType.http));
      expect(StepType.values, contains(StepType.unknown));
    });

    test('fromString returns correct value', () {
      expect(StepType.fromString('action'), equals(StepType.action));
      expect(StepType.fromString('condition'), equals(StepType.condition));
      expect(StepType.fromString('loop'), equals(StepType.loop));
      expect(StepType.fromString('parallel'), equals(StepType.parallel));
      expect(StepType.fromString('wait'), equals(StepType.wait));
      expect(StepType.fromString('transform'), equals(StepType.transform));
      expect(StepType.fromString('call'), equals(StepType.call));
      expect(StepType.fromString('setVar'), equals(StepType.setVar));
      expect(StepType.fromString('output'), equals(StepType.output));
      expect(StepType.fromString('log'), equals(StepType.log));
      expect(StepType.fromString('http'), equals(StepType.http));
    });

    test('fromString returns unknown for invalid values', () {
      expect(StepType.fromString('invalid'), equals(StepType.unknown));
      expect(StepType.fromString(''), equals(StepType.unknown));
    });
  });

  group('SkillStep', () {
    test('constructor creates instance with required fields', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.action,
      );

      expect(step.id, equals('step1'));
      expect(step.type, equals(StepType.action));
      expect(step.name, isNull);
      expect(step.config, isEmpty);
      expect(step.condition, isNull);
      expect(step.next, isEmpty);
      expect(step.onError, isNull);
      expect(step.metadata, isEmpty);
    });

    test('constructor creates instance with all fields', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.action,
        name: 'Execute Action',
        config: {'action': 'doSomething'},
        condition: 'inputs.enabled == true',
        next: ['step2', 'step3'],
        onError: 'errorHandler',
        metadata: {'key': 'value'},
      );

      expect(step.name, equals('Execute Action'));
      expect(step.config, equals({'action': 'doSomething'}));
      expect(step.condition, equals('inputs.enabled == true'));
      expect(step.next, equals(['step2', 'step3']));
      expect(step.onError, equals('errorHandler'));
      expect(step.metadata, equals({'key': 'value'}));
    });

    test('getConfig returns config value', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.action,
        config: {'key1': 'value1', 'key2': 42},
      );

      expect(step.getConfig('key1'), equals('value1'));
      expect(step.getConfig('key2'), equals(42));
      expect(step.getConfig('missing'), isNull);
    });

    test('hasConfig checks config key presence', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.action,
        config: {'exists': 'value'},
      );

      expect(step.hasConfig('exists'), isTrue);
      expect(step.hasConfig('missing'), isFalse);
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'id': 'step1',
        'type': 'transform',
        'name': 'Transform Data',
        'config': {'expression': 'inputs.value * 2'},
        'condition': 'inputs.value > 0',
        'next': ['step2'],
        'onError': 'errorStep',
        'metadata': {'description': 'Multiplies value'},
      };

      final step = SkillStep.fromJson(json);

      expect(step.id, equals('step1'));
      expect(step.type, equals(StepType.transform));
      expect(step.name, equals('Transform Data'));
      expect(step.config, equals({'expression': 'inputs.value * 2'}));
      expect(step.condition, equals('inputs.value > 0'));
      expect(step.next, equals(['step2']));
      expect(step.onError, equals('errorStep'));
      expect(step.metadata, equals({'description': 'Multiplies value'}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final step = SkillStep.fromJson(json);

      expect(step.id, equals(''));
      expect(step.type, equals(StepType.action));
      expect(step.config, isEmpty);
      expect(step.next, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.setVar,
        name: 'Set Variable',
        config: {'name': 'count', 'value': 0},
        condition: 'true',
        next: ['step2'],
        onError: 'handleError',
        metadata: {'key': 'value'},
      );

      final json = step.toJson();

      expect(json['id'], equals('step1'));
      expect(json['type'], equals('setVar'));
      expect(json['name'], equals('Set Variable'));
      expect(json['config'], equals({'name': 'count', 'value': 0}));
      expect(json['condition'], equals('true'));
      expect(json['next'], equals(['step2']));
      expect(json['onError'], equals('handleError'));
      expect(json['metadata'], equals({'key': 'value'}));
    });

    test('toJson excludes null and empty fields', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.action,
      );

      final json = step.toJson();

      expect(json.containsKey('name'), isFalse);
      expect(json.containsKey('config'), isFalse);
      expect(json.containsKey('condition'), isFalse);
      expect(json.containsKey('next'), isFalse);
      expect(json.containsKey('onError'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString returns expected string representation', () {
      final step = SkillStep(
        id: 'step1',
        type: StepType.action,
      );

      final str = step.toString();

      expect(str, contains('SkillStep'));
      expect(str, contains('step1'));
      expect(str, contains('action'));
    });
  });

  group('ActionConfig', () {
    test('constructor creates instance with required fields', () {
      final config = ActionConfig(action: 'doSomething');

      expect(config.action, equals('doSomething'));
      expect(config.arguments, isEmpty);
      expect(config.resultVar, isNull);
    });

    test('constructor creates instance with all fields', () {
      final config = ActionConfig(
        action: 'callApi',
        arguments: {'url': 'https://api.example.com', 'method': 'GET'},
        resultVar: 'apiResult',
      );

      expect(config.action, equals('callApi'));
      expect(config.arguments, equals({'url': 'https://api.example.com', 'method': 'GET'}));
      expect(config.resultVar, equals('apiResult'));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'action': 'sendEmail',
        'arguments': {'to': 'user@example.com', 'subject': 'Hello'},
        'resultVar': 'emailResult',
      };

      final config = ActionConfig.fromJson(json);

      expect(config.action, equals('sendEmail'));
      expect(config.arguments, equals({'to': 'user@example.com', 'subject': 'Hello'}));
      expect(config.resultVar, equals('emailResult'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final config = ActionConfig.fromJson(json);

      expect(config.action, equals(''));
      expect(config.arguments, isEmpty);
      expect(config.resultVar, isNull);
    });

    test('toJson converts instance to JSON', () {
      final config = ActionConfig(
        action: 'process',
        arguments: {'data': 'value'},
        resultVar: 'result',
      );

      final json = config.toJson();

      expect(json['action'], equals('process'));
      expect(json['arguments'], equals({'data': 'value'}));
      expect(json['resultVar'], equals('result'));
    });

    test('toJson excludes empty arguments and null resultVar', () {
      final config = ActionConfig(action: 'simple');

      final json = config.toJson();

      expect(json.containsKey('arguments'), isFalse);
      expect(json.containsKey('resultVar'), isFalse);
    });
  });

  group('ConditionConfig', () {
    test('constructor creates instance with required fields', () {
      final config = ConditionConfig(expression: 'value > 0');

      expect(config.expression, equals('value > 0'));
      expect(config.thenStep, isNull);
      expect(config.elseStep, isNull);
    });

    test('constructor creates instance with all fields', () {
      final config = ConditionConfig(
        expression: 'inputs.enabled',
        thenStep: 'enabledStep',
        elseStep: 'disabledStep',
      );

      expect(config.expression, equals('inputs.enabled'));
      expect(config.thenStep, equals('enabledStep'));
      expect(config.elseStep, equals('disabledStep'));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'expression': 'count > 0',
        'then': 'processItems',
        'else': 'noItems',
      };

      final config = ConditionConfig.fromJson(json);

      expect(config.expression, equals('count > 0'));
      expect(config.thenStep, equals('processItems'));
      expect(config.elseStep, equals('noItems'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final config = ConditionConfig.fromJson(json);

      expect(config.expression, equals(''));
      expect(config.thenStep, isNull);
      expect(config.elseStep, isNull);
    });

    test('toJson converts instance to JSON', () {
      final config = ConditionConfig(
        expression: 'isValid',
        thenStep: 'proceed',
        elseStep: 'reject',
      );

      final json = config.toJson();

      expect(json['expression'], equals('isValid'));
      expect(json['then'], equals('proceed'));
      expect(json['else'], equals('reject'));
    });

    test('toJson excludes null fields', () {
      final config = ConditionConfig(expression: 'condition');

      final json = config.toJson();

      expect(json.containsKey('then'), isFalse);
      expect(json.containsKey('else'), isFalse);
    });
  });

  group('LoopConfig', () {
    test('constructor creates instance with required fields', () {
      final config = LoopConfig(items: 'inputs.list');

      expect(config.items, equals('inputs.list'));
      expect(config.itemVar, equals('item'));
      expect(config.indexVar, equals('index'));
      expect(config.body, isNull);
    });

    test('constructor creates instance with all fields', () {
      final config = LoopConfig(
        items: 'data.records',
        itemVar: 'record',
        indexVar: 'i',
        body: 'processRecord',
      );

      expect(config.items, equals('data.records'));
      expect(config.itemVar, equals('record'));
      expect(config.indexVar, equals('i'));
      expect(config.body, equals('processRecord'));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'items': 'users',
        'itemVar': 'user',
        'indexVar': 'idx',
        'body': 'processUser',
      };

      final config = LoopConfig.fromJson(json);

      expect(config.items, equals('users'));
      expect(config.itemVar, equals('user'));
      expect(config.indexVar, equals('idx'));
      expect(config.body, equals('processUser'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final config = LoopConfig.fromJson(json);

      expect(config.items, equals(''));
      expect(config.itemVar, equals('item'));
      expect(config.indexVar, equals('index'));
      expect(config.body, isNull);
    });

    test('toJson converts instance to JSON', () {
      final config = LoopConfig(
        items: 'items',
        itemVar: 'element',
        indexVar: 'pos',
        body: 'processElement',
      );

      final json = config.toJson();

      expect(json['items'], equals('items'));
      expect(json['itemVar'], equals('element'));
      expect(json['indexVar'], equals('pos'));
      expect(json['body'], equals('processElement'));
    });

    test('toJson excludes null body', () {
      final config = LoopConfig(items: 'items');

      final json = config.toJson();

      expect(json.containsKey('body'), isFalse);
    });
  });

  group('TransformConfig', () {
    test('constructor creates instance with required fields', () {
      final config = TransformConfig(
        expression: 'value * 2',
        resultVar: 'doubled',
      );

      expect(config.expression, equals('value * 2'));
      expect(config.resultVar, equals('doubled'));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'expression': 'data.map(x => x.name)',
        'resultVar': 'names',
      };

      final config = TransformConfig.fromJson(json);

      expect(config.expression, equals('data.map(x => x.name)'));
      expect(config.resultVar, equals('names'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final config = TransformConfig.fromJson(json);

      expect(config.expression, equals(''));
      expect(config.resultVar, equals(''));
    });

    test('toJson converts instance to JSON', () {
      final config = TransformConfig(
        expression: 'items.filter(i => i.active)',
        resultVar: 'activeItems',
      );

      final json = config.toJson();

      expect(json['expression'], equals('items.filter(i => i.active)'));
      expect(json['resultVar'], equals('activeItems'));
    });
  });
}
