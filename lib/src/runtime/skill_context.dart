/// Skill Context - Context management for skill execution.
///
/// Provides context for skill execution including request, workspace,
/// temporal constraints, inputs, and budget.
library;

// Import and re-export canonical types from mcp_bundle
import 'package:mcp_bundle/ports.dart' show Period, ContextBundle;

import '../exceptions/execution_exceptions.dart';
import 'retry_config.dart';

export 'package:mcp_bundle/ports.dart'
    show
        Period,
        RelativePeriod,
        AbsolutePeriod,
        PeriodUnit,
        DateRange,
        ContextBundle,
        ContextEntity,
        ContextEvent,
        ContextView,
        ContextClaim;

export 'retry_config.dart' show RetryConfig, CacheConfig;

/// Context for skill execution.
///
/// Contains all necessary information for executing a skill,
/// including the request, workspace, temporal constraints, and budget.
class SkillContext {
  /// Unique identifier for this context instance.
  final String contextId;

  /// ID of the skill being executed.
  final String skillId;

  /// ID of this specific run.
  final String runId;

  /// Distributed tracing ID for cross-service correlation.
  final String traceId;

  /// Parent context ID (for nested skills).
  final String? parentContextId;

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

  /// The procedure to run in the skill; when null the skill's first
  /// procedure runs.
  final String? procedureId;

  /// Input values.
  final Map<String, dynamic> inputs;

  /// FactGraph context bundle (populated by runtime).
  final ContextBundle? contextBundle;

  /// Budget constraints.
  final ExecutionBudget? budget;

  /// User ID (for user-specific execution).
  final String? userId;

  /// Retry configuration.
  final RetryConfig? retryConfig;

  /// Cache configuration hints.
  final CacheConfig? cacheConfig;

  /// Custom metadata.
  final Map<String, dynamic>? metadata;

  const SkillContext({
    required this.contextId,
    required this.skillId,
    required this.runId,
    required this.traceId,
    this.parentContextId,
    required this.request,
    required this.workspaceId,
    required this.asOf,
    this.period,
    this.policyVersion,
    this.activeSkills,
    this.procedureId,
    this.inputs = const {},
    this.contextBundle,
    this.budget,
    this.userId,
    this.retryConfig,
    this.cacheConfig,
    this.metadata,
  });

  /// Create a copy with updated fields.
  SkillContext copyWith({
    String? contextId,
    String? skillId,
    String? runId,
    String? traceId,
    String? parentContextId,
    String? request,
    String? workspaceId,
    DateTime? asOf,
    Period? period,
    String? policyVersion,
    List<String>? activeSkills,
    String? procedureId,
    Map<String, dynamic>? inputs,
    ContextBundle? contextBundle,
    ExecutionBudget? budget,
    String? userId,
    RetryConfig? retryConfig,
    CacheConfig? cacheConfig,
    Map<String, dynamic>? metadata,
  }) {
    return SkillContext(
      contextId: contextId ?? this.contextId,
      skillId: skillId ?? this.skillId,
      runId: runId ?? this.runId,
      traceId: traceId ?? this.traceId,
      parentContextId: parentContextId ?? this.parentContextId,
      request: request ?? this.request,
      workspaceId: workspaceId ?? this.workspaceId,
      asOf: asOf ?? this.asOf,
      period: period ?? this.period,
      policyVersion: policyVersion ?? this.policyVersion,
      activeSkills: activeSkills ?? this.activeSkills,
      procedureId: procedureId ?? this.procedureId,
      inputs: inputs ?? this.inputs,
      contextBundle: contextBundle ?? this.contextBundle,
      budget: budget ?? this.budget,
      userId: userId ?? this.userId,
      retryConfig: retryConfig ?? this.retryConfig,
      cacheConfig: cacheConfig ?? this.cacheConfig,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create from JSON.
  factory SkillContext.fromJson(Map<String, dynamic> json) {
    return SkillContext(
      contextId: json['contextId'] as String? ?? '',
      skillId: json['skillId'] as String? ?? '',
      runId: json['runId'] as String? ?? '',
      traceId: json['traceId'] as String? ?? '',
      parentContextId: json['parentContextId'] as String?,
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
      procedureId: json['procedureId'] as String?,
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
        'contextId': contextId,
        'skillId': skillId,
        'runId': runId,
        'traceId': traceId,
        if (parentContextId != null) 'parentContextId': parentContextId,
        'request': request,
        'workspaceId': workspaceId,
        'asOf': asOf.toIso8601String(),
        if (period != null) 'period': period!.toJson(),
        if (policyVersion != null) 'policyVersion': policyVersion,
        if (activeSkills != null) 'activeSkills': activeSkills,
        if (procedureId != null) 'procedureId': procedureId,
        if (inputs.isNotEmpty) 'inputs': inputs,
        if (contextBundle != null) 'contextBundle': contextBundle!.toJson(),
        if (budget != null) 'budget': budget!.toJson(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() =>
      'SkillContext(contextId: $contextId, skillId: $skillId, runId: $runId, '
      'traceId: $traceId, request: "$request", workspaceId: $workspaceId)';
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

/// Budget tracker for monitoring execution resource usage.
class BudgetTracker {
  final ExecutionBudget budget;

  int _tokensUsed = 0;
  int _stepsExecuted = 0;
  int _llmCallsMade = 0;
  int _mcpCallsMade = 0;
  final DateTime _startTime = DateTime.now();

  BudgetTracker(this.budget);

  /// Track token usage (no enforcement — use [consumeTokens] to enforce).
  void trackTokens(int tokens) {
    _tokensUsed += tokens;
  }

  /// Track step execution (no enforcement — use [incrementStep] to enforce).
  void trackStep() {
    _stepsExecuted++;
  }

  /// Track LLM call (no enforcement — use [addLlmCall] to enforce).
  void trackLlmCall() {
    _llmCallsMade++;
  }

  /// Track MCP call (no enforcement — use [addMcpCall] to enforce).
  void trackMcpCall() {
    _mcpCallsMade++;
  }

  /// Consume tokens and enforce the token budget.
  ///
  /// Throws [BudgetExceededException] when the resulting total exceeds
  /// [ExecutionBudget.maxTokens] (ignored when the limit is negative /
  /// unlimited).
  void consumeTokens(int tokens) {
    _tokensUsed += tokens;
    if (budget.maxTokens >= 0 && _tokensUsed > budget.maxTokens) {
      throw BudgetExceededException('tokens', budget.maxTokens, _tokensUsed);
    }
  }

  /// Increment the step counter and enforce the step budget.
  ///
  /// Throws [BudgetExceededException] when the resulting total exceeds
  /// [ExecutionBudget.maxSteps] (ignored when the limit is negative /
  /// unlimited).
  void incrementStep() {
    _stepsExecuted++;
    if (budget.maxSteps >= 0 && _stepsExecuted > budget.maxSteps) {
      throw BudgetExceededException('steps', budget.maxSteps, _stepsExecuted);
    }
  }

  /// Record an LLM call and enforce the LLM-call budget.
  ///
  /// Throws [BudgetExceededException] when the resulting total exceeds
  /// [ExecutionBudget.maxLlmCalls] (ignored when the limit is negative /
  /// unlimited).
  void addLlmCall() {
    _llmCallsMade++;
    if (budget.maxLlmCalls >= 0 && _llmCallsMade > budget.maxLlmCalls) {
      throw BudgetExceededException(
          'llm_calls', budget.maxLlmCalls, _llmCallsMade);
    }
  }

  /// Record an MCP call and enforce the MCP-call budget.
  ///
  /// Throws [BudgetExceededException] when the resulting total exceeds
  /// [ExecutionBudget.maxMcpCalls] (ignored when the limit is negative /
  /// unlimited).
  void addMcpCall() {
    _mcpCallsMade++;
    if (budget.maxMcpCalls >= 0 && _mcpCallsMade > budget.maxMcpCalls) {
      throw BudgetExceededException(
          'mcp_calls', budget.maxMcpCalls, _mcpCallsMade);
    }
  }

  /// Assert that execution has not exceeded the wall-clock duration budget.
  ///
  /// Throws [BudgetExceededException] when [elapsed] has surpassed
  /// [ExecutionBudget.maxDuration].
  void assertNotExpired() {
    final elapsedMs = elapsed.inMilliseconds;
    final maxMs = budget.maxDuration.inMilliseconds;
    if (elapsedMs > maxMs) {
      throw BudgetExceededException('duration', maxMs, elapsedMs);
    }
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
