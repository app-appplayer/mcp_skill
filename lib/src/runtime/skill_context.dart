/// Skill Context - Context management for skill execution.
///
/// Provides context for skill execution including request, workspace,
/// temporal constraints, inputs, and budget.
library;

/// Context for skill execution.
///
/// Contains all necessary information for executing a skill,
/// including the request, workspace, temporal constraints, and budget.
class SkillContext {
  /// User request/goal.
  final String request;

  /// Workspace identifier.
  final String workspaceId;

  /// Point-in-time snapshot (for reproducibility).
  final DateTime asOf;

  /// Time period filter.
  final Period? period;

  /// Policy version to use.
  final String? policyVersion;

  /// Active skills (for routing).
  final List<String>? activeSkills;

  /// Input values.
  final Map<String, dynamic> inputs;

  /// FactGraph context bundle (populated by runtime).
  final ContextBundle? contextBundle;

  /// Budget constraints.
  final ExecutionBudget? budget;

  /// Custom metadata.
  final Map<String, dynamic>? metadata;

  const SkillContext({
    required this.request,
    required this.workspaceId,
    required this.asOf,
    this.period,
    this.policyVersion,
    this.activeSkills,
    this.inputs = const {},
    this.contextBundle,
    this.budget,
    this.metadata,
  });

  /// Create a copy with updated fields.
  SkillContext copyWith({
    String? request,
    String? workspaceId,
    DateTime? asOf,
    Period? period,
    String? policyVersion,
    List<String>? activeSkills,
    Map<String, dynamic>? inputs,
    ContextBundle? contextBundle,
    ExecutionBudget? budget,
    Map<String, dynamic>? metadata,
  }) {
    return SkillContext(
      request: request ?? this.request,
      workspaceId: workspaceId ?? this.workspaceId,
      asOf: asOf ?? this.asOf,
      period: period ?? this.period,
      policyVersion: policyVersion ?? this.policyVersion,
      activeSkills: activeSkills ?? this.activeSkills,
      inputs: inputs ?? this.inputs,
      contextBundle: contextBundle ?? this.contextBundle,
      budget: budget ?? this.budget,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create from JSON.
  factory SkillContext.fromJson(Map<String, dynamic> json) {
    return SkillContext(
      request: json['request'] as String? ?? '',
      workspaceId: json['workspaceId'] as String? ?? '',
      asOf: json['asOf'] != null
          ? DateTime.parse(json['asOf'] as String)
          : DateTime.now(),
      period: json['period'] != null
          ? Period.fromJson(json['period'] as Map<String, dynamic>)
          : null,
      policyVersion: json['policyVersion'] as String?,
      activeSkills: (json['activeSkills'] as List<dynamic>?)?.cast<String>(),
      inputs: json['inputs'] as Map<String, dynamic>? ?? {},
      contextBundle: json['contextBundle'] != null
          ? ContextBundle.fromJson(
              json['contextBundle'] as Map<String, dynamic>)
          : null,
      budget: json['budget'] != null
          ? ExecutionBudget.fromJson(json['budget'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'request': request,
        'workspaceId': workspaceId,
        'asOf': asOf.toIso8601String(),
        if (period != null) 'period': period!.toJson(),
        if (policyVersion != null) 'policyVersion': policyVersion,
        if (activeSkills != null) 'activeSkills': activeSkills,
        if (inputs.isNotEmpty) 'inputs': inputs,
        if (contextBundle != null) 'contextBundle': contextBundle!.toJson(),
        if (budget != null) 'budget': budget!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() =>
      'SkillContext(request: "$request", workspaceId: $workspaceId, asOf: $asOf)';
}

/// Execution budget constraints.
///
/// Defines limits for resource consumption during skill execution.
class ExecutionBudget {
  /// Maximum tokens for LLM calls (total).
  final int maxTokens;

  /// Maximum execution duration.
  final Duration maxDuration;

  /// Maximum number of steps.
  final int maxSteps;

  /// Maximum LLM API calls.
  final int maxLlmCalls;

  /// Maximum MCP tool calls.
  final int maxMcpCalls;

  /// Maximum concurrent operations.
  final int maxConcurrency;

  const ExecutionBudget({
    this.maxTokens = 100000,
    this.maxDuration = const Duration(minutes: 5),
    this.maxSteps = 50,
    this.maxLlmCalls = 20,
    this.maxMcpCalls = 100,
    this.maxConcurrency = 5,
  });

  /// Create a minimal budget for testing.
  ExecutionBudget.minimal()
      : maxTokens = 1000,
        maxDuration = const Duration(seconds: 30),
        maxSteps = 10,
        maxLlmCalls = 3,
        maxMcpCalls = 10,
        maxConcurrency = 1;

  /// Create an unlimited budget.
  ExecutionBudget.unlimited()
      : maxTokens = -1,
        maxDuration = const Duration(hours: 24),
        maxSteps = -1,
        maxLlmCalls = -1,
        maxMcpCalls = -1,
        maxConcurrency = 100;

  /// Create from JSON.
  factory ExecutionBudget.fromJson(Map<String, dynamic> json) {
    return ExecutionBudget(
      maxTokens: json['maxTokens'] as int? ?? 100000,
      maxDuration: json['maxDurationMs'] != null
          ? Duration(milliseconds: json['maxDurationMs'] as int)
          : const Duration(minutes: 5),
      maxSteps: json['maxSteps'] as int? ?? 50,
      maxLlmCalls: json['maxLlmCalls'] as int? ?? 20,
      maxMcpCalls: json['maxMcpCalls'] as int? ?? 100,
      maxConcurrency: json['maxConcurrency'] as int? ?? 5,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'maxTokens': maxTokens,
        'maxDurationMs': maxDuration.inMilliseconds,
        'maxSteps': maxSteps,
        'maxLlmCalls': maxLlmCalls,
        'maxMcpCalls': maxMcpCalls,
        'maxConcurrency': maxConcurrency,
      };

  /// Check if tokens are within budget.
  bool isWithinTokenBudget(int tokens) =>
      maxTokens < 0 || tokens <= maxTokens;

  /// Check if duration is within budget.
  bool isWithinDurationBudget(Duration duration) =>
      duration <= maxDuration;

  /// Check if step count is within budget.
  bool isWithinStepBudget(int steps) =>
      maxSteps < 0 || steps <= maxSteps;

  @override
  String toString() =>
      'ExecutionBudget(maxTokens: $maxTokens, maxSteps: $maxSteps, maxLlmCalls: $maxLlmCalls)';
}

/// Time period for filtering.
class Period {
  /// Start time.
  final DateTime start;

  /// End time.
  final DateTime end;

  const Period({required this.start, required this.end});

  /// Create a period for today.
  factory Period.today() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return Period(start: startOfDay, end: endOfDay);
  }

  /// Create a period for the last N days.
  factory Period.lastDays(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    return Period(start: start, end: now);
  }

  /// Create from JSON.
  factory Period.fromJson(Map<String, dynamic> json) {
    return Period(
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  /// Get duration of period.
  Duration get duration => end.difference(start);

  /// Check if a timestamp is within this period.
  bool contains(DateTime timestamp) =>
      timestamp.isAfter(start) && timestamp.isBefore(end) ||
      timestamp == start ||
      timestamp == end;

  @override
  String toString() => 'Period($start to $end)';
}

/// Context bundle from FactGraph.
///
/// Contains context information retrieved from the FactGraph
/// for enriching skill execution.
class ContextBundle {
  /// Bundle ID.
  final String id;

  /// Retrieved entities.
  final List<ContextEntity> entities;

  /// Retrieved events.
  final List<ContextEvent> events;

  /// Retrieved views/summaries.
  final List<ContextView> views;

  /// Claims from the context.
  final List<ContextClaim> claims;

  /// When the bundle was created.
  final DateTime createdAt;

  /// Total token count estimate.
  final int? estimatedTokens;

  const ContextBundle({
    required this.id,
    this.entities = const [],
    this.events = const [],
    this.views = const [],
    this.claims = const [],
    required this.createdAt,
    this.estimatedTokens,
  });

  /// Create an empty context bundle.
  factory ContextBundle.empty() {
    return ContextBundle(
      id: 'empty',
      createdAt: DateTime.now(),
    );
  }

  /// Create from JSON.
  factory ContextBundle.fromJson(Map<String, dynamic> json) {
    return ContextBundle(
      id: json['id'] as String? ?? '',
      entities: (json['entities'] as List<dynamic>?)
              ?.map((e) => ContextEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => ContextEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      views: (json['views'] as List<dynamic>?)
              ?.map((e) => ContextView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      claims: (json['claims'] as List<dynamic>?)
              ?.map((e) => ContextClaim.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      estimatedTokens: json['estimatedTokens'] as int?,
    );
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (entities.isNotEmpty)
          'entities': entities.map((e) => e.toJson()).toList(),
        if (events.isNotEmpty)
          'events': events.map((e) => e.toJson()).toList(),
        if (views.isNotEmpty) 'views': views.map((e) => e.toJson()).toList(),
        if (claims.isNotEmpty)
          'claims': claims.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        if (estimatedTokens != null) 'estimatedTokens': estimatedTokens,
      };

  /// Check if the bundle is empty.
  bool get isEmpty =>
      entities.isEmpty && events.isEmpty && views.isEmpty && claims.isEmpty;

  @override
  String toString() =>
      'ContextBundle(id: $id, entities: ${entities.length}, events: ${events.length})';
}

/// Entity from context.
class ContextEntity {
  final String id;
  final String type;
  final String name;
  final Map<String, dynamic> attributes;

  const ContextEntity({
    required this.id,
    required this.type,
    required this.name,
    this.attributes = const {},
  });

  factory ContextEntity.fromJson(Map<String, dynamic> json) {
    return ContextEntity(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      name: json['name'] as String? ?? '',
      attributes: json['attributes'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (attributes.isNotEmpty) 'attributes': attributes,
      };
}

/// Event from context.
class ContextEvent {
  final String id;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const ContextEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    this.data = const {},
  });

  factory ContextEvent.fromJson(Map<String, dynamic> json) {
    return ContextEvent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        if (data.isNotEmpty) 'data': data,
      };
}

/// View/summary from context.
class ContextView {
  final String id;
  final String type;
  final String content;
  final DateTime asOf;

  const ContextView({
    required this.id,
    required this.type,
    required this.content,
    required this.asOf,
  });

  factory ContextView.fromJson(Map<String, dynamic> json) {
    return ContextView(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      content: json['content'] as String? ?? '',
      asOf: json['asOf'] != null
          ? DateTime.parse(json['asOf'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'content': content,
        'asOf': asOf.toIso8601String(),
      };
}

/// Claim from context.
class ContextClaim {
  final String id;
  final String text;
  final double confidence;
  final List<String> evidenceRefs;

  const ContextClaim({
    required this.id,
    required this.text,
    required this.confidence,
    this.evidenceRefs = const [],
  });

  factory ContextClaim.fromJson(Map<String, dynamic> json) {
    return ContextClaim(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      evidenceRefs: (json['evidenceRefs'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'confidence': confidence,
        if (evidenceRefs.isNotEmpty) 'evidenceRefs': evidenceRefs,
      };
}

/// Budget tracker for monitoring execution resource usage.
class BudgetTracker {
  final ExecutionBudget budget;

  int _tokensUsed = 0;
  int _stepsExecuted = 0;
  int _llmCallsMade = 0;
  int _mcpCallsMade = 0;
  final DateTime _startTime = DateTime.now();

  BudgetTracker(this.budget);

  /// Track token usage.
  void trackTokens(int tokens) {
    _tokensUsed += tokens;
  }

  /// Track step execution.
  void trackStep() {
    _stepsExecuted++;
  }

  /// Track LLM call.
  void trackLlmCall() {
    _llmCallsMade++;
  }

  /// Track MCP call.
  void trackMcpCall() {
    _mcpCallsMade++;
  }

  /// Get current token usage.
  int get tokensUsed => _tokensUsed;

  /// Get current step count.
  int get stepsExecuted => _stepsExecuted;

  /// Get current LLM call count.
  int get llmCallsMade => _llmCallsMade;

  /// Get current MCP call count.
  int get mcpCallsMade => _mcpCallsMade;

  /// Get elapsed time.
  Duration get elapsed => DateTime.now().difference(_startTime);

  /// Check if budget is exceeded.
  bool get isExceeded =>
      !budget.isWithinTokenBudget(_tokensUsed) ||
      !budget.isWithinStepBudget(_stepsExecuted) ||
      !budget.isWithinDurationBudget(elapsed) ||
      (budget.maxLlmCalls > 0 && _llmCallsMade > budget.maxLlmCalls) ||
      (budget.maxMcpCalls > 0 && _mcpCallsMade > budget.maxMcpCalls);

  /// Get remaining token budget.
  int get remainingTokens =>
      budget.maxTokens < 0 ? -1 : budget.maxTokens - _tokensUsed;

  /// Get remaining steps.
  int get remainingSteps =>
      budget.maxSteps < 0 ? -1 : budget.maxSteps - _stepsExecuted;

  /// Get usage summary.
  Map<String, dynamic> toJson() => {
        'tokensUsed': _tokensUsed,
        'stepsExecuted': _stepsExecuted,
        'llmCallsMade': _llmCallsMade,
        'mcpCallsMade': _mcpCallsMade,
        'elapsedMs': elapsed.inMilliseconds,
        'isExceeded': isExceeded,
      };
}
