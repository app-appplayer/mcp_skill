/// Skill Router - Routes requests to appropriate skills.
///
/// Implements capability-based and LLM-based routing strategies.
library;

import '../registry/skill_registry.dart';
import '../bundle/skill_bundle.dart';
import '../ports/llm_port.dart';
import 'skill_context.dart';


/// Abstract skill router interface.
abstract class SkillRouter {
  /// Route a context to one or more skills.
  Future<List<String>> route(SkillContext context);
}

/// Capability-based router - routes based on skill capabilities.
class CapabilityRouter implements SkillRouter {
  final SkillBundleRegistry registry;

  CapabilityRouter({required this.registry});

  @override
  Future<List<String>> route(SkillContext context) async {
    // Get all available skills
    final skills = await registry.listSkills(workspaceId: context.workspaceId);

    // Filter skills by capability matching
    final matched = <String>[];

    for (final skill in skills) {
      if (_matchesCapability(skill, context)) {
        matched.add(skill.manifest.id);
      }
    }

    // If no matches, return empty (will trigger fallback)
    if (matched.isEmpty) {
      return [];
    }

    // Return matched skills (sorted by priority if available)
    return matched;
  }

  bool _matchesCapability(SkillBundle skill, SkillContext context) {
    final query = context.request.toLowerCase();
    final skillName = skill.manifest.name.toLowerCase();
    final skillDesc = (skill.manifest.description ?? '').toLowerCase();

    // Simple keyword matching
    return skillName.contains(query) || skillDesc.contains(query);
  }
}

/// LLM-based router - uses LLM to select appropriate skills.
class LlmRouter implements SkillRouter {
  final SkillBundleRegistry registry;
  final LlmPort llmPort;

  LlmRouter({
    required this.registry,
    required this.llmPort,
  });

  @override
  Future<List<String>> route(SkillContext context) async {
    // Get all available skills
    final skills = await registry.listSkills(workspaceId: context.workspaceId);

    if (skills.isEmpty) {
      return [];
    }

    // Build skill catalog for LLM
    final skillCatalog = skills.map((skill) {
      return {
        'id': skill.manifest.id,
        'name': skill.manifest.name,
        'description': skill.manifest.description,
        'capabilities': skill.manifest.capabilities ?? [],
      };
    }).toList();

    // Build prompt for LLM routing
    final prompt = _buildRoutingPrompt(context.request, skillCatalog);

    // Call LLM to select skills
    try {
      final response = await llmPort.complete(
        LlmRequest(
          messages: [
            LlmMessage.system(
              'You are a skill router. Select the most appropriate skill(s) '
              'for the given user request. Respond with a JSON array of skill IDs.',
            ),
            LlmMessage.user(prompt),
          ],
          temperature: 0.0, // Deterministic routing
          maxTokens: 500,
        ),
      );

      // Parse LLM response to extract skill IDs
      final selectedSkills = _parseRoutingResponse(response.content);

      return selectedSkills;
    } catch (e) {
      // Fallback to first skill if LLM routing fails
      return skills.isNotEmpty ? [skills.first.manifest.id] : [];
    }
  }

  String _buildRoutingPrompt(
      String request, List<Map<String, dynamic>> catalog) {
    final buffer = StringBuffer();
    buffer.writeln('User Request: $request');
    buffer.writeln();
    buffer.writeln('Available Skills:');

    for (var i = 0; i < catalog.length; i++) {
      final skill = catalog[i];
      buffer.writeln('${i + 1}. ${skill['name']} (ID: ${skill['id']})');
      buffer.writeln('   Description: ${skill['description']}');
      if (skill['capabilities'] is List &&
          (skill['capabilities'] as List).isNotEmpty) {
        buffer
            .writeln('   Capabilities: ${(skill['capabilities'] as List).join(', ')}');
      }
      buffer.writeln();
    }

    buffer.writeln('Select the skill(s) that best match the request.');
    buffer.writeln('Respond with a JSON array of skill IDs, e.g.: ["skill-1", "skill-2"]');

    return buffer.toString();
  }

  List<String> _parseRoutingResponse(String response) {
    try {
      // Extract JSON array from response
      final jsonMatch = RegExp(r'\[(.*?)\]').firstMatch(response);
      if (jsonMatch == null) {
        return [];
      }

      final jsonStr = jsonMatch.group(0)!;
      // Simple JSON parsing (assumes well-formed array of strings)
      final skillIds = jsonStr
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      return skillIds;
    } catch (e) {
      return [];
    }
  }
}

/// Composite router - tries multiple routing strategies in sequence.
class CompositeRouter implements SkillRouter {
  final List<SkillRouter> routers;

  CompositeRouter(this.routers);

  @override
  Future<List<String>> route(SkillContext context) async {
    for (final router in routers) {
      final result = await router.route(context);
      if (result.isNotEmpty) {
        return result;
      }
    }
    return [];
  }
}

/// Fixed router - always returns the same skills.
class FixedRouter implements SkillRouter {
  final List<String> skillIds;

  FixedRouter(this.skillIds);

  @override
  Future<List<String>> route(SkillContext context) async {
    return skillIds;
  }
}

/// Conditional router - routes based on conditions.
class ConditionalRouter implements SkillRouter {
  final Map<bool Function(SkillContext), SkillRouter> conditions;
  final SkillRouter? defaultRouter;

  ConditionalRouter({
    required this.conditions,
    this.defaultRouter,
  });

  @override
  Future<List<String>> route(SkillContext context) async {
    for (final entry in conditions.entries) {
      if (entry.key(context)) {
        return await entry.value.route(context);
      }
    }

    if (defaultRouter != null) {
      return await defaultRouter!.route(context);
    }

    return [];
  }
}

/// Router builder for fluent construction.
class RouterBuilder {
  final List<SkillRouter> _routers = [];

  /// Add a capability-based router.
  RouterBuilder withCapabilityRouting(SkillBundleRegistry registry) {
    _routers.add(CapabilityRouter(registry: registry));
    return this;
  }

  /// Add an LLM-based router.
  RouterBuilder withLlmRouting({
    required SkillBundleRegistry registry,
    required LlmPort llmPort,
  }) {
    _routers.add(LlmRouter(registry: registry, llmPort: llmPort));
    return this;
  }

  /// Add a fixed router as fallback.
  RouterBuilder withFallback(List<String> skillIds) {
    _routers.add(FixedRouter(skillIds));
    return this;
  }

  /// Add a custom router.
  RouterBuilder withCustom(SkillRouter router) {
    _routers.add(router);
    return this;
  }

  /// Build the final router.
  SkillRouter build() {
    if (_routers.isEmpty) {
      throw StateError('No routers configured');
    }
    if (_routers.length == 1) {
      return _routers.first;
    }
    return CompositeRouter(_routers);
  }
}
