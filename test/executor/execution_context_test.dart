import 'package:test/test.dart';
import 'package:mcp_skill/src/executor/execution_context.dart';

void main() {
  group('ExecutionContext', () {
    test('constructor creates empty context', () {
      final context = ExecutionContext();

      expect(context.inputs, isEmpty);
      expect(context.variables, isEmpty);
      expect(context.stepResults, isEmpty);
    });

    test('constructor accepts initial inputs', () {
      final context = ExecutionContext(
        inputs: {'key': 'value', 'num': 42},
      );

      expect(context.inputs, equals({'key': 'value', 'num': 42}));
      expect(context.getInput('key'), equals('value'));
      expect(context.getInput('num'), equals(42));
      expect(context.getInput('missing'), isNull);
    });

    test('inputs are unmodifiable', () {
      final context = ExecutionContext(inputs: {'key': 'value'});

      expect(
        () => context.inputs['new'] = 'val',
        throwsUnsupportedError,
      );
    });

    test('setVariable and getVariable work correctly', () {
      final context = ExecutionContext();

      context.setVariable('var1', 'value1');
      context.setVariable('var2', 42);

      expect(context.getVariable('var1'), equals('value1'));
      expect(context.getVariable('var2'), equals(42));
      expect(context.getVariable('missing'), isNull);
    });

    test('hasVariable returns correct value', () {
      final context = ExecutionContext();

      context.setVariable('exists', 'value');

      expect(context.hasVariable('exists'), isTrue);
      expect(context.hasVariable('missing'), isFalse);
    });

    test('variables getter returns all variables', () {
      final context = ExecutionContext();

      context.setVariable('var1', 'value1');
      context.setVariable('var2', 'value2');

      final vars = context.variables;
      expect(vars, equals({'var1': 'value1', 'var2': 'value2'}));
    });

    test('setStepResult and getStepResult work correctly', () {
      final context = ExecutionContext();

      context.setStepResult('step1', {'output': 'result1'});
      context.setStepResult('step2', 42);

      expect(context.getStepResult('step1'), equals({'output': 'result1'}));
      expect(context.getStepResult('step2'), equals(42));
      expect(context.getStepResult('missing'), isNull);
    });

    test('stepResults are unmodifiable', () {
      final context = ExecutionContext();
      context.setStepResult('step1', 'result');

      expect(
        () => context.stepResults['new'] = 'val',
        throwsUnsupportedError,
      );
    });

    test('child creates child context with parent', () {
      final parent = ExecutionContext(inputs: {'key': 'value'});
      parent.setVariable('parentVar', 'parentValue');

      final child = parent.child({'childVar': 'childValue'});

      // Child has access to parent inputs
      expect(child.getInput('key'), equals('value'));

      // Child has access to parent variables
      expect(child.getVariable('parentVar'), equals('parentValue'));

      // Child has its own variables
      expect(child.getVariable('childVar'), equals('childValue'));
    });

    test('child variable shadows parent variable', () {
      final parent = ExecutionContext();
      parent.setVariable('shared', 'parentValue');

      final child = parent.child({'shared': 'childValue'});

      // Child value shadows parent
      expect(child.getVariable('shared'), equals('childValue'));

      // Parent unchanged
      expect(parent.getVariable('shared'), equals('parentValue'));
    });

    test('hasVariable checks parent context', () {
      final parent = ExecutionContext();
      parent.setVariable('parentVar', 'value');

      final child = parent.child();

      expect(child.hasVariable('parentVar'), isTrue);
      expect(child.hasVariable('missing'), isFalse);
    });

    test('variables getter includes parent variables', () {
      final parent = ExecutionContext();
      parent.setVariable('parentVar', 'parentValue');

      final child = parent.child({'childVar': 'childValue'});
      child.setVariable('addedVar', 'addedValue');

      final vars = child.variables;
      expect(vars['parentVar'], equals('parentValue'));
      expect(vars['childVar'], equals('childValue'));
      expect(vars['addedVar'], equals('addedValue'));
    });

    test('toMap returns context as map', () {
      final context = ExecutionContext(inputs: {'input1': 'val1'});
      context.setVariable('var1', 'varVal1');
      context.setStepResult('step1', 'result1');

      final map = context.toMap();

      expect(map['inputs'], equals({'input1': 'val1'}));
      expect(map['variables'], equals({'var1': 'varVal1'}));
      expect(map['steps'], equals({'step1': 'result1'}));
    });
  });

  group('ExecutionResult', () {
    test('constructor creates instance with required fields', () {
      final result = ExecutionResult(
        success: true,
        output: 'test output',
      );

      expect(result.success, isTrue);
      expect(result.output, equals('test output'));
      expect(result.error, isNull);
      expect(result.stepResults, isEmpty);
      expect(result.duration, isNull);
    });

    test('constructor creates instance with all fields', () {
      final result = ExecutionResult(
        success: false,
        error: 'Error occurred',
        stepResults: {'step1': 'result1'},
        duration: const Duration(seconds: 5),
      );

      expect(result.success, isFalse);
      expect(result.output, isNull);
      expect(result.error, equals('Error occurred'));
      expect(result.stepResults, equals({'step1': 'result1'}));
      expect(result.duration, equals(const Duration(seconds: 5)));
    });

    test('success factory creates success result', () {
      final result = ExecutionResult.success(
        'output value',
        stepResults: {'step1': 'res1'},
        duration: const Duration(milliseconds: 500),
      );

      expect(result.success, isTrue);
      expect(result.output, equals('output value'));
      expect(result.error, isNull);
      expect(result.stepResults, equals({'step1': 'res1'}));
      expect(result.duration, equals(const Duration(milliseconds: 500)));
    });

    test('success factory with minimal args', () {
      final result = ExecutionResult.success('output');

      expect(result.success, isTrue);
      expect(result.output, equals('output'));
      expect(result.stepResults, isEmpty);
      expect(result.duration, isNull);
    });

    test('failure factory creates failure result', () {
      final result = ExecutionResult.failure(
        'Something went wrong',
        stepResults: {'step1': 'partial'},
        duration: const Duration(seconds: 2),
      );

      expect(result.success, isFalse);
      expect(result.output, isNull);
      expect(result.error, equals('Something went wrong'));
      expect(result.stepResults, equals({'step1': 'partial'}));
      expect(result.duration, equals(const Duration(seconds: 2)));
    });

    test('failure factory with minimal args', () {
      final result = ExecutionResult.failure('Error');

      expect(result.success, isFalse);
      expect(result.error, equals('Error'));
      expect(result.stepResults, isEmpty);
      expect(result.duration, isNull);
    });

    test('toString for success result', () {
      final result = ExecutionResult.success('output value');

      final str = result.toString();
      expect(str, contains('success'));
      expect(str, contains('output value'));
    });

    test('toString for failure result', () {
      final result = ExecutionResult.failure('Error message');

      final str = result.toString();
      expect(str, contains('failure'));
      expect(str, contains('Error message'));
    });
  });

  group('ExecutionTrace', () {
    test('constructor creates empty trace', () {
      final trace = ExecutionTrace();

      expect(trace.entries, isEmpty);
    });

    test('add appends entry to trace', () {
      final trace = ExecutionTrace();
      final entry = TraceEntry(
        stepId: 'step1',
        type: TraceType.start,
        timestamp: DateTime.now(),
      );

      trace.add(entry);

      expect(trace.entries, hasLength(1));
      expect(trace.entries.first.stepId, equals('step1'));
    });

    test('entries are unmodifiable', () {
      final trace = ExecutionTrace();

      expect(
        () => trace.entries.add(TraceEntry(
          stepId: 'step',
          type: TraceType.start,
          timestamp: DateTime.now(),
        )),
        throwsUnsupportedError,
      );
    });

    test('clear removes all entries', () {
      final trace = ExecutionTrace();
      trace.add(TraceEntry(
        stepId: 'step1',
        type: TraceType.start,
        timestamp: DateTime.now(),
      ));
      trace.add(TraceEntry(
        stepId: 'step2',
        type: TraceType.complete,
        timestamp: DateTime.now(),
      ));

      expect(trace.entries, hasLength(2));

      trace.clear();

      expect(trace.entries, isEmpty);
    });
  });

  group('TraceEntry', () {
    test('constructor creates instance with required fields', () {
      final timestamp = DateTime(2024, 1, 15);
      final entry = TraceEntry(
        stepId: 'step1',
        type: TraceType.start,
        timestamp: timestamp,
      );

      expect(entry.stepId, equals('step1'));
      expect(entry.type, equals(TraceType.start));
      expect(entry.timestamp, equals(timestamp));
      expect(entry.input, isNull);
      expect(entry.output, isNull);
      expect(entry.error, isNull);
      expect(entry.duration, isNull);
    });

    test('constructor creates instance with all fields', () {
      final timestamp = DateTime(2024, 1, 15);
      final entry = TraceEntry(
        stepId: 'step1',
        type: TraceType.complete,
        timestamp: timestamp,
        input: {'key': 'inputVal'},
        output: {'key': 'outputVal'},
        error: 'Error message',
        duration: const Duration(seconds: 2),
      );

      expect(entry.input, equals({'key': 'inputVal'}));
      expect(entry.output, equals({'key': 'outputVal'}));
      expect(entry.error, equals('Error message'));
      expect(entry.duration, equals(const Duration(seconds: 2)));
    });
  });

  group('TraceType', () {
    test('has all expected values', () {
      expect(TraceType.values, contains(TraceType.start));
      expect(TraceType.values, contains(TraceType.complete));
      expect(TraceType.values, contains(TraceType.error));
      expect(TraceType.values, contains(TraceType.skip));
    });
  });
}
