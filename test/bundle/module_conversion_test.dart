// Conversion of a bundle skill module (bundle spec 03 §3.5.1): what is
// carried over, what is refused, and what then runs on the production path.

import 'package:mcp_bundle/mcp_bundle.dart' as mb;
import 'package:mcp_bundle/src/ports/mcp_port.dart' show ToolResult;
import 'package:mcp_skill/mcp_skill.dart' as sk;
import 'package:test/test.dart';

import '../helpers/mock_ports.dart';

mb.ProcedureStep step(
  String id,
  Map<String, dynamic> action, {
  String? condition,
  List<String> next = const [],
  String? onError,
}) =>
    mb.ProcedureStep(
      id: id,
      action: mb.StepAction.fromJson(action),
      condition: condition,
      next: next,
      onError: onError,
    );

mb.SkillModule module(List<mb.ProcedureStep> steps, {String? entryPoint}) =>
    mb.SkillModule(
      id: 'm',
      name: 'M',
      procedures: [
        mb.SkillProcedure(
            id: 'main', name: 'main', steps: steps, entryPoint: entryPoint),
      ],
    );

Matcher refused({String? mentions, String? stepId}) =>
    isA<sk.InvalidProcedureException>()
        .having((e) => e.message, 'message', contains(mentions ?? ''))
        .having((e) => e.stepId, 'stepId', stepId ?? anything)
        .having((e) => e.procedureId, 'procedureId', 'main');

List<Map<String, dynamic>> stepsOf(sk.SkillBundle b) =>
    [for (final s in b.procedures.single.steps) s.toJson()];

void main() {
  group('what is carried over', () {
    test('ids, order and name', () {
      final b = sk.skillBundleFromModule(module([
        step('a', {'type': 'tool', 'toolRef': 't'}),
        step('b', {'type': 'tool', 'toolRef': 't'}),
      ]));
      expect(stepsOf(b).map((s) => [s['id'], s['order'], s['name']]), [
        ['a', 1, 'a'],
        ['b', 2, 'b'],
      ]);
    });

    test('the manifest comes from the module and the arguments', () {
      final b = sk.skillBundleFromModule(
          mb.SkillModule(
              id: 'm', name: 'M', version: '2.0.0', capabilities: const ['x']),
          id: 'pkg.m',
          provider: 'pkg');
      expect(b.manifest.id, 'pkg.m');
      expect(b.manifest.name, 'M');
      expect(b.manifest.version, '2.0.0');
      expect(b.manifest.provider, 'pkg');
      expect(b.manifest.capabilities, ['x']);
    });

    test('next to the following step needs no jump, a later one does', () {
      final b = sk.skillBundleFromModule(module([
        step('a', {'type': 'tool'}, next: ['b']),
        step('b', {'type': 'tool'}, next: ['d']),
        step('c', {'type': 'tool'}),
        step('d', {'type': 'tool'}),
      ]));
      final s = stepsOf(b);
      expect(s[0].containsKey('onSuccess'), isFalse);
      expect(s[1]['onSuccess'], 'd');
    });

    test('onError becomes onFailure, condition is kept', () {
      final b = sk.skillBundleFromModule(module([
        step('a', {'type': 'tool'}, onError: 'c', condition: 'inputs.x'),
        step('b', {'type': 'tool'}),
        step('c', {'type': 'tool'}),
      ]));
      final first = stepsOf(b).first;
      expect(first['onFailure'], 'c');
      expect(first['condition'], 'inputs.x');
    });

    test('an entryPoint that is the first step is accepted', () {
      sk.skillBundleFromModule(module([
        step('a', {'type': 'tool'}),
        step('b', {'type': 'tool'}),
      ], entryPoint: 'a'));
    });
  });

  group('what is refused', () {
    void refuses(String name, List<mb.ProcedureStep> steps,
        {String? mentions, String? stepId, String? entry}) {
      test(name, () {
        expect(
            () => sk.skillBundleFromModule(module(steps, entryPoint: entry)),
            throwsA(refused(mentions: mentions, stepId: stepId)));
      });
    }

    // The bundle model reads any type it does not know as `unknown`.
    refuses('an unknown step type', [step('a', {'type': 'dance'})],
        mentions: 'unknown', stepId: 'a');
    refuses('several next steps',
        [step('a', {'type': 'tool'}, next: ['b', 'c']), step('b', {'type': 'tool'}), step('c', {'type': 'tool'})],
        mentions: 'several', stepId: 'a');
    refuses('a next that goes back',
        [step('a', {'type': 'tool'}), step('b', {'type': 'tool'}, next: ['a'])],
        mentions: 'later', stepId: 'b');
    refuses('a next to itself',
        [step('a', {'type': 'tool'}, next: ['a'])],
        mentions: 'later', stepId: 'a');
    refuses('a next to an unknown step',
        [step('a', {'type': 'tool'}, next: ['zz'])],
        mentions: 'zz', stepId: 'a');
    refuses('an onError that goes back',
        [step('a', {'type': 'tool'}), step('b', {'type': 'tool'}, onError: 'a')],
        mentions: 'onError', stepId: 'b');
    refuses('an onError to an unknown step',
        [step('a', {'type': 'tool'}, onError: 'zz')],
        mentions: 'zz', stepId: 'a');
    refuses('an entryPoint that is not the first step',
        [step('a', {'type': 'tool'}), step('b', {'type': 'tool'})],
        entry: 'b', mentions: 'entryPoint');
    refuses('a repeated step id',
        [step('a', {'type': 'tool'}), step('a', {'type': 'tool'})],
        mentions: 'twice', stepId: 'a');
    refuses('a step without an id', [step('', {'type': 'tool'})],
        mentions: 'no id');

    refuses('a prompt step with an unknown extractClaims',
        [step('p', {'type': 'prompt', 'prompt': 'x', 'extractClaims': 'sometimes'})],
        mentions: 'extractClaims', stepId: 'p');

    test('a prompt step with a known extractClaims is accepted', () {
      for (final v in ['none', 'rules', 'llm', 'hybrid']) {
        sk.skillBundleFromModule(module([
          step('p', {'type': 'prompt', 'prompt': 'x', 'extractClaims': v}),
        ]));
      }
    });

    group('branch', () {
      refuses('without cases and without a default',
          [step('b', {'type': 'branch'})],
          mentions: 'cases', stepId: 'b');
      refuses('a case without when',
          [step('b', {'type': 'branch', 'cases': [{'goto': 'c'}]}), step('c', {'type': 'tool'})],
          mentions: 'when', stepId: 'b');
      refuses('a case that goes back',
          [step('a', {'type': 'tool'}), step('b', {'type': 'branch', 'cases': [{'when': 'true', 'goto': 'a'}]})],
          mentions: 'goto', stepId: 'b');
      refuses('a default to an unknown step',
          [step('b', {'type': 'branch', 'default': 'zz'})],
          mentions: 'zz', stepId: 'b');
      test('a branch with only a default is accepted', () {
        sk.skillBundleFromModule(module([
          step('b', {'type': 'branch', 'default': 'c'}),
          step('c', {'type': 'tool'}),
        ]));
      });
    });

    group('loop', () {
      Map<String, dynamic> body() => {
            'steps': [
              {'id': 'x', 'action': {'type': 'tool', 'toolRef': 't'}},
            ],
          };
      refuses('with neither over nor while',
          [step('l', {'type': 'loop', ...body()})],
          mentions: 'exactly one', stepId: 'l');
      refuses('with both over and while',
          [step('l', {'type': 'loop', 'over': 'a', 'while': 'b', 'maxIterations': 2, ...body()})],
          mentions: 'exactly one', stepId: 'l');
      refuses('while without maxIterations',
          [step('l', {'type': 'loop', 'while': 'true', ...body()})],
          mentions: 'maxIterations', stepId: 'l');
      refuses('a maxIterations that is not positive',
          [step('l', {'type': 'loop', 'over': 'a', 'maxIterations': 0, ...body()})],
          mentions: 'positive', stepId: 'l');
      refuses('a maxIterations that is not an integer',
          [step('l', {'type': 'loop', 'over': 'a', 'maxIterations': '3', ...body()})],
          mentions: 'positive', stepId: 'l');
      refuses('an empty body',
          [step('l', {'type': 'loop', 'over': 'a', 'steps': []})],
          mentions: 'steps', stepId: 'l');
      refuses('a missing body', [step('l', {'type': 'loop', 'over': 'a'})],
          mentions: 'steps', stepId: 'l');
      refuses('a loop inside a loop', [
        step('l', {
          'type': 'loop',
          'over': 'a',
          'steps': [
            {'id': 'inner', 'action': {'type': 'loop', 'over': 'b', ...body()}},
          ],
        }),
      ], mentions: 'loop', stepId: 'inner');
      refuses('a body step with an unknown type', [
        step('l', {
          'type': 'loop',
          'over': 'a',
          'steps': [
            {'id': 'x', 'action': {'type': 'dance'}},
          ],
        }),
      ], mentions: 'dance', stepId: 'x');
      refuses('a body step whose next goes back', [
        step('l', {
          'type': 'loop',
          'over': 'a',
          'steps': [
            {'id': 'x', 'action': {'type': 'tool'}},
            {'id': 'y', 'action': {'type': 'tool'}, 'next': ['x']},
          ],
        }),
      ], mentions: 'later', stepId: 'y');
      refuses('a body step id repeated', [
        step('l', {
          'type': 'loop',
          'over': 'a',
          'steps': [
            {'id': 'x', 'action': {'type': 'tool'}},
            {'id': 'x', 'action': {'type': 'tool'}},
          ],
        }),
      ], mentions: 'twice', stepId: 'x');
    });

    test('a procedure that fails fails the whole module', () {
      final m = mb.SkillModule(id: 'm', name: 'M', procedures: [
        mb.SkillProcedure(id: 'ok', name: 'ok', steps: [step('a', {'type': 'tool'})]),
        mb.SkillProcedure(id: 'main', name: 'main', steps: [step('a', {'type': 'dance'})]),
      ]);
      expect(() => sk.skillBundleFromModule(m),
          throwsA(isA<sk.InvalidProcedureException>()));
    });
  });

  group('running what was converted, on the production path', () {
    late MockMcpPort mcp;
    late MockLlmPort llm;
    late sk.SkillRuntime runtime;
    late sk.MemorySkillRegistry registry;

    setUp(() {
      mcp = MockMcpPort();
      llm = MockLlmPort();
      registry = sk.MemorySkillRegistry();
      runtime = sk.SkillRuntime(
        registry: registry,
        ports: sk.SkillPorts.stub().copyWith(llm: llm, mcp: mcp),
      );
    });

    Future<sk.SkillResult> run(mb.SkillModule m,
        {Map<String, dynamic> inputs = const {}}) async {
      await registry.registerSkill(sk.skillBundleFromModule(m));
      return runtime.run(sk.SkillContext(
        contextId: 'c',
        skillId: 'm',
        runId: 'r',
        traceId: 't',
        request: 'q',
        workspaceId: 'w',
        asOf: DateTime(2026, 1, 1),
        inputs: inputs,
        activeSkills: const ['m'],
      ));
    }

    test('the bundle spec example runs with its prompt', () async {
      await run(
        module([
          step('p', {'type': 'prompt', 'prompt': r'Summarize: ${inputs.text}'}),
        ]),
        inputs: {'text': 'hello'},
      );
      expect(llm.completeCalls.single.messages!.last.content,
          'Summarize: hello');
    });

    test('a prompt written with the old key "template" runs with its prompt',
        () async {
      await run(
        module([
          step('p', {'type': 'prompt', 'template': r'Summarize: ${inputs.text}'}),
        ]),
        inputs: {'text': 'hello'},
      );
      expect(llm.completeCalls.single.messages!.last.content,
          'Summarize: hello');
    });

    test('a tool written with the key "tool" calls that tool', () async {
      await run(module([
        step('t', {'type': 'tool', 'tool': 'ns.do', 'args': {'a': 1}}),
      ]));
      expect(mcp.toolCalls.single.toolName, 'ns.do');
    });

    test('branch, loop and output together', () async {
      final result = await run(
        module([
          step('pick', {
            'type': 'branch',
            'cases': [
              {'when': 'inputs.big', 'goto': 'many'},
            ],
            'default': 'few',
          }),
          step('many', {'type': 'transform', 'expression': '[1, 2, 3]'},
              next: ['each']),
          step('few', {'type': 'transform', 'expression': '[1]'}),
          step('each', {
            'type': 'loop',
            'over': 'steps.many.result ?? steps.few.result',
            'steps': [
              {
                'id': 'tick',
                'action': {'type': 'tool', 'toolRef': 'count'},
              },
            ],
          }),
          step('done', {'type': 'output', 'value': 'steps.each.result'}),
        ]),
        inputs: {'big': true},
      );
      expect(mcp.toolCalls.map((c) => c.toolName), ['count', 'count', 'count']);
      expect((result.output as List).length, 3);
    });

    test('a tool that reports isError fails the run on the production path',
        () async {
      mcp.nextToolResult = ToolResult.error('boom');
      final result =
          await run(module([step('t', {'type': 'tool', 'toolRef': 'x'})]));
      expect(result.success, isFalse);
      expect(result.metadata.custom!['error'], contains('boom'));
    });

    test('onError routes the failure to a rescue step', () async {
      mcp.nextToolResult = ToolResult.error('boom');
      final result = await run(module([
        step('t', {'type': 'tool', 'toolRef': 'x'}, onError: 'rescue'),
        step('skipped', {'type': 'output', 'value': '"no"'}),
        step('rescue', {'type': 'output', 'value': '"rescued"'}),
      ]));
      expect(result.output, 'rescued');
    });
  });
}
