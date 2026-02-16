/// Skill Runtime - Runtime management for skill execution.
///
/// Provides runtime services for managing skill execution lifecycle.
library;

import '../definition/skill.dart';
import '../executor/skill_executor.dart';
import '../ports/skill_port.dart';
import '../bundle/skill_bundle.dart';

/// Runtime for skill execution.
class SkillRuntime {
  /// Skill storage port.
  final SkillStoragePort? _storage;

  /// Skill executor.
  final SkillExecutor _executor;

  /// Active executions.
  final Map<String, SkillExecution> _activeExecutions = {};

  /// Execution history.
  final List<ExecutionRecord> _history = [];

  /// Maximum history size.
  final int maxHistorySize;

  SkillRuntime({
    SkillStoragePort? storage,
    SkillExecutor? executor,
    this.maxHistorySize = 1000,
  })  : _storage = storage,
        _executor = executor ?? SkillExecutor();

  /// Load skills from bundle.
  Future<void> loadBundle(SkillBundle bundle) async {
    if (_storage == null) return;

    for (final skill in bundle.skills) {
      await _storage!.saveSkill(skill);
    }
  }

  /// Execute a skill by ID.
  Future<SkillExecutionResult> execute(
    String skillId,
    Map<String, dynamic> inputs, {
    String? executionId,
  }) async {
    final skill = await _getSkill(skillId);
    if (skill == null) {
      return SkillExecutionResult.failure(
        executionId: executionId ?? _generateId(),
        skillId: skillId,
        error: 'Skill not found: $skillId',
        duration: Duration.zero,
      );
    }

    return executeSkill(skill, inputs, executionId: executionId);
  }

  /// Execute a skill directly.
  Future<SkillExecutionResult> executeSkill(
    Skill skill,
    Map<String, dynamic> inputs, {
    String? executionId,
  }) async {
    final execId = executionId ?? _generateId();
    final startTime = DateTime.now();

    // Create execution record
    final execution = SkillExecution(
      executionId: execId,
      skillId: skill.id,
      inputs: inputs,
      startedAt: startTime,
      status: ExecutionStatus.running,
    );
    _activeExecutions[execId] = execution;

    try {
      // Execute skill
      final result = await _executor.execute(skill, inputs);

      final duration = DateTime.now().difference(startTime);

      // Create result
      final execResult = result.success
          ? SkillExecutionResult.success(
              executionId: execId,
              skillId: skill.id,
              output: result.output,
              duration: duration,
              stepResults: result.stepResults,
            )
          : SkillExecutionResult.failure(
              executionId: execId,
              skillId: skill.id,
              error: result.error ?? 'Unknown error',
              duration: duration,
              stepResults: result.stepResults,
            );

      // Record history
      _recordExecution(execution.copyWith(
        status: result.success
            ? ExecutionStatus.completed
            : ExecutionStatus.failed,
        completedAt: DateTime.now(),
        result: execResult,
      ));

      return execResult;
    } catch (e) {
      final duration = DateTime.now().difference(startTime);

      final execResult = SkillExecutionResult.failure(
        executionId: execId,
        skillId: skill.id,
        error: e.toString(),
        duration: duration,
      );

      _recordExecution(execution.copyWith(
        status: ExecutionStatus.failed,
        completedAt: DateTime.now(),
        error: e.toString(),
      ));

      return execResult;
    } finally {
      _activeExecutions.remove(execId);
    }
  }

  /// Get active executions.
  List<SkillExecution> get activeExecutions => _activeExecutions.values.toList();

  /// Get execution history.
  List<ExecutionRecord> get history => List.unmodifiable(_history);

  /// Get execution by ID.
  SkillExecution? getExecution(String executionId) {
    return _activeExecutions[executionId];
  }

  /// Cancel execution.
  Future<bool> cancel(String executionId) async {
    final execution = _activeExecutions[executionId];
    if (execution == null) return false;

    _activeExecutions.remove(executionId);
    _recordExecution(execution.copyWith(
      status: ExecutionStatus.cancelled,
      completedAt: DateTime.now(),
    ));

    return true;
  }

  /// Clear history.
  void clearHistory() {
    _history.clear();
  }

  Future<Skill?> _getSkill(String skillId) async {
    return _storage?.getSkill(skillId);
  }

  void _recordExecution(SkillExecution execution) {
    _history.add(ExecutionRecord(
      executionId: execution.executionId,
      skillId: execution.skillId,
      status: execution.status,
      startedAt: execution.startedAt,
      completedAt: execution.completedAt,
      duration: execution.completedAt?.difference(execution.startedAt),
      error: execution.error,
    ));

    // Trim history
    while (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
  }

  String _generateId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode.abs() % 10000;
    return 'exec_${timestamp}_$random';
  }
}

/// Active skill execution.
class SkillExecution {
  /// Execution ID.
  final String executionId;

  /// Skill ID.
  final String skillId;

  /// Input values.
  final Map<String, dynamic> inputs;

  /// When execution started.
  final DateTime startedAt;

  /// When execution completed.
  final DateTime? completedAt;

  /// Execution status.
  final ExecutionStatus status;

  /// Execution result.
  final SkillExecutionResult? result;

  /// Error message.
  final String? error;

  const SkillExecution({
    required this.executionId,
    required this.skillId,
    required this.inputs,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.result,
    this.error,
  });

  SkillExecution copyWith({
    String? executionId,
    String? skillId,
    Map<String, dynamic>? inputs,
    DateTime? startedAt,
    DateTime? completedAt,
    ExecutionStatus? status,
    SkillExecutionResult? result,
    String? error,
  }) {
    return SkillExecution(
      executionId: executionId ?? this.executionId,
      skillId: skillId ?? this.skillId,
      inputs: inputs ?? this.inputs,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

/// Execution status.
enum ExecutionStatus {
  /// Pending execution.
  pending,

  /// Running.
  running,

  /// Completed successfully.
  completed,

  /// Failed.
  failed,

  /// Cancelled.
  cancelled,
}

/// Record of past execution.
class ExecutionRecord {
  /// Execution ID.
  final String executionId;

  /// Skill ID.
  final String skillId;

  /// Execution status.
  final ExecutionStatus status;

  /// When execution started.
  final DateTime startedAt;

  /// When execution completed.
  final DateTime? completedAt;

  /// Duration.
  final Duration? duration;

  /// Error message if failed.
  final String? error;

  const ExecutionRecord({
    required this.executionId,
    required this.skillId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.duration,
    this.error,
  });
}
