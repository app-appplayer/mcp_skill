/// Dependency Resolver - PubGrub-style dependency resolution.
///
/// Implements the PubGrub algorithm for dependency resolution,
/// providing deterministic, efficient resolution with clear error messages.
library;

import 'dart:async';
import 'dart:collection';

import 'version_constraint.dart';
import 'dependency_graph.dart';
import 'lock_file.dart';

// =============================================================================
// Package Specification
// =============================================================================

/// Specification of a package's dependencies.
class PackageSpec {
  /// Package name.
  final String name;

  /// Package version.
  final SemanticVersion version;

  /// Dependencies.
  final Map<String, VersionConstraint> dependencies;

  /// Development dependencies.
  final Map<String, VersionConstraint> devDependencies;

  const PackageSpec({
    required this.name,
    required this.version,
    this.dependencies = const {},
    this.devDependencies = const {},
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'version': version.toString(),
        'dependencies':
            dependencies.map((k, v) => MapEntry(k, v.toString())),
        'devDependencies':
            devDependencies.map((k, v) => MapEntry(k, v.toString())),
      };
}

// =============================================================================
// Package Registry Interface
// =============================================================================

/// Interface for package registries.
abstract class PackageRegistry {
  /// Get available versions for a package.
  Future<List<SemanticVersion>> getVersions(String packageName);

  /// Get package specification for a specific version.
  Future<PackageSpec?> getSpec(String packageName, SemanticVersion version);

  /// Check if a package exists.
  Future<bool> exists(String packageName);
}

/// In-memory package registry for testing.
class InMemoryPackageRegistry implements PackageRegistry {
  final Map<String, Map<SemanticVersion, PackageSpec>> _packages = {};

  void register(PackageSpec spec) {
    _packages.putIfAbsent(spec.name, () => {});
    _packages[spec.name]![spec.version] = spec;
  }

  @override
  Future<List<SemanticVersion>> getVersions(String packageName) async {
    final versions = _packages[packageName]?.keys.toList() ?? [];
    versions.sort((a, b) => b.compareTo(a)); // Descending order
    return versions;
  }

  @override
  Future<PackageSpec?> getSpec(
    String packageName,
    SemanticVersion version,
  ) async {
    return _packages[packageName]?[version];
  }

  @override
  Future<bool> exists(String packageName) async {
    return _packages.containsKey(packageName);
  }
}

// =============================================================================
// Resolution Configuration
// =============================================================================

/// Configuration for dependency resolution.
class ResolutionConfig {
  /// Version selection strategy.
  final VersionSelectionStrategy strategy;

  /// Whether to allow pre-release versions.
  final bool allowPrerelease;

  /// Whether to include dev dependencies.
  final bool includeDevDependencies;

  /// Maximum resolution time.
  final Duration timeout;

  /// Whether to force upgrade all packages.
  final bool forceUpgrade;

  const ResolutionConfig({
    this.strategy = VersionSelectionStrategy.preferLocked,
    this.allowPrerelease = false,
    this.includeDevDependencies = true,
    this.timeout = const Duration(minutes: 5),
    this.forceUpgrade = false,
  });
}

/// Version selection strategy.
enum VersionSelectionStrategy {
  /// Prefer locked versions if compatible.
  preferLocked,

  /// Always pick latest compatible version.
  preferLatest,

  /// Prefer stable over pre-release.
  preferStable,

  /// Pick minimum satisfying version.
  preferMinimum,
}

// =============================================================================
// Resolution Result
// =============================================================================

/// Result of dependency resolution.
class ResolutionResult {
  /// Whether resolution succeeded.
  final bool success;

  /// Resolved dependency graph.
  final DependencyGraph? graph;

  /// Generated lock file.
  final LockFile? lockFile;

  /// Resolution error (if failed).
  final ResolutionError? error;

  /// Warnings during resolution.
  final List<ResolutionWarning> warnings;

  /// Resolution metrics.
  final ResolutionMetrics metrics;

  const ResolutionResult._({
    required this.success,
    this.graph,
    this.lockFile,
    this.error,
    this.warnings = const [],
    required this.metrics,
  });

  factory ResolutionResult.success({
    required DependencyGraph graph,
    required LockFile lockFile,
    List<ResolutionWarning> warnings = const [],
    required ResolutionMetrics metrics,
  }) {
    return ResolutionResult._(
      success: true,
      graph: graph,
      lockFile: lockFile,
      warnings: warnings,
      metrics: metrics,
    );
  }

  factory ResolutionResult.failure({
    required ResolutionError error,
    required ResolutionMetrics metrics,
  }) {
    return ResolutionResult._(
      success: false,
      error: error,
      metrics: metrics,
    );
  }

  factory ResolutionResult.fromLock(LockFile lockFile) {
    return ResolutionResult._(
      success: true,
      lockFile: lockFile,
      metrics: ResolutionMetrics(
        duration: Duration.zero,
        versionsConsidered: 0,
        backtrackCount: 0,
      ),
    );
  }
}

/// Resolution error.
class ResolutionError {
  /// Error type.
  final ResolutionErrorType type;

  /// Error message.
  final String message;

  /// Packages involved in the error.
  final List<String> packages;

  /// Conflict details (if applicable).
  final List<ConflictPath>? conflictPaths;

  /// Suggested fixes.
  final List<SuggestedFix> suggestions;

  const ResolutionError({
    required this.type,
    required this.message,
    this.packages = const [],
    this.conflictPaths,
    this.suggestions = const [],
  });
}

/// Resolution error types.
enum ResolutionErrorType {
  /// No version satisfies all constraints.
  versionIncompatible,

  /// Circular dependency detected.
  cyclicDependency,

  /// Package not found.
  packageNotFound,

  /// Resolution timed out.
  timeout,

  /// Other error.
  other,
}

/// A path showing how a conflict arose.
class ConflictPath {
  /// Packages in the path.
  final List<PackageRef> path;

  /// The conflicting constraint.
  final VersionConstraint constraint;

  const ConflictPath({required this.path, required this.constraint});
}

/// Suggested fix for resolution error.
class SuggestedFix {
  /// Fix description.
  final String description;

  /// Fix action.
  final String action;

  /// Packages to modify.
  final Map<String, String>? modifications;

  const SuggestedFix({
    required this.description,
    required this.action,
    this.modifications,
  });
}

/// Resolution warning.
class ResolutionWarning {
  /// Warning message.
  final String message;

  /// Package involved.
  final String? packageName;

  const ResolutionWarning({required this.message, this.packageName});
}

/// Resolution metrics.
class ResolutionMetrics {
  /// Total resolution time.
  final Duration duration;

  /// Number of versions considered.
  final int versionsConsidered;

  /// Number of backtracks.
  final int backtrackCount;

  const ResolutionMetrics({
    required this.duration,
    required this.versionsConsidered,
    required this.backtrackCount,
  });
}

// =============================================================================
// Dependency Resolver Service
// =============================================================================

/// Main service interface for dependency resolution.
abstract class DependencyResolverService {
  /// Resolve all dependencies.
  Future<ResolutionResult> resolve(
    PackageSpec spec, {
    LockFile? lockFile,
    ResolutionConfig? config,
  });

  /// Check if resolution is possible.
  Future<ResolutionCheck> check(PackageSpec spec);

  /// Get dependency tree.
  Future<DependencyTree> getTree(PackageSpec spec);

  /// Suggest fixes for conflicts.
  Future<List<SuggestedFix>> suggestFixes(ResolutionError error);
}

/// Result of resolution check.
class ResolutionCheck {
  /// Whether resolution is possible.
  final bool possible;

  /// Potential issues.
  final List<String> issues;

  const ResolutionCheck({required this.possible, this.issues = const []});
}

// =============================================================================
// PubGrub Solver
// =============================================================================

/// PubGrub-style dependency resolver implementation.
class PubGrubResolver implements DependencyResolverService {
  final PackageRegistry registry;
  final ResolutionConfig defaultConfig;

  PubGrubResolver({
    required this.registry,
    this.defaultConfig = const ResolutionConfig(),
  });

  @override
  Future<ResolutionResult> resolve(
    PackageSpec spec, {
    LockFile? lockFile,
    ResolutionConfig? config,
  }) async {
    final resolveConfig = config ?? defaultConfig;
    final startTime = DateTime.now();
    var versionsConsidered = 0;
    var backtrackCount = 0;

    try {
      final solver = _PubGrubSolver(
        registry: registry,
        config: resolveConfig,
        lockFile: lockFile,
      );

      // Add root package
      solver.addRoot(spec);

      // Solve
      final solution = await solver.solve();
      versionsConsidered = solver.versionsConsidered;
      backtrackCount = solver.backtrackCount;

      // Build graph
      final graph = await _buildGraph(solution, spec);

      // Generate lock file
      final newLockFile = LockFile.fromGraph(graph);

      final metrics = ResolutionMetrics(
        duration: DateTime.now().difference(startTime),
        versionsConsidered: versionsConsidered,
        backtrackCount: backtrackCount,
      );

      return ResolutionResult.success(
        graph: graph,
        lockFile: newLockFile,
        metrics: metrics,
      );
    } on _SolverException catch (e) {
      return ResolutionResult.failure(
        error: ResolutionError(
          type: e.type,
          message: e.message,
          packages: e.packages,
          suggestions: const [],
        ),
        metrics: ResolutionMetrics(
          duration: DateTime.now().difference(startTime),
          versionsConsidered: versionsConsidered,
          backtrackCount: backtrackCount,
        ),
      );
    }
  }

  Future<DependencyGraph> _buildGraph(
    Map<String, SemanticVersion> solution,
    PackageSpec rootSpec,
  ) async {
    final nodes = <String, DependencyNode>{};
    final roots = <PackageId>{PackageId(rootSpec.name, rootSpec.version)};

    for (final entry in solution.entries) {
      final spec = await registry.getSpec(entry.key, entry.value);
      if (spec != null) {
        final deps = <DependencyEdge>[];
        for (final depEntry in spec.dependencies.entries) {
          deps.add(DependencyEdge(
            target: PackageRef(depEntry.key, depEntry.value),
          ));
        }

        nodes[entry.key] = DependencyNode(
          id: PackageId(entry.key, entry.value),
          dependencies: deps,
          metadata: ResolutionMetadata(source: 'registry'),
        );
      }
    }

    return DependencyGraph(nodes: nodes, roots: roots);
  }

  @override
  Future<ResolutionCheck> check(PackageSpec spec) async {
    final issues = <String>[];

    for (final dep in spec.dependencies.entries) {
      final exists = await registry.exists(dep.key);
      if (!exists) {
        issues.add('Package not found: ${dep.key}');
        continue;
      }

      final versions = await registry.getVersions(dep.key);
      final compatible = versions.where((v) => dep.value.allows(v)).toList();
      if (compatible.isEmpty) {
        issues.add(
            'No compatible version for ${dep.key} (constraint: ${dep.value})');
      }
    }

    return ResolutionCheck(possible: issues.isEmpty, issues: issues);
  }

  @override
  Future<DependencyTree> getTree(PackageSpec spec) async {
    final result = await resolve(spec);
    if (!result.success || result.graph == null) {
      return DependencyTree(root: PackageId(spec.name, spec.version));
    }
    return DependencyTree.fromGraph(
      result.graph!,
      PackageId(spec.name, spec.version),
    );
  }

  @override
  Future<List<SuggestedFix>> suggestFixes(ResolutionError error) async {
    final suggestions = <SuggestedFix>[];

    switch (error.type) {
      case ResolutionErrorType.versionIncompatible:
        suggestions.add(const SuggestedFix(
          description: 'Try relaxing version constraints',
          action: 'update_constraints',
        ));
        break;
      case ResolutionErrorType.packageNotFound:
        suggestions.add(const SuggestedFix(
          description: 'Check package name spelling',
          action: 'verify_package',
        ));
        break;
      case ResolutionErrorType.cyclicDependency:
        suggestions.add(const SuggestedFix(
          description: 'Break the dependency cycle',
          action: 'refactor',
        ));
        break;
      default:
        break;
    }

    return suggestions;
  }
}

// =============================================================================
// Internal Solver
// =============================================================================

class _PubGrubSolver {
  final PackageRegistry registry;
  final ResolutionConfig config;
  final LockFile? lockFile;

  final Map<String, _Assignment> _assignments = {};
  final List<_Incompatibility> _incompatibilities = [];
  final Queue<String> _changed = Queue();

  int versionsConsidered = 0;
  int backtrackCount = 0;

  _PubGrubSolver({
    required this.registry,
    required this.config,
    this.lockFile,
  });

  void addRoot(PackageSpec spec) {
    // Add root package assignment
    _assignments[spec.name] = _Assignment(
      package: spec.name,
      version: spec.version,
      isDecision: true,
      decisionLevel: 0,
    );

    // Add dependencies as constraints
    for (final dep in spec.dependencies.entries) {
      _addConstraint(spec.name, dep.key, dep.value);
    }

    _changed.add(spec.name);
  }

  void _addConstraint(String from, String to, VersionConstraint constraint) {
    _incompatibilities.add(_Incompatibility(
      terms: [
        _Term(package: from, constraint: VersionConstraint.any, positive: true),
        _Term(package: to, constraint: constraint, positive: false),
      ],
      cause: 'dependency from $from',
    ));
    _changed.add(to);
  }

  Future<Map<String, SemanticVersion>> solve() async {
    await _unitPropagate();

    while (true) {
      // Find next package to decide
      final next = await _choosePackageVersion();
      if (next == null) {
        // All packages resolved
        return _buildSolution();
      }

      final (package, version) = next;
      versionsConsidered++;

      // Try to assign version
      final success = await _decide(package, version);
      if (!success) {
        // Need to backtrack
        final resolved = await _resolveConflict();
        if (!resolved) {
          throw _SolverException(
            type: ResolutionErrorType.versionIncompatible,
            message: 'No solution exists',
            packages: _assignments.keys.toList(),
          );
        }
        backtrackCount++;
      }

      await _unitPropagate();
    }
  }

  Future<void> _unitPropagate() async {
    while (_changed.isNotEmpty) {
      final package = _changed.removeFirst();

      for (final incompat in _incompatibilities) {
        if (incompat.terms.any((t) => t.package == package)) {
          await _propagate(incompat);
        }
      }
    }
  }

  Future<void> _propagate(_Incompatibility incompat) async {
    // Check if incompatibility is satisfied
    _Term? unsatisfied;
    var satisfiedCount = 0;

    for (final term in incompat.terms) {
      final assignment = _assignments[term.package];
      if (assignment == null) {
        if (unsatisfied != null) return; // Multiple unknowns
        unsatisfied = term;
      } else {
        final satisfied = term.positive
            ? term.constraint.allows(assignment.version)
            : !term.constraint.allows(assignment.version);
        if (satisfied) {
          satisfiedCount++;
        }
      }
    }

    if (unsatisfied == null && satisfiedCount == incompat.terms.length) {
      // Conflict! All terms satisfied
      throw _SolverException(
        type: ResolutionErrorType.versionIncompatible,
        message: 'Conflict: ${incompat.cause}',
        packages: incompat.terms.map((t) => t.package).toList(),
      );
    }
  }

  Future<(String, SemanticVersion)?> _choosePackageVersion() async {
    // Find unassigned package with tightest constraint
    for (final incompat in _incompatibilities) {
      for (final term in incompat.terms) {
        if (!_assignments.containsKey(term.package)) {
          final versions = await registry.getVersions(term.package);
          final compatible =
              versions.where((v) => _isCompatible(term.package, v)).toList();

          if (compatible.isEmpty) {
            throw _SolverException(
              type: ResolutionErrorType.versionIncompatible,
              message: 'No compatible version for ${term.package}',
              packages: [term.package],
            );
          }

          // Select version based on strategy
          final selected = _selectVersion(term.package, compatible);
          return (term.package, selected);
        }
      }
    }
    return null;
  }

  bool _isCompatible(String package, SemanticVersion version) {
    for (final incompat in _incompatibilities) {
      for (final term in incompat.terms) {
        if (term.package == package && !term.positive) {
          if (!term.constraint.allows(version)) return false;
        }
      }
    }
    return true;
  }

  SemanticVersion _selectVersion(
    String package,
    List<SemanticVersion> candidates,
  ) {
    // Check lock file first
    if (lockFile != null &&
        config.strategy == VersionSelectionStrategy.preferLocked) {
      final locked = lockFile!.getVersion(package);
      if (locked != null && candidates.contains(locked)) {
        return locked;
      }
    }

    // Apply strategy
    switch (config.strategy) {
      case VersionSelectionStrategy.preferLatest:
      case VersionSelectionStrategy.preferLocked:
        candidates.sort((a, b) => b.compareTo(a));
        return candidates.first;

      case VersionSelectionStrategy.preferStable:
        final stable = candidates.where((v) => !v.isPrerelease).toList();
        if (stable.isNotEmpty) {
          stable.sort((a, b) => b.compareTo(a));
          return stable.first;
        }
        candidates.sort((a, b) => b.compareTo(a));
        return candidates.first;

      case VersionSelectionStrategy.preferMinimum:
        candidates.sort();
        return candidates.first;
    }
  }

  Future<bool> _decide(String package, SemanticVersion version) async {
    // Get spec for this version
    final spec = await registry.getSpec(package, version);
    if (spec == null) return false;

    // Add assignment
    _assignments[package] = _Assignment(
      package: package,
      version: version,
      isDecision: true,
      decisionLevel: _assignments.length,
    );

    // Add dependency constraints
    for (final dep in spec.dependencies.entries) {
      _addConstraint(package, dep.key, dep.value);
    }

    _changed.add(package);
    return true;
  }

  Future<bool> _resolveConflict() async {
    // Simple backtracking - remove last decision
    if (_assignments.isEmpty) return false;

    final lastDecision = _assignments.entries
        .where((e) => e.value.isDecision)
        .reduce((a, b) =>
            a.value.decisionLevel > b.value.decisionLevel ? a : b);

    _assignments.remove(lastDecision.key);

    // Remove related constraints
    _incompatibilities.removeWhere(
      (i) => i.cause.contains('from ${lastDecision.key}'),
    );

    return true;
  }

  Map<String, SemanticVersion> _buildSolution() {
    return {
      for (final entry in _assignments.entries) entry.key: entry.value.version,
    };
  }
}

class _Assignment {
  final String package;
  final SemanticVersion version;
  final bool isDecision;
  final int decisionLevel;

  _Assignment({
    required this.package,
    required this.version,
    required this.isDecision,
    required this.decisionLevel,
  });
}

class _Term {
  final String package;
  final VersionConstraint constraint;
  final bool positive;

  _Term({
    required this.package,
    required this.constraint,
    required this.positive,
  });
}

class _Incompatibility {
  final List<_Term> terms;
  final String cause;

  _Incompatibility({required this.terms, required this.cause});
}

class _SolverException implements Exception {
  final ResolutionErrorType type;
  final String message;
  final List<String> packages;

  _SolverException({
    required this.type,
    required this.message,
    this.packages = const [],
  });
}
