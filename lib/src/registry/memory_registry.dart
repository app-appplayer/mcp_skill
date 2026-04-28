/// Memory-based implementation of SkillBundleRegistry.
///
/// Stores skill bundles in memory for development and testing.
library;

import '../bundle/skill_bundle.dart';
import 'skill_registry.dart';

/// In-memory implementation of [SkillBundleRegistry].
class MemorySkillRegistry implements SkillBundleRegistry {
  final Map<String, SkillBundle> _bundles = {};
  final Map<String, bool> _enabled = {};
  final Map<String, Set<String>> _workspaceEnabled = {};

  @override
  Future<List<SkillBundle>> listSkills({String? workspaceId}) async {
    if (workspaceId == null) {
      return _bundles.values.toList();
    }

    // Filter by workspace-level enablement
    return _bundles.values.where((bundle) {
      final skillId = bundle.manifest.id;
      return _isEnabledForWorkspace(skillId, workspaceId);
    }).toList();
  }

  @override
  Future<SkillBundle?> getSkill(String skillId) async {
    return _bundles[skillId];
  }

  @override
  Future<void> registerSkill(SkillBundle bundle) async {
    final id = bundle.manifest.id;
    _bundles[id] = bundle;
    _enabled.putIfAbsent(id, () => true);
  }

  @override
  Future<void> unregisterSkill(String skillId) async {
    _bundles.remove(skillId);
    _enabled.remove(skillId);
    _workspaceEnabled.remove(skillId);
  }

  @override
  Future<bool> isEnabled(String skillId, {String? workspaceId}) async {
    if (workspaceId != null) {
      return _isEnabledForWorkspace(skillId, workspaceId);
    }
    return _enabled[skillId] ?? false;
  }

  @override
  Future<void> setEnabled(String skillId, bool enabled,
      {String? workspaceId}) async {
    if (workspaceId != null) {
      final workspaceSet =
          _workspaceEnabled.putIfAbsent(skillId, () => <String>{});
      if (enabled) {
        workspaceSet.add(workspaceId);
      } else {
        workspaceSet.remove(workspaceId);
      }
    } else {
      _enabled[skillId] = enabled;
    }
  }

  /// Get count of registered bundles.
  int get count => _bundles.length;

  /// Check if a bundle exists.
  bool has(String skillId) => _bundles.containsKey(skillId);

  /// Clear all registered bundles.
  void clear() {
    _bundles.clear();
    _enabled.clear();
    _workspaceEnabled.clear();
  }

  bool _isEnabledForWorkspace(String skillId, String workspaceId) {
    // Check workspace-specific override first
    final workspaceSet = _workspaceEnabled[skillId];
    if (workspaceSet != null) {
      return workspaceSet.contains(workspaceId);
    }
    // Fall back to global enablement
    return _enabled[skillId] ?? false;
  }
}
