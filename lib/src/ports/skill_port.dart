/// Skill Port - Abstract interfaces for skill operations.
///
/// Defines contracts for skill loading, storage, and execution.
library;

import '../definition/skill.dart';

/// Port for skill storage operations.
abstract class SkillStoragePort {
  /// Save a skill.
  Future<void> saveSkill(Skill skill);

  /// Get skill by ID.
  Future<Skill?> getSkill(String skillId);

  /// Get all skills.
  Future<List<Skill>> getAllSkills();

  /// Delete skill.
  Future<void> deleteSkill(String skillId);

  /// Get skills by tag.
  Future<List<Skill>> getSkillsByTag(String tag);

  /// Search skills by name or description.
  Future<List<Skill>> searchSkills(String query);
}

/// Port for skill execution.
abstract class SkillExecutionPort {
  /// Execute a skill with inputs.
  Future<SkillExecutionResult> execute(
    String skillId,
    Map<String, dynamic> inputs,
  );

  /// Check if skill is available.
  Future<bool> isAvailable(String skillId);

  /// Cancel execution.
  Future<void> cancel(String executionId);
}

/// Skill execution result.
class SkillExecutionResult {
  /// Execution ID.
  final String executionId;

  /// Skill ID.
  final String skillId;

  /// Whether execution succeeded.
  final bool success;

  /// Output value.
  final dynamic output;

  /// Error message if failed.
  final String? error;

  /// Execution duration.
  final Duration duration;

  /// Step results.
  final Map<String, dynamic> stepResults;

  const SkillExecutionResult({
    required this.executionId,
    required this.skillId,
    required this.success,
    this.output,
    this.error,
    required this.duration,
    this.stepResults = const {},
  });

  /// Create success result.
  factory SkillExecutionResult.success({
    required String executionId,
    required String skillId,
    required dynamic output,
    required Duration duration,
    Map<String, dynamic>? stepResults,
  }) {
    return SkillExecutionResult(
      executionId: executionId,
      skillId: skillId,
      success: true,
      output: output,
      duration: duration,
      stepResults: stepResults ?? const {},
    );
  }

  /// Create failure result.
  factory SkillExecutionResult.failure({
    required String executionId,
    required String skillId,
    required String error,
    required Duration duration,
    Map<String, dynamic>? stepResults,
  }) {
    return SkillExecutionResult(
      executionId: executionId,
      skillId: skillId,
      success: false,
      error: error,
      duration: duration,
      stepResults: stepResults ?? const {},
    );
  }
}

/// Port for external action handlers.
abstract class ActionHandlerPort {
  /// Handle an action.
  Future<dynamic> handle(
    String actionName,
    Map<String, dynamic> args,
    ActionContext context,
  );

  /// Get supported actions.
  List<String> get supportedActions;
}

/// Context for action execution.
class ActionContext {
  /// Execution ID.
  final String executionId;

  /// Skill ID.
  final String skillId;

  /// Step ID.
  final String stepId;

  /// Variables from execution context.
  final Map<String, dynamic> variables;

  /// Inputs from execution context.
  final Map<String, dynamic> inputs;

  const ActionContext({
    required this.executionId,
    required this.skillId,
    required this.stepId,
    this.variables = const {},
    this.inputs = const {},
  });
}

/// Port for LLM operations in skills.
abstract class SkillLlmPort {
  /// Complete a prompt.
  Future<LlmResult> complete(SkillLlmRequest request);

  /// Generate embeddings.
  Future<List<double>> embed(String text);
}

/// LLM request for skill operations.
class SkillLlmRequest {
  /// System prompt.
  final String? systemPrompt;

  /// User prompt.
  final String prompt;

  /// Maximum tokens.
  final int? maxTokens;

  /// Temperature.
  final double? temperature;

  /// Additional options.
  final Map<String, dynamic>? options;

  const SkillLlmRequest({
    this.systemPrompt,
    required this.prompt,
    this.maxTokens,
    this.temperature,
    this.options,
  });
}

/// LLM result.
class LlmResult {
  /// Response content.
  final String content;

  /// Token usage.
  final int? tokensUsed;

  const LlmResult({
    required this.content,
    this.tokensUsed,
  });
}
