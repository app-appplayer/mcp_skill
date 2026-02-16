/// Skill step definitions for execution flow.
library;

/// A step in a skill execution flow.
class SkillStep {
  SkillStep({
    required this.id,
    required this.type,
    this.name,
    this.config = const {},
    this.condition,
    this.next = const [],
    this.onError,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  /// Step identifier.
  final String id;

  /// Step type.
  final StepType type;

  /// Step name.
  final String? name;

  /// Step configuration.
  final Map<String, dynamic> config;

  /// Condition expression (evaluated to determine if step should execute).
  final String? condition;

  /// Next step IDs.
  final List<String> next;

  /// Error handler step ID.
  final String? onError;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  /// Get a config value.
  dynamic getConfig(String key) => config[key];

  /// Check if step has a config key.
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
      metadata: json['metadata'] as Map<String, dynamic>?,
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

/// Types of skill steps.
enum StepType {
  /// Execute an action.
  action,

  /// Conditional branch.
  condition,

  /// Loop/iteration.
  loop,

  /// Parallel execution.
  parallel,

  /// Wait/delay.
  wait,

  /// Transform data.
  transform,

  /// Call another skill.
  call,

  /// Set variable.
  setVar,

  /// Return/output.
  output,

  /// Log/debug.
  log,

  /// HTTP request.
  http,

  /// Unknown step type.
  unknown;

  static StepType fromString(String value) {
    return StepType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => StepType.unknown,
    );
  }
}

/// Action step configuration.
class ActionConfig {
  ActionConfig({
    required this.action,
    this.arguments = const {},
    this.resultVar,
  });

  /// Action name.
  final String action;

  /// Action arguments.
  final Map<String, dynamic> arguments;

  /// Variable to store result.
  final String? resultVar;

  factory ActionConfig.fromJson(Map<String, dynamic> json) {
    return ActionConfig(
      action: json['action'] as String? ?? '',
      arguments: json['arguments'] as Map<String, dynamic>? ?? {},
      resultVar: json['resultVar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        if (arguments.isNotEmpty) 'arguments': arguments,
        if (resultVar != null) 'resultVar': resultVar,
      };
}

/// Condition step configuration.
class ConditionConfig {
  ConditionConfig({
    required this.expression,
    this.thenStep,
    this.elseStep,
  });

  /// Condition expression.
  final String expression;

  /// Step to execute if true.
  final String? thenStep;

  /// Step to execute if false.
  final String? elseStep;

  factory ConditionConfig.fromJson(Map<String, dynamic> json) {
    return ConditionConfig(
      expression: json['expression'] as String? ?? '',
      thenStep: json['then'] as String?,
      elseStep: json['else'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'expression': expression,
        if (thenStep != null) 'then': thenStep,
        if (elseStep != null) 'else': elseStep,
      };
}

/// Loop step configuration.
class LoopConfig {
  LoopConfig({
    required this.items,
    this.itemVar = 'item',
    this.indexVar = 'index',
    this.body,
  });

  /// Expression for items to iterate.
  final String items;

  /// Variable name for current item.
  final String itemVar;

  /// Variable name for current index.
  final String indexVar;

  /// Body step ID.
  final String? body;

  factory LoopConfig.fromJson(Map<String, dynamic> json) {
    return LoopConfig(
      items: json['items'] as String? ?? '',
      itemVar: json['itemVar'] as String? ?? 'item',
      indexVar: json['indexVar'] as String? ?? 'index',
      body: json['body'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items,
        'itemVar': itemVar,
        'indexVar': indexVar,
        if (body != null) 'body': body,
      };
}

/// Transform step configuration.
class TransformConfig {
  TransformConfig({
    required this.expression,
    required this.resultVar,
  });

  /// Transform expression.
  final String expression;

  /// Variable to store result.
  final String resultVar;

  factory TransformConfig.fromJson(Map<String, dynamic> json) {
    return TransformConfig(
      expression: json['expression'] as String? ?? '',
      resultVar: json['resultVar'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'expression': expression,
        'resultVar': resultVar,
      };
}
