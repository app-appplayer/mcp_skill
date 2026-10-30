/// Profile-Aware Skill Runtime - Runtime with mcp_profile integration.
///
/// Extends SkillRuntime to integrate with mcp_profile for:
/// - Appraisal metrics
/// - Decision guidance
/// - Expression styling
library;

import '../registry/skill_registry.dart';
import '../ports/skill_ports.dart';
import 'skill_router.dart';
import 'skill_context.dart';
import 'skill_result.dart';
import 'runtime_hooks.dart';

/// Profile-aware runtime that integrates with mcp_profile.
///
/// Execution lifecycle with profile integration:
/// 1. Resolve applicable profiles
/// 2. Compute appraisal metrics BEFORE skill execution
/// 3. Get decision guidance (may modify/block execution)
/// 4. Apply modifications to context
/// 5. Execute skill (via super.run)
/// 6. Get expression style for output
/// 7. Format result with style and appraisal
class ProfileAwareSkillRuntime {
  /// Base skill registry.
  final SkillBundleRegistry registry;

  /// Ports for external access.
  final SkillPorts ports;

  /// Router for skill selection.
  final SkillRouter? router;

  /// Runtime hooks.
  final List<RuntimeHook>? hooks;

  /// Profile runtime (from mcp_profile package).
  final ProfileRuntime profileRuntime;

  /// Profile registry.
  final ProfileRegistry profileRegistry;

  ProfileAwareSkillRuntime({
    required this.registry,
    required this.ports,
    required this.profileRuntime,
    required this.profileRegistry,
    this.router,
    this.hooks,
  });

  /// Execute skill with profile integration.
  Future<SkillResult> run(SkillContext context) async {
    // Step 1: Resolve applicable profiles
    final profiles = await _resolveProfiles(context);

    // If no profiles bound, use standard execution
    if (profiles.isEmpty) {
      return await _executeStandard(context);
    }

    // Step 2: Build profile context
    final profileContext = ProfileContext(
      skillId: context.skillId,
      userId: context.userId ?? 'anonymous',
      workspaceId: context.workspaceId,
      request: context.request,
      inputs: context.inputs,
      asOf: context.asOf,
      profiles: profiles,
    );

    // Step 3: Compute appraisal metrics BEFORE execution
    final appraisal = await profileRuntime.appraise(profileContext);

    await _notifyHooks((hook) => hook.onProfileAppraisal(context, appraisal));

    // Step 4: Get decision guidance
    final guidance =
        await profileRuntime.getDecisionGuidance(appraisal, profileContext);

    await _notifyHooks((hook) => hook.onDecisionGuidance(context, guidance));

    // Step 5: Apply decision modifications to context
    final modifiedContext = _applyDecisionGuidance(context, guidance);

    // Step 6: Check if execution should proceed
    if (guidance.action == DecisionAction.reject) {
      return _createRejectionResult(context, guidance);
    }

    if (guidance.action == DecisionAction.hold) {
      return _createHoldResult(context, guidance, appraisal);
    }

    // Step 7: Execute skill with modified context
    final rawResult = await _executeStandard(modifiedContext);

    // Step 8: Get expression style for output formatting
    final style = await profileRuntime.getExpressionStyle(
      appraisal,
      profileContext,
    );

    // Step 9: Format result with style and appraisal
    return _formatWithStyle(rawResult, style, appraisal, guidance);
  }

  // ========================================================================
  // PROFILE RESOLUTION
  // ========================================================================

  /// Resolve profiles bound to the executing skill.
  Future<List<Profile>> _resolveProfiles(SkillContext context) async {
    final skillId = context.activeSkills?.firstOrNull ?? context.skillId;
    if (skillId.isEmpty) return [];

    // Get bindings from profile registry
    final bindings = await profileRegistry.getBindingsForSkill(skillId);
    if (bindings.isEmpty) return [];

    final profiles = <Profile>[];

    for (final binding in bindings) {
      // Check binding condition if present
      if (binding.condition != null) {
        final conditionMet = _evaluateCondition(binding.condition!, context);
        if (!conditionMet) continue;
      }

      // Load profiles in order
      for (final profileId in binding.profileIds) {
        final profile = await profileRegistry.getProfile(profileId);
        if (profile != null) {
          profiles.add(profile);
        }
      }
    }

    return profiles;
  }

  bool _evaluateCondition(String condition, SkillContext context) {
    // Simple condition evaluation
    // TODO: Integrate with expression evaluator
    return true; // For now, always true
  }

  // ========================================================================
  // DECISION GUIDANCE
  // ========================================================================

  /// Apply decision guidance to modify execution context.
  SkillContext _applyDecisionGuidance(
    SkillContext context,
    DecisionGuidance guidance,
  ) {
    if (guidance.modifications.isEmpty) {
      return context;
    }

    // Apply modifications
    var modified = context;

    for (final mod in guidance.modifications) {
      switch (mod.type) {
        case 'input_override':
          modified = modified.copyWith(
            inputs: {...modified.inputs, ...mod.values},
          );
          break;

        case 'budget_adjust':
          if (mod.values['budget'] != null) {
            // Apply budget adjustments
            modified = modified.copyWith(
              budget: _adjustBudget(modified.budget, mod.values['budget']),
            );
          }
          break;

        case 'metadata_add':
          modified = modified.copyWith(
            metadata: {...?modified.metadata, ...mod.values},
          );
          break;
      }
    }

    return modified;
  }

  ExecutionBudget? _adjustBudget(ExecutionBudget? current, dynamic adjustment) {
    if (current == null) return null;
    if (adjustment is! Map) return current;

    final maxTokens = adjustment['maxTokens'] as int? ?? current.maxTokens;
    final maxDuration = adjustment['maxDurationMs'] != null
        ? Duration(milliseconds: adjustment['maxDurationMs'] as int)
        : current.maxDuration;

    return ExecutionBudget(
      maxTokens: maxTokens,
      maxDuration: maxDuration,
      maxSteps: adjustment['maxSteps'] as int? ?? current.maxSteps,
      maxLlmCalls: adjustment['maxLlmCalls'] as int? ?? current.maxLlmCalls,
      maxMcpCalls: adjustment['maxMcpCalls'] as int? ?? current.maxMcpCalls,
      maxConcurrency:
          adjustment['maxConcurrency'] as int? ?? current.maxConcurrency,
    );
  }

  // ========================================================================
  // RESULT CREATION
  // ========================================================================

  SkillResult _createRejectionResult(
    SkillContext context,
    DecisionGuidance guidance,
  ) {
    return SkillResult.failure(
      skillId: context.skillId,
      error: guidance.reason ?? 'Execution rejected by decision guidance',
    );
  }

  SkillResult _createHoldResult(
    SkillContext context,
    DecisionGuidance guidance,
    ProfileAppraisal appraisal,
  ) {
    return SkillResult(
      claims: [],
      evidenceRefs: [],
      confidence: 0.0,
      asOf: DateTime.now(),
      metadata: ExecutionMetadata(
        skillId: context.skillId,
        skillVersion: '',
        procedureId: '',
        startedAt: DateTime.now(),
        finishedAt: DateTime.now(),
        duration: Duration.zero,
        stepsExecuted: 0,
        toolsCalled: [],
        custom: {
          'decisionAction': 'hold',
          'holdReason': guidance.reason,
          'appraisal': appraisal.toJson(),
          'requiresApproval': true,
        },
      ),
    );
  }

  // ========================================================================
  // RESULT FORMATTING
  // ========================================================================

  SkillResult _formatWithStyle(
    SkillResult result,
    ExpressionStyle style,
    ProfileAppraisal appraisal,
    DecisionGuidance guidance,
  ) {
    // Enrich metadata with profile information
    final enrichedCustom = {
      ...?result.metadata.custom,
      'profile': {
        'appraisal': appraisal.toJson(),
        'guidance': guidance.toJson(),
        'style': style.toJson(),
      },
    };

    return SkillResult(
      claims: result.claims,
      evidenceRefs: result.evidenceRefs,
      actions: result.actions,
      rubricScores: result.rubricScores,
      confidence: result.confidence,
      asOf: result.asOf,
      policyVersion: result.policyVersion,
      ui: result.ui,
      artifacts: result.artifacts,
      output: result.output,
      metadata: ExecutionMetadata(
        skillId: result.metadata.skillId,
        skillVersion: result.metadata.skillVersion,
        procedureId: result.metadata.procedureId,
        startedAt: result.metadata.startedAt,
        finishedAt: result.metadata.finishedAt,
        duration: result.metadata.duration,
        stepsExecuted: result.metadata.stepsExecuted,
        llmUsage: result.metadata.llmUsage,
        toolsCalled: result.metadata.toolsCalled,
        custom: enrichedCustom,
      ),
    );
  }

  // ========================================================================
  // STANDARD EXECUTION (FALLBACK)
  // ========================================================================

  Future<SkillResult> _executeStandard(SkillContext context) async {
    // This would delegate to the standard SkillRuntime.run()
    // For now, return a placeholder
    return SkillResult.failure(
      skillId: context.skillId,
      error: 'Standard execution not implemented in ProfileAwareRuntime',
    );
  }

  // ========================================================================
  // HOOKS
  // ========================================================================

  Future<void> _notifyHooks(
    Future<void> Function(ProfileRuntimeHook hook) callback,
  ) async {
    if (hooks == null) return;

    for (final hook in hooks!) {
      if (hook is ProfileRuntimeHook) {
        try {
          await callback(hook);
        } catch (e) {
          // Ignore hook errors
        }
      }
    }
  }
}

// ========================================================================
// PROFILE TYPES (Minimal definitions for standalone implementation)
// ========================================================================

/// Profile runtime interface.
abstract class ProfileRuntime {
  Future<ProfileAppraisal> appraise(ProfileContext context);
  Future<DecisionGuidance> getDecisionGuidance(
    ProfileAppraisal appraisal,
    ProfileContext context,
  );
  Future<ExpressionStyle> getExpressionStyle(
    ProfileAppraisal appraisal,
    ProfileContext context,
  );
}

/// Profile registry interface.
abstract class ProfileRegistry {
  Future<List<ProfileBinding>> getBindingsForSkill(String skillId);
  Future<Profile?> getProfile(String profileId);
}

/// Profile binding.
class ProfileBinding {
  final String skillId;
  final List<String> profileIds;
  final String? condition;

  const ProfileBinding({
    required this.skillId,
    required this.profileIds,
    this.condition,
  });
}

/// Profile definition.
class Profile {
  final String id;
  final String name;
  final Map<String, dynamic> config;

  const Profile({
    required this.id,
    required this.name,
    required this.config,
  });
}

/// Profile context.
class ProfileContext {
  final String skillId;
  final String userId;
  final String workspaceId;
  final String request;
  final Map<String, dynamic> inputs;
  final DateTime asOf;
  final List<Profile> profiles;

  const ProfileContext({
    required this.skillId,
    required this.userId,
    required this.workspaceId,
    required this.request,
    required this.inputs,
    required this.asOf,
    required this.profiles,
  });
}

/// Profile appraisal result.
class ProfileAppraisal {
  final Map<String, double> metrics;
  final Map<String, dynamic> metadata;

  const ProfileAppraisal({
    required this.metrics,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'metrics': metrics,
        'metadata': metadata,
      };
}

/// Decision guidance.
class DecisionGuidance {
  final DecisionAction action;
  final String? reason;
  final List<ContextModification> modifications;

  const DecisionGuidance({
    required this.action,
    this.reason,
    this.modifications = const [],
  });

  Map<String, dynamic> toJson() => {
        'action': action.toString(),
        'reason': reason,
        'modifications': modifications.map((m) => m.toJson()).toList(),
      };
}

/// Decision action.
enum DecisionAction {
  /// Proceed with execution.
  proceed,

  /// Hold execution pending approval.
  hold,

  /// Reject execution.
  reject,
}

/// Context modification.
class ContextModification {
  final String type;
  final Map<String, dynamic> values;

  const ContextModification({
    required this.type,
    required this.values,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'values': values,
      };
}

/// Expression style.
class ExpressionStyle {
  final String? tone;
  final String? formality;
  final Map<String, dynamic> options;

  const ExpressionStyle({
    this.tone,
    this.formality,
    this.options = const {},
  });

  Map<String, dynamic> toJson() => {
        if (tone != null) 'tone': tone,
        if (formality != null) 'formality': formality,
        'options': options,
      };
}

/// Profile runtime hook.
abstract class ProfileRuntimeHook extends RuntimeHook {
  Future<void> onProfileAppraisal(
    SkillContext context,
    ProfileAppraisal appraisal,
  ) async {}

  Future<void> onDecisionGuidance(
    SkillContext context,
    DecisionGuidance guidance,
  ) async {}
}

// Extension for firstOrNull
extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
