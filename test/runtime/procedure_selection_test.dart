// A skill with several procedures runs the one the run names; the first is
// the default.

import 'package:mcp_bundle/mcp_bundle.dart' as mb;
import 'package:mcp_skill/mcp_skill.dart' as sk;
import 'package:test/test.dart';

mb.ProcedureStep out(String id, String value) => mb.ProcedureStep(
      id: id,
      action: mb.StepAction.fromJson({'type': 'output', 'value': value}),
    );

mb.SkillModule twoProcedures() => mb.SkillModule(id: 'm', name: 'M', procedures: [
      mb.SkillProcedure(id: 'first', name: 'first', steps: [out('o', '"one"')]),
      mb.SkillProcedure(id: 'second', name: 'second', steps: [out('o', '"two"')]),
    ]);

void main() {
  late sk.SkillRuntime runtime;

  setUp(() async {
    final registry = sk.MemorySkillRegistry();
    await registry.registerSkill(sk.skillBundleFromModule(twoProcedures()));
    runtime = sk.SkillRuntime(registry: registry, ports: sk.SkillPorts.stub());
  });

  sk.SkillContext ctx({String? procedureId}) => sk.SkillContext(
        contextId: 'c',
        skillId: 'm',
        runId: 'r',
        traceId: 't',
        request: 'q',
        workspaceId: 'w',
        asOf: DateTime(2026, 1, 1),
        activeSkills: const ['m'],
        procedureId: procedureId,
      );

  test('without a procedureId the first procedure runs', () async {
    expect((await runtime.run(ctx())).output, 'one');
  });

  test('a procedureId picks that procedure', () async {
    expect((await runtime.run(ctx(procedureId: 'second'))).output, 'two');
    expect((await runtime.run(ctx(procedureId: 'first'))).output, 'one');
  });

  test('an unknown procedureId is a failure naming it, not the first',
      () async {
    final result = await runtime.run(ctx(procedureId: 'nope'));
    expect(result.success, isFalse);
    expect(result.metadata.custom!['error'], contains('nope'));
  });

  test('runProcedure runs the procedure it is given', () async {
    expect((await runtime.runProcedure('m', 'second', ctx())).output, 'two');
  });

  test('runProcedure with an unknown id throws', () async {
    expect(() => runtime.runProcedure('m', 'nope', ctx()),
        throwsA(isA<sk.ProcedureNotFoundException>()));
  });

  test('procedureId survives JSON and copyWith', () {
    final c = ctx(procedureId: 'second');
    expect(sk.SkillContext.fromJson(c.toJson()).procedureId, 'second');
    expect(c.copyWith(request: 'x').procedureId, 'second');
    expect(ctx().toJson().containsKey('procedureId'), isFalse);
  });
}
