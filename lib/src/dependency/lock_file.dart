/// Lock File - Lock file management for reproducible builds.
///
/// Provides lock file parsing, generation, and verification for
/// ensuring reproducible dependency resolution across environments.
library;

import 'version_constraint.dart';
import 'dependency_graph.dart';

// =============================================================================
// Lock File Entry
// =============================================================================

/// A single package entry in the lock file.
class LockFileEntry {
  /// Package name.
  final String name;

  /// Resolved version.
  final SemanticVersion version;

  /// Package source (registry, git, path).
  final String source;

  /// Resolved URL or path.
  final String? resolved;

  /// Git reference (for git sources).
  final String? gitRef;

  /// Checksum for integrity verification.
  final String? checksum;

  /// Dependencies of this package.
  final Map<String, String> dependencies;

  const LockFileEntry({
    required this.name,
    required this.version,
    required this.source,
    this.resolved,
    this.gitRef,
    this.checksum,
    this.dependencies = const {},
  });

  Map<String, dynamic> toJson() => {
        'version': version.toString(),
        'source': source,
        if (resolved != null) 'resolved': resolved,
        if (gitRef != null) 'ref': gitRef,
        if (checksum != null) 'checksum': checksum,
        if (dependencies.isNotEmpty) 'dependencies': dependencies,
      };

  factory LockFileEntry.fromJson(String name, Map<String, dynamic> json) =>
      LockFileEntry(
        name: name,
        version: SemanticVersion.parse(json['version'] as String),
        source: json['source'] as String,
        resolved: json['resolved'] as String?,
        gitRef: json['ref'] as String?,
        checksum: json['checksum'] as String?,
        dependencies:
            (json['dependencies'] as Map<String, dynamic>?)?.cast<String, String>() ??
                const {},
      );
}

// =============================================================================
// Lock File
// =============================================================================

/// Complete lock file representation.
class LockFile {
  /// Lock file format version.
  final int lockVersion;

  /// Locked packages.
  final Map<String, LockFileEntry> packages;

  /// Resolution metadata.
  final LockFileMetadata metadata;

  const LockFile({
    this.lockVersion = 1,
    this.packages = const {},
    required this.metadata,
  });

  /// Create an empty lock file.
  factory LockFile.empty() => LockFile(
        metadata: LockFileMetadata(
          resolvedAt: DateTime.now(),
          resolverVersion: '1.0.0',
        ),
      );

  /// Get locked version for a package.
  SemanticVersion? getVersion(String packageName) =>
      packages[packageName]?.version;

  /// Check if package is locked.
  bool isLocked(String packageName) => packages.containsKey(packageName);

  /// Get all locked package names.
  List<String> get packageNames => packages.keys.toList();

  /// Create lock file from resolution result.
  factory LockFile.fromGraph(DependencyGraph graph) {
    final packages = <String, LockFileEntry>{};

    for (final node in graph.nodes.values) {
      if (node.id.version != null) {
        packages[node.id.name] = LockFileEntry(
          name: node.id.name,
          version: node.id.version!,
          source: node.metadata?.source ?? 'registry',
          resolved: node.metadata?.resolved,
          checksum: node.metadata?.checksum,
          dependencies: {
            for (final dep in node.dependencies)
              dep.target.name: dep.target.constraint.toString(),
          },
        );
      }
    }

    return LockFile(
      packages: packages,
      metadata: LockFileMetadata(
        resolvedAt: DateTime.now(),
        resolverVersion: '1.0.0',
      ),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'lockVersion': lockVersion,
        'packages':
            packages.map((name, entry) => MapEntry(name, entry.toJson())),
        'metadata': metadata.toJson(),
      };

  /// Parse from JSON.
  factory LockFile.fromJson(Map<String, dynamic> json) {
    final packagesJson = json['packages'] as Map<String, dynamic>? ?? {};
    return LockFile(
      lockVersion: json['lockVersion'] as int? ?? 1,
      packages: packagesJson.map((name, value) => MapEntry(
            name,
            LockFileEntry.fromJson(name, value as Map<String, dynamic>),
          )),
      metadata: json['metadata'] != null
          ? LockFileMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : LockFileMetadata(resolvedAt: DateTime.now(), resolverVersion: '1.0.0'),
    );
  }

  /// Create a copy with updated packages.
  LockFile copyWith({
    int? lockVersion,
    Map<String, LockFileEntry>? packages,
    LockFileMetadata? metadata,
  }) {
    return LockFile(
      lockVersion: lockVersion ?? this.lockVersion,
      packages: packages ?? this.packages,
      metadata: metadata ?? this.metadata,
    );
  }
}

// =============================================================================
// Lock File Metadata
// =============================================================================

/// Metadata about lock file resolution.
class LockFileMetadata {
  /// When the resolution was computed.
  final DateTime resolvedAt;

  /// Resolver version used.
  final String resolverVersion;

  /// Dart SDK version.
  final String? dartSdkVersion;

  /// Flutter SDK version.
  final String? flutterSdkVersion;

  const LockFileMetadata({
    required this.resolvedAt,
    required this.resolverVersion,
    this.dartSdkVersion,
    this.flutterSdkVersion,
  });

  Map<String, dynamic> toJson() => {
        'resolvedAt': resolvedAt.toIso8601String(),
        'resolverVersion': resolverVersion,
        if (dartSdkVersion != null) 'dartSdkVersion': dartSdkVersion,
        if (flutterSdkVersion != null) 'flutterSdkVersion': flutterSdkVersion,
      };

  factory LockFileMetadata.fromJson(Map<String, dynamic> json) =>
      LockFileMetadata(
        resolvedAt: DateTime.parse(json['resolvedAt'] as String),
        resolverVersion: json['resolverVersion'] as String,
        dartSdkVersion: json['dartSdkVersion'] as String?,
        flutterSdkVersion: json['flutterSdkVersion'] as String?,
      );
}

// =============================================================================
// Lock File Diff
// =============================================================================

/// Difference between two lock files.
class LockFileDiff {
  /// Packages added.
  final List<PackageChange> added;

  /// Packages removed.
  final List<PackageChange> removed;

  /// Packages upgraded.
  final List<PackageUpgrade> upgraded;

  /// Packages downgraded.
  final List<PackageDowngrade> downgraded;

  const LockFileDiff({
    this.added = const [],
    this.removed = const [],
    this.upgraded = const [],
    this.downgraded = const [],
  });

  /// Whether there are any changes.
  bool get hasChanges =>
      added.isNotEmpty ||
      removed.isNotEmpty ||
      upgraded.isNotEmpty ||
      downgraded.isNotEmpty;

  /// Total number of changes.
  int get changeCount =>
      added.length + removed.length + upgraded.length + downgraded.length;

  /// Compute diff between two lock files.
  factory LockFileDiff.between(LockFile current, LockFile previous) {
    final added = <PackageChange>[];
    final removed = <PackageChange>[];
    final upgraded = <PackageUpgrade>[];
    final downgraded = <PackageDowngrade>[];

    final currentNames = current.packageNames.toSet();
    final previousNames = previous.packageNames.toSet();

    // Find added packages
    for (final name in currentNames.difference(previousNames)) {
      added.add(PackageChange(
        name: name,
        version: current.packages[name]!.version,
      ));
    }

    // Find removed packages
    for (final name in previousNames.difference(currentNames)) {
      removed.add(PackageChange(
        name: name,
        version: previous.packages[name]!.version,
      ));
    }

    // Find changed packages
    for (final name in currentNames.intersection(previousNames)) {
      final currentEntry = current.packages[name]!;
      final previousEntry = previous.packages[name]!;

      final cmp = currentEntry.version.compareTo(previousEntry.version);
      if (cmp > 0) {
        upgraded.add(PackageUpgrade(
          name: name,
          from: previousEntry.version,
          to: currentEntry.version,
        ));
      } else if (cmp < 0) {
        downgraded.add(PackageDowngrade(
          name: name,
          from: previousEntry.version,
          to: currentEntry.version,
        ));
      }
    }

    return LockFileDiff(
      added: added,
      removed: removed,
      upgraded: upgraded,
      downgraded: downgraded,
    );
  }

  /// Format as human-readable string.
  String toHumanReadable() {
    final buffer = StringBuffer();

    if (added.isNotEmpty) {
      buffer.writeln('Added:');
      for (final pkg in added) {
        buffer.writeln('  + ${pkg.name} ${pkg.version}');
      }
    }

    if (removed.isNotEmpty) {
      buffer.writeln('Removed:');
      for (final pkg in removed) {
        buffer.writeln('  - ${pkg.name} ${pkg.version}');
      }
    }

    if (upgraded.isNotEmpty) {
      buffer.writeln('Upgraded:');
      for (final pkg in upgraded) {
        buffer.writeln('  ^ ${pkg.name} ${pkg.from} -> ${pkg.to}');
      }
    }

    if (downgraded.isNotEmpty) {
      buffer.writeln('Downgraded:');
      for (final pkg in downgraded) {
        buffer.writeln('  v ${pkg.name} ${pkg.from} -> ${pkg.to}');
      }
    }

    if (!hasChanges) {
      buffer.writeln('No changes');
    }

    return buffer.toString();
  }
}

/// A package addition or removal.
class PackageChange {
  final String name;
  final SemanticVersion version;

  const PackageChange({required this.name, required this.version});
}

/// A package version upgrade.
class PackageUpgrade {
  final String name;
  final SemanticVersion from;
  final SemanticVersion to;

  const PackageUpgrade({
    required this.name,
    required this.from,
    required this.to,
  });
}

/// A package version downgrade.
class PackageDowngrade {
  final String name;
  final SemanticVersion from;
  final SemanticVersion to;

  const PackageDowngrade({
    required this.name,
    required this.from,
    required this.to,
  });
}

// =============================================================================
// Lock File Verification
// =============================================================================

/// Result of lock file verification.
class LockVerification {
  /// Whether the lock file is valid.
  final bool valid;

  /// List of issues found.
  final List<LockVerificationIssue> issues;

  const LockVerification({required this.valid, this.issues = const []});

  factory LockVerification.success() =>
      const LockVerification(valid: true);

  factory LockVerification.failure(List<LockVerificationIssue> issues) =>
      LockVerification(valid: false, issues: issues);
}

/// A verification issue.
class LockVerificationIssue {
  /// Issue type.
  final LockVerificationIssueType type;

  /// Package name.
  final String packageName;

  /// Issue description.
  final String message;

  const LockVerificationIssue({
    required this.type,
    required this.packageName,
    required this.message,
  });
}

/// Types of verification issues.
enum LockVerificationIssueType {
  /// Checksum mismatch.
  checksumMismatch,

  /// Package not found.
  packageNotFound,

  /// Version mismatch.
  versionMismatch,

  /// Missing dependency.
  missingDependency,

  /// Incompatible constraint.
  incompatibleConstraint,
}
