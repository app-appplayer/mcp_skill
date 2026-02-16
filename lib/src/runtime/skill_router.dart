/// Skill Router - Routes requests to appropriate skills.
///
/// Provides routing strategies for selecting skills based on
/// context, capabilities, and request content.
library;

import 'skill_context.dart';
import '../bundle/skill_bundle.dart';
import '../ports/llm_port.dart';

/// Routes requests to appropriate skills.
abstract class SkillRouter {
  /// Route a request to one or more skill bundles.
  Future<List<SkillBundle>> route(
    SkillContext context,
    List<SkillBundle> availableSkills,
  );
}

/// Simple capability-based router.
///
/// Matches skills based on explicit skill IDs in context
/// or keyword matching against skill tags/names.
class CapabilityRouter implements SkillRouter {
  @override
  Future<List<SkillBundle>> route(
    SkillContext context,
    List<SkillBundle> availableSkills,
  ) async {
    // If skills specified in context, use those
    if (context.activeSkills != null && context.activeSkills!.isNotEmpty) {
      return availableSkills.where(
        (bundle) => bundle.skills.any((s) => context.activeSkills!.contains(s.id)),
      ).toList();
    }

    // Otherwise, match by tags/name keywords in request
    final requestLower = context.request.toLowerCase();
    return availableSkills.where((bundle) {
      return bundle.skills.any((skill) {
        // Match by tags
        if (skill.tags.any((tag) => requestLower.contains(tag.toLowerCase()))) {
          return true;
        }
        // Match by name
        if (requestLower.contains(skill.name.toLowerCase())) {
          return true;
        }
        return false;
      });
    }).toList();
  }
}

/// LLM-based router for complex routing decisions.
///
/// Uses an LLM to analyze the request and select appropriate skills.
class LlmRouter implements SkillRouter {
  /// LLM port for routing decisions.
  final LlmPort llm;

  /// Maximum skills to select.
  final int maxSkills;

  LlmRouter(this.llm, {this.maxSkills = 3});

  @override
  Future<List<SkillBundle>> route(
    SkillContext context,
    List<SkillBundle> availableSkills,
  ) async {
    if (availableSkills.isEmpty) return [];

    // Build descriptions from bundles and their skills
    final descriptions = <String>[];
    for (final bundle in availableSkills) {
      for (final skill in bundle.skills) {
        descriptions.add('${skill.id}: ${skill.description ?? skill.name}');
      }
    }
    final skillDescriptions = descriptions.join('\n');

    final response = await llm.complete(LlmRequest(
      messages: [
        LlmMessage(
          role: 'system',
          content: '''You are a skill router. Select the best skill(s) for the user's request.
Respond with a JSON array of skill IDs, ordered by relevance.
Select at most $maxSkills skills.''',
        ),
        LlmMessage(
          role: 'user',
          content: '''Select the best skill(s) for this request:

Request: ${context.request}

Available skills:
$skillDescriptions

Respond with a JSON array of skill IDs.''',
        ),
      ],
      temperature: 0.0,
    ));

    // Parse response to get skill IDs
    final selectedIds = _parseSkillIds(response.content);

    // Return bundles that contain selected skills
    return availableSkills.where(
      (bundle) => bundle.skills.any((s) => selectedIds.contains(s.id))
    ).toList();
  }

  List<String> _parseSkillIds(String content) {
    // Simple JSON array parsing
    final match = RegExp(r'\[([^\]]*)\]').firstMatch(content);
    if (match == null) return [];

    final arrayContent = match.group(1) ?? '';
    return RegExp(r'"([^"]+)"')
        .allMatches(arrayContent)
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

/// Priority-based router.
///
/// Routes to skills based on priority levels and conditions.
class PriorityRouter implements SkillRouter {
  /// Priority rules.
  final List<PriorityRule> rules;

  /// Fallback router.
  final SkillRouter? fallback;

  PriorityRouter({
    required this.rules,
    this.fallback,
  });

  @override
  Future<List<SkillBundle>> route(
    SkillContext context,
    List<SkillBundle> availableSkills,
  ) async {
    // Sort rules by priority (higher first)
    final sortedRules = rules.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in sortedRules) {
      if (rule.condition(context)) {
        final matches = availableSkills.where(
          (bundle) => bundle.skills.any((s) => rule.skillIds.contains(s.id))
        ).toList();
        if (matches.isNotEmpty) return matches;
      }
    }

    // Use fallback if no rules matched
    if (fallback != null) {
      return fallback!.route(context, availableSkills);
    }

    return [];
  }
}

/// Priority routing rule.
class PriorityRule {
  /// Rule identifier.
  final String id;

  /// Priority level (higher = more important).
  final int priority;

  /// Condition function.
  final bool Function(SkillContext) condition;

  /// Skill IDs to route to.
  final List<String> skillIds;

  const PriorityRule({
    required this.id,
    required this.priority,
    required this.condition,
    required this.skillIds,
  });
}

/// Composite router that combines multiple routing strategies.
class CompositeRouter implements SkillRouter {
  /// List of routers to try in order.
  final List<SkillRouter> routers;

  /// Whether to merge results from all routers.
  final bool mergeResults;

  CompositeRouter({
    required this.routers,
    this.mergeResults = false,
  });

  @override
  Future<List<SkillBundle>> route(
    SkillContext context,
    List<SkillBundle> availableSkills,
  ) async {
    if (mergeResults) {
      // Collect results from all routers
      final allResults = <SkillBundle>[];
      final seenIds = <String>{};

      for (final router in routers) {
        final results = await router.route(context, availableSkills);
        for (final bundle in results) {
          if (!seenIds.contains(bundle.bundleId)) {
            seenIds.add(bundle.bundleId);
            allResults.add(bundle);
          }
        }
      }

      return allResults;
    } else {
      // Return first non-empty result
      for (final router in routers) {
        final results = await router.route(context, availableSkills);
        if (results.isNotEmpty) return results;
      }
      return [];
    }
  }
}

/// Router that filters skills based on workspace access.
class WorkspaceRouter implements SkillRouter {
  /// Workspace to skill mapping.
  final Map<String, List<String>> workspaceSkills;

  /// Inner router.
  final SkillRouter inner;

  WorkspaceRouter({
    required this.workspaceSkills,
    required this.inner,
  });

  @override
  Future<List<SkillBundle>> route(
    SkillContext context,
    List<SkillBundle> availableSkills,
  ) async {
    // Filter bundles by workspace
    final allowedSkillIds = workspaceSkills[context.workspaceId] ?? [];
    final filteredBundles = availableSkills.where((bundle) {
      if (allowedSkillIds.isEmpty) return true;
      return bundle.skills.any((s) => allowedSkillIds.contains(s.id));
    }).toList();

    // Route with filtered list
    return inner.route(context, filteredBundles);
  }
}
