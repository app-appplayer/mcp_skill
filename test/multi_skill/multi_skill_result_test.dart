import 'package:test/test.dart';
import 'package:mcp_skill/src/multi_skill/multi_skill_result.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';

/// Helper to create a minimal SkillResult for testing.
SkillResult _makeResult({double confidence = 1.0}) {
  final now = DateTime.now();
  return SkillResult(
    claims: [],
    evidenceRefs: [],
    confidence: confidence,
    asOf: now,
    metadata: ExecutionMetadata(
      skillId: 'test-skill',
      skillVersion: '1.0.0',
      procedureId: 'proc-1',
      startedAt: now,
      finishedAt: now,
      duration: const Duration(seconds: 1),
      stepsExecuted: 1,
      toolsCalled: [],
    ),
  );
}

void main() {
  group('MultiSkillResult', () {
    test('constructor sets all fields', () {
      final result = _makeResult();
      final msr = MultiSkillResult(
        result: result,
        individualResults: [result],
        mode: 'chain',
        totalDuration: const Duration(seconds: 5),
      );
      expect(msr.result, result);
      expect(msr.individualResults.length, 1);
      expect(msr.mode, 'chain');
      expect(msr.totalDuration, const Duration(seconds: 5));
    });
  });

  group('ChainResult', () {
    test('constructor sets mode to chain', () {
      final result = _makeResult();
      final step = ChainStepResult(
        skillId: 'skill-1',
        result: result,
        duration: const Duration(seconds: 2),
        inputs: {'text': 'hello'},
      );
      final chainResult = ChainResult(
        result: result,
        individualResults: [result],
        totalDuration: const Duration(seconds: 3),
        chainSteps: [step],
      );
      expect(chainResult.mode, 'chain');
      expect(chainResult.chainSteps.length, 1);
      expect(chainResult.chainSteps[0].skillId, 'skill-1');
      expect(chainResult.chainSteps[0].inputs, {'text': 'hello'});
    });
  });

  group('ChainStepResult', () {
    test('constructor sets all fields', () {
      final result = _makeResult();
      final step = ChainStepResult(
        skillId: 'skill-A',
        result: result,
        duration: const Duration(seconds: 1),
        inputs: const {'key': 'val'},
      );
      expect(step.skillId, 'skill-A');
      expect(step.result, result);
      expect(step.duration, const Duration(seconds: 1));
      expect(step.inputs, {'key': 'val'});
    });

    test('inputs defaults to empty map', () {
      final result = _makeResult();
      final step = ChainStepResult(
        skillId: 'skill-B',
        result: result,
        duration: const Duration(seconds: 2),
      );
      expect(step.inputs, isEmpty);
    });
  });

  group('CompetitionResult', () {
    test('constructor sets mode to competition', () {
      final result = _makeResult();
      final outcome = CompetitorOutcome(
        skillId: 'skill-1',
        result: result,
        score: 0.95,
        isWinner: true,
      );
      final compResult = CompetitionResult(
        result: result,
        individualResults: [result],
        totalDuration: const Duration(seconds: 4),
        winnerId: 'skill-1',
        outcomes: [outcome],
      );
      expect(compResult.mode, 'competition');
      expect(compResult.winnerId, 'skill-1');
      expect(compResult.outcomes.length, 1);
    });
  });

  group('CompetitorOutcome', () {
    test('constructor sets all fields', () {
      final result = _makeResult();
      final outcome = CompetitorOutcome(
        skillId: 'skill-X',
        result: result,
        score: 0.88,
        isWinner: false,
        error: null,
      );
      expect(outcome.skillId, 'skill-X');
      expect(outcome.result, result);
      expect(outcome.score, 0.88);
      expect(outcome.isWinner, false);
      expect(outcome.error, isNull);
    });

    test('constructor with error and no result', () {
      const outcome = CompetitorOutcome(
        skillId: 'skill-Y',
        result: null,
        score: 0.0,
        isWinner: false,
        error: 'timeout',
      );
      expect(outcome.result, isNull);
      expect(outcome.error, 'timeout');
    });
  });

  group('ParallelResult', () {
    test('constructor sets mode to parallel', () {
      final result = _makeResult();
      final outcome = ParallelOutcome(
        skillId: 'skill-1',
        result: result,
        success: true,
        duration: const Duration(seconds: 1),
      );
      final parResult = ParallelResult(
        result: result,
        individualResults: [result],
        totalDuration: const Duration(seconds: 2),
        outcomes: [outcome],
        successCount: 1,
        failureCount: 0,
      );
      expect(parResult.mode, 'parallel');
      expect(parResult.outcomes.length, 1);
      expect(parResult.successCount, 1);
      expect(parResult.failureCount, 0);
    });
  });

  group('ParallelOutcome', () {
    test('constructor sets all fields for success', () {
      final result = _makeResult();
      final outcome = ParallelOutcome(
        skillId: 'skill-P',
        result: result,
        success: true,
        duration: const Duration(seconds: 2),
      );
      expect(outcome.skillId, 'skill-P');
      expect(outcome.success, true);
      expect(outcome.result, result);
      expect(outcome.duration, const Duration(seconds: 2));
      expect(outcome.error, isNull);
    });

    test('constructor sets all fields for failure', () {
      const outcome = ParallelOutcome(
        skillId: 'skill-Q',
        result: null,
        success: false,
        duration: Duration(seconds: 3),
        error: 'something failed',
      );
      expect(outcome.success, false);
      expect(outcome.result, isNull);
      expect(outcome.error, 'something failed');
    });
  });
}
