/// SkillRegistryPortAdapter - Implements mcp_bundle's SkillRegistryPort.
///
/// Exposes `mcp_skill`'s `SkillBundleRegistry` as a `SkillRegistryPort`
/// (the capability-named standard port defined in `mcp_bundle`). Added
/// as part of REDESIGN-PLAN Phase 4 §3.1.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;

import '../bundle/skill_bundle.dart';
import '../definition/procedure.dart';
import '../definition/step.dart';
import '../registry/skill_registry.dart';

/// Adapter that implements [bundle.SkillRegistryPort] over
/// `SkillBundleRegistry`.
class SkillRegistryPortAdapter implements bundle.SkillRegistryPort {
  final SkillBundleRegistry _registry;

  SkillRegistryPortAdapter({required SkillBundleRegistry registry})
      : _registry = registry;

  @override
  Future<void> registerBundle(bundle.BundleDescriptor descriptor) async {
    final manifest = SkillManifest(
      id: descriptor.id,
      name: descriptor.name,
      version: descriptor.version,
      provider: descriptor.metadata['provider'] as String? ?? 'adapter',
      description: descriptor.metadata['description'] as String? ?? '',
    );

    final skillBundle = SkillBundle(
      schemaVersion: descriptor.metadata['schemaVersion'] as String? ?? '0.1.0',
      manifest: manifest,
      procedures: [_placeholderProcedure(descriptor.id)],
    );

    await _registry.registerSkill(skillBundle);
  }

  @override
  Future<bundle.BundleDescriptor?> getBundle(String id) async {
    final skill = await _registry.getSkill(id);
    if (skill == null) return null;
    return _toDescriptor(skill);
  }

  @override
  Future<List<bundle.BundleDescriptor>> listBundles() async {
    final skills = await _registry.listSkills();
    return skills.map(_toDescriptor).toList();
  }

  @override
  Future<void> unregister(String id) async {
    await _registry.unregisterSkill(id);
  }

  bundle.BundleDescriptor _toDescriptor(SkillBundle skill) {
    return bundle.BundleDescriptor(
      id: skill.manifest.id,
      name: skill.manifest.name,
      version: skill.manifest.version,
      skillIds: [skill.manifest.id],
      metadata: {
        'provider': skill.manifest.provider,
        'description': skill.manifest.description,
        'schemaVersion': skill.schemaVersion,
      },
    );
  }

  Procedure _placeholderProcedure(String bundleId) {
    return Procedure(
      id: 'default',
      name: 'default',
      description: 'Auto-generated default procedure for $bundleId',
      steps: const [
        Step(
          id: 'noop',
          order: 0,
          name: 'noop',
          action: StepAction(type: 'transform', expression: 'inputs'),
        ),
      ],
    );
  }
}
