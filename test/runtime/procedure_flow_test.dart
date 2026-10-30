// Flow of a procedure run (bundle spec 03 §3.5.1): forward jumps, guards,
// failure routing, branch, loop and output.

import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';
import 'package:mcp_skill/src/ports/skill_ports.dart';
import 'package:mcp_skill/src/runtime/procedure_executor.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_bundle/src/ports/mcp_port.dart' show ToolResult;
import 'package:test/test.dart';

import '../helpers/mock_ports.dart';

SkillContext ctx({
  Map<String, dynamic> inputs = const {},
  ExecutionBudget? budget,
}) =>
    SkillContext(
      contextId: 'c',
      skillId: 's',
      runId: 'r',
      traceId: 't',
      request: 'q',
      workspaceId: 'w',
      asOf: DateTime(2026, 1, 1),
      inputs: inputs,
      budget: budget,
    );

/// A step that records its own execution as a tool call named `t_<id>`.
ProcedureStep tool(
  String id, {
  String? condition,
  String? onSuccess,
  String? onFailure,
  Map<String, dynamic>? args,
}) =>
    ProcedureStep(
      id: id,
      order: 0,
      name: id,
      action: StepAction(type: 'tool', toolRef: 't_$id', args: args),
      condition: condition,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );

ProcedureStep step(
  String id,
  StepAction action, {
  String? condition,
  String? onSuccess,
  String? onFailure,
}) =>
    ProcedureStep(
      id: id,
      order: 0,
      name: id,
      action: action,
      condition: condition,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );

/// Gives the steps their array position as `order`.
Procedure proc(List<ProcedureStep> steps) => Procedure(
      id: 'p',
      name: 'p',
      steps: [
        for (var i = 0; i < steps.length; i++)
          ProcedureStep(
            id: steps[i].id,
            order: i + 1,
            name: steps[i].name,
            action: steps[i].action,
            condition: steps[i].condition,
            onSuccess: steps[i].onSuccess,
            onFailure: steps[i].onFailure,
          ),
      ],
    );

void main() {
  late MockMcpPort mcp;
  late ProcedureExecutor executor;

  setUp(() {
    mcp = MockMcpPort();
    executor = ProcedureExecutor(ports: SkillPorts.stub().copyWith(mcp: mcp));
  });

  List<String> ran() => [for (final c in mcp.toolCalls) c.toolName];

  group('order and guards', () {
    test('steps run front to back', () async {
      await executor.execute(proc([tool('a'), tool('b'), tool('c')]), ctx());
      expect(ran(), ['t_a', 't_b', 't_c']);
    });

    test('a falsy condition skips only that step', () async {
      await executor.execute(
          proc([tool('a'), tool('b', condition: 'inputs.go'), tool('c')]),
          ctx(inputs: {'go': false}));
      expect(ran(), ['t_a', 't_c']);
    });

    test('a truthy condition runs the step', () async {
      await executor.execute(
          proc([tool('a', condition: 'inputs.n > 1')]), ctx(inputs: {'n': 2}));
      expect(ran(), ['t_a']);
    });

    test('zero, empty text and empty list are falsy', () async {
      for (final value in <Object>[0, '', <Object>[], <String, Object>{}]) {
        mcp.toolCalls.clear();
        await executor.execute(
            proc([tool('a', condition: 'inputs.v')]), ctx(inputs: {'v': value}));
        expect(ran(), isEmpty, reason: '$value');
      }
    });

    test('a condition that cannot be evaluated is not met', () async {
      await executor.execute(
          proc([tool('a', condition: '1 +')]), ctx());
      expect(ran(), isEmpty);
    });

    test('a condition can read an earlier step result', () async {
      await executor.execute(
          proc([
            step('n', const StepAction(type: 'transform', expression: '5')),
            tool('big', condition: 'steps.n.result > 3'),
            tool('small', condition: 'steps.n.result < 3'),
          ]),
          ctx());
      expect(ran(), ['t_big']);
    });
  });

  group('onSuccess and onFailure', () {
    test('onSuccess continues at a later step', () async {
      await executor.execute(
          proc([tool('a', onSuccess: 'c'), tool('b'), tool('c')]), ctx());
      expect(ran(), ['t_a', 't_c']);
    });

    test('a step that fails goes to onFailure', () async {
      mcp.nextToolResult = ToolResult.error('boom');
      await executor.execute(
          proc([
            tool('a', onFailure: 'rescue'),
            tool('skipped'),
            step('rescue', const StepAction(type: 'transform', expression: '1')),
          ]),
          ctx());
      expect(ran(), ['t_a']);
    });

    test('a failed step without onFailure fails the procedure', () async {
      mcp.nextToolResult = ToolResult.error('boom');
      expect(() => executor.execute(proc([tool('a')]), ctx()),
          throwsA(isA<ActionExecutionException>()));
    });

    test('a tool result with isError fails the step with its message',
        () async {
      mcp.nextToolResult = ToolResult.error('disk full');
      await expectLater(
          executor.execute(proc([tool('a')]), ctx()),
          throwsA(isA<ActionExecutionException>()
              .having((e) => e.message, 'message', contains('disk full'))));
    });

    test('a tool result without isError is a success', () async {
      mcp.nextToolResult = ToolResult.success('ok');
      await executor.execute(proc([tool('a'), tool('b')]), ctx());
      expect(ran(), ['t_a', 't_b']);
    });

    test('a step that is not reached by a jump is not run', () async {
      await executor.execute(
          proc([tool('a', onSuccess: 'd'), tool('b'), tool('c'), tool('d')]),
          ctx());
      expect(ran(), ['t_a', 't_d']);
    });

    test('a jump to an unknown step is refused, not skipped', () async {
      expect(
          () => executor.execute(
              proc([tool('a', onSuccess: 'nowhere'), tool('b')]), ctx()),
          throwsA(isA<InvalidProcedureException>()));
    });

    test('a jump back is refused', () async {
      expect(
          () => executor.execute(
              proc([tool('a'), tool('b', onSuccess: 'a')]), ctx()),
          throwsA(isA<InvalidProcedureException>()));
    });

    test('a flow error is not rerouted by onFailure', () async {
      expect(
          () => executor.execute(
              proc([
                tool('a', onSuccess: 'nowhere', onFailure: 'c'),
                tool('b'),
                tool('c'),
              ]),
              ctx()),
          throwsA(isA<InvalidProcedureException>()));
    });
  });

  group('branch', () {
    ProcedureStep branch({String? fallback}) => step(
          'br',
          StepAction(
            type: 'branch',
            cases: const [
              BranchCase(when: 'inputs.n > 10', goto: 'big'),
              BranchCase(when: 'inputs.n > 5', goto: 'mid'),
            ],
            defaultTarget: fallback,
          ),
        );

    Procedure p({String? fallback}) => proc([
          branch(fallback: fallback),
          tool('big', onSuccess: 'end'),
          tool('mid', onSuccess: 'end'),
          tool('low', onSuccess: 'end'),
          step('end', const StepAction(type: 'transform', expression: '0')),
        ]);

    test('the first truthy case wins', () async {
      await executor.execute(p(), ctx(inputs: {'n': 11}));
      expect(ran(), ['t_big']);
    });

    test('a later case is taken when the first does not match', () async {
      await executor.execute(p(), ctx(inputs: {'n': 7}));
      expect(ran(), ['t_mid']);
    });

    test('no case: default when given', () async {
      await executor.execute(p(fallback: 'low'), ctx(inputs: {'n': 1}));
      expect(ran(), ['t_low']);
    });

    test('no case and no default: continue at the following step', () async {
      await executor.execute(
          proc([branch(), tool('next'), tool('after')]), ctx(inputs: {'n': 1}));
      expect(ran(), ['t_next', 't_after']);
    });

    test('the result names the step taken', () async {
      final r = await executor.execute(
          proc([
            branch(),
            tool('big'),
            tool('mid'),
            step('out', const StepAction(type: 'output', value: 'steps.br.result.taken')),
          ]),
          ctx(inputs: {'n': 7}));
      expect(r.output, 'mid');
    });

    test('a case that cannot be evaluated is not taken', () async {
      await executor.execute(
          proc([
            step('br',
                const StepAction(type: 'branch', cases: [
                  BranchCase(when: '1 +', goto: 'x'),
                ])),
            tool('x'),
          ]),
          ctx());
      expect(ran(), ['t_x']);
    });

    test('a jump back from a branch is refused', () async {
      expect(
          () => executor.execute(
              proc([
                tool('a'),
                step('br',
                    const StepAction(type: 'branch', cases: [
                      BranchCase(when: 'true', goto: 'a'),
                    ])),
              ]),
              ctx()),
          throwsA(isA<InvalidProcedureException>()));
    });
  });

  group('output', () {
    test('a procedure without an output step returns no value', () async {
      final r = await executor.execute(proc([tool('a')]), ctx());
      expect(r.output, isNull);
    });

    test('the value is an expression', () async {
      final r = await executor.execute(
          proc([step('o', const StepAction(type: 'output', value: '1 + 2'))]),
          ctx());
      expect(r.output, 3);
    });

    test('a single interpolation keeps the type', () async {
      final r = await executor.execute(
          proc([
            step('n', const StepAction(type: 'transform', expression: '41')),
            step('o', const StepAction(type: 'output', value: r'${steps.n.result}')),
          ]),
          ctx());
      expect(r.output, 41);
    });

    test('text with interpolation is rendered', () async {
      final r = await executor.execute(
          proc([
            step('o', const StepAction(type: 'output', value: r'hello ${inputs.who}!')),
          ]),
          ctx(inputs: {'who': 'ann'}));
      expect(r.output, 'hello ann!');
    });

    test('it ends the procedure: later steps do not run', () async {
      final r = await executor.execute(
          proc([
            tool('a'),
            step('o', const StepAction(type: 'output', value: '7')),
            tool('after'),
          ]),
          ctx());
      expect(ran(), ['t_a']);
      expect(r.output, 7);
    });

    test('an output step in a branch arm ends the run', () async {
      final r = await executor.execute(
          proc([
            step('br',
                const StepAction(type: 'branch', cases: [
                  BranchCase(when: 'inputs.n > 1', goto: 'o'),
                ])),
            tool('skipped'),
            step('o', const StepAction(type: 'output', value: '"big"')),
            tool('after'),
          ]),
          ctx(inputs: {'n': 2}));
      expect(ran(), isEmpty);
      expect(r.output, 'big');
    });

    test('an empty value returns null', () async {
      final r = await executor.execute(
          proc([step('o', const StepAction(type: 'output'))]), ctx());
      expect(r.output, isNull);
    });
  });

  group('loop', () {
    ProcedureStep loop({
      String? over,
      String? whileCondition,
      int? max,
      String? as,
      required List<ProcedureStep> body,
    }) =>
        step(
          'lp',
          StepAction(
            type: 'loop',
            over: over,
            whileCondition: whileCondition,
            maxIterations: max,
            loopVariable: as,
            steps: [
              for (var i = 0; i < body.length; i++)
                ProcedureStep(
                  id: body[i].id,
                  order: i + 1,
                  name: body[i].name,
                  action: body[i].action,
                  condition: body[i].condition,
                  onSuccess: body[i].onSuccess,
                  onFailure: body[i].onFailure,
                ),
            ],
          ),
        );

    test('over: runs the body once per element', () async {
      await executor.execute(
          proc([loop(over: 'inputs.xs', body: [tool('t')])]),
          ctx(inputs: {'xs': [1, 2, 3]}));
      expect(ran(), ['t_t', 't_t', 't_t']);
    });

    test('the element and index are visible in the body', () async {
      await executor.execute(
          proc([
            loop(over: 'inputs.xs', as: 'x', body: [
              tool('t', args: {'v': r'${loop.x}', 'i': r'${loop.index}'}),
            ]),
          ]),
          ctx(inputs: {'xs': ['a', 'b']}));
      final args = [for (final c in mcp.toolCalls) c.arguments];
      expect(args, [
        {'v': 'a', 'i': 0},
        {'v': 'b', 'i': 1},
      ]);
    });

    test('the element is called item by default', () async {
      await executor.execute(
          proc([
            loop(over: 'inputs.xs', body: [
              tool('t', args: {'v': r'${loop.item}'}),
            ]),
          ]),
          ctx(inputs: {'xs': ['a']}));
      expect(mcp.toolCalls.single.arguments, {'v': 'a'});
    });

    test('the result is the last result of each iteration', () async {
      final r = await executor.execute(
          proc([
            loop(over: 'inputs.xs', body: [
              step('d', const StepAction(type: 'transform', expression: 'loop.item * 2')),
            ]),
            step('o', const StepAction(type: 'output', value: 'steps.lp.result')),
          ]),
          ctx(inputs: {'xs': [1, 2, 3]}));
      expect(r.output, [2, 4, 6]);
    });

    test('an empty list runs the body zero times', () async {
      final r = await executor.execute(
          proc([
            loop(over: 'inputs.xs', body: [tool('t')]),
            step('o', const StepAction(type: 'output', value: 'steps.lp.result')),
          ]),
          ctx(inputs: {'xs': <Object>[]}));
      expect(ran(), isEmpty);
      expect(r.output, <Object>[]);
    });

    test('over something that is not a list fails', () async {
      expect(
          () => executor.execute(
              proc([loop(over: 'inputs.xs', body: [tool('t')])]),
              ctx(inputs: {'xs': 'text'})),
          throwsA(isA<InvalidProcedureException>()));
    });

    test('over with more elements than maxIterations fails before running',
        () async {
      await expectLater(
          executor.execute(
              proc([loop(over: 'inputs.xs', max: 2, body: [tool('t')])]),
              ctx(inputs: {'xs': [1, 2, 3]})),
          throwsA(isA<InvalidProcedureException>()));
      expect(ran(), isEmpty);
    });

    test('while: repeats until the condition is false', () async {
      final r = await executor.execute(
          proc([
            loop(whileCondition: 'loop.index < 3', max: 10, body: [tool('t')]),
          ]),
          ctx());
      expect(ran(), ['t_t', 't_t', 't_t']);
      expect(r.metadata.stepsExecuted, greaterThan(0));
    });

    test('while needs maxIterations', () async {
      expect(
          () => executor.execute(
              proc([loop(whileCondition: 'true', body: [tool('t')])]), ctx()),
          throwsA(isA<InvalidProcedureException>()));
    });

    test('while that never ends stops at maxIterations with an error',
        () async {
      await expectLater(
          executor.execute(
              proc([loop(whileCondition: 'true', max: 4, body: [tool('t')])]),
              ctx()),
          throwsA(isA<InvalidProcedureException>()));
      expect(ran().length, 4);
    });

    test('the host limit caps a larger maxIterations', () async {
      final capped = ProcedureExecutor(
          ports: SkillPorts.stub().copyWith(mcp: mcp), loopLimit: 3);
      await expectLater(
          capped.execute(
              proc([loop(whileCondition: 'true', max: 100, body: [tool('t')])]),
              ctx()),
          throwsA(isA<InvalidProcedureException>()));
      expect(ran().length, 3);
    });

    test('exactly one of over and while is required', () async {
      expect(
          () => executor.execute(proc([loop(body: [tool('t')])]), ctx()),
          throwsA(isA<InvalidProcedureException>()));
      expect(
          () => executor.execute(
              proc([
                loop(over: 'inputs.xs', whileCondition: 'true', max: 2, body: [tool('t')])
              ]),
              ctx(inputs: {'xs': [1]})),
          throwsA(isA<InvalidProcedureException>()));
    });

    test('an output step in the body ends the whole procedure', () async {
      final r = await executor.execute(
          proc([
            loop(over: 'inputs.xs', body: [
              step('o', const StepAction(type: 'output', value: 'loop.item')),
            ]),
            tool('after'),
          ]),
          ctx(inputs: {'xs': [9, 8]}));
      expect(r.output, 9);
      expect(ran(), isEmpty);
    });

    test('an ended run does not follow the loop step\'s own onSuccess',
        () async {
      final lp = loop(over: 'inputs.xs', body: [
        step('o', const StepAction(type: 'output', value: '1')),
      ]);
      final r = await executor.execute(
          proc([
            ProcedureStep(
                id: lp.id,
                order: 0,
                name: lp.name,
                action: lp.action,
                onSuccess: 'nowhere'),
            tool('after'),
          ]),
          ctx(inputs: {'xs': [1]}));
      expect(r.output, 1);
      expect(ran(), isEmpty);
    });

    test('the body can read results of steps before the loop', () async {
      await executor.execute(
          proc([
            step('n', const StepAction(type: 'transform', expression: '2')),
            loop(over: 'inputs.xs', body: [
              tool('t', condition: 'steps.n.result == 2'),
            ]),
          ]),
          ctx(inputs: {'xs': [1, 1]}));
      expect(ran().length, 2);
    });

    test('results inside the body do not leak to later steps', () async {
      final r = await executor.execute(
          proc([
            loop(over: 'inputs.xs', body: [
              step('inner', const StepAction(type: 'transform', expression: '1')),
            ]),
            step('o', const StepAction(type: 'output', value: 'steps.inner')),
          ]),
          ctx(inputs: {'xs': [1]}));
      expect(r.output, isNull);
    });

    test('each iteration and each nested step counts against the budget',
        () async {
      const budget = ExecutionBudget(maxSteps: 4);
      // 1 (loop) + 2 iterations * (1 iteration + 1 nested step) = 5 > 4
      await expectLater(
          executor.execute(
              proc([loop(over: 'inputs.xs', body: [tool('t')])]),
              ctx(inputs: {'xs': [1, 2]}, budget: budget)),
          throwsA(isA<BudgetExceededException>()));
    });

    test('a failing step in the body fails the loop step', () async {
      mcp.nextToolResult = ToolResult.error('x');
      expect(
          () => executor.execute(
              proc([loop(over: 'inputs.xs', body: [tool('t')])]),
              ctx(inputs: {'xs': [1]})),
          throwsA(isA<ActionExecutionException>()));
    });
  });

  group('step keys', () {
    test('template is read as prompt and tool as toolRef', () {
      final action = StepAction.fromJson(
          {'type': 'prompt', 'template': 'hi', 'tool': 'x'});
      expect(action.type, 'llm');
      expect(action.prompt, 'hi');
      expect(action.toolRef, 'x');
    });

    test('prompt wins over template', () {
      final action = StepAction.fromJson(
          {'type': 'prompt', 'prompt': 'a', 'template': 'b'});
      expect(action.prompt, 'a');
    });

    test('branch, loop and output keys round-trip', () {
      final json = {
        'type': 'loop',
        'over': 'inputs.xs',
        'as': 'x',
        'maxIterations': 5,
        'steps': [
          {
            'id': 'b',
            'name': 'b',
            'action': {
              'type': 'branch',
              'cases': [
                {'when': 'x', 'goto': 'c'}
              ],
              'default': 'd',
            },
          },
        ],
      };
      final action = StepAction.fromJson(json);
      expect(action.steps!.single.order, 1);
      final again = StepAction.fromJson(action.toJson());
      expect(again.over, 'inputs.xs');
      expect(again.loopVariable, 'x');
      expect(again.maxIterations, 5);
      expect(again.steps!.single.action.cases!.single.goto, 'c');
      expect(again.steps!.single.action.defaultTarget, 'd');
      expect(StepAction.fromJson({'type': 'output', 'value': '1'}).value, '1');
    });
  });

  group('templates', () {
    test('a template can use a real expression', () async {
      mcp.nextToolResult = ToolResult.success('ok');
      await executor.execute(
          proc([
            tool('a', args: {'v': r'${inputs.n * 2}', 'esc': r'\$1.00'}),
          ]),
          ctx(inputs: {'n': 4}));
      expect(mcp.toolCalls.single.arguments, {'v': 8, 'esc': r'$1.00'});
    });

    test('a string that is exactly one interpolation keeps its type',
        () async {
      await executor.execute(
          proc([
            tool('a', args: {
              'n': r'${inputs.n}',
              'flag': r'${inputs.flag}',
              'list': r'${inputs.xs}',
              'map': r'${inputs.m}',
            }),
          ]),
          ctx(inputs: {
            'n': 3,
            'flag': true,
            'xs': [1, 2],
            'm': {'k': 'v'},
          }));
      expect(mcp.toolCalls.single.arguments, {
        'n': 3,
        'flag': true,
        'list': [1, 2],
        'map': {'k': 'v'},
      });
    });

    test('text around an interpolation makes the whole value text', () async {
      await executor.execute(
          proc([tool('a', args: {'v': r'n=${inputs.n}', 'w': r' ${inputs.n}'})]),
          ctx(inputs: {'n': 3}));
      expect(mcp.toolCalls.single.arguments, {'v': 'n=3', 'w': ' 3'});
    });

    test('elements of a list are rendered, at any depth', () async {
      await executor.execute(
          proc([
            tool('a', args: {
              'list': [r'${inputs.x}', 'plain', r'id-${inputs.x}', 7],
              'deep': {
                'rows': [
                  {'v': r'${inputs.x}'},
                  [r'${inputs.x}'],
                ],
              },
            }),
          ]),
          ctx(inputs: {'x': 5}));
      expect(mcp.toolCalls.single.arguments, {
        'list': [5, 'plain', 'id-5', 7],
        'deep': {
          'rows': [
            {'v': 5},
            [5],
          ],
        },
      });
    });

    test('a single interpolation that fails becomes the empty string',
        () async {
      await executor.execute(
          proc([tool('a', args: {'v': r'${1 +}'})]), ctx());
      expect(mcp.toolCalls.single.arguments, {'v': ''});
    });

    test('a missing value renders as the empty string', () async {
      await executor.execute(
          proc([tool('a', args: {'v': r'[${inputs.nope}]'})]), ctx());
      expect(mcp.toolCalls.single.arguments, {'v': '[]'});
    });

    test('an earlier step result is read as steps.<id>.result', () async {
      await executor.execute(
          proc([
            step('n', const StepAction(type: 'transform', expression: '"x"')),
            tool('a', args: {'v': r'${steps.n.result}'}),
          ]),
          ctx());
      expect(mcp.toolCalls.single.arguments, {'v': 'x'});
    });
  });
}
