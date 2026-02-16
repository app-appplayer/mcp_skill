/// Execution context for skill execution.
library;

/// Context for skill execution containing variables and state.
class ExecutionContext {
  ExecutionContext({
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? variables,
    ExecutionContext? parent,
  })  : _inputs = inputs ?? {},
        _variables = variables ?? {},
        _parent = parent;

  final Map<String, dynamic> _inputs;
  final Map<String, dynamic> _variables;
  final ExecutionContext? _parent;
  final Map<String, dynamic> _stepResults = {};

  /// Get an input value.
  dynamic getInput(String name) => _inputs[name];

  /// Get all inputs.
  Map<String, dynamic> get inputs => Map.unmodifiable(_inputs);

  /// Get a variable value.
  dynamic getVariable(String name) {
    if (_variables.containsKey(name)) {
      return _variables[name];
    }
    final parent = _parent;
    if (parent != null) {
      return parent.getVariable(name);
    }
    return null;
  }

  /// Set a variable value.
  void setVariable(String name, dynamic value) {
    _variables[name] = value;
  }

  /// Check if a variable exists.
  bool hasVariable(String name) {
    if (_variables.containsKey(name)) return true;
    final parent = _parent;
    if (parent != null) {
      return parent.hasVariable(name);
    }
    return false;
  }

  /// Get all variables.
  Map<String, dynamic> get variables {
    final result = <String, dynamic>{};
    final parent = _parent;
    if (parent != null) {
      result.addAll(parent.variables);
    }
    result.addAll(_variables);
    return result;
  }

  /// Set a step result.
  void setStepResult(String stepId, dynamic result) {
    _stepResults[stepId] = result;
  }

  /// Get a step result.
  dynamic getStepResult(String stepId) => _stepResults[stepId];

  /// Get all step results.
  Map<String, dynamic> get stepResults => Map.unmodifiable(_stepResults);

  /// Create a child context.
  ExecutionContext child([Map<String, dynamic>? additionalVars]) {
    return ExecutionContext(
      inputs: _inputs,
      variables: additionalVars,
      parent: this,
    );
  }

  /// Convert to map for expression evaluation.
  Map<String, dynamic> toMap() => {
        'inputs': inputs,
        'variables': variables,
        'steps': stepResults,
      };
}

/// Result of skill execution.
class ExecutionResult {
  ExecutionResult({
    required this.success,
    this.output,
    this.error,
    this.stepResults = const {},
    this.duration,
  });

  /// Whether execution succeeded.
  final bool success;

  /// Output value.
  final dynamic output;

  /// Error message if failed.
  final String? error;

  /// Results from each step.
  final Map<String, dynamic> stepResults;

  /// Execution duration.
  final Duration? duration;

  /// Create a success result.
  factory ExecutionResult.success(dynamic output, {
    Map<String, dynamic>? stepResults,
    Duration? duration,
  }) {
    return ExecutionResult(
      success: true,
      output: output,
      stepResults: stepResults ?? {},
      duration: duration,
    );
  }

  /// Create a failure result.
  factory ExecutionResult.failure(String error, {
    Map<String, dynamic>? stepResults,
    Duration? duration,
  }) {
    return ExecutionResult(
      success: false,
      error: error,
      stepResults: stepResults ?? {},
      duration: duration,
    );
  }

  @override
  String toString() => success
      ? 'ExecutionResult.success($output)'
      : 'ExecutionResult.failure($error)';
}

/// Execution trace for debugging.
class ExecutionTrace {
  ExecutionTrace();

  final List<TraceEntry> _entries = [];

  /// Add a trace entry.
  void add(TraceEntry entry) => _entries.add(entry);

  /// Get all entries.
  List<TraceEntry> get entries => List.unmodifiable(_entries);

  /// Clear trace.
  void clear() => _entries.clear();
}

/// A single trace entry.
class TraceEntry {
  TraceEntry({
    required this.stepId,
    required this.type,
    required this.timestamp,
    this.input,
    this.output,
    this.error,
    this.duration,
  });

  /// Step ID.
  final String stepId;

  /// Entry type.
  final TraceType type;

  /// Timestamp.
  final DateTime timestamp;

  /// Input data.
  final dynamic input;

  /// Output data.
  final dynamic output;

  /// Error if any.
  final String? error;

  /// Duration if completed.
  final Duration? duration;
}

/// Trace entry types.
enum TraceType {
  /// Step started.
  start,

  /// Step completed.
  complete,

  /// Step failed.
  error,

  /// Step skipped.
  skip,
}
