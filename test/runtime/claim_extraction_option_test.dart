// An `llm` step extracts claims from its reply unless the host or the step
// says otherwise (bundle spec 03 §3.5.1).

import 'package:mcp_bundle/mcp_bundle.dart' as mb;
import 'package:mcp_skill/mcp_skill.dart' as sk;
import 'package:mcp_skill/src/runtime/procedure_executor.dart' as rt;
import 'package:test/test.dart';

import '../helpers/mock_ports.dart';

const reply = 'Revenue grew 12% in the third quarter. The trend is certain.';

rt.Procedure judge({String? extractClaims}) => rt.Procedure.fromJson({
      'id': 'p',
      'name': 'p',
      'steps': [
        {
          'id': 'j',
          'order': 1,
          'name': 'j',
          'action': {
            'type': 'llm',
            'prompt': 'judge',
            if (extractClaims != null) 'extractClaims': extractClaims,
          },
        },
      ],
    });

sk.SkillContext ctx() => sk.SkillContext(
      contextId: 'c',
      skillId: 's',
      runId: 'r',
      traceId: 't',
      request: 'q',
      workspaceId: 'w',
      asOf: DateTime(2026, 1, 1),
    );

void main() {
  late MockLlmPort llm;

  setUp(() {
    llm = MockLlmPort(
        response: const mb.LlmResponse(
            content: reply, usage: mb.LlmUsage(inputTokens: 1, outputTokens: 1)));
  });

  sk.ProcedureExecutor executor({sk.ClaimExtractionConfig? config}) =>
      sk.ProcedureExecutor(
          ports: sk.SkillPorts.stub().copyWith(llm: llm),
          claimExtraction: config);

  test('the default is unchanged: claims are extracted from the reply',
      () async {
    final r = await executor().execute(judge(), ctx());
    expect(r.claims, isNotEmpty);
  });

  test('a host that sets none gets the reply as text, no claims, one call',
      () async {
    final r = await executor(
            config: const sk.ClaimExtractionConfig(
                strategy: sk.ClaimExtractionStrategy.none))
        .execute(judge(), ctx());
    expect(r.claims, isEmpty);
    expect(llm.completeCalls.length, 1);
  });

  test('a host that sets rules makes no extra LLM call', () async {
    final r = await executor(
            config: const sk.ClaimExtractionConfig(
                strategy: sk.ClaimExtractionStrategy.ruleBased))
        .execute(judge(), ctx());
    expect(r.claims, isNotEmpty);
    expect(llm.completeCalls.length, 1);
  });

  test('a step can turn extraction off although the host extracts', () async {
    final r = await executor().execute(judge(extractClaims: 'none'), ctx());
    expect(r.claims, isEmpty);
    expect(llm.completeCalls.length, 1);
  });

  test('a step can ask for extraction although the host turned it off',
      () async {
    final r = await executor(
            config: const sk.ClaimExtractionConfig(
                strategy: sk.ClaimExtractionStrategy.none))
        .execute(judge(extractClaims: 'rules'), ctx());
    expect(r.claims, isNotEmpty);
  });

  test('a step keeps the host\'s minConfidence and maxClaims', () async {
    final r = await executor(
            config: const sk.ClaimExtractionConfig(
                strategy: sk.ClaimExtractionStrategy.none, maxClaims: 1))
        .execute(judge(extractClaims: 'rules'), ctx());
    expect(r.claims.length, 1);
  });

  test('an unknown value is an error naming the step', () async {
    await expectLater(
        executor().execute(judge(extractClaims: 'sometimes'), ctx()),
        throwsA(isA<sk.InvalidProcedureException>()
            .having((e) => e.stepId, 'stepId', 'j')));
  });

  test('the key survives the conversion and the production path', () async {
    final registry = sk.MemorySkillRegistry();
    await registry.registerSkill(sk.skillBundleFromModule(mb.SkillModule(
      id: 'm',
      name: 'M',
      procedures: [
        mb.SkillProcedure(id: 'main', name: 'main', steps: [
          mb.ProcedureStep(
            id: 'j',
            action: mb.StepAction.fromJson(
                {'type': 'prompt', 'prompt': 'judge', 'extractClaims': 'none'}),
          ),
        ]),
      ],
    )));
    final runtime = sk.SkillRuntime(
        registry: registry,
        ports: sk.SkillPorts.stub().copyWith(llm: llm));
    final r = await runtime.run(sk.SkillContext(
      contextId: 'c',
      skillId: 'm',
      runId: 'r',
      traceId: 't',
      request: 'q',
      workspaceId: 'w',
      asOf: DateTime(2026, 1, 1),
      activeSkills: const ['m'],
    ));
    expect(r.claims, isEmpty);
    expect(llm.completeCalls.length, 1);
  });

  test('SkillRuntime passes the host setting to runProcedure and run',
      () async {
    final registry = sk.MemorySkillRegistry();
    await registry.registerSkill(sk.skillBundleFromModule(mb.SkillModule(
      id: 'm',
      name: 'M',
      procedures: [
        mb.SkillProcedure(id: 'main', name: 'main', steps: [
          mb.ProcedureStep(
            id: 'j',
            action:
                mb.StepAction.fromJson({'type': 'prompt', 'prompt': 'judge'}),
          ),
        ]),
      ],
    )));
    final runtime = sk.SkillRuntime(
      registry: registry,
      ports: sk.SkillPorts.stub().copyWith(llm: llm),
      claimExtraction: const sk.ClaimExtractionConfig(
          strategy: sk.ClaimExtractionStrategy.none),
    );
    final context = sk.SkillContext(
      contextId: 'c',
      skillId: 'm',
      runId: 'r',
      traceId: 't',
      request: 'q',
      workspaceId: 'w',
      asOf: DateTime(2026, 1, 1),
      activeSkills: const ['m'],
    );
    expect((await runtime.run(context)).claims, isEmpty);
    expect((await runtime.runProcedure('m', 'main', context)).claims, isEmpty);
    expect(llm.completeCalls.length, 2);
  });
}
