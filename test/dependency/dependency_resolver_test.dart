import 'package:test/test.dart';
import 'package:mcp_skill/src/dependency/dependency_resolver.dart';
import 'package:mcp_skill/src/dependency/dependency_graph.dart';
import 'package:mcp_skill/src/dependency/lock_file.dart';
import 'package:mcp_skill/src/dependency/version_constraint.dart';

void main() {
  group('InMemoryPackageRegistry', () {
    late InMemoryPackageRegistry registry;

    setUp(() {
      registry = InMemoryPackageRegistry();
    });

    test('register and getVersions returns registered versions', () async {
      registry.register(PackageSpec(
        name: 'foo',
        version: SemanticVersion.parse('1.0.0'),
      ));
      registry.register(PackageSpec(
        name: 'foo',
        version: SemanticVersion.parse('2.0.0'),
      ));

      final versions = await registry.getVersions('foo');
      expect(versions.length, 2);
      // Descending order
      expect(versions.first, SemanticVersion.parse('2.0.0'));
      expect(versions.last, SemanticVersion.parse('1.0.0'));
    });

    test('getVersions returns empty list for unknown package', () async {
      final versions = await registry.getVersions('unknown');
      expect(versions, isEmpty);
    });

    test('getSpec returns registered spec', () async {
      final spec = PackageSpec(
        name: 'bar',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'baz': VersionConstraint.parse('^1.0.0')},
      );
      registry.register(spec);

      final result =
          await registry.getSpec('bar', SemanticVersion.parse('1.0.0'));
      expect(result, isNotNull);
      expect(result!.name, 'bar');
      expect(result.dependencies.containsKey('baz'), true);
    });

    test('getSpec returns null for unknown version', () async {
      registry.register(PackageSpec(
        name: 'bar',
        version: SemanticVersion.parse('1.0.0'),
      ));

      final result =
          await registry.getSpec('bar', SemanticVersion.parse('2.0.0'));
      expect(result, isNull);
    });

    test('exists returns true for registered package', () async {
      registry.register(PackageSpec(
        name: 'existing',
        version: SemanticVersion.parse('1.0.0'),
      ));
      expect(await registry.exists('existing'), true);
    });

    test('exists returns false for unknown package', () async {
      expect(await registry.exists('nope'), false);
    });
  });

  group('ResolutionConfig', () {
    test('default values', () {
      const config = ResolutionConfig();
      expect(config.strategy, VersionSelectionStrategy.preferLocked);
      expect(config.allowPrerelease, false);
      expect(config.includeDevDependencies, true);
      expect(config.timeout, const Duration(minutes: 5));
      expect(config.forceUpgrade, false);
    });
  });

  group('ResolutionResult', () {
    test('success factory creates successful result', () {
      final result = ResolutionResult.success(
        graph: const DependencyGraph(),
        lockFile: LockFile.empty(),
        metrics: const ResolutionMetrics(
          duration: Duration.zero,
          versionsConsidered: 5,
          backtrackCount: 1,
        ),
      );
      expect(result.success, true);
      expect(result.graph, isNotNull);
      expect(result.lockFile, isNotNull);
      expect(result.error, isNull);
    });

    test('failure factory creates failed result', () {
      final result = ResolutionResult.failure(
        error: const ResolutionError(
          type: ResolutionErrorType.packageNotFound,
          message: 'not found',
          packages: ['missing'],
        ),
        metrics: const ResolutionMetrics(
          duration: Duration.zero,
          versionsConsidered: 0,
          backtrackCount: 0,
        ),
      );
      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.error!.type, ResolutionErrorType.packageNotFound);
      expect(result.graph, isNull);
    });

    test('fromLock creates result from lock file', () {
      final result = ResolutionResult.fromLock(LockFile.empty());
      expect(result.success, true);
      expect(result.lockFile, isNotNull);
    });
  });

  group('PackageSpec', () {
    test('toJson produces correct map', () {
      final spec = PackageSpec(
        name: 'test_pkg',
        version: SemanticVersion.parse('1.2.3'),
        dependencies: {'dep1': VersionConstraint.parse('^1.0.0')},
        devDependencies: {'test': VersionConstraint.parse('^2.0.0')},
      );
      final json = spec.toJson();
      expect(json['name'], 'test_pkg');
      expect(json['version'], '1.2.3');
      expect(json['dependencies'], isA<Map>());
      expect(json['devDependencies'], isA<Map>());
    });
  });

  group('PubGrubResolver', () {
    late InMemoryPackageRegistry registry;
    late PubGrubResolver resolver;

    setUp(() {
      registry = InMemoryPackageRegistry();
      resolver = PubGrubResolver(registry: registry);
    });

    test('simple resolution: A depends on B', () async {
      // Register package B version 1.0.0
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.0.0'),
      ));

      // Root package A depends on B ^1.0.0
      final rootSpec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'B': VersionConstraint.parse('^1.0.0')},
      );

      final result = await resolver.resolve(rootSpec);
      expect(result.success, true);
      expect(result.graph, isNotNull);

      // Graph should contain B
      final bNode = result.graph!.getNode('B');
      expect(bNode, isNotNull);
      expect(bNode!.id.version, SemanticVersion.parse('1.0.0'));
    });

    test('diamond dependency resolves correctly', () async {
      // B 1.0.0 depends on D ^1.0.0
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'D': VersionConstraint.parse('^1.0.0')},
      ));

      // C 1.0.0 depends on D ^1.0.0
      registry.register(PackageSpec(
        name: 'C',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'D': VersionConstraint.parse('^1.0.0')},
      ));

      // D 1.0.0 (no deps)
      registry.register(PackageSpec(
        name: 'D',
        version: SemanticVersion.parse('1.0.0'),
      ));

      // Root A depends on B and C
      final rootSpec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {
          'B': VersionConstraint.parse('^1.0.0'),
          'C': VersionConstraint.parse('^1.0.0'),
        },
      );

      final result = await resolver.resolve(rootSpec);
      expect(result.success, true);
      // D should be resolved
      expect(result.graph!.getNode('D'), isNotNull);
    });

    test('conflict detection when no compatible version exists', () async {
      // No versions of 'missing' are registered
      final rootSpec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'missing': VersionConstraint.parse('^1.0.0')},
      );

      final result = await resolver.resolve(rootSpec);
      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.error!.type, ResolutionErrorType.versionIncompatible);
    });

    test('resolution with version ranges picks compatible version', () async {
      // Register multiple versions of B
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.0.0'),
      ));
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.5.0'),
      ));
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('2.0.0'),
      ));

      // Root depends on B >=1.0.0 <2.0.0
      final rootSpec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {
          'B': VersionConstraint.parse('>=1.0.0 <2.0.0'),
        },
      );

      final result = await resolver.resolve(rootSpec);
      expect(result.success, true);
      final bNode = result.graph!.getNode('B');
      expect(bNode, isNotNull);
      // Should pick latest compatible version (1.5.0)
      expect(bNode!.id.version, SemanticVersion.parse('1.5.0'));
    });

    test('check returns possible for valid dependencies', () async {
      registry.register(PackageSpec(
        name: 'dep',
        version: SemanticVersion.parse('1.0.0'),
      ));

      final spec = PackageSpec(
        name: 'root',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'dep': VersionConstraint.parse('^1.0.0')},
      );

      final check = await resolver.check(spec);
      expect(check.possible, true);
      expect(check.issues, isEmpty);
    });

    test('check returns issues for missing package', () async {
      final spec = PackageSpec(
        name: 'root',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'missing': VersionConstraint.parse('^1.0.0')},
      );

      final check = await resolver.check(spec);
      expect(check.possible, false);
      expect(check.issues.first, contains('not found'));
    });

    test('check returns issues for incompatible constraint', () async {
      registry.register(PackageSpec(
        name: 'old',
        version: SemanticVersion.parse('0.1.0'),
      ));

      final spec = PackageSpec(
        name: 'root',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'old': VersionConstraint.parse('^1.0.0')},
      );

      final check = await resolver.check(spec);
      expect(check.possible, false);
      expect(check.issues.first, contains('No compatible version'));
    });

    test('getTree returns tree for resolvable spec', () async {
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.0.0'),
      ));

      final spec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'B': VersionConstraint.parse('^1.0.0')},
      );

      final tree = await resolver.getTree(spec);
      expect(tree.root.name, 'A');
    });

    test('suggestFixes returns suggestions for version incompatible', () async {
      const error = ResolutionError(
        type: ResolutionErrorType.versionIncompatible,
        message: 'test',
      );
      final fixes = await resolver.suggestFixes(error);
      expect(fixes, isNotEmpty);
      expect(fixes.first.action, 'update_constraints');
    });

    test('suggestFixes returns suggestions for package not found', () async {
      const error = ResolutionError(
        type: ResolutionErrorType.packageNotFound,
        message: 'test',
      );
      final fixes = await resolver.suggestFixes(error);
      expect(fixes, isNotEmpty);
      expect(fixes.first.action, 'verify_package');
    });

    test('suggestFixes returns suggestions for cyclic dependency', () async {
      const error = ResolutionError(
        type: ResolutionErrorType.cyclicDependency,
        message: 'test',
      );
      final fixes = await resolver.suggestFixes(error);
      expect(fixes, isNotEmpty);
      expect(fixes.first.action, 'refactor');
    });

    test('generates lock file on successful resolution', () async {
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.0.0'),
      ));

      final rootSpec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'B': VersionConstraint.parse('^1.0.0')},
      );

      final result = await resolver.resolve(rootSpec);
      expect(result.success, true);
      expect(result.lockFile, isNotNull);
      expect(result.lockFile!.isLocked('B'), true);
    });

    test('resolution metrics are populated', () async {
      registry.register(PackageSpec(
        name: 'B',
        version: SemanticVersion.parse('1.0.0'),
      ));

      final rootSpec = PackageSpec(
        name: 'A',
        version: SemanticVersion.parse('1.0.0'),
        dependencies: {'B': VersionConstraint.parse('^1.0.0')},
      );

      final result = await resolver.resolve(rootSpec);
      expect(result.metrics.versionsConsidered, greaterThan(0));
    });
  });

  group('ResolutionError', () {
    test('stores all fields', () {
      const error = ResolutionError(
        type: ResolutionErrorType.timeout,
        message: 'took too long',
        packages: ['a', 'b'],
      );
      expect(error.type, ResolutionErrorType.timeout);
      expect(error.message, 'took too long');
      expect(error.packages, ['a', 'b']);
      expect(error.conflictPaths, isNull);
      expect(error.suggestions, isEmpty);
    });
  });

  group('ResolutionWarning', () {
    test('stores message and optional package', () {
      const warning = ResolutionWarning(
        message: 'deprecated package',
        packageName: 'old_pkg',
      );
      expect(warning.message, 'deprecated package');
      expect(warning.packageName, 'old_pkg');
    });
  });
}
