import 'package:test/test.dart';
import 'package:mcp_skill/src/dependency/dependency_graph.dart';
import 'package:mcp_skill/src/dependency/version_constraint.dart';

void main() {
  group('PackageId', () {
    test('stores name and version', () {
      final id = PackageId('foo', SemanticVersion.parse('1.0.0'));
      expect(id.name, 'foo');
      expect(id.version, SemanticVersion.parse('1.0.0'));
    });

    test('version is null when not provided', () {
      const id = PackageId('foo');
      expect(id.version, isNull);
    });

    test('parse with name and version', () {
      final id = PackageId.parse('foo@1.2.3');
      expect(id.name, 'foo');
      expect(id.version, SemanticVersion.parse('1.2.3'));
    });

    test('parse with name only', () {
      final id = PackageId.parse('foo');
      expect(id.name, 'foo');
      expect(id.version, isNull);
    });

    test('equality based on name and version', () {
      final a = PackageId('foo', SemanticVersion.parse('1.0.0'));
      final b = PackageId('foo', SemanticVersion.parse('1.0.0'));
      expect(a, b);
    });

    test('inequality with different version', () {
      final a = PackageId('foo', SemanticVersion.parse('1.0.0'));
      final b = PackageId('foo', SemanticVersion.parse('2.0.0'));
      expect(a == b, false);
    });

    test('toString with version', () {
      final id = PackageId('foo', SemanticVersion.parse('1.0.0'));
      expect(id.toString(), 'foo@1.0.0');
    });

    test('toString without version', () {
      const id = PackageId('foo');
      expect(id.toString(), 'foo');
    });

    test('toJson and fromJson round-trip', () {
      final original = PackageId('bar', SemanticVersion.parse('2.1.0'));
      final json = original.toJson();
      final restored = PackageId.fromJson(json);
      expect(restored, original);
    });

    test('fromJson with null version', () {
      final id = PackageId.fromJson({'name': 'baz'});
      expect(id.name, 'baz');
      expect(id.version, isNull);
    });
  });

  group('PackageRef', () {
    test('stores name and constraint', () {
      final ref = PackageRef('foo', VersionConstraint.any);
      expect(ref.name, 'foo');
      expect(ref.constraint.isAny, true);
    });

    test('parse with constraint', () {
      final ref = PackageRef.parse('foo@^1.0.0');
      expect(ref.name, 'foo');
      expect(ref.constraint, isA<CaretConstraint>());
    });

    test('parse without constraint uses any', () {
      final ref = PackageRef.parse('foo');
      expect(ref.name, 'foo');
      expect(ref.constraint.isAny, true);
    });

    test('equality by name and constraint string', () {
      final a = PackageRef('foo', VersionConstraint.parse('^1.0.0'));
      final b = PackageRef('foo', VersionConstraint.parse('^1.0.0'));
      expect(a, b);
    });

    test('toString includes name and constraint', () {
      final ref = PackageRef('foo', VersionConstraint.any);
      expect(ref.toString(), contains('foo'));
    });
  });

  group('DependencyEdge', () {
    test('default type is normal and not optional', () {
      final edge = DependencyEdge(
        target: PackageRef('dep', VersionConstraint.any),
      );
      expect(edge.type, DependencyType.normal);
      expect(edge.optional, false);
      expect(edge.features, isNull);
    });

    test('toJson and fromJson round-trip', () {
      final edge = DependencyEdge(
        target: PackageRef('dep', VersionConstraint.parse('^1.0.0')),
        type: DependencyType.dev,
        optional: true,
        features: ['feature1'],
      );
      final json = edge.toJson();
      final restored = DependencyEdge.fromJson(json);
      expect(restored.target.name, 'dep');
      expect(restored.type, DependencyType.dev);
      expect(restored.optional, true);
      expect(restored.features, ['feature1']);
    });
  });

  group('DependencyNode', () {
    test('default dependencies and dependents are empty', () {
      const node = DependencyNode(id: PackageId('foo'));
      expect(node.dependencies, isEmpty);
      expect(node.dependents, isEmpty);
      expect(node.metadata, isNull);
    });

    test('copyWith creates modified copy', () {
      final original = DependencyNode(
        id: PackageId('foo', SemanticVersion.parse('1.0.0')),
        dependencies: [
          DependencyEdge(
            target: PackageRef('bar', VersionConstraint.any),
          ),
        ],
      );
      final modified = original.copyWith(
        dependents: [PackageId('baz', SemanticVersion.parse('2.0.0'))],
      );
      expect(modified.id, original.id);
      expect(modified.dependencies.length, 1);
      expect(modified.dependents.length, 1);
      expect(modified.dependents.first.name, 'baz');
    });
  });

  group('DependencyGraph', () {
    test('empty graph has no nodes or roots', () {
      final graph = DependencyGraph.empty();
      expect(graph.nodes, isEmpty);
      expect(graph.roots, isEmpty);
    });

    test('addNode adds a node to the graph', () {
      final graph = DependencyGraph.empty();
      final node = DependencyNode(
        id: PackageId('foo', SemanticVersion.parse('1.0.0')),
      );
      final updated = graph.addNode(node);
      expect(updated.nodes.length, 1);
      expect(updated.getNode('foo'), isNotNull);
    });

    test('addRoot adds a root to the graph', () {
      final graph = DependencyGraph.empty();
      final root = PackageId('root', SemanticVersion.parse('1.0.0'));
      final updated = graph.addRoot(root);
      expect(updated.roots.length, 1);
    });

    test('getNode returns null for missing package', () {
      final graph = DependencyGraph.empty();
      expect(graph.getNode('missing'), isNull);
    });

    test('getNode returns the node when present', () {
      final node = DependencyNode(
        id: PackageId('foo', SemanticVersion.parse('1.0.0')),
      );
      final graph = DependencyGraph.empty().addNode(node);
      expect(graph.getNode('foo')!.id.name, 'foo');
    });

    group('getAllDependencies (DFS traversal)', () {
      test('returns direct dependencies', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
        );
        final graph = DependencyGraph.empty().addNode(a).addNode(b);
        final deps = graph.getAllDependencies(a.id);
        expect(deps.length, 1);
        expect(deps.first.name, 'b');
      });

      test('returns transitive dependencies', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('c', VersionConstraint.any)),
          ],
        );
        final c = DependencyNode(
          id: PackageId('c', SemanticVersion.parse('1.0.0')),
        );
        final graph =
            DependencyGraph.empty().addNode(a).addNode(b).addNode(c);
        final deps = graph.getAllDependencies(a.id);
        expect(deps.length, 2);
        final names = deps.map((d) => d.name).toSet();
        expect(names, {'b', 'c'});
      });

      test('handles packages with no dependencies', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
        );
        final graph = DependencyGraph.empty().addNode(a);
        final deps = graph.getAllDependencies(a.id);
        expect(deps, isEmpty);
      });
    });

    group('cycle detection', () {
      test('no cycle in acyclic graph', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
        );
        final graph = DependencyGraph.empty().addNode(a).addNode(b);
        final cycles = graph.detectCycles();
        expect(cycles, isEmpty);
      });

      test('detects simple cycle A -> B -> A', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('a', VersionConstraint.any)),
          ],
        );
        final graph = DependencyGraph.empty().addNode(a).addNode(b);
        final cycles = graph.detectCycles();
        expect(cycles, isNotEmpty);
        // At least one cycle containing both a and b
        final cycleNames =
            cycles.first.map((id) => id.name).toSet();
        expect(cycleNames, containsAll(['a', 'b']));
      });

      test('detects transitive cycle A -> B -> C -> A', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('c', VersionConstraint.any)),
          ],
        );
        final c = DependencyNode(
          id: PackageId('c', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('a', VersionConstraint.any)),
          ],
        );
        final graph =
            DependencyGraph.empty().addNode(a).addNode(b).addNode(c);
        final cycles = graph.detectCycles();
        expect(cycles, isNotEmpty);
      });
    });

    group('topological sort', () {
      test('returns correct order for linear chain', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('c', VersionConstraint.any)),
          ],
        );
        final c = DependencyNode(
          id: PackageId('c', SemanticVersion.parse('1.0.0')),
        );
        final root = PackageId('a', SemanticVersion.parse('1.0.0'));
        final graph = DependencyGraph(
          nodes: {'a': a, 'b': b, 'c': c},
          roots: {root},
        );
        final sorted = graph.topologicalSort();
        final names = sorted.map((id) => id.name).toList();
        // Reversed post-order: a before b, b before c
        expect(names.indexOf('a'), lessThan(names.indexOf('b')));
        expect(names.indexOf('b'), lessThan(names.indexOf('c')));
      });

      test('throws StateError on cycle', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('a', VersionConstraint.any)),
          ],
        );
        final root = PackageId('a', SemanticVersion.parse('1.0.0'));
        final graph = DependencyGraph(
          nodes: {'a': a, 'b': b},
          roots: {root},
        );
        expect(() => graph.topologicalSort(), throwsStateError);
      });

      test('handles diamond dependency', () {
        // A -> B, A -> C, B -> D, C -> D
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
            DependencyEdge(target: PackageRef('c', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('d', VersionConstraint.any)),
          ],
        );
        final c = DependencyNode(
          id: PackageId('c', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('d', VersionConstraint.any)),
          ],
        );
        final d = DependencyNode(
          id: PackageId('d', SemanticVersion.parse('1.0.0')),
        );
        final root = PackageId('a', SemanticVersion.parse('1.0.0'));
        final graph = DependencyGraph(
          nodes: {'a': a, 'b': b, 'c': c, 'd': d},
          roots: {root},
        );
        final sorted = graph.topologicalSort();
        final names = sorted.map((id) => id.name).toList();
        // Reversed post-order: a comes first, d comes last
        expect(names.indexOf('a'), 0);
        expect(names.indexOf('b'), lessThan(names.indexOf('d')));
        expect(names.indexOf('c'), lessThan(names.indexOf('d')));
      });
    });

    group('getPath', () {
      test('finds direct path', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
          dependencies: [
            DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
          ],
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
        );
        final graph = DependencyGraph.empty().addNode(a).addNode(b);
        final path = graph.getPath(a.id, b.id);
        expect(path, isNotNull);
        expect(path!.map((id) => id.name), ['a', 'b']);
      });

      test('returns null when no path exists', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
        );
        final b = DependencyNode(
          id: PackageId('b', SemanticVersion.parse('1.0.0')),
        );
        final graph = DependencyGraph.empty().addNode(a).addNode(b);
        final path = graph.getPath(a.id, b.id);
        expect(path, isNull);
      });

      test('finds path to self', () {
        final a = DependencyNode(
          id: PackageId('a', SemanticVersion.parse('1.0.0')),
        );
        final graph = DependencyGraph.empty().addNode(a);
        final path = graph.getPath(a.id, a.id);
        expect(path, isNotNull);
        expect(path!.length, 1);
        expect(path.first.name, 'a');
      });
    });
  });

  group('DependencyTree', () {
    test('builds tree from simple graph', () {
      final a = DependencyNode(
        id: PackageId('a', SemanticVersion.parse('1.0.0')),
        dependencies: [
          DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
        ],
      );
      final b = DependencyNode(
        id: PackageId('b', SemanticVersion.parse('1.0.0')),
      );
      final graph = DependencyGraph.empty().addNode(a).addNode(b);
      final tree = DependencyTree.fromGraph(graph, a.id);
      expect(tree.root, a.id);
      expect(tree.children.length, 1);
      expect(tree.children.first.root.name, 'b');
      expect(tree.isRepeat, false);
    });

    test('marks repeated nodes', () {
      // A -> B -> A (cycle causes isRepeat on the back-edge)
      final a = DependencyNode(
        id: PackageId('a', SemanticVersion.parse('1.0.0')),
        dependencies: [
          DependencyEdge(target: PackageRef('b', VersionConstraint.any)),
        ],
      );
      final b = DependencyNode(
        id: PackageId('b', SemanticVersion.parse('1.0.0')),
        dependencies: [
          DependencyEdge(target: PackageRef('a', VersionConstraint.any)),
        ],
      );
      final graph = DependencyGraph.empty().addNode(a).addNode(b);
      final tree = DependencyTree.fromGraph(graph, a.id);
      // The second occurrence of 'a' (under b) should be marked as repeat
      final aNodes = <DependencyTree>[];
      void collectA(DependencyTree node) {
        if (node.root.name == 'a') aNodes.add(node);
        for (final child in node.children) {
          collectA(child);
        }
      }
      collectA(tree);
      expect(aNodes.any((n) => n.isRepeat), true);
    });

    test('format produces non-empty output', () {
      final a = DependencyNode(
        id: PackageId('a', SemanticVersion.parse('1.0.0')),
      );
      final graph = DependencyGraph.empty().addNode(a);
      final tree = DependencyTree.fromGraph(graph, a.id);
      final formatted = tree.format();
      expect(formatted, contains('a@1.0.0'));
    });
  });
}
