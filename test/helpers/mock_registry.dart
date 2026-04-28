/// Mock registry implementations for testing.
library;

import 'package:mcp_skill/src/bundle/skill_bundle.dart';
import 'package:mcp_skill/src/registry/skill_registry.dart';

/// Mock implementation of [SkillBundleRegistry] for testing.
///
/// Stores bundles in memory and allows configuring error behavior.
class MockSkillBundleRegistry implements SkillBundleRegistry {
  final Map<String, SkillBundle> _bundles = {};
  final Map<String, bool> _enabled = {};

  /// Optional error to throw on next operation.
  Object? nextError;

  /// Track method calls for assertions.
  final List<String> callLog = [];

  @override
  Future<List<SkillBundle>> listSkills({String? workspaceId}) async {
    callLog.add('listSkills');
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    return _bundles.values.toList();
  }

  @override
  Future<SkillBundle?> getSkill(String skillId) async {
    callLog.add('getSkill:$skillId');
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    return _bundles[skillId];
  }

  @override
  Future<void> registerSkill(SkillBundle bundle) async {
    callLog.add('registerSkill:${bundle.manifest.id}');
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    _bundles[bundle.manifest.id] = bundle;
    _enabled.putIfAbsent(bundle.manifest.id, () => true);
  }

  @override
  Future<void> unregisterSkill(String skillId) async {
    callLog.add('unregisterSkill:$skillId');
    if (nextError != null) {
      final err = nextError!;
      nextError = null;
      throw err;
    }
    _bundles.remove(skillId);
    _enabled.remove(skillId);
  }

  @override
  Future<bool> isEnabled(String skillId, {String? workspaceId}) async {
    callLog.add('isEnabled:$skillId');
    return _enabled[skillId] ?? false;
  }

  @override
  Future<void> setEnabled(String skillId, bool enabled,
      {String? workspaceId}) async {
    callLog.add('setEnabled:$skillId:$enabled');
    _enabled[skillId] = enabled;
  }

  /// Number of registered bundles.
  int get count => _bundles.length;

  /// Check if a bundle exists.
  bool has(String skillId) => _bundles.containsKey(skillId);

  /// Clear all state.
  void clear() {
    _bundles.clear();
    _enabled.clear();
    callLog.clear();
    nextError = null;
  }
}
