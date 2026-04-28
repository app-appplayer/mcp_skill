/// Dependency Graph - Graph representation of package dependencies.
///
/// Provides data structures for representing and querying dependency
/// relationships between packages.
library;

import 'version_constraint.dart';

// =============================================================================
// Package Identification
// =============================================================================

/// Unique identifier for a package.
class PackageId {
  /// Package name.
  final String name;

  /// Package version (null for unresolved references).
  final SemanticVersion? version;

  const PackageId(this.name, [this.version]);

  /// Create from name and version string.
  factory PackageId.parse(String spec) {
    final parts = spec.split('@');
    if (parts.length == 1) {
      return PackageId(parts[0]);
    }
    return PackageId(parts[0], SemanticVersion.parse(parts[1]));
  }

  @override
  bool operator ==(Object other) =>
      other is PackageId && name == other.name && version == other.version;

  @override
  int get hashCode => Object.hash(name, version);

  @override
  String toString() => version != null ? '$name@$version' : name;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (version != null) 'version': version!.toJson(),
      };

  factory PackageId.fromJson(Map<String, dynamic> json) => PackageId(
        json['name'] as String,
        json['version'] != null
            ? SemanticVersion.fromJson(json['version'] as Map<String, dynamic>)
            : null,
      );
}

/// Reference to a package with version constraint.
class PackageRef {
  /// Package name.
  final String name;

  /// Version constraint.
  final VersionConstraint constraint;

  const PackageRef(this.name, this.constraint);

  /// Parse from string (e.g., "package@^1.0.0").
  factory PackageRef.parse(String spec) {
    final atIndex = spec.indexOf('@');
    if (atIndex == -1) {
      return PackageRef(spec, VersionConstraint.any);
    }
    return PackageRef(
      spec.substring(0, atIndex),
      VersionConstraint.parse(spec.substring(atIndex + 1)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PackageRef &&
      name == other.name &&
      constraint.toString() == other.constraint.toString();

  @override
  int get hashCode => Object.hash(name, constraint.toString());

  @override
  String toString() => '$name@$constraint';
}

// =============================================================================
// Dependency Types
// =============================================================================

/// Type of dependency relationship.
enum DependencyType {
  /// Normal runtime dependency.
  normal,

  /// Development-only dependency.
  dev,

  /// Peer dependency (must match parent's version).
  peer,

  /// Optional dependency.
  optional,
}

/// A dependency edge in the graph.
class DependencyEdge {
  /// Target package reference.
  final PackageRef target;

  /// Dependency type.
  final DependencyType type;

  /// Whether this dependency is optional.
  final bool optional;

  /// Dependency features (optional features to enable).
  final List<String>? features;

  const DependencyEdge({
    required this.target,
    this.type = DependencyType.normal,
    this.optional = false,
    this.features,
  });

  Map<String, dynamic> toJson() => {
        'target': {
          'name': target.name,
          'constraint': target.constraint.toString(),
        },
        'type': type.name,
        'optional': optional,
        if (features != null) 'features': features,
      };

  factory DependencyEdge.fromJson(Map<String, dynamic> json) {
    final targetJson = json['target'] as Map<String, dynamic>;
    return DependencyEdge(
      target: PackageRef(
        targetJson['name'] as String,
        VersionConstraint.parse(targetJson['constraint'] as String),
      ),
      type: DependencyType.values.byName(json['type'] as String),
      optional: json['optional'] as bool? ?? false,
      features: (json['features'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

// =============================================================================
// Dependency Node
// =============================================================================

/// A node in the dependency graph.
class DependencyNode {
  /// Package identifier.
  final PackageId id;

  /// Direct dependencies.
  final List<DependencyEdge> dependencies;

  /// Packages that depend on this one.
  final List<PackageId> dependents;

  /// Resolution metadata.
  final ResolutionMetadata? metadata;

  const DependencyNode({
    required this.id,
    this.dependencies = const [],
    this.dependents = const [],
    this.metadata,
  });

  DependencyNode copyWith({
    PackageId? id,
    List<DependencyEdge>? dependencies,
    List<PackageId>? dependents,
    ResolutionMetadata? metadata,
  }) {
    return DependencyNode(
      id: id ?? this.id,
      dependencies: dependencies ?? this.dependencies,
      dependents: dependents ?? this.dependents,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id.toJson(),
        'dependencies': dependencies.map((d) => d.toJson()).toList(),
        'dependents': dependents.map((d) => d.toJson()).toList(),
        if (metadata != null) 'metadata': metadata!.toJson(),
      };
}

/// Metadata about how a package was resolved.
class ResolutionMetadata {
  /// Source of the package.
  final String source;

  /// Resolved URL or path.
  final String? resolved;

  /// Checksum for integrity verification.
  final String? checksum;

  /// When this resolution was computed.
  final DateTime? resolvedAt;

  const ResolutionMetadata({
    required this.source,
    this.resolved,
    this.checksum,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        if (resolved != null) 'resolved': resolved,
        if (checksum != null) 'checksum': checksum,
        if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      };

  factory ResolutionMetadata.fromJson(Map<String, dynamic> json) =>
      ResolutionMetadata(
        source: json['source'] as String,
        resolved: json['resolved'] as String?,
        checksum: json['checksum'] as String?,
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
      );
}

// =============================================================================
// Dependency Graph
// =============================================================================

/// Complete dependency graph.
class DependencyGraph {
  /// All nodes in the graph.
  final Map<String, DependencyNode> nodes;

  /// Root packages (entry points).
  final Set<PackageId> roots;

  const DependencyGraph({
    this.nodes = const {},
    this.roots = const {},
  });

  /// Create an empty graph.
  factory DependencyGraph.empty() =>
      const DependencyGraph(nodes: {}, roots: {});

  /// Get a node by package name.
  DependencyNode? getNode(String name) => nodes[name];

  /// Get all dependencies (direct + transitive).
  Set<PackageId> getAllDependencies(PackageId id) {
    final result = <PackageId>{};
    final visited = <String>{};
    _collectDependencies(id.name, result, visited);
    return result;
  }

  void _collectDependencies(
    String name,
    Set<PackageId> result,
    Set<String> visited,
  ) {
    if (visited.contains(name)) return;
    visited.add(name);

    final node = nodes[name];
    if (node == null) return;

    for (final dep in node.dependencies) {
      final depNode = nodes[dep.target.name];
      if (depNode != null) {
        result.add(depNode.id);
        _collectDependencies(dep.target.name, result, visited);
      }
    }
  }

  /// Get dependency path from one package to another.
  List<PackageId>? getPath(PackageId from, PackageId to) {
    final visited = <String>{};
    final path = <PackageId>[];
    if (_findPath(from.name, to.name, visited, path)) {
      return path;
    }
    return null;
  }

  bool _findPath(
    String from,
    String to,
    Set<String> visited,
    List<PackageId> path,
  ) {
    if (from == to) {
      final node = nodes[from];
      if (node != null) path.add(node.id);
      return true;
    }

    if (visited.contains(from)) return false;
    visited.add(from);

    final node = nodes[from];
    if (node == null) return false;

    path.add(node.id);

    for (final dep in node.dependencies) {
      if (_findPath(dep.target.name, to, visited, path)) {
        return true;
      }
    }

    path.removeLast();
    return false;
  }

  /// Detect cycles in the graph.
  List<List<PackageId>> detectCycles() {
    final cycles = <List<PackageId>>[];
    final visited = <String>{};
    final stack = <String>[];
    final onStack = <String>{};

    for (final node in nodes.values) {
      if (!visited.contains(node.id.name)) {
        _detectCyclesDfs(node.id.name, visited, stack, onStack, cycles);
      }
    }

    return cycles;
  }

  void _detectCyclesDfs(
    String name,
    Set<String> visited,
    List<String> stack,
    Set<String> onStack,
    List<List<PackageId>> cycles,
  ) {
    visited.add(name);
    stack.add(name);
    onStack.add(name);

    final node = nodes[name];
    if (node != null) {
      for (final dep in node.dependencies) {
        final depName = dep.target.name;
        if (!visited.contains(depName)) {
          _detectCyclesDfs(depName, visited, stack, onStack, cycles);
        } else if (onStack.contains(depName)) {
          // Found cycle
          final cycleStart = stack.indexOf(depName);
          final cycle = stack.sublist(cycleStart).map((n) => nodes[n]!.id).toList();
          cycles.add(cycle);
        }
      }
    }

    stack.removeLast();
    onStack.remove(name);
  }

  /// Topological sort (installation order).
  List<PackageId> topologicalSort() {
    final result = <PackageId>[];
    final visited = <String>{};
    final visiting = <String>{};

    for (final root in roots) {
      _topologicalSortDfs(root.name, visited, visiting, result);
    }

    return result.reversed.toList();
  }

  void _topologicalSortDfs(
    String name,
    Set<String> visited,
    Set<String> visiting,
    List<PackageId> result,
  ) {
    if (visited.contains(name)) return;
    if (visiting.contains(name)) {
      throw StateError('Circular dependency detected at $name');
    }

    visiting.add(name);

    final node = nodes[name];
    if (node != null) {
      for (final dep in node.dependencies) {
        _topologicalSortDfs(dep.target.name, visited, visiting, result);
      }
      visited.add(name);
      result.add(node.id);
    }

    visiting.remove(name);
  }

  /// Create a copy with an additional node.
  DependencyGraph addNode(DependencyNode node) {
    final newNodes = Map<String, DependencyNode>.from(nodes);
    newNodes[node.id.name] = node;
    return DependencyGraph(nodes: newNodes, roots: roots);
  }

  /// Create a copy with an additional root.
  DependencyGraph addRoot(PackageId root) {
    return DependencyGraph(
      nodes: nodes,
      roots: {...roots, root},
    );
  }

  Map<String, dynamic> toJson() => {
        'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
        'roots': roots.map((r) => r.toJson()).toList(),
      };
}

// =============================================================================
// Dependency Tree (for display)
// =============================================================================

/// Tree representation of dependencies for display.
class DependencyTree {
  /// Root package.
  final PackageId root;

  /// Children nodes.
  final List<DependencyTree> children;

  /// Whether this is a repeated reference.
  final bool isRepeat;

  const DependencyTree({
    required this.root,
    this.children = const [],
    this.isRepeat = false,
  });

  /// Build tree from graph.
  factory DependencyTree.fromGraph(DependencyGraph graph, PackageId root) {
    final seen = <String>{};
    return _buildTree(graph, root, seen);
  }

  static DependencyTree _buildTree(
    DependencyGraph graph,
    PackageId root,
    Set<String> seen,
  ) {
    if (seen.contains(root.name)) {
      return DependencyTree(root: root, isRepeat: true);
    }

    seen.add(root.name);

    final node = graph.nodes[root.name];
    if (node == null) {
      return DependencyTree(root: root);
    }

    final children = <DependencyTree>[];
    for (final dep in node.dependencies) {
      final depNode = graph.nodes[dep.target.name];
      if (depNode != null) {
        children.add(_buildTree(graph, depNode.id, seen));
      }
    }

    seen.remove(root.name);

    return DependencyTree(root: root, children: children);
  }

  /// Format as tree string.
  String format({String prefix = '', bool isLast = true}) {
    final buffer = StringBuffer();
    buffer.write(prefix);
    buffer.write(isLast ? '└── ' : '├── ');
    buffer.write(root);
    if (isRepeat) buffer.write(' (*)');
    buffer.writeln();

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final childPrefix = prefix + (isLast ? '    ' : '│   ');
      buffer.write(child.format(
        prefix: childPrefix,
        isLast: i == children.length - 1,
      ));
    }

    return buffer.toString();
  }
}
