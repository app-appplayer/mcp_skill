// Tests for StepExecutor - action type dispatching and result building.

import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/step_executor.dart';
import 'package:mcp_skill/src/runtime/procedure_executor.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_bundle/src/types/knowledge_types.dart';
import '../helpers/mock_ports.dart';

void main() {
  // Helper to create a minimal SkillContext.
  SkillContext _makeContext({
    Map<String, dynamic> inputs = const {},
  }) {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: 'test-skill',
      runId: 'run-1',
      traceId: 'trace-1',
      request: 'test request',
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 1, 1),
      inputs: inputs,
    );
  }

  group('StepExecutor', () {
    late MockLlmPort mockLlm;
    late MockMcpPort mockMcp;
    late MockRetrievalPort mockRetrieval;
    late MockClaimsPort mockClaims;
    late SkillPorts ports;
    late StepExecutor executor;

    setUp(() {
      mockLlm = MockLlmPort();
      mockMcp = MockMcpPort();
      mockRetrieval = MockRetrievalPort();
      mockClaims = MockClaimsPort();
      ports = SkillPorts(
        llm: mockLlm,
        mcp: mockMcp,
        retrieval: mockRetrieval,
        claims: mockClaims,
      );
      executor = StepExecutor(ports: ports);
    });

    group('llm action', () {
      test('calls LlmPort.complete with prompt', () async {
        const step = ProcedureStep(
          id: 'step-llm',
          order: 1,
          name: 'LLM Step',
          action: StepAction(type: 'llm', prompt: 'Analyze this data'),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-llm'));
        expect(result.result, equals('mock response'));
        expect(mockLlm.completeCalls.length, equals(1));
      });

      test('includes system prompt in request', () async {
        const step = ProcedureStep(
          id: 'step-llm',
          order: 1,
          name: 'LLM Step',
          action: StepAction(
            type: 'llm',
            prompt: 'Query',
            systemPrompt: 'You are an analyst',
          ),
        );

        await executor.execute(step, _makeContext(), {});

        final request = mockLlm.completeCalls.first;
        expect(request.messages!.length, equals(2));
        expect(request.messages![0].role, equals('system'));
        expect(request.messages![0].content, equals('You are an analyst'));
      });

      test('passes model and temperature', () async {
        const step = ProcedureStep(
          id: 'step-llm',
          order: 1,
          name: 'LLM Step',
          action: StepAction(
            type: 'llm',
            prompt: 'Query',
            model: 'gpt-4',
            temperature: 0.3,
            maxTokens: 200,
          ),
        );

        await executor.execute(step, _makeContext(), {});

        final request = mockLlm.completeCalls.first;
        expect(request.model, equals('gpt-4'));
        expect(request.temperature, equals(0.3));
        expect(request.maxTokens, equals(200));
      });

      test('interpolates inputs in prompt', () async {
        const step = ProcedureStep(
          id: 'step-llm',
          order: 1,
          name: 'LLM Step',
          action: StepAction(
            type: 'llm',
            prompt: r'Analyze ${inputs.topic}',
          ),
        );

        await executor.execute(
            step, _makeContext(inputs: {'topic': 'finance'}), {});

        final request = mockLlm.completeCalls.first;
        expect(request.messages!.last.content, equals('Analyze finance'));
      });
    });

    group('tool action', () {
      test('calls McpPort.callTool with toolRef and args', () async {
        const step = ProcedureStep(
          id: 'step-tool',
          order: 1,
          name: 'Tool Step',
          action: StepAction(
            type: 'tool',
            toolRef: 'calculator',
            args: {'expression': '2+2'},
          ),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-tool'));
        expect(result.toolCalled, equals('calculator'));
        expect(mockMcp.toolCalls.length, equals(1));
        expect(mockMcp.toolCalls.first.toolName, equals('calculator'));
      });
    });

    group('retrieve action', () {
      test('calls RetrievalPort.queryKnowledge with retrieverRef and query', () async {
        mockRetrieval.nextQueryResult = RetrievalResult(
          passages: [
            RetrievedPassage(
              id: 'p1',
              content: 'relevant passage',
              score: 0.9,
            ),
          ],
        );

        const step = ProcedureStep(
          id: 'step-retrieve',
          order: 1,
          name: 'Retrieve Step',
          action: StepAction(
            type: 'retrieve',
            retrieverRef: 'my-retriever',
            query: 'search query',
            maxResults: 5,
          ),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-retrieve'));
        expect(result.result, contains('relevant passage'));
        expect(mockRetrieval.queryCalls.length, equals(1));
      });

      test('evidence refs populated from passages', () async {
        mockRetrieval.nextQueryResult = RetrievalResult(
          passages: [
            RetrievedPassage(
              id: 'p1',
              content: 'passage 1',
              score: 0.9,
              sourceUri: 'doc://source1',
            ),
            RetrievedPassage(
              id: 'p2',
              content: 'passage 2',
              score: 0.8,
            ),
          ],
        );

        const step = ProcedureStep(
          id: 'step-retrieve',
          order: 1,
          name: 'Retrieve Step',
          action: StepAction(
            type: 'retrieve',
            query: 'query',
          ),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.evidenceRefs, isNotEmpty);
        expect(result.evidenceRefs, contains('doc://source1'));
      });
    });

    group('transform action', () {
      test('uses expressionEvaluator to transform data', () async {
        final transformExecutor = StepExecutor(
          ports: ports,
          expressionEvaluator: (expr, ctx, results) async {
            return 'transformed: $expr';
          },
        );

        const step = ProcedureStep(
          id: 'step-transform',
          order: 1,
          name: 'Transform Step',
          action: StepAction(
            type: 'transform',
            expression: 'input.data | uppercase',
          ),
        );

        final result =
            await transformExecutor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-transform'));
        expect(result.result, equals('transformed: input.data | uppercase'));
      });

      test('throws when no expression evaluator configured', () {
        const step = ProcedureStep(
          id: 'step-transform',
          order: 1,
          name: 'Transform Step',
          action: StepAction(
            type: 'transform',
            expression: 'something',
          ),
        );

        expect(
          () => executor.execute(step, _makeContext(), {}),
          throwsA(isA<UnsupportedActionException>()),
        );
      });
    });

    group('validate action', () {
      test('returns valid true when ClaimsPort passes validation', () async {
        const step = ProcedureStep(
          id: 'step-validate',
          order: 1,
          name: 'Validate Step',
          action: StepAction(type: 'validate'),
        );

        final result = await executor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-validate'));
        final resultMap = result.result as Map<String, dynamic>;
        expect(resultMap['valid'], isTrue);
      });

      test('returns skipped when no ClaimsPort configured', () async {
        final portsWithoutClaims = SkillPorts(llm: mockLlm, mcp: mockMcp);
        final localExecutor = StepExecutor(ports: portsWithoutClaims);

        const step = ProcedureStep(
          id: 'step-validate-nop',
          order: 1,
          name: 'Validate Step',
          action: StepAction(type: 'validate'),
        );

        final result =
            await localExecutor.execute(step, _makeContext(), {});

        final resultMap = result.result as Map<String, dynamic>;
        expect(resultMap['valid'], isTrue);
        expect(resultMap['skipped'], isTrue);
      });
    });

    group('parallel action', () {
      test('executes sub-actions concurrently', () async {
        const step = ProcedureStep(
          id: 'step-parallel',
          order: 1,
          name: 'Parallel Step',
          action: StepAction(
            type: 'parallel',
            parallel: [
              StepAction(type: 'llm', prompt: 'prompt1'),
              StepAction(type: 'llm', prompt: 'prompt2'),
            ],
          ),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-parallel'));
        final resultList = result.result as List;
        expect(resultList.length, equals(2));
        expect(mockLlm.completeCalls.length, equals(2));
      });

      test('empty parallel returns empty list', () async {
        const step = ProcedureStep(
          id: 'step-parallel',
          order: 1,
          name: 'Parallel Step',
          action: StepAction(type: 'parallel', parallel: []),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.result, equals([]));
      });
    });

    group('procedure action', () {
      test('returns stub result', () async {
        const step = ProcedureStep(
          id: 'step-proc',
          order: 1,
          name: 'Procedure Step',
          action: StepAction(
            type: 'procedure',
            procedureRef: 'sub-proc-1',
          ),
        );

        final result =
            await executor.execute(step, _makeContext(), {});

        expect(result.stepId, equals('step-proc'));
        final resultMap = result.result as Map<String, dynamic>;
        expect(resultMap['procedureRef'], equals('sub-proc-1'));
        expect(resultMap['executed'], equals(false));
      });
    });

    group('unknown action type', () {
      test('throws UnsupportedActionException', () {
        const step = ProcedureStep(
          id: 'step-unknown',
          order: 1,
          name: 'Unknown Step',
          action: StepAction(type: 'nonexistent'),
        );

        expect(
          () => executor.execute(step, _makeContext(), {}),
          throwsA(isA<UnsupportedActionException>()),
        );
      });
    });
  });

  group('UnsupportedActionException', () {
    test('stores action type', () {
      final ex = UnsupportedActionException('magic');
      expect(ex.actionType, equals('magic'));
    });

    test('toString includes action type', () {
      final ex = UnsupportedActionException('magic');
      expect(ex.toString(), contains('magic'));
    });
  });
}
