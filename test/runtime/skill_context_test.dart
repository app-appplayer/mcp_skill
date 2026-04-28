import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';

void main() {
  group('SkillContext', () {
    test('constructor creates instance with required fields', () {
      final asOf = DateTime(2024, 1, 15);
      final context = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Test request',
        workspaceId: 'workspace-1',
        asOf: asOf,
      );

      expect(context.contextId, equals('ctx-123'));
      expect(context.skillId, equals('skill-1'));
      expect(context.runId, equals('run-456'));
      expect(context.traceId, equals('trace-789'));
      expect(context.request, equals('Test request'));
      expect(context.workspaceId, equals('workspace-1'));
      expect(context.asOf, equals(asOf));
      expect(context.period, isNull);
      expect(context.policyVersion, isNull);
      expect(context.activeSkills, isNull);
      expect(context.inputs, isEmpty);
      expect(context.contextBundle, isNull);
      expect(context.budget, isNull);
      expect(context.metadata, isNull);
    });

    test('constructor creates instance with all fields', () {
      final asOf = DateTime(2024, 1, 15);
      final budget = const ExecutionBudget();
      final context = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Test request',
        workspaceId: 'workspace-1',
        asOf: asOf,
        policyVersion: 'v1.0',
        activeSkills: ['skill1', 'skill2'],
        inputs: {'key': 'value'},
        budget: budget,
        metadata: {'meta': 'data'},
      );

      expect(context.policyVersion, equals('v1.0'));
      expect(context.activeSkills, equals(['skill1', 'skill2']));
      expect(context.inputs, equals({'key': 'value'}));
      expect(context.budget, equals(budget));
      expect(context.metadata, equals({'meta': 'data'}));
    });

    test('copyWith creates a copy with updated fields', () {
      final asOf = DateTime(2024, 1, 15);
      final original = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Original request',
        workspaceId: 'workspace-1',
        asOf: asOf,
      );

      final newAsOf = DateTime(2024, 2, 20);
      final copy = original.copyWith(
        request: 'Updated request',
        asOf: newAsOf,
      );

      expect(copy.request, equals('Updated request'));
      expect(copy.workspaceId, equals('workspace-1'));
      expect(copy.asOf, equals(newAsOf));
    });

    test('copyWith preserves original fields when not specified', () {
      final asOf = DateTime(2024, 1, 15);
      final budget = const ExecutionBudget();
      final original = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Test request',
        workspaceId: 'workspace-1',
        asOf: asOf,
        policyVersion: 'v1.0',
        budget: budget,
      );

      final copy = original.copyWith(request: 'New request');

      expect(copy.request, equals('New request'));
      expect(copy.workspaceId, equals('workspace-1'));
      expect(copy.asOf, equals(asOf));
      expect(copy.policyVersion, equals('v1.0'));
      expect(copy.budget, equals(budget));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'request': 'Test request',
        'workspaceId': 'workspace-1',
        'asOf': '2024-01-15T00:00:00.000',
        'policyVersion': 'v1.0',
        'activeSkills': ['skill1', 'skill2'],
        'inputs': {'key': 'value'},
        'budget': {
          'maxTokens': 50000,
          'maxDurationMs': 60000,
          'maxSteps': 25,
          'maxLlmCalls': 10,
          'maxMcpCalls': 50,
          'maxConcurrency': 3,
        },
        'metadata': {'meta': 'data'},
      };

      final context = SkillContext.fromJson(json);

      expect(context.request, equals('Test request'));
      expect(context.workspaceId, equals('workspace-1'));
      expect(context.asOf, equals(DateTime.parse('2024-01-15T00:00:00.000')));
      expect(context.policyVersion, equals('v1.0'));
      expect(context.activeSkills, equals(['skill1', 'skill2']));
      expect(context.inputs, equals({'key': 'value'}));
      expect(context.budget, isNotNull);
      expect(context.budget!.maxTokens, equals(50000));
      expect(context.metadata, equals({'meta': 'data'}));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final context = SkillContext.fromJson(json);

      expect(context.request, equals(''));
      expect(context.workspaceId, equals(''));
      expect(context.asOf, isNotNull);
      expect(context.inputs, isEmpty);
    });

    test('toJson converts instance to JSON', () {
      final asOf = DateTime(2024, 1, 15);
      final context = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Test request',
        workspaceId: 'workspace-1',
        asOf: asOf,
        policyVersion: 'v1.0',
        activeSkills: ['skill1'],
        inputs: {'key': 'value'},
        metadata: {'meta': 'data'},
      );

      final json = context.toJson();

      expect(json['contextId'], equals('ctx-123'));
      expect(json['skillId'], equals('skill-1'));
      expect(json['runId'], equals('run-456'));
      expect(json['traceId'], equals('trace-789'));
      expect(json['request'], equals('Test request'));
      expect(json['workspaceId'], equals('workspace-1'));
      expect(json['asOf'], equals(asOf.toIso8601String()));
      expect(json['policyVersion'], equals('v1.0'));
      expect(json['activeSkills'], equals(['skill1']));
      expect(json['inputs'], equals({'key': 'value'}));
      expect(json['metadata'], equals({'meta': 'data'}));
    });

    test('toJson excludes null and empty fields', () {
      final asOf = DateTime(2024, 1, 15);
      final context = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Test request',
        workspaceId: 'workspace-1',
        asOf: asOf,
      );

      final json = context.toJson();

      expect(json.containsKey('policyVersion'), isFalse);
      expect(json.containsKey('activeSkills'), isFalse);
      expect(json.containsKey('inputs'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
    });

    test('toString returns expected string representation', () {
      final asOf = DateTime(2024, 1, 15);
      final context = SkillContext(
        contextId: 'ctx-123',
        skillId: 'skill-1',
        runId: 'run-456',
        traceId: 'trace-789',
        request: 'Test request',
        workspaceId: 'workspace-1',
        asOf: asOf,
      );

      final str = context.toString();

      expect(str, contains('SkillContext'));
      expect(str, contains('ctx-123'));
      expect(str, contains('skill-1'));
    });
  });

  group('ExecutionBudget', () {
    test('default constructor has expected defaults', () {
      const budget = ExecutionBudget();

      expect(budget.maxTokens, equals(100000));
      expect(budget.maxDuration, equals(const Duration(minutes: 5)));
      expect(budget.maxSteps, equals(50));
      expect(budget.maxLlmCalls, equals(20));
      expect(budget.maxMcpCalls, equals(100));
      expect(budget.maxConcurrency, equals(5));
    });

    test('custom constructor sets custom values', () {
      const budget = ExecutionBudget(
        maxTokens: 50000,
        maxDuration: Duration(minutes: 10),
        maxSteps: 100,
        maxLlmCalls: 30,
        maxMcpCalls: 200,
        maxConcurrency: 10,
      );

      expect(budget.maxTokens, equals(50000));
      expect(budget.maxDuration, equals(const Duration(minutes: 10)));
      expect(budget.maxSteps, equals(100));
      expect(budget.maxLlmCalls, equals(30));
      expect(budget.maxMcpCalls, equals(200));
      expect(budget.maxConcurrency, equals(10));
    });

    test('minimal constructor creates minimal budget', () {
      final budget = ExecutionBudget.minimal();

      expect(budget.maxTokens, equals(1000));
      expect(budget.maxDuration, equals(const Duration(seconds: 30)));
      expect(budget.maxSteps, equals(10));
      expect(budget.maxLlmCalls, equals(3));
      expect(budget.maxMcpCalls, equals(10));
      expect(budget.maxConcurrency, equals(1));
    });

    test('unlimited constructor creates unlimited budget', () {
      final budget = ExecutionBudget.unlimited();

      expect(budget.maxTokens, equals(-1));
      expect(budget.maxDuration, equals(const Duration(hours: 24)));
      expect(budget.maxSteps, equals(-1));
      expect(budget.maxLlmCalls, equals(-1));
      expect(budget.maxMcpCalls, equals(-1));
      expect(budget.maxConcurrency, equals(100));
    });

    test('fromJson creates instance from JSON', () {
      final json = {
        'maxTokens': 75000,
        'maxDurationMs': 120000,
        'maxSteps': 30,
        'maxLlmCalls': 15,
        'maxMcpCalls': 75,
        'maxConcurrency': 7,
      };

      final budget = ExecutionBudget.fromJson(json);

      expect(budget.maxTokens, equals(75000));
      expect(budget.maxDuration, equals(const Duration(milliseconds: 120000)));
      expect(budget.maxSteps, equals(30));
      expect(budget.maxLlmCalls, equals(15));
      expect(budget.maxMcpCalls, equals(75));
      expect(budget.maxConcurrency, equals(7));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final budget = ExecutionBudget.fromJson(json);

      expect(budget.maxTokens, equals(100000));
      expect(budget.maxDuration, equals(const Duration(minutes: 5)));
      expect(budget.maxSteps, equals(50));
      expect(budget.maxLlmCalls, equals(20));
      expect(budget.maxMcpCalls, equals(100));
      expect(budget.maxConcurrency, equals(5));
    });

    test('toJson converts instance to JSON', () {
      const budget = ExecutionBudget(
        maxTokens: 50000,
        maxDuration: Duration(minutes: 2),
        maxSteps: 25,
        maxLlmCalls: 10,
        maxMcpCalls: 50,
        maxConcurrency: 3,
      );

      final json = budget.toJson();

      expect(json['maxTokens'], equals(50000));
      expect(json['maxDurationMs'], equals(120000));
      expect(json['maxSteps'], equals(25));
      expect(json['maxLlmCalls'], equals(10));
      expect(json['maxMcpCalls'], equals(50));
      expect(json['maxConcurrency'], equals(3));
    });

    test('isWithinTokenBudget returns true when within budget', () {
      const budget = ExecutionBudget(maxTokens: 1000);

      expect(budget.isWithinTokenBudget(500), isTrue);
      expect(budget.isWithinTokenBudget(1000), isTrue);
    });

    test('isWithinTokenBudget returns false when exceeded', () {
      const budget = ExecutionBudget(maxTokens: 1000);

      expect(budget.isWithinTokenBudget(1001), isFalse);
    });

    test('isWithinTokenBudget returns true for unlimited tokens', () {
      final budget = ExecutionBudget.unlimited();

      expect(budget.isWithinTokenBudget(999999), isTrue);
    });

    test('isWithinDurationBudget returns true when within budget', () {
      const budget = ExecutionBudget(maxDuration: Duration(minutes: 5));

      expect(budget.isWithinDurationBudget(const Duration(minutes: 3)), isTrue);
      expect(budget.isWithinDurationBudget(const Duration(minutes: 5)), isTrue);
    });

    test('isWithinDurationBudget returns false when exceeded', () {
      const budget = ExecutionBudget(maxDuration: Duration(minutes: 5));

      expect(budget.isWithinDurationBudget(const Duration(minutes: 6)), isFalse);
    });

    test('isWithinStepBudget returns true when within budget', () {
      const budget = ExecutionBudget(maxSteps: 50);

      expect(budget.isWithinStepBudget(25), isTrue);
      expect(budget.isWithinStepBudget(50), isTrue);
    });

    test('isWithinStepBudget returns false when exceeded', () {
      const budget = ExecutionBudget(maxSteps: 50);

      expect(budget.isWithinStepBudget(51), isFalse);
    });

    test('isWithinStepBudget returns true for unlimited steps', () {
      final budget = ExecutionBudget.unlimited();

      expect(budget.isWithinStepBudget(999999), isTrue);
    });

    test('toString returns expected string representation', () {
      const budget = ExecutionBudget();

      final str = budget.toString();

      expect(str, contains('ExecutionBudget'));
      expect(str, contains('maxTokens'));
      expect(str, contains('maxSteps'));
      expect(str, contains('maxLlmCalls'));
    });
  });

  group('BudgetTracker', () {
    test('constructor initializes with zero usage', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      expect(tracker.tokensUsed, equals(0));
      expect(tracker.stepsExecuted, equals(0));
      expect(tracker.llmCallsMade, equals(0));
      expect(tracker.mcpCallsMade, equals(0));
    });

    test('trackTokens increments token usage', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      tracker.trackTokens(100);
      expect(tracker.tokensUsed, equals(100));

      tracker.trackTokens(50);
      expect(tracker.tokensUsed, equals(150));
    });

    test('trackStep increments step count', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      tracker.trackStep();
      expect(tracker.stepsExecuted, equals(1));

      tracker.trackStep();
      expect(tracker.stepsExecuted, equals(2));
    });

    test('trackLlmCall increments LLM call count', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      tracker.trackLlmCall();
      expect(tracker.llmCallsMade, equals(1));

      tracker.trackLlmCall();
      expect(tracker.llmCallsMade, equals(2));
    });

    test('trackMcpCall increments MCP call count', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      tracker.trackMcpCall();
      expect(tracker.mcpCallsMade, equals(1));

      tracker.trackMcpCall();
      expect(tracker.mcpCallsMade, equals(2));
    });

    test('elapsed returns non-negative duration', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      expect(tracker.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('isExceeded returns false when within budget', () {
      const budget = ExecutionBudget(
        maxTokens: 1000,
        maxSteps: 10,
        maxLlmCalls: 5,
        maxMcpCalls: 10,
      );
      final tracker = BudgetTracker(budget);

      tracker.trackTokens(500);
      tracker.trackStep();
      tracker.trackLlmCall();
      tracker.trackMcpCall();

      expect(tracker.isExceeded, isFalse);
    });

    test('isExceeded returns true when tokens exceeded', () {
      const budget = ExecutionBudget(maxTokens: 100);
      final tracker = BudgetTracker(budget);

      tracker.trackTokens(101);

      expect(tracker.isExceeded, isTrue);
    });

    test('isExceeded returns true when steps exceeded', () {
      const budget = ExecutionBudget(maxSteps: 2);
      final tracker = BudgetTracker(budget);

      tracker.trackStep();
      tracker.trackStep();
      tracker.trackStep();

      expect(tracker.isExceeded, isTrue);
    });

    test('isExceeded returns true when LLM calls exceeded', () {
      const budget = ExecutionBudget(maxLlmCalls: 1);
      final tracker = BudgetTracker(budget);

      tracker.trackLlmCall();
      tracker.trackLlmCall();

      expect(tracker.isExceeded, isTrue);
    });

    test('isExceeded returns true when MCP calls exceeded', () {
      const budget = ExecutionBudget(maxMcpCalls: 1);
      final tracker = BudgetTracker(budget);

      tracker.trackMcpCall();
      tracker.trackMcpCall();

      expect(tracker.isExceeded, isTrue);
    });

    test('remainingTokens returns correct value', () {
      const budget = ExecutionBudget(maxTokens: 1000);
      final tracker = BudgetTracker(budget);

      expect(tracker.remainingTokens, equals(1000));

      tracker.trackTokens(300);
      expect(tracker.remainingTokens, equals(700));
    });

    test('remainingTokens returns -1 for unlimited', () {
      final budget = ExecutionBudget.unlimited();
      final tracker = BudgetTracker(budget);

      expect(tracker.remainingTokens, equals(-1));
    });

    test('remainingSteps returns correct value', () {
      const budget = ExecutionBudget(maxSteps: 10);
      final tracker = BudgetTracker(budget);

      expect(tracker.remainingSteps, equals(10));

      tracker.trackStep();
      tracker.trackStep();
      expect(tracker.remainingSteps, equals(8));
    });

    test('remainingSteps returns -1 for unlimited', () {
      final budget = ExecutionBudget.unlimited();
      final tracker = BudgetTracker(budget);

      expect(tracker.remainingSteps, equals(-1));
    });

    test('toJson returns usage summary', () {
      const budget = ExecutionBudget();
      final tracker = BudgetTracker(budget);

      tracker.trackTokens(100);
      tracker.trackStep();
      tracker.trackLlmCall();
      tracker.trackMcpCall();

      final json = tracker.toJson();

      expect(json['tokensUsed'], equals(100));
      expect(json['stepsExecuted'], equals(1));
      expect(json['llmCallsMade'], equals(1));
      expect(json['mcpCallsMade'], equals(1));
      expect(json['elapsedMs'], isA<int>());
      expect(json['isExceeded'], isFalse);
    });
  });

  group('BudgetTracker enforcement', () {
    test('consumeTokens throws BudgetExceededException when over maxTokens',
        () {
      const budget = ExecutionBudget(maxTokens: 100);
      final tracker = BudgetTracker(budget);
      tracker.consumeTokens(50);
      expect(
        () => tracker.consumeTokens(60),
        throwsA(isA<BudgetExceededException>()),
      );
    });

    test('consumeTokens is a no-op when the budget is unlimited', () {
      final tracker = BudgetTracker(ExecutionBudget.unlimited());
      expect(() => tracker.consumeTokens(1000000), returnsNormally);
    });

    test('incrementStep throws when step count exceeds maxSteps', () {
      const budget = ExecutionBudget(maxSteps: 2);
      final tracker = BudgetTracker(budget);
      tracker.incrementStep();
      tracker.incrementStep();
      expect(tracker.incrementStep,
          throwsA(isA<BudgetExceededException>()));
    });

    test('addLlmCall throws when LLM call count exceeds maxLlmCalls', () {
      const budget = ExecutionBudget(maxLlmCalls: 1);
      final tracker = BudgetTracker(budget);
      tracker.addLlmCall();
      expect(
          tracker.addLlmCall, throwsA(isA<BudgetExceededException>()));
    });

    test('addMcpCall throws when MCP call count exceeds maxMcpCalls', () {
      const budget = ExecutionBudget(maxMcpCalls: 1);
      final tracker = BudgetTracker(budget);
      tracker.addMcpCall();
      expect(
          tracker.addMcpCall, throwsA(isA<BudgetExceededException>()));
    });

    test('assertNotExpired throws when elapsed time exceeds maxDuration',
        () async {
      const budget = ExecutionBudget(maxDuration: Duration(milliseconds: 1));
      final tracker = BudgetTracker(budget);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(tracker.assertNotExpired,
          throwsA(isA<BudgetExceededException>()));
    });

    test('enforcement methods do not throw while within budget', () {
      const budget = ExecutionBudget(
        maxTokens: 1000,
        maxSteps: 10,
        maxLlmCalls: 5,
        maxMcpCalls: 5,
      );
      final tracker = BudgetTracker(budget);
      expect(() => tracker.consumeTokens(500), returnsNormally);
      expect(tracker.incrementStep, returnsNormally);
      expect(tracker.addLlmCall, returnsNormally);
      expect(tracker.addMcpCall, returnsNormally);
      expect(tracker.assertNotExpired, returnsNormally);
    });
  });
}
