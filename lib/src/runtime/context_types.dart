/// Context Types - Supporting types for SkillContext.
///
/// Includes BudgetUsage, ContextState, SkillConfig, and FeatureFlags.
library;

/// Budget usage snapshot at a point in time.
class BudgetUsage {
  /// Tokens consumed.
  final int tokensUsed;

  /// Steps executed.
  final int stepsExecuted;

  /// LLM calls made.
  final int llmCallsMade;

  /// MCP tool calls made.
  final int mcpCallsMade;

  /// Elapsed duration.
  final Duration elapsed;

  /// Estimated remaining tokens.
  final int remainingTokens;

  /// Estimated remaining steps.
  final int remainingSteps;

  const BudgetUsage({
    this.tokensUsed = 0,
    this.stepsExecuted = 0,
    this.llmCallsMade = 0,
    this.mcpCallsMade = 0,
    this.elapsed = Duration.zero,
    this.remainingTokens = -1,
    this.remainingSteps = -1,
  });

  /// Whether any budget limit has been exceeded.
  bool get isExceeded => remainingTokens == 0 || remainingSteps == 0;

  /// Usage as a percentage (0.0 - 1.0) of the total budget.
  double get utilizationRatio {
    if (remainingTokens < 0) return 0.0;
    final total = tokensUsed + remainingTokens;
    if (total == 0) return 0.0;
    return tokensUsed / total;
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'tokensUsed': tokensUsed,
        'stepsExecuted': stepsExecuted,
        'llmCallsMade': llmCallsMade,
        'mcpCallsMade': mcpCallsMade,
        'elapsedMs': elapsed.inMilliseconds,
        'remainingTokens': remainingTokens,
        'remainingSteps': remainingSteps,
      };
}

/// Mutable state container for skill execution.
///
/// Provides typed get/set/accumulate operations for managing
/// state that persists across steps within a single execution.
class ContextState {
  final Map<String, dynamic> _state;

  /// Create an empty state container.
  ContextState() : _state = {};

  ContextState._(this._state);

  /// Get a typed value from state.
  T? get<T>(String key) {
    final value = _state[key];
    if (value is T) return value;
    return null;
  }

  /// Set a typed value in state.
  void set<T>(String key, T value) {
    _state[key] = value;
  }

  /// Accumulate a numeric value.
  void accumulate(String key, num amount) {
    final current = _state[key];
    if (current is num) {
      _state[key] = current + amount;
    } else {
      _state[key] = amount;
    }
  }

  /// Check if a key exists.
  bool has(String key) => _state.containsKey(key);

  /// Remove a key.
  void remove(String key) => _state.remove(key);

  /// Get all state as a map.
  Map<String, dynamic> toMap() => Map.unmodifiable(_state);

  /// Create a copy of this state.
  ContextState copy() {
    return ContextState._(Map<String, dynamic>.from(_state));
  }

  /// Create from a map.
  factory ContextState.from(Map<String, dynamic> initial) {
    return ContextState._(Map<String, dynamic>.from(initial));
  }
}

/// Typed configuration access for skills.
class SkillConfig {
  final Map<String, dynamic> _config;

  const SkillConfig(this._config);

  /// Empty configuration.
  const SkillConfig.empty() : _config = const {};

  /// Get a typed configuration value.
  T? get<T>(String key) {
    final value = _config[key];
    if (value is T) return value;
    return null;
  }

  /// Get a required configuration value.
  ///
  /// Throws [StateError] if the key is not found.
  T require<T>(String key) {
    final value = get<T>(key);
    if (value == null) {
      throw StateError('Required config key not found: $key');
    }
    return value;
  }

  /// Check if a key exists.
  bool has(String key) => _config.containsKey(key);

  /// Get all configuration as a map.
  Map<String, dynamic> toMap() => Map.unmodifiable(_config);

  /// Create from JSON.
  factory SkillConfig.fromJson(Map<String, dynamic> json) =>
      SkillConfig(json);
}

/// Feature flags for conditional execution.
class FeatureFlags {
  final Map<String, bool> _flags;

  const FeatureFlags(this._flags);

  /// Empty feature flags (all disabled).
  const FeatureFlags.empty() : _flags = const {};

  /// Check if a feature is enabled.
  bool isEnabled(String feature) => _flags[feature] ?? false;

  /// Get all enabled features.
  Set<String> get enabledFeatures =>
      _flags.entries.where((e) => e.value).map((e) => e.key).toSet();

  /// Create from JSON.
  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      json.map((k, v) => MapEntry(k, v == true)),
    );
  }
}
