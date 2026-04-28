// Tests for SharedBudgetTracker - reserve, commit, release, canAfford, getUsage.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/shared_budget_tracker.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';

void main() {
  group('BudgetCost', () {
    test('default constructor has expected defaults', () {
      const cost = BudgetCost();
      expect(cost.estimatedTokens, equals(0));
      expect(cost.steps, equals(1));
      expect(cost.llmCalls, equals(0));
      expect(cost.mcpCalls, equals(0));
      expect(cost.estimatedDuration, isNull);
    });

    test('llm factory creates correct cost', () {
      final cost = BudgetCost.llm(estimatedTokens: 500);
      expect(cost.estimatedTokens, equals(500));
      expect(cost.steps, equals(1));
      expect(cost.llmCalls, equals(1));
      expect(cost.mcpCalls, equals(0));
    });

    test('llm factory uses default token estimate', () {
      final cost = BudgetCost.llm();
      expect(cost.estimatedTokens, equals(1000));
    });

    test('mcp factory creates correct cost', () {
      final cost = BudgetCost.mcp();
      expect(cost.estimatedTokens, equals(0));
      expect(cost.steps, equals(1));
      expect(cost.llmCalls, equals(0));
      expect(cost.mcpCalls, equals(1));
    });

    test('step factory creates correct cost', () {
      final cost = BudgetCost.step();
      expect(cost.estimatedTokens, equals(0));
      expect(cost.steps, equals(1));
      expect(cost.llmCalls, equals(0));
      expect(cost.mcpCalls, equals(0));
    });
  });

  group('SharedBudgetTracker', () {
    late SharedBudgetTracker tracker;

    setUp(() {
      tracker = SharedBudgetTracker(const ExecutionBudget(
        maxTokens: 10000,
        maxSteps: 20,
        maxLlmCalls: 5,
        maxMcpCalls: 10,
      ));
    });

    group('tryReserve', () {
      test('returns reservation when budget available', () async {
        final cost = BudgetCost.llm(estimatedTokens: 1000);
        final reservation = await tracker.tryReserve(cost);

        expect(reservation, isNotNull);
        expect(reservation!.reservationId, isNotEmpty);
        expect(reservation.reserved.estimatedTokens, equals(1000));
      });

      test('returns null when token budget exceeded', () async {
        final cost = BudgetCost.llm(estimatedTokens: 11000);
        final reservation = await tracker.tryReserve(cost);

        expect(reservation, isNull);
      });

      test('returns null when step budget exceeded', () async {
        final cost = const BudgetCost(steps: 21);
        final reservation = await tracker.tryReserve(cost);

        expect(reservation, isNull);
      });

      test('returns null when LLM calls budget exceeded', () async {
        final cost = const BudgetCost(llmCalls: 6);
        final reservation = await tracker.tryReserve(cost);

        expect(reservation, isNull);
      });

      test('returns null when MCP calls budget exceeded', () async {
        final cost = const BudgetCost(mcpCalls: 11);
        final reservation = await tracker.tryReserve(cost);

        expect(reservation, isNull);
      });

      test('accounts for active reservations in budget check', () async {
        // Reserve most of the LLM call budget
        final cost1 = const BudgetCost(llmCalls: 4);
        final r1 = await tracker.tryReserve(cost1);
        expect(r1, isNotNull);

        // Try to reserve more than remaining
        final cost2 = const BudgetCost(llmCalls: 2);
        final r2 = await tracker.tryReserve(cost2);
        expect(r2, isNull);

        // One more that fits should succeed
        final cost3 = const BudgetCost(llmCalls: 1);
        final r3 = await tracker.tryReserve(cost3);
        expect(r3, isNotNull);
      });
    });

    group('commit', () {
      test('commits actual usage and removes reservation', () async {
        final reserved = BudgetCost.llm(estimatedTokens: 1000);
        final reservation = await tracker.tryReserve(reserved);
        expect(reservation, isNotNull);

        final actual = BudgetCost.llm(estimatedTokens: 800);
        await reservation!.commit(actual);

        final usage = await tracker.getUsage();
        expect(usage['tokensUsed'], equals(800));
        expect(usage['llmCallsMade'], equals(1));
        expect(usage['activeReservations'], equals(0));
      });

      test('throws if reservation already released', () async {
        final reserved = BudgetCost.llm(estimatedTokens: 500);
        final reservation = await tracker.tryReserve(reserved);
        expect(reservation, isNotNull);

        await reservation!.commit(BudgetCost.llm(estimatedTokens: 400));

        expect(
          () => reservation.commit(BudgetCost.llm(estimatedTokens: 100)),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('release', () {
      test('releases reservation without using budget', () async {
        final reserved = BudgetCost.llm(estimatedTokens: 1000);
        final reservation = await tracker.tryReserve(reserved);
        expect(reservation, isNotNull);

        await reservation!.release();

        final usage = await tracker.getUsage();
        expect(usage['tokensUsed'], equals(0));
        expect(usage['llmCallsMade'], equals(0));
        expect(usage['activeReservations'], equals(0));
      });

      test('release is idempotent', () async {
        final reserved = BudgetCost.step();
        final reservation = await tracker.tryReserve(reserved);
        expect(reservation, isNotNull);

        await reservation!.release();
        // Second release should not throw
        await reservation.release();
      });

      test('released budget is available for new reservations', () async {
        // Reserve 4 of 5 LLM calls
        final cost = const BudgetCost(llmCalls: 4);
        final r1 = await tracker.tryReserve(cost);
        expect(r1, isNotNull);

        // Cannot reserve 2 more
        final cost2 = const BudgetCost(llmCalls: 2);
        expect(await tracker.tryReserve(cost2), isNull);

        // Release first reservation
        await r1!.release();

        // Now 2 more should fit
        final r2 = await tracker.tryReserve(cost2);
        expect(r2, isNotNull);
      });
    });

    group('canAfford', () {
      test('returns true when within budget', () async {
        final cost = BudgetCost.llm(estimatedTokens: 5000);
        expect(await tracker.canAfford(cost), isTrue);
      });

      test('returns false when over budget', () async {
        final cost = BudgetCost.llm(estimatedTokens: 11000);
        expect(await tracker.canAfford(cost), isFalse);
      });

      test('considers committed usage', () async {
        // Commit some usage first
        final reserved = BudgetCost.llm(estimatedTokens: 8000);
        final reservation = await tracker.tryReserve(reserved);
        await reservation!.commit(BudgetCost.llm(estimatedTokens: 8000));

        // Now 3000 should not fit
        final cost = BudgetCost.llm(estimatedTokens: 3000);
        expect(await tracker.canAfford(cost), isFalse);
      });
    });

    group('getUsage', () {
      test('returns initial usage as zero', () async {
        final usage = await tracker.getUsage();
        expect(usage['tokensUsed'], equals(0));
        expect(usage['stepsExecuted'], equals(0));
        expect(usage['llmCallsMade'], equals(0));
        expect(usage['mcpCallsMade'], equals(0));
        expect(usage['activeReservations'], equals(0));
        expect(usage['elapsedMs'], isA<int>());
      });

      test('tracks committed usage correctly', () async {
        final reserved = const BudgetCost(
          estimatedTokens: 500,
          steps: 2,
          llmCalls: 1,
          mcpCalls: 3,
        );
        final reservation = await tracker.tryReserve(reserved);
        await reservation!.commit(reserved);

        final usage = await tracker.getUsage();
        expect(usage['tokensUsed'], equals(500));
        expect(usage['stepsExecuted'], equals(2));
        expect(usage['llmCallsMade'], equals(1));
        expect(usage['mcpCallsMade'], equals(3));
      });

      test('tracks active reservations count', () async {
        final cost = BudgetCost.step();
        await tracker.tryReserve(cost);
        await tracker.tryReserve(cost);

        final usage = await tracker.getUsage();
        expect(usage['activeReservations'], equals(2));
      });
    });

    group('multiple concurrent reservations', () {
      test('handles multiple sequential reservations', () async {
        final cost = BudgetCost.llm(estimatedTokens: 2000);

        final r1 = await tracker.tryReserve(cost);
        final r2 = await tracker.tryReserve(cost);
        final r3 = await tracker.tryReserve(cost);

        expect(r1, isNotNull);
        expect(r2, isNotNull);
        expect(r3, isNotNull);

        await r1!.commit(BudgetCost.llm(estimatedTokens: 1500));
        await r2!.commit(BudgetCost.llm(estimatedTokens: 1800));
        await r3!.release();

        final usage = await tracker.getUsage();
        expect(usage['tokensUsed'], equals(3300));
        expect(usage['llmCallsMade'], equals(2));
      });
    });
  });

  group('BudgetReservation', () {
    test('has reservationId and reserved cost', () async {
      final tracker = SharedBudgetTracker(const ExecutionBudget(
        maxTokens: 10000,
        maxSteps: 100,
      ));

      final cost = BudgetCost.llm(estimatedTokens: 500);
      final reservation = await tracker.tryReserve(cost);

      expect(reservation, isNotNull);
      expect(reservation!.reservationId, startsWith('res_'));
      expect(reservation.reserved.estimatedTokens, equals(500));
    });
  });
}
