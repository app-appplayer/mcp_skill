/// Dependency Resolution - PubGrub-style dependency resolution for skills.
///
/// This module provides:
/// - Semantic version parsing and comparison
/// - Version constraint evaluation
/// - Dependency graph representation
/// - Lock file management
/// - PubGrub-style dependency resolution algorithm
library;

export 'version_constraint.dart';
export 'dependency_graph.dart';
export 'lock_file.dart';
export 'dependency_resolver.dart';
