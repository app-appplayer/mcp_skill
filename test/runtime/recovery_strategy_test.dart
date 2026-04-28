// Tests for RecoveryStrategy - FallbackRecovery, SkipRecovery, RecoveryResult.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/recovery_strategy.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';

void main() {
  // Helper to build a minimal SkillContext for testing.
  SkillContext _makeContext() {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: 'skill-1',
      runId: 'run-1',
      traceId: 'trace-1',
      request: 'test request',
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 1, 1),
    );
  }

  // Helper to build a StepContext for testing.
  StepContext _makeStepContext() {
    return StepContext(
      skillId: 'skill-1',
      stepId: 'step-1',
      inputHash: 'hash-abc',
      skillContext: _makeContext(),
    );
  }

  group('StepContext', () {
    test('stores all required fields', () {
      final ctx = _makeStepContext();
      expect(ctx.skillId, equals('skill-1'));
      expect(ctx.stepId, equals('step-1'));
      expect(ctx.inputHash, equals('hash-abc'));
      expect(ctx.skillContext.workspaceId, equals('ws-1'));
    });
  });

  group('RecoveryResult', () {
    test('recovered factory creates result with outcome recovered', () {
      final result = RecoveryResult.recovered('value', message: 'OK');
      expect(result.outcome, equals(RecoveryOutcome.recovered));
      expect(result.result, equals('value'));
      expect(result.message, equals('OK'));
    });

    test('skipped factory creates result with outcome skipped', () {
      final result = RecoveryResult.skipped(message: 'skipped step');
      expect(result.outcome, equals(RecoveryOutcome.skipped));
      expect(result.result, isNull);
      expect(result.message, equals('skipped step'));
    });

    test('failed factory creates result with outcome failed', () {
      final result = RecoveryResult.failed('all options exhausted');
      expect(result.outcome, equals(RecoveryOutcome.failed));
      expect(result.result, isNull);
      expect(result.message, equals('all options exhausted'));
    });

    test('recovered with null result', () {
      final result = RecoveryResult.recovered(null);
      expect(result.outcome, equals(RecoveryOutcome.recovered));
      expect(result.result, isNull);
    });
  });

  group('FallbackRecovery', () {
    test('returns result from first successful fallback', () async {
      final strategy = FallbackRecovery([
        (_) async => 'fallback-1-result',
        (_) async => 'fallback-2-result',
      ]);

      final exception = SkillExecutionException('test error');
      final result = await strategy.recover(exception, _makeStepContext());

      expect(result.outcome, equals(RecoveryOutcome.recovered));
      expect(result.result, equals('fallback-1-result'));
      expect(result.message, equals('Used fallback'));
    });

    test('skips failed fallback and uses next', () async {
      final strategy = FallbackRecovery([
        (_) async => throw Exception('first failed'),
        (_) async => 'second-result',
      ]);

      final exception = SkillExecutionException('test error');
      final result = await strategy.recover(exception, _makeStepContext());

      expect(result.outcome, equals(RecoveryOutcome.recovered));
      expect(result.result, equals('second-result'));
    });

    test('returns failed when all fallbacks fail', () async {
      final strategy = FallbackRecovery([
        (_) async => throw Exception('first failed'),
        (_) async => throw Exception('second failed'),
        (_) async => throw Exception('third failed'),
      ]);

      final exception = SkillExecutionException('test error');
      final result = await strategy.recover(exception, _makeStepContext());

      expect(result.outcome, equals(RecoveryOutcome.failed));
      expect(result.message, equals('All fallbacks exhausted'));
    });

    test('empty fallback list returns failed', () async {
      final strategy = FallbackRecovery([]);

      final exception = SkillExecutionException('test error');
      final result = await strategy.recover(exception, _makeStepContext());

      expect(result.outcome, equals(RecoveryOutcome.failed));
    });

    test('passes StepContext to fallback functions', () async {
      String? capturedSkillId;
      final strategy = FallbackRecovery([
        (ctx) async {
          capturedSkillId = ctx.skillId;
          return 'ok';
        },
      ]);

      final exception = SkillExecutionException('test error');
      await strategy.recover(exception, _makeStepContext());

      expect(capturedSkillId, equals('skill-1'));
    });
  });

  group('SkipRecovery', () {
    test('returns skipped result with message', () async {
      final strategy = SkipRecovery();
      final exception = SkillExecutionException('step failed');
      final result = await strategy.recover(exception, _makeStepContext());

      expect(result.outcome, equals(RecoveryOutcome.skipped));
      expect(result.message, contains('step failed'));
    });

    test('includes exception message in skip message', () async {
      final strategy = SkipRecovery();
      final exception = SkillExecutionException('timeout on LLM call');
      final result = await strategy.recover(exception, _makeStepContext());

      expect(result.message, contains('timeout on LLM call'));
    });

    test('accepts default value parameter', () {
      final strategy = SkipRecovery(defaultValue: 'default');
      expect(strategy.defaultValue, equals('default'));
    });
  });

  group('RecoveryOutcome', () {
    test('has expected values', () {
      expect(RecoveryOutcome.values.length, equals(3));
      expect(RecoveryOutcome.values, contains(RecoveryOutcome.recovered));
      expect(RecoveryOutcome.values, contains(RecoveryOutcome.skipped));
      expect(RecoveryOutcome.values, contains(RecoveryOutcome.failed));
    });
  });
}
