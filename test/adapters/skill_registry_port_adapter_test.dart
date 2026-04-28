/// Tests for SkillRegistryPortAdapter — REDESIGN-PLAN Phase 4.
library;

import 'package:mcp_bundle/mcp_bundle.dart' as bundle;
import 'package:test/test.dart';

import 'package:mcp_skill/src/adapters/skill_registry_port_adapter.dart';

import '../helpers/mock_registry.dart';

void main() {
  group('SkillRegistryPortAdapter', () {
    late MockSkillBundleRegistry registry;
    late SkillRegistryPortAdapter adapter;

    setUp(() {
      registry = MockSkillBundleRegistry();
      adapter = SkillRegistryPortAdapter(registry: registry);
    });

    test('registerBundle stores a SkillBundle under the descriptor id',
        () async {
      final descriptor = bundle.BundleDescriptor(
        id: 'bundle-1',
        name: 'Bundle One',
        version: '1.0.0',
        metadata: const {
          'provider': 'acme',
          'description': 'Test bundle',
        },
      );

      await adapter.registerBundle(descriptor);

      final stored = await registry.getSkill('bundle-1');
      expect(stored, isNotNull);
      expect(stored!.manifest.id, equals('bundle-1'));
      expect(stored.manifest.name, equals('Bundle One'));
      expect(stored.manifest.version, equals('1.0.0'));
      expect(stored.manifest.provider, equals('acme'));
      expect(stored.manifest.description, equals('Test bundle'));
    });

    test('getBundle returns a BundleDescriptor for a registered id',
        () async {
      await adapter.registerBundle(
        const bundle.BundleDescriptor(
          id: 'bundle-2',
          name: 'Bundle Two',
          version: '2.0.0',
        ),
      );

      final descriptor = await adapter.getBundle('bundle-2');

      expect(descriptor, isNotNull);
      expect(descriptor!.id, equals('bundle-2'));
      expect(descriptor.name, equals('Bundle Two'));
      expect(descriptor.version, equals('2.0.0'));
      expect(descriptor.skillIds, equals(['bundle-2']));
      expect(descriptor.metadata['provider'], isNotNull);
      expect(descriptor.metadata['schemaVersion'], isNotNull);
    });

    test('getBundle returns null for unknown id', () async {
      final descriptor = await adapter.getBundle('nope');
      expect(descriptor, isNull);
    });

    test('listBundles projects every registered skill', () async {
      await adapter.registerBundle(
        const bundle.BundleDescriptor(
          id: 'a',
          name: 'A',
          version: '1.0.0',
        ),
      );
      await adapter.registerBundle(
        const bundle.BundleDescriptor(
          id: 'b',
          name: 'B',
          version: '1.0.0',
        ),
      );

      final descriptors = await adapter.listBundles();

      expect(descriptors, hasLength(2));
      final ids = descriptors.map((d) => d.id).toSet();
      expect(ids, equals({'a', 'b'}));
    });

    test('unregister removes the bundle', () async {
      await adapter.registerBundle(
        const bundle.BundleDescriptor(
          id: 'to-drop',
          name: 'Drop',
          version: '1.0.0',
        ),
      );
      expect(await adapter.getBundle('to-drop'), isNotNull);

      await adapter.unregister('to-drop');

      expect(await adapter.getBundle('to-drop'), isNull);
    });

    test('registerBundle fills default metadata when descriptor omits it',
        () async {
      await adapter.registerBundle(
        const bundle.BundleDescriptor(
          id: 'minimal',
          name: 'Minimal',
          version: '0.1.0',
        ),
      );

      final stored = await registry.getSkill('minimal');
      expect(stored, isNotNull);
      expect(stored!.manifest.provider, equals('adapter'));
      expect(stored.manifest.description, equals(''));
      expect(stored.schemaVersion, equals('0.1.0'));
    });
  });
}
