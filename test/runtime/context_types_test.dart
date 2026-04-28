import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/context_types.dart';

void main() {
  group('BudgetUsage', () {
    test('default constructor uses expected defaults', () {
      const usage = BudgetUsage();
      expect(usage.tokensUsed, 0);
      expect(usage.stepsExecuted, 0);
      expect(usage.llmCallsMade, 0);
      expect(usage.mcpCallsMade, 0);
      expect(usage.elapsed, Duration.zero);
      expect(usage.remainingTokens, -1);
      expect(usage.remainingSteps, -1);
    });

    test('isExceeded is true when remainingTokens is 0', () {
      const usage = BudgetUsage(remainingTokens: 0);
      expect(usage.isExceeded, true);
    });

    test('isExceeded is true when remainingSteps is 0', () {
      const usage = BudgetUsage(remainingSteps: 0);
      expect(usage.isExceeded, true);
    });

    test('isExceeded is false when remaining budgets are positive', () {
      const usage = BudgetUsage(remainingTokens: 100, remainingSteps: 5);
      expect(usage.isExceeded, false);
    });

    test('isExceeded is false with negative remaining (unlimited)', () {
      const usage = BudgetUsage();
      expect(usage.isExceeded, false);
    });

    test('utilizationRatio returns 0.0 when remainingTokens < 0', () {
      const usage = BudgetUsage(tokensUsed: 50, remainingTokens: -1);
      expect(usage.utilizationRatio, 0.0);
    });

    test('utilizationRatio returns 0.0 when total is 0', () {
      const usage = BudgetUsage(tokensUsed: 0, remainingTokens: 0);
      expect(usage.utilizationRatio, 0.0);
    });

    test('utilizationRatio computes correctly', () {
      const usage = BudgetUsage(tokensUsed: 30, remainingTokens: 70);
      expect(usage.utilizationRatio, closeTo(0.3, 0.001));
    });

    test('toJson produces correct map', () {
      const usage = BudgetUsage(
        tokensUsed: 100,
        stepsExecuted: 5,
        llmCallsMade: 3,
        mcpCallsMade: 2,
        elapsed: Duration(milliseconds: 1500),
        remainingTokens: 900,
        remainingSteps: 15,
      );
      final json = usage.toJson();
      expect(json['tokensUsed'], 100);
      expect(json['stepsExecuted'], 5);
      expect(json['llmCallsMade'], 3);
      expect(json['mcpCallsMade'], 2);
      expect(json['elapsedMs'], 1500);
      expect(json['remainingTokens'], 900);
      expect(json['remainingSteps'], 15);
    });
  });

  group('ContextState', () {
    test('starts empty', () {
      final state = ContextState();
      expect(state.toMap(), isEmpty);
    });

    test('set and get typed value', () {
      final state = ContextState();
      state.set<String>('key', 'value');
      expect(state.get<String>('key'), 'value');
    });

    test('get returns null for missing key', () {
      final state = ContextState();
      expect(state.get<String>('missing'), isNull);
    });

    test('get returns null for type mismatch', () {
      final state = ContextState();
      state.set<int>('key', 42);
      expect(state.get<String>('key'), isNull);
    });

    test('has returns correct values', () {
      final state = ContextState();
      expect(state.has('key'), false);
      state.set('key', 'val');
      expect(state.has('key'), true);
    });

    test('remove deletes key', () {
      final state = ContextState();
      state.set('key', 'val');
      state.remove('key');
      expect(state.has('key'), false);
    });

    test('accumulate initializes and increments numeric values', () {
      final state = ContextState();
      state.accumulate('counter', 5);
      expect(state.get<num>('counter'), 5);
      state.accumulate('counter', 3);
      expect(state.get<num>('counter'), 8);
    });

    test('accumulate overwrites non-numeric value', () {
      final state = ContextState();
      state.set('key', 'not a number');
      state.accumulate('key', 10);
      expect(state.get<num>('key'), 10);
    });

    test('toMap returns unmodifiable map', () {
      final state = ContextState();
      state.set('a', 1);
      final map = state.toMap();
      expect(map['a'], 1);
      expect(() => map['b'] = 2, throwsUnsupportedError);
    });

    test('copy creates independent copy', () {
      final state = ContextState();
      state.set('x', 10);
      final copy = state.copy();
      copy.set('x', 20);
      expect(state.get<int>('x'), 10);
      expect(copy.get<int>('x'), 20);
    });

    test('from creates state from map', () {
      final state = ContextState.from({'a': 1, 'b': 'two'});
      expect(state.get<int>('a'), 1);
      expect(state.get<String>('b'), 'two');
    });
  });

  group('SkillConfig', () {
    test('empty constructor creates empty config', () {
      const config = SkillConfig.empty();
      expect(config.toMap(), isEmpty);
    });

    test('get returns typed value', () {
      final config = SkillConfig({'name': 'test', 'count': 42});
      expect(config.get<String>('name'), 'test');
      expect(config.get<int>('count'), 42);
    });

    test('get returns null for missing key', () {
      const config = SkillConfig.empty();
      expect(config.get<String>('missing'), isNull);
    });

    test('get returns null for type mismatch', () {
      final config = SkillConfig({'key': 42});
      expect(config.get<String>('key'), isNull);
    });

    test('require returns value when present', () {
      final config = SkillConfig({'key': 'value'});
      expect(config.require<String>('key'), 'value');
    });

    test('require throws StateError when key missing', () {
      const config = SkillConfig.empty();
      expect(() => config.require<String>('missing'), throwsStateError);
    });

    test('has checks key existence', () {
      final config = SkillConfig({'key': 'val'});
      expect(config.has('key'), true);
      expect(config.has('other'), false);
    });

    test('toMap returns unmodifiable map', () {
      final config = SkillConfig({'a': 1});
      final map = config.toMap();
      expect(() => map['b'] = 2, throwsUnsupportedError);
    });

    test('fromJson creates from map', () {
      final config = SkillConfig.fromJson({'x': 10});
      expect(config.get<int>('x'), 10);
    });
  });

  group('FeatureFlags', () {
    test('empty constructor creates no flags', () {
      const flags = FeatureFlags.empty();
      expect(flags.enabledFeatures, isEmpty);
    });

    test('isEnabled returns true for enabled flag', () {
      final flags = FeatureFlags({'featureA': true, 'featureB': false});
      expect(flags.isEnabled('featureA'), true);
    });

    test('isEnabled returns false for disabled flag', () {
      final flags = FeatureFlags({'featureA': true, 'featureB': false});
      expect(flags.isEnabled('featureB'), false);
    });

    test('isEnabled returns false for unknown flag', () {
      const flags = FeatureFlags.empty();
      expect(flags.isEnabled('unknown'), false);
    });

    test('enabledFeatures returns only enabled ones', () {
      final flags = FeatureFlags({
        'a': true,
        'b': false,
        'c': true,
      });
      expect(flags.enabledFeatures, {'a', 'c'});
    });

    test('fromJson creates from map', () {
      final flags = FeatureFlags.fromJson({
        'feature1': true,
        'feature2': false,
        'feature3': 'not_bool',
      });
      expect(flags.isEnabled('feature1'), true);
      expect(flags.isEnabled('feature2'), false);
      // Non-bool values become false
      expect(flags.isEnabled('feature3'), false);
    });
  });
}
