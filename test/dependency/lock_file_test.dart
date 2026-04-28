import 'package:test/test.dart';
import 'package:mcp_skill/src/dependency/lock_file.dart';
import 'package:mcp_skill/src/dependency/version_constraint.dart';
import 'package:mcp_skill/src/dependency/dependency_graph.dart';

void main() {
  group('LockFileEntry', () {
    test('constructor stores all fields', () {
      final entry = LockFileEntry(
        name: 'foo',
        version: SemanticVersion.parse('1.2.3'),
        source: 'registry',
        resolved: 'https://pub.dev',
        gitRef: 'abc123',
        checksum: 'sha256:xyz',
        dependencies: {'bar': '^1.0.0'},
      );
      expect(entry.name, 'foo');
      expect(entry.version, SemanticVersion.parse('1.2.3'));
      expect(entry.source, 'registry');
      expect(entry.resolved, 'https://pub.dev');
      expect(entry.gitRef, 'abc123');
      expect(entry.checksum, 'sha256:xyz');
      expect(entry.dependencies, {'bar': '^1.0.0'});
    });

    test('defaults: resolved, gitRef, checksum are null, dependencies empty', () {
      final entry = LockFileEntry(
        name: 'foo',
        version: SemanticVersion.parse('1.0.0'),
        source: 'registry',
      );
      expect(entry.resolved, isNull);
      expect(entry.gitRef, isNull);
      expect(entry.checksum, isNull);
      expect(entry.dependencies, isEmpty);
    });

    test('toJson produces correct map', () {
      final entry = LockFileEntry(
        name: 'foo',
        version: SemanticVersion.parse('1.0.0'),
        source: 'git',
        resolved: 'https://github.com/foo',
        gitRef: 'main',
        checksum: 'abc',
        dependencies: {'dep1': '^1.0.0'},
      );
      final json = entry.toJson();
      expect(json['version'], '1.0.0');
      expect(json['source'], 'git');
      expect(json['resolved'], 'https://github.com/foo');
      expect(json['ref'], 'main');
      expect(json['checksum'], 'abc');
      expect(json['dependencies'], {'dep1': '^1.0.0'});
    });

    test('toJson omits null and empty fields', () {
      final entry = LockFileEntry(
        name: 'foo',
        version: SemanticVersion.parse('1.0.0'),
        source: 'registry',
      );
      final json = entry.toJson();
      expect(json.containsKey('resolved'), false);
      expect(json.containsKey('ref'), false);
      expect(json.containsKey('checksum'), false);
      expect(json.containsKey('dependencies'), false);
    });

    test('fromJson parses correctly', () {
      final entry = LockFileEntry.fromJson('bar', {
        'version': '2.1.0',
        'source': 'registry',
        'resolved': 'https://pub.dev/bar',
        'ref': 'v2',
        'checksum': 'sha256:aaa',
        'dependencies': {'baz': '^1.0.0'},
      });
      expect(entry.name, 'bar');
      expect(entry.version, SemanticVersion.parse('2.1.0'));
      expect(entry.source, 'registry');
      expect(entry.resolved, 'https://pub.dev/bar');
      expect(entry.gitRef, 'v2');
      expect(entry.checksum, 'sha256:aaa');
      expect(entry.dependencies, {'baz': '^1.0.0'});
    });

    test('fromJson handles missing optional fields', () {
      final entry = LockFileEntry.fromJson('minimal', {
        'version': '1.0.0',
        'source': 'path',
      });
      expect(entry.name, 'minimal');
      expect(entry.resolved, isNull);
      expect(entry.gitRef, isNull);
      expect(entry.checksum, isNull);
      expect(entry.dependencies, isEmpty);
    });

    test('toJson/fromJson round-trip', () {
      final original = LockFileEntry(
        name: 'pkg',
        version: SemanticVersion.parse('3.0.0'),
        source: 'registry',
        resolved: 'https://example.com',
        checksum: 'hash123',
        dependencies: {'dep': '>=1.0.0'},
      );
      final json = original.toJson();
      final restored = LockFileEntry.fromJson('pkg', json);
      expect(restored.name, original.name);
      expect(restored.version, original.version);
      expect(restored.source, original.source);
      expect(restored.resolved, original.resolved);
      expect(restored.checksum, original.checksum);
      expect(restored.dependencies, original.dependencies);
    });
  });

  group('LockFile', () {
    test('constructor with defaults', () {
      final lockFile = LockFile(
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
      expect(lockFile.lockVersion, 1);
      expect(lockFile.packages, isEmpty);
    });

    test('empty factory creates lock file with no packages', () {
      final lockFile = LockFile.empty();
      expect(lockFile.packages, isEmpty);
      expect(lockFile.lockVersion, 1);
      expect(lockFile.metadata.resolverVersion, '1.0.0');
    });

    test('getVersion returns version for locked package', () {
      final lockFile = LockFile(
        packages: {
          'foo': LockFileEntry(
            name: 'foo',
            version: SemanticVersion.parse('1.2.3'),
            source: 'registry',
          ),
        },
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
      expect(lockFile.getVersion('foo'), SemanticVersion.parse('1.2.3'));
    });

    test('getVersion returns null for unlocked package', () {
      final lockFile = LockFile.empty();
      expect(lockFile.getVersion('missing'), isNull);
    });

    test('isLocked returns true for present package', () {
      final lockFile = LockFile(
        packages: {
          'foo': LockFileEntry(
            name: 'foo',
            version: SemanticVersion.parse('1.0.0'),
            source: 'registry',
          ),
        },
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
      expect(lockFile.isLocked('foo'), true);
      expect(lockFile.isLocked('bar'), false);
    });

    test('packageNames returns all locked package names', () {
      final lockFile = LockFile(
        packages: {
          'alpha': LockFileEntry(
            name: 'alpha',
            version: SemanticVersion.parse('1.0.0'),
            source: 'registry',
          ),
          'beta': LockFileEntry(
            name: 'beta',
            version: SemanticVersion.parse('2.0.0'),
            source: 'registry',
          ),
        },
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
      expect(lockFile.packageNames, containsAll(['alpha', 'beta']));
      expect(lockFile.packageNames.length, 2);
    });

    test('copyWith creates modified copy', () {
      final original = LockFile(
        lockVersion: 1,
        packages: {
          'foo': LockFileEntry(
            name: 'foo',
            version: SemanticVersion.parse('1.0.0'),
            source: 'registry',
          ),
        },
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
      final modified = original.copyWith(lockVersion: 2);
      expect(modified.lockVersion, 2);
      expect(modified.packages.length, 1);
    });

    test('toJson produces correct structure', () {
      final lockFile = LockFile(
        lockVersion: 1,
        packages: {
          'pkg': LockFileEntry(
            name: 'pkg',
            version: SemanticVersion.parse('1.0.0'),
            source: 'registry',
          ),
        },
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
      final json = lockFile.toJson();
      expect(json['lockVersion'], 1);
      expect(json['packages'], isA<Map>());
      expect((json['packages'] as Map).containsKey('pkg'), true);
      expect(json['metadata'], isA<Map>());
    });

    test('fromJson parses correctly', () {
      final json = {
        'lockVersion': 1,
        'packages': {
          'foo': {
            'version': '2.0.0',
            'source': 'registry',
          },
        },
        'metadata': {
          'resolvedAt': '2026-01-01T00:00:00.000',
          'resolverVersion': '1.0.0',
        },
      };
      final lockFile = LockFile.fromJson(json);
      expect(lockFile.lockVersion, 1);
      expect(lockFile.isLocked('foo'), true);
      expect(lockFile.getVersion('foo'), SemanticVersion.parse('2.0.0'));
      expect(lockFile.metadata.resolverVersion, '1.0.0');
    });

    test('toJson/fromJson round-trip', () {
      final original = LockFile(
        lockVersion: 1,
        packages: {
          'alpha': LockFileEntry(
            name: 'alpha',
            version: SemanticVersion.parse('1.0.0'),
            source: 'registry',
            checksum: 'hash1',
          ),
          'beta': LockFileEntry(
            name: 'beta',
            version: SemanticVersion.parse('2.0.0'),
            source: 'git',
            gitRef: 'main',
            dependencies: {'alpha': '^1.0.0'},
          ),
        },
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 6, 15, 10, 30),
          resolverVersion: '1.0.0',
          dartSdkVersion: '3.0.0',
        ),
      );
      final json = original.toJson();
      final restored = LockFile.fromJson(json);

      expect(restored.lockVersion, original.lockVersion);
      expect(restored.packageNames.length, 2);
      expect(restored.getVersion('alpha'), SemanticVersion.parse('1.0.0'));
      expect(restored.getVersion('beta'), SemanticVersion.parse('2.0.0'));
      expect(restored.packages['alpha']!.checksum, 'hash1');
      expect(restored.packages['beta']!.gitRef, 'main');
      expect(restored.packages['beta']!.dependencies, {'alpha': '^1.0.0'});
      expect(restored.metadata.resolverVersion, '1.0.0');
      expect(restored.metadata.dartSdkVersion, '3.0.0');
    });

    test('fromJson handles missing packages key', () {
      final json = {
        'metadata': {
          'resolvedAt': '2026-01-01T00:00:00.000',
          'resolverVersion': '1.0.0',
        },
      };
      final lockFile = LockFile.fromJson(json);
      expect(lockFile.packages, isEmpty);
    });

    test('fromJson handles missing metadata key', () {
      final json = {
        'lockVersion': 1,
        'packages': <String, dynamic>{},
      };
      final lockFile = LockFile.fromJson(json);
      expect(lockFile.metadata.resolverVersion, '1.0.0');
    });
  });

  group('LockFileMetadata', () {
    test('stores all fields', () {
      final meta = LockFileMetadata(
        resolvedAt: DateTime(2026, 3, 15),
        resolverVersion: '2.0.0',
        dartSdkVersion: '3.1.0',
        flutterSdkVersion: '3.19.0',
      );
      expect(meta.resolvedAt, DateTime(2026, 3, 15));
      expect(meta.resolverVersion, '2.0.0');
      expect(meta.dartSdkVersion, '3.1.0');
      expect(meta.flutterSdkVersion, '3.19.0');
    });

    test('toJson produces correct map', () {
      final meta = LockFileMetadata(
        resolvedAt: DateTime(2026, 1, 1),
        resolverVersion: '1.0.0',
        dartSdkVersion: '3.0.0',
      );
      final json = meta.toJson();
      expect(json['resolvedAt'], '2026-01-01T00:00:00.000');
      expect(json['resolverVersion'], '1.0.0');
      expect(json['dartSdkVersion'], '3.0.0');
      expect(json.containsKey('flutterSdkVersion'), false);
    });

    test('fromJson parses correctly', () {
      final meta = LockFileMetadata.fromJson({
        'resolvedAt': '2026-06-01T12:00:00.000',
        'resolverVersion': '1.0.0',
        'dartSdkVersion': '3.2.0',
        'flutterSdkVersion': '3.20.0',
      });
      expect(meta.resolvedAt, DateTime(2026, 6, 1, 12, 0));
      expect(meta.resolverVersion, '1.0.0');
      expect(meta.dartSdkVersion, '3.2.0');
      expect(meta.flutterSdkVersion, '3.20.0');
    });

    test('toJson/fromJson round-trip', () {
      final original = LockFileMetadata(
        resolvedAt: DateTime(2026, 2, 20, 14, 30),
        resolverVersion: '1.5.0',
        dartSdkVersion: '3.3.0',
      );
      final json = original.toJson();
      final restored = LockFileMetadata.fromJson(json);
      expect(restored.resolvedAt, original.resolvedAt);
      expect(restored.resolverVersion, original.resolverVersion);
      expect(restored.dartSdkVersion, original.dartSdkVersion);
    });
  });

  group('LockFileDiff', () {
    LockFile _makeLockFile(Map<String, String> packages) {
      return LockFile(
        packages: packages.map((name, version) => MapEntry(
              name,
              LockFileEntry(
                name: name,
                version: SemanticVersion.parse(version),
                source: 'registry',
              ),
            )),
        metadata: LockFileMetadata(
          resolvedAt: DateTime(2026, 1, 1),
          resolverVersion: '1.0.0',
        ),
      );
    }

    test('between detects added packages', () {
      final previous = _makeLockFile({'foo': '1.0.0'});
      final current = _makeLockFile({'foo': '1.0.0', 'bar': '2.0.0'});
      final diff = LockFileDiff.between(current, previous);
      expect(diff.added.length, 1);
      expect(diff.added.first.name, 'bar');
      expect(diff.added.first.version, SemanticVersion.parse('2.0.0'));
    });

    test('between detects removed packages', () {
      final previous = _makeLockFile({'foo': '1.0.0', 'bar': '2.0.0'});
      final current = _makeLockFile({'foo': '1.0.0'});
      final diff = LockFileDiff.between(current, previous);
      expect(diff.removed.length, 1);
      expect(diff.removed.first.name, 'bar');
    });

    test('between detects upgraded packages', () {
      final previous = _makeLockFile({'foo': '1.0.0'});
      final current = _makeLockFile({'foo': '2.0.0'});
      final diff = LockFileDiff.between(current, previous);
      expect(diff.upgraded.length, 1);
      expect(diff.upgraded.first.name, 'foo');
      expect(diff.upgraded.first.from, SemanticVersion.parse('1.0.0'));
      expect(diff.upgraded.first.to, SemanticVersion.parse('2.0.0'));
    });

    test('between detects downgraded packages', () {
      final previous = _makeLockFile({'foo': '2.0.0'});
      final current = _makeLockFile({'foo': '1.0.0'});
      final diff = LockFileDiff.between(current, previous);
      expect(diff.downgraded.length, 1);
      expect(diff.downgraded.first.name, 'foo');
      expect(diff.downgraded.first.from, SemanticVersion.parse('2.0.0'));
      expect(diff.downgraded.first.to, SemanticVersion.parse('1.0.0'));
    });

    test('between detects no changes for identical lock files', () {
      final a = _makeLockFile({'foo': '1.0.0', 'bar': '2.0.0'});
      final b = _makeLockFile({'foo': '1.0.0', 'bar': '2.0.0'});
      final diff = LockFileDiff.between(a, b);
      expect(diff.hasChanges, false);
    });

    test('hasChanges reflects change state', () {
      const emptyDiff = LockFileDiff();
      expect(emptyDiff.hasChanges, false);

      final diff = LockFileDiff(
        added: [
          PackageChange(
            name: 'new',
            version: SemanticVersion.parse('1.0.0'),
          ),
        ],
      );
      expect(diff.hasChanges, true);
    });

    test('changeCount sums all changes', () {
      final diff = LockFileDiff(
        added: [
          PackageChange(name: 'a', version: SemanticVersion.parse('1.0.0')),
        ],
        removed: [
          PackageChange(name: 'b', version: SemanticVersion.parse('1.0.0')),
        ],
        upgraded: [
          PackageUpgrade(
            name: 'c',
            from: SemanticVersion.parse('1.0.0'),
            to: SemanticVersion.parse('2.0.0'),
          ),
        ],
        downgraded: [
          PackageDowngrade(
            name: 'd',
            from: SemanticVersion.parse('2.0.0'),
            to: SemanticVersion.parse('1.0.0'),
          ),
        ],
      );
      expect(diff.changeCount, 4);
    });

    test('toHumanReadable for no changes', () {
      const diff = LockFileDiff();
      final text = diff.toHumanReadable();
      expect(text, contains('No changes'));
    });

    test('toHumanReadable includes all change types', () {
      final diff = LockFileDiff(
        added: [
          PackageChange(name: 'new_pkg', version: SemanticVersion.parse('1.0.0')),
        ],
        removed: [
          PackageChange(name: 'old_pkg', version: SemanticVersion.parse('0.5.0')),
        ],
        upgraded: [
          PackageUpgrade(
            name: 'upgraded_pkg',
            from: SemanticVersion.parse('1.0.0'),
            to: SemanticVersion.parse('2.0.0'),
          ),
        ],
        downgraded: [
          PackageDowngrade(
            name: 'downgraded_pkg',
            from: SemanticVersion.parse('3.0.0'),
            to: SemanticVersion.parse('2.0.0'),
          ),
        ],
      );
      final text = diff.toHumanReadable();
      expect(text, contains('Added:'));
      expect(text, contains('new_pkg'));
      expect(text, contains('Removed:'));
      expect(text, contains('old_pkg'));
      expect(text, contains('Upgraded:'));
      expect(text, contains('upgraded_pkg'));
      expect(text, contains('Downgraded:'));
      expect(text, contains('downgraded_pkg'));
    });

    test('between handles complex scenario with mixed changes', () {
      final previous = _makeLockFile({
        'kept': '1.0.0',
        'upgraded': '1.0.0',
        'downgraded': '3.0.0',
        'removed': '1.0.0',
      });
      final current = _makeLockFile({
        'kept': '1.0.0',
        'upgraded': '2.0.0',
        'downgraded': '2.0.0',
        'added': '1.0.0',
      });
      final diff = LockFileDiff.between(current, previous);
      expect(diff.added.length, 1);
      expect(diff.removed.length, 1);
      expect(diff.upgraded.length, 1);
      expect(diff.downgraded.length, 1);
      expect(diff.changeCount, 4);
    });
  });

  group('LockVerification', () {
    test('success factory creates valid verification', () {
      final verification = LockVerification.success();
      expect(verification.valid, true);
      expect(verification.issues, isEmpty);
    });

    test('failure factory creates invalid verification with issues', () {
      final verification = LockVerification.failure([
        const LockVerificationIssue(
          type: LockVerificationIssueType.checksumMismatch,
          packageName: 'pkg',
          message: 'checksum does not match',
        ),
        const LockVerificationIssue(
          type: LockVerificationIssueType.packageNotFound,
          packageName: 'missing',
          message: 'package not found',
        ),
      ]);
      expect(verification.valid, false);
      expect(verification.issues.length, 2);
    });
  });

  group('LockVerificationIssue', () {
    test('stores all fields', () {
      const issue = LockVerificationIssue(
        type: LockVerificationIssueType.versionMismatch,
        packageName: 'foo',
        message: 'expected 1.0.0 but got 2.0.0',
      );
      expect(issue.type, LockVerificationIssueType.versionMismatch);
      expect(issue.packageName, 'foo');
      expect(issue.message, contains('expected'));
    });
  });

  group('LockVerificationIssueType', () {
    test('has all expected values', () {
      expect(LockVerificationIssueType.values, containsAll([
        LockVerificationIssueType.checksumMismatch,
        LockVerificationIssueType.packageNotFound,
        LockVerificationIssueType.versionMismatch,
        LockVerificationIssueType.missingDependency,
        LockVerificationIssueType.incompatibleConstraint,
      ]));
    });
  });

  group('LockFile.fromGraph', () {
    test('creates lock file from dependency graph', () {
      final graph = DependencyGraph(
        nodes: {
          'foo': DependencyNode(
            id: PackageId('foo', SemanticVersion.parse('1.0.0')),
            dependencies: [
              DependencyEdge(
                target: PackageRef('bar', VersionConstraint.parse('^1.0.0')),
              ),
            ],
            metadata: const ResolutionMetadata(source: 'registry'),
          ),
          'bar': DependencyNode(
            id: PackageId('bar', SemanticVersion.parse('1.2.0')),
            metadata: const ResolutionMetadata(
              source: 'git',
              resolved: 'https://github.com/bar',
              checksum: 'sha256:xyz',
            ),
          ),
        },
        roots: {PackageId('foo', SemanticVersion.parse('1.0.0'))},
      );

      final lockFile = LockFile.fromGraph(graph);
      expect(lockFile.isLocked('foo'), true);
      expect(lockFile.isLocked('bar'), true);
      expect(lockFile.getVersion('foo'), SemanticVersion.parse('1.0.0'));
      expect(lockFile.getVersion('bar'), SemanticVersion.parse('1.2.0'));
      expect(lockFile.packages['bar']!.source, 'git');
      expect(lockFile.packages['bar']!.resolved, 'https://github.com/bar');
      expect(lockFile.packages['bar']!.checksum, 'sha256:xyz');
      // foo's dependencies should include bar
      expect(lockFile.packages['foo']!.dependencies.containsKey('bar'), true);
    });

    test('skips nodes without version', () {
      final graph = DependencyGraph(
        nodes: {
          'unversioned': const DependencyNode(id: PackageId('unversioned')),
        },
        roots: const {},
      );
      final lockFile = LockFile.fromGraph(graph);
      expect(lockFile.isLocked('unversioned'), false);
    });
  });
}
