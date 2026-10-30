// `parseJson` in the skill expression language, and reading a model's JSON
// reply in a procedure.

import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/runtime/procedure_executor.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/default_expression_evaluator.dart';
import 'package:test/test.dart';
import 'package:mcp_bundle/mcp_bundle.dart' show LlmResponse, LlmUsage;

import '../helpers/mock_ports.dart';

SkillContext ctx(Map<String, dynamic> inputs) => SkillContext(
      contextId: 'c',
      skillId: 's',
      runId: 'r',
      traceId: 't',
      request: 'q',
      workspaceId: 'w',
      asOf: DateTime(2026, 1, 1),
      inputs: inputs,
    );

Future<dynamic> eval(String expression, Map<String, dynamic> inputs) =>
    defaultExpressionEvaluator(expression, ctx(inputs), const {});

void main() {
  group('parseJson in an expression', () {
    test('reads JSON text and its fields', () async {
      expect(await eval('parseJson(inputs.r).score', {'r': '{"score": 0.8}'}),
          0.8);
    });

    test('removes a code fence a model put around the answer', () async {
      expect(
          await eval('parseJson(inputs.r).score',
              {'r': '```json\n{"score": 0.9}\n```'}),
          0.9);
    });

    test('compares a field in a condition', () async {
      expect(
          await eval('parseJson(inputs.r).score >= 0.7', {'r': '{"score": 0.5}'}),
          false);
    });

    test('text that is not JSON fails the evaluation', () async {
      await expectLater(eval('parseJson(inputs.r)', {'r': 'sorry'}),
          throwsA(anything));
    });

    test('a map is returned as it is', () async {
      expect(await eval('parseJson(inputs.m).a', {'m': {'a': 1}}), 1);
    });
  });

  group('a procedure reading a model reply', () {
    late MockLlmPort llm;
    late ProcedureExecutor executor;

    setUp(() {
      llm = MockLlmPort();
      executor = ProcedureExecutor(
          ports: SkillPorts.stub().copyWith(llm: llm, mcp: MockMcpPort()));
    });

    Procedure judge(String reply) {
      llm.nextResponse = LlmResponse(
          content: reply, usage: const LlmUsage(inputTokens: 1, outputTokens: 1));
      return Procedure.fromJson({
        'id': 'p',
        'name': 'p',
        'steps': [
          {
            'id': 'judge',
            'order': 1,
            'name': 'judge',
            'action': {'type': 'llm', 'prompt': 'score it'},
          },
          {
            'id': 'parsed',
            'order': 2,
            'name': 'parsed',
            'action': {'type': 'transform', 'expression': 'parseJson(steps.judge.result)'},
          },
          {
            'id': 'out',
            'order': 3,
            'name': 'out',
            'action': {'type': 'output', 'value': 'steps.parsed.result.score'},
          },
        ],
      });
    }

    test('the score is read from the parsed reply', () async {
      final r = await executor.execute(judge('```json\n{"score": 0.75}\n```'), ctx({}));
      expect(r.output, 0.75);
    });

    test('an unreadable reply fails the transform step', () async {
      await expectLater(
          executor.execute(judge('I cannot score this.'), ctx({})),
          throwsA(anything));
    });

    test('an unreadable reply goes to onFailure when one is given', () async {
      llm.nextResponse = const LlmResponse(
          content: 'nope', usage: LlmUsage(inputTokens: 1, outputTokens: 1));
      final r = await executor.execute(
          Procedure.fromJson({
            'id': 'p',
            'name': 'p',
            'steps': [
              {
                'id': 'judge',
                'order': 1,
                'name': 'judge',
                'action': {'type': 'llm', 'prompt': 'x'},
              },
              {
                'id': 'parsed',
                'order': 2,
                'name': 'parsed',
                'onFailure': 'fallback',
                'action': {'type': 'transform', 'expression': 'parseJson(steps.judge.result)'},
              },
              {
                'id': 'skipped',
                'order': 3,
                'name': 'skipped',
                'action': {'type': 'output', 'value': '"read"'},
              },
              {
                'id': 'fallback',
                'order': 4,
                'name': 'fallback',
                'action': {'type': 'output', 'value': '"unreadable"'},
              },
            ],
          }),
          ctx({}));
      expect(r.output, 'unreadable');
    });
  });
}
