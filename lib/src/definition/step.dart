/// Step definitions - Procedure execution steps and legacy skill steps.
///
/// Contains two step models:
/// - [Step] / [StepAction]: Runtime execution schema (docs/spec/04-execution-schema.md)
/// - [SkillStep]: Legacy definition layer model (used by Skill and SkillExecutor)
library;

// ============================================================================
// Step (Runtime Execution Schema)
// ============================================================================

/// A step in a procedure execution flow.
class Step {
  /// Step identifier (unique within procedure).
  final String id;

  /// Execution order.
  final int order;

  /// Step name.
  final String name;

  /// Step description.
  final String? description;

  /// Action configuration.
  final StepAction action;

  // === CONTROL FLOW ===
  /// Condition expression for conditional execution.
  final String? condition;

  /// Next step ID on success.
  final String? onSuccess;

  /// Next step ID on failure.
  final String? onFailure;

  /// Retry configuration.
  final RetryConfig? retryConfig;

  /// Timeout in milliseconds.
  final int? timeout;

  const Step({
    required this.id,
    required this.order,
    required this.name,
    this.description,
    required this.action,
    this.condition,
    this.onSuccess,
    this.onFailure,
    this.retryConfig,
    this.timeout,
  });

  /// Create from JSON.
  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      id: json['id'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      action: StepAction.fromJson(json['action'] as Map<String, dynamic>? ?? {}),
      condition: json['condition'] as String?,
      onSuccess: json['onSuccess'] as String?,
      onFailure: json['onFailure'] as String?,
      retryConfig: json['retryConfig'] != null
          ? RetryConfig.fromJson(json['retryConfig'] as Map<String, dynamic>)
          : null,
      timeout: json['timeout'] as int?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'name': name,
        if (description != null) 'description': description,
        'action': action.toJson(),
        if (condition != null) 'condition': condition,
        if (onSuccess != null) 'onSuccess': onSuccess,
        if (onFailure != null) 'onFailure': onFailure,
        if (retryConfig != null) 'retryConfig': retryConfig!.toJson(),
        if (timeout != null) 'timeout': timeout,
      };

  @override
  String toString() => 'Step($id: ${action.type})';
}

/// Step action configuration.
class StepAction {
  /// Action type (llm, tool, retrieve, transform, validate, rubric, ui, procedure, parallel, custom).
  final String type;

  // === LLM ACTION ===
  /// LLM prompt template.
  final String? prompt;

  /// LLM model name.
  final String? model;

  /// Temperature for LLM.
  final double? temperature;

  /// Max tokens for LLM.
  final int? maxTokens;

  /// System prompt for LLM.
  final String? systemPrompt;

  /// MCP tool names to enable for LLM.
  final List<String>? tools;

  // === TOOL ACTION ===
  /// Tool reference (serverId/toolName or toolName).
  final String? toolRef;

  /// Tool arguments.
  final Map<String, dynamic>? args;

  // === RETRIEVE ACTION ===
  /// Retriever reference.
  final String? retrieverRef;

  /// Query expression.
  final String? query;

  /// Filters for retrieval.
  final Map<String, dynamic>? filters;

  /// Maximum results.
  final int? maxResults;

  // === TRANSFORM ACTION ===
  /// Transform expression.
  final String? expression;

  // === VALIDATE ACTION ===
  /// Validator reference.
  final String? validatorRef;

  /// Input to validate.
  final String? input;

  // === RUBRIC ACTION ===
  /// Rubric reference.
  final String? rubricRef;

  /// Evaluation input.
  final Map<String, dynamic>? evaluationInput;

  // === UI ACTION ===
  /// Screen reference.
  final String? screenRef;

  /// Wait for user input.
  final bool? waitForInput;

  /// Input mapping.
  final Map<String, String>? inputMapping;

  // === PROCEDURE ACTION ===
  /// Procedure reference (skillId/procedureId or procedureId).
  final String? procedureRef;

  /// Procedure inputs.
  final Map<String, dynamic>? procedureInputs;

  // === PARALLEL ACTION ===
  /// Parallel actions.
  final List<StepAction>? parallel;

  // === CUSTOM ACTION ===
  /// Custom action type.
  final String? customType;

  /// Custom configuration.
  final Map<String, dynamic>? config;

  const StepAction({
    required this.type,
    this.prompt,
    this.model,
    this.temperature,
    this.maxTokens,
    this.systemPrompt,
    this.tools,
    this.toolRef,
    this.args,
    this.retrieverRef,
    this.query,
    this.filters,
    this.maxResults,
    this.expression,
    this.validatorRef,
    this.input,
    this.rubricRef,
    this.evaluationInput,
    this.screenRef,
    this.waitForInput,
    this.inputMapping,
    this.procedureRef,
    this.procedureInputs,
    this.parallel,
    this.customType,
    this.config,
  });

  /// Create from JSON.
  factory StepAction.fromJson(Map<String, dynamic> json) {
    return StepAction(
      type: json['type'] as String? ?? 'llm',
      prompt: json['prompt'] as String?,
      model: json['model'] as String?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxTokens: json['maxTokens'] as int?,
      systemPrompt: json['systemPrompt'] as String?,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>(),
      toolRef: json['toolRef'] as String?,
      args: json['args'] as Map<String, dynamic>?,
      retrieverRef: json['retrieverRef'] as String?,
      query: json['query'] as String?,
      filters: json['filters'] as Map<String, dynamic>?,
      maxResults: json['maxResults'] as int?,
      expression: json['expression'] as String?,
      validatorRef: json['validatorRef'] as String?,
      input: json['input'] as String?,
      rubricRef: json['rubricRef'] as String?,
      evaluationInput: json['evaluationInput'] as Map<String, dynamic>?,
      screenRef: json['screenRef'] as String?,
      waitForInput: json['waitForInput'] as bool?,
      inputMapping: (json['inputMapping'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v.toString())),
      procedureRef: json['procedureRef'] as String?,
      procedureInputs: json['procedureInputs'] as Map<String, dynamic>?,
      parallel: (json['parallel'] as List<dynamic>?)
          ?.map((e) => StepAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      customType: json['customType'] as String?,
      config: json['config'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'type': type,
        if (prompt != null) 'prompt': prompt,
        if (model != null) 'model': model,
        if (temperature != null) 'temperature': temperature,
        if (maxTokens != null) 'maxTokens': maxTokens,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        if (tools != null) 'tools': tools,
        if (toolRef != null) 'toolRef': toolRef,
        if (args != null) 'args': args,
        if (retrieverRef != null) 'retrieverRef': retrieverRef,
        if (query != null) 'query': query,
        if (filters != null) 'filters': filters,
        if (maxResults != null) 'maxResults': maxResults,
        if (expression != null) 'expression': expression,
        if (validatorRef != null) 'validatorRef': validatorRef,
        if (input != null) 'input': input,
        if (rubricRef != null) 'rubricRef': rubricRef,
        if (evaluationInput != null) 'evaluationInput': evaluationInput,
        if (screenRef != null) 'screenRef': screenRef,
        if (waitForInput != null) 'waitForInput': waitForInput,
        if (inputMapping != null) 'inputMapping': inputMapping,
        if (procedureRef != null) 'procedureRef': procedureRef,
        if (procedureInputs != null) 'procedureInputs': procedureInputs,
        if (parallel != null)
          'parallel': parallel!.map((e) => e.toJson()).toList(),
        if (customType != null) 'customType': customType,
        if (config != null) 'config': config,
      };

  @override
  String toString() => 'StepAction($type)';
}

// ============================================================================
// Step Type Enum (unified)
// ============================================================================

/// Step type enum matching action types.
///
/// Contains both runtime step types (llm, tool, retrieve, etc.) and
/// legacy definition step types (action, setVar, output, etc.).
enum StepType {
  // Runtime step types (from execution schema)
  llm,
  tool,
  retrieve,
  validate,
  rubric,
  ui,
  procedure,
  custom,

  // Legacy step types (from definition layer)
  action,
  condition,
  loop,
  wait,
  call,
  setVar,
  output,
  log,
  http,

  // Shared between both models
  transform,
  parallel,
  unknown;

  static StepType fromString(String value) {
    return StepType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StepType.unknown,
    );
  }
}

/// Step action type constants.
class ActionType {
  static const String llm = 'llm';
  static const String tool = 'tool';
  static const String retrieve = 'retrieve';
  static const String transform = 'transform';
  static const String validate = 'validate';
  static const String rubric = 'rubric';
  static const String ui = 'ui';
  static const String procedure = 'procedure';
  static const String parallel = 'parallel';
  static const String custom = 'custom';

  static const List<String> all = [
    llm, tool, retrieve, transform, validate,
    rubric, ui, procedure, parallel, custom,
  ];

  static bool isValid(String type) => all.contains(type);
}

// ============================================================================
// Retry Configuration
// ============================================================================

/// Retry configuration for step execution.
class RetryConfig {
  /// Maximum number of retries.
  final int maxRetries;

  /// Initial delay in milliseconds.
  final int initialDelay;

  /// Maximum delay in milliseconds.
  final int? maxDelay;

  /// Backoff multiplier (default 2.0).
  final double? backoffMultiplier;

  /// Whether to use jitter (default true).
  final bool? jitter;

  const RetryConfig({
    required this.maxRetries,
    required this.initialDelay,
    this.maxDelay,
    this.backoffMultiplier,
    this.jitter,
  });

  /// Create from JSON.
  factory RetryConfig.fromJson(Map<String, dynamic> json) {
    return RetryConfig(
      maxRetries: json['maxRetries'] as int? ?? 0,
      initialDelay: json['initialDelay'] as int? ?? 1000,
      maxDelay: json['maxDelay'] as int?,
      backoffMultiplier: (json['backoffMultiplier'] as num?)?.toDouble(),
      jitter: json['jitter'] as bool?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'maxRetries': maxRetries,
        'initialDelay': initialDelay,
        if (maxDelay != null) 'maxDelay': maxDelay,
        if (backoffMultiplier != null) 'backoffMultiplier': backoffMultiplier,
        if (jitter != null) 'jitter': jitter,
      };

  @override
  String toString() =>
      'RetryConfig(maxRetries: $maxRetries, initialDelay: ${initialDelay}ms)';
}

// ============================================================================
// SkillStep (Legacy Definition Layer Model)
// ============================================================================

/// A step in a skill definition (legacy model).
///
/// Used by [Skill] and [SkillExecutor] for simple step-based execution.
/// For runtime procedure execution, see [Step] and [StepAction] above.
class SkillStep {
  /// Step identifier.
  final String id;

  /// Step type.
  final StepType type;

  /// Human-readable name.
  final String? name;

  /// Step configuration.
  final Map<String, dynamic> config;

  /// Condition expression for conditional execution.
  final String? condition;

  /// Next step IDs.
  final List<String> next;

  /// Error handler step ID.
  final String? onError;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  const SkillStep({
    required this.id,
    required this.type,
    this.name,
    this.config = const {},
    this.condition,
    this.next = const [],
    this.onError,
    this.metadata = const {},
  });

  /// Get a config value by key.
  dynamic getConfig(String key) => config[key];

  /// Check if a config key exists.
  bool hasConfig(String key) => config.containsKey(key);

  /// Create from JSON.
  factory SkillStep.fromJson(Map<String, dynamic> json) {
    return SkillStep(
      id: json['id'] as String? ?? '',
      type: StepType.fromString(json['type'] as String? ?? 'action'),
      name: json['name'] as String?,
      config: json['config'] as Map<String, dynamic>? ?? {},
      condition: json['condition'] as String?,
      next: (json['next'] as List<dynamic>?)?.cast<String>() ?? [],
      onError: json['onError'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        if (name != null) 'name': name,
        if (config.isNotEmpty) 'config': config,
        if (condition != null) 'condition': condition,
        if (next.isNotEmpty) 'next': next,
        if (onError != null) 'onError': onError,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  @override
  String toString() => 'SkillStep($id: ${type.name})';
}

// ============================================================================
// Legacy Step Config Classes
// ============================================================================

/// Action step configuration.
class ActionConfig {
  /// Action name to invoke.
  final String action;

  /// Arguments for the action.
  final Map<String, dynamic> arguments;

  /// Variable name to store result.
  final String? resultVar;

  const ActionConfig({
    required this.action,
    this.arguments = const {},
    this.resultVar,
  });

  /// Create from JSON.
  factory ActionConfig.fromJson(Map<String, dynamic> json) {
    return ActionConfig(
      action: json['action'] as String? ?? '',
      arguments: json['arguments'] as Map<String, dynamic>? ?? {},
      resultVar: json['resultVar'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'action': action,
        if (arguments.isNotEmpty) 'arguments': arguments,
        if (resultVar != null) 'resultVar': resultVar,
      };
}

/// Condition step configuration.
class ConditionConfig {
  /// Condition expression.
  final String expression;

  /// Step ID to execute if condition is true.
  final String? thenStep;

  /// Step ID to execute if condition is false.
  final String? elseStep;

  const ConditionConfig({
    required this.expression,
    this.thenStep,
    this.elseStep,
  });

  /// Create from JSON.
  factory ConditionConfig.fromJson(Map<String, dynamic> json) {
    return ConditionConfig(
      expression: json['expression'] as String? ?? '',
      thenStep: json['then'] as String?,
      elseStep: json['else'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'expression': expression,
        if (thenStep != null) 'then': thenStep,
        if (elseStep != null) 'else': elseStep,
      };
}

/// Loop step configuration.
class LoopConfig {
  /// Expression resolving to iterable items.
  final String items;

  /// Variable name for current item.
  final String itemVar;

  /// Variable name for current index.
  final String indexVar;

  /// Step ID for loop body.
  final String? body;

  const LoopConfig({
    required this.items,
    this.itemVar = 'item',
    this.indexVar = 'index',
    this.body,
  });

  /// Create from JSON.
  factory LoopConfig.fromJson(Map<String, dynamic> json) {
    return LoopConfig(
      items: json['items'] as String? ?? '',
      itemVar: json['itemVar'] as String? ?? 'item',
      indexVar: json['indexVar'] as String? ?? 'index',
      body: json['body'] as String?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'items': items,
        'itemVar': itemVar,
        'indexVar': indexVar,
        if (body != null) 'body': body,
      };
}

/// Transform step configuration.
class TransformConfig {
  /// Transform expression.
  final String expression;

  /// Variable name to store result.
  final String resultVar;

  const TransformConfig({
    required this.expression,
    required this.resultVar,
  });

  /// Create from JSON.
  factory TransformConfig.fromJson(Map<String, dynamic> json) {
    return TransformConfig(
      expression: json['expression'] as String? ?? '',
      resultVar: json['resultVar'] as String? ?? '',
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'expression': expression,
        'resultVar': resultVar,
      };
}
