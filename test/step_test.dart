import 'package:test/test.dart';
import 'package:mcp_skill/mcp_skill.dart';

void main() {
  group('SkillStep', () {
    test('creates step with required fields', () {
      final step = SkillStep(
        id: 'step-1',
        type: StepType.action,
      );

      expect(step.id, equals('step-1'));
      expect(step.type, equals(StepType.action));
      expect(step.config, isEmpty);
      expect(step.next, isEmpty);
    });

    test('creates step with all fields', () {
      final step = SkillStep(
        id: 'step-2',
        type: StepType.condition,
        name: 'Check User',
        config: {'expression': 'user.active'},
        condition: 'enabled == true',
        next: ['step-3', 'step-4'],
        onError: 'error-handler',
        metadata: {'priority': 1},
      );

      expect(step.name, equals('Check User'));
      expect(step.config['expression'], equals('user.active'));
      expect(step.condition, equals('enabled == true'));
      expect(step.next.length, equals(2));
      expect(step.onError, equals('error-handler'));
    });

    test('getConfig retrieves config value', () {
      final step = SkillStep(
        id: 'step-3',
        type: StepType.transform,
        config: {'key': 'value', 'count': 10},
      );

      expect(step.getConfig('key'), equals('value'));
      expect(step.getConfig('count'), equals(10));
      expect(step.getConfig('missing'), isNull);
    });

    test('hasConfig checks existence', () {
      final step = SkillStep(
        id: 'step-4',
        type: StepType.action,
        config: {'exists': true},
      );

      expect(step.hasConfig('exists'), isTrue);
      expect(step.hasConfig('missing'), isFalse);
    });

    test('serializes and deserializes correctly', () {
      final original = SkillStep(
        id: 'step-5',
        type: StepType.loop,
        name: 'Process Items',
        config: {'items': 'data.list'},
        next: ['next-step'],
      );

      final json = original.toJson();
      final restored = SkillStep.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.type, equals(original.type));
      expect(restored.name, equals(original.name));
      expect(restored.config['items'], equals(original.config['items']));
      expect(restored.next, equals(original.next));
    });
  });

  group('StepType', () {
    test('fromString parses correctly', () {
      expect(StepType.fromString('action'), equals(StepType.action));
      expect(StepType.fromString('condition'), equals(StepType.condition));
      expect(StepType.fromString('loop'), equals(StepType.loop));
      expect(StepType.fromString('parallel'), equals(StepType.parallel));
      expect(StepType.fromString('wait'), equals(StepType.wait));
      expect(StepType.fromString('transform'), equals(StepType.transform));
      expect(StepType.fromString('call'), equals(StepType.call));
      expect(StepType.fromString('setVar'), equals(StepType.setVar));
      expect(StepType.fromString('output'), equals(StepType.output));
      expect(StepType.fromString('http'), equals(StepType.http));
    });

    test('fromString returns unknown for invalid', () {
      expect(StepType.fromString('invalid'), equals(StepType.unknown));
    });
  });

  group('ActionConfig', () {
    test('creates config with required fields', () {
      final config = ActionConfig(action: 'sendEmail');

      expect(config.action, equals('sendEmail'));
      expect(config.arguments, isEmpty);
      expect(config.resultVar, isNull);
    });

    test('creates config with all fields', () {
      final config = ActionConfig(
        action: 'sendEmail',
        arguments: {'to': 'user@example.com', 'subject': 'Hello'},
        resultVar: 'emailResult',
      );

      expect(config.arguments['to'], equals('user@example.com'));
      expect(config.resultVar, equals('emailResult'));
    });

    test('serializes and deserializes correctly', () {
      final original = ActionConfig(
        action: 'calculate',
        arguments: {'x': 10, 'y': 20},
        resultVar: 'sum',
      );

      final json = original.toJson();
      final restored = ActionConfig.fromJson(json);

      expect(restored.action, equals(original.action));
      expect(restored.arguments, equals(original.arguments));
      expect(restored.resultVar, equals(original.resultVar));
    });
  });

  group('ConditionConfig', () {
    test('creates config with required fields', () {
      final config = ConditionConfig(expression: 'x > 0');

      expect(config.expression, equals('x > 0'));
      expect(config.thenStep, isNull);
      expect(config.elseStep, isNull);
    });

    test('creates config with all fields', () {
      final config = ConditionConfig(
        expression: 'user.isAdmin',
        thenStep: 'admin-flow',
        elseStep: 'user-flow',
      );

      expect(config.thenStep, equals('admin-flow'));
      expect(config.elseStep, equals('user-flow'));
    });

    test('serializes and deserializes correctly', () {
      final original = ConditionConfig(
        expression: 'count > 10',
        thenStep: 'large',
        elseStep: 'small',
      );

      final json = original.toJson();
      final restored = ConditionConfig.fromJson(json);

      expect(restored.expression, equals(original.expression));
      expect(restored.thenStep, equals(original.thenStep));
      expect(restored.elseStep, equals(original.elseStep));
    });
  });

  group('LoopConfig', () {
    test('creates config with required fields', () {
      final config = LoopConfig(items: 'data.items');

      expect(config.items, equals('data.items'));
      expect(config.itemVar, equals('item'));
      expect(config.indexVar, equals('index'));
    });

    test('creates config with all fields', () {
      final config = LoopConfig(
        items: 'users',
        itemVar: 'user',
        indexVar: 'i',
        body: 'process-user',
      );

      expect(config.itemVar, equals('user'));
      expect(config.indexVar, equals('i'));
      expect(config.body, equals('process-user'));
    });

    test('serializes and deserializes correctly', () {
      final original = LoopConfig(
        items: 'list',
        itemVar: 'el',
        body: 'loop-body',
      );

      final json = original.toJson();
      final restored = LoopConfig.fromJson(json);

      expect(restored.items, equals(original.items));
      expect(restored.itemVar, equals(original.itemVar));
      expect(restored.body, equals(original.body));
    });
  });

  group('TransformConfig', () {
    test('creates config with required fields', () {
      final config = TransformConfig(
        expression: 'x * 2',
        resultVar: 'doubled',
      );

      expect(config.expression, equals('x * 2'));
      expect(config.resultVar, equals('doubled'));
    });

    test('serializes and deserializes correctly', () {
      final original = TransformConfig(
        expression: 'data.map(x => x.name)',
        resultVar: 'names',
      );

      final json = original.toJson();
      final restored = TransformConfig.fromJson(json);

      expect(restored.expression, equals(original.expression));
      expect(restored.resultVar, equals(original.resultVar));
    });
  });
}
