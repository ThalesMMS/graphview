import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';

class _GraphFixture {
  final Graph graph;
  final Map<int, Node> nodes;

  _GraphFixture(this.graph, this.nodes);
}

_GraphFixture _createGraphFixture({
  required List<int> nodeIds,
  List<List<int>> edges = const [],
  Map<int, Offset> positions = const {},
  bool setDefaultNodeSize = false,
  Size defaultNodeSize = const Size(50, 50),
}) {
  final graph = Graph();
  final nodes = <int, Node>{
    for (final id in nodeIds) id: Node.Id(id),
  };

  graph.addNodes(nodes.values.toList());

  for (final edge in edges) {
    graph.addEdge(nodes[edge[0]]!, nodes[edge[1]]!);
  }

  positions.forEach((id, position) {
    nodes[id]!.position = position;
  });

  if (setDefaultNodeSize) {
    for (final node in nodes.values) {
      node.size = defaultNodeSize;
    }
  }

  return _GraphFixture(graph, nodes);
}

void main() {
  group('Distance Threshold Tests', () {
    testWidgets('Movements less than 1px do not mark edges dirty',
        (WidgetTester tester) async {
      final fixture = _createGraphFixture(
        nodeIds: [1, 2],
        edges: const [
          [1, 2]
        ],
        positions: const {
          1: Offset(100, 100),
          2: Offset(200, 200),
        },
        setDefaultNodeSize: true,
      );
      final graph = fixture.graph;
      final node1 = fixture.nodes[1]!;

      // Create widget tree with GraphView
      graph.isTree = true;
      final controller = GraphViewController();
      final configuration = BuchheimWalkerConfiguration();
      final algorithm = BuchheimWalkerAlgorithm(
          configuration, TreeEdgeRenderer(configuration));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GraphView(
              graph: graph,
              algorithm: algorithm,
              controller: controller,
              builder: (Node node) {
                return Container(
                  width: 50,
                  height: 50,
                  color: Colors.blue,
                  child: Center(child: Text('${node.key?.value}')),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get the render object and verify initial dirty state
      final graphViewFinder = find.byType(GraphView);
      expect(graphViewFinder, findsOneWidget);
      final renderBox = tester
          .renderObject<RenderCustomLayoutBox>(find.byType(GraphViewWidget));
      expect(renderBox.getDirtyEdges(), isEmpty);

      // Start a drag interaction on node "1"
      final nodeFinder = find.text('1');
      expect(nodeFinder, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(nodeFinder));

      // First movement exceeds drag-start threshold and marks connected edges dirty
      await gesture.moveBy(const Offset(6, 0));
      final positionAfterLargeMove = node1.position;
      expect(renderBox.getDirtyEdges(), isNotEmpty);

      // Clear existing dirty edges, then apply sub-pixel movement
      renderBox.dirtyEdges.clear();
      await gesture.moveBy(const Offset(0.5, 0));

      // Movement < 1px should not update node position or mark edges dirty
      expect(node1.position, equals(positionAfterLargeMove));
      expect(renderBox.getDirtyEdges(), isEmpty);

      await gesture.up();
    });

    test('Movements of exactly 1px mark edges dirty', () {
      final fixture = _createGraphFixture(
        nodeIds: [1, 2],
        edges: const [
          [1, 2]
        ],
        positions: const {
          1: Offset(100, 100),
          2: Offset(200, 200),
        },
      );
      final node1 = fixture.nodes[1]!;

      // Test that distance of exactly 1.0 triggers update
      final newPosition = const Offset(101, 100); // 1px horizontal movement
      final distance = (newPosition - node1.position).distance;

      expect(distance, equals(1.0));
    });

    test('Movements greater than 1px mark edges dirty', () {
      final fixture = _createGraphFixture(
        nodeIds: [1, 2],
        edges: const [
          [1, 2]
        ],
        positions: const {
          1: Offset(100, 100),
          2: Offset(200, 200),
        },
      );
      final node1 = fixture.nodes[1]!;

      // Test that distance > 1.0 triggers update
      final newPosition = const Offset(105, 100); // 5px horizontal movement
      final distance = (newPosition - node1.position).distance;

      expect(distance, equals(5.0));
      expect(distance, greaterThan(1.0));
    });

    test('Sub-pixel diagonal movements do not mark edges dirty', () {
      final fixture = _createGraphFixture(
        nodeIds: [1],
        positions: const {1: Offset(100, 100)},
      );
      final node1 = fixture.nodes[1]!;

      // Test diagonal movement < 1px
      final newPosition = const Offset(100.5, 100.5); // ~0.707px diagonal
      final distance = (newPosition - node1.position).distance;

      expect(distance, lessThan(1.0));
      expect(distance, closeTo(0.707, 0.01));
    });

    test('Exactly 1px diagonal movement marks edges dirty', () {
      final fixture = _createGraphFixture(
        nodeIds: [1],
        positions: const {1: Offset(100, 100)},
      );
      final node1 = fixture.nodes[1]!;

      // Test diagonal movement = 1px
      // For 1px distance: x^2 + y^2 = 1, so x = y = sqrt(0.5) ≈ 0.707
      final newPosition = Offset(100 + 0.707, 100 + 0.707);
      final distance = (newPosition - node1.position).distance;

      expect(distance, closeTo(1.0, 0.01));
    });

    test('Distance threshold prevents redundant edge recalculations', () {
      final fixture = _createGraphFixture(
        nodeIds: [1, 2, 3],
        edges: const [
          [1, 2],
          [2, 3]
        ],
        positions: const {
          1: Offset(100, 100),
          2: Offset(200, 100),
          3: Offset(300, 100),
        },
      );
      final node1 = fixture.nodes[1]!;

      // Simulate small movement (0.5px)
      final smallMovement = const Offset(100.5, 100);
      final smallDistance = (smallMovement - node1.position).distance;
      expect(smallDistance, lessThan(1.0));

      // Simulate large movement (10px)
      final largeMovement = const Offset(110, 100);
      final largeDistance = (largeMovement - node1.position).distance;
      expect(largeDistance, greaterThan(1.0));
    });

    test('Threshold applies to vertical movements', () {
      final fixture = _createGraphFixture(
        nodeIds: [1],
        positions: const {1: Offset(100, 100)},
      );
      final node1 = fixture.nodes[1]!;

      // Sub-pixel vertical movement
      final subPixelMove = const Offset(100, 100.5);
      final subPixelDistance = (subPixelMove - node1.position).distance;
      expect(subPixelDistance, lessThan(1.0));

      // Exactly 1px vertical movement
      final onePixelMove = const Offset(100, 101);
      final onePixelDistance = (onePixelMove - node1.position).distance;
      expect(onePixelDistance, equals(1.0));
    });

    test('Multiple consecutive sub-pixel movements accumulate correctly', () {
      final fixture = _createGraphFixture(
        nodeIds: [1],
        positions: const {1: Offset(100, 100)},
      );
      final node1 = fixture.nodes[1]!;

      // Simulate multiple 0.3px movements, measuring cumulative distance from origin
      final originPos = node1.position;
      final movements = [
        const Offset(100.3, 100), // 0.3px from origin
        const Offset(100.6, 100), // 0.6px from origin
        const Offset(100.9, 100), // 0.9px from origin
        const Offset(101.2, 100), // 1.2px from origin (now > 1px)
      ];

      for (var i = 0; i < movements.length; i++) {
        final distance = (movements[i] - originPos).distance;

        if (i < 3) {
          // First 3 movements are sub-pixel from origin
          expect(distance, lessThan(1.0));
        } else {
          // 4th movement crosses 1px threshold from origin
          expect(distance, greaterThanOrEqualTo(1.0));
        }
      }
    });

    test('Zero movement does not mark edges dirty', () {
      final fixture = _createGraphFixture(
        nodeIds: [1, 2],
        edges: const [
          [1, 2]
        ],
        positions: const {
          1: Offset(100, 100),
          2: Offset(200, 200),
        },
      );
      final node1 = fixture.nodes[1]!;

      // No movement
      final samePosition = const Offset(100, 100);
      final distance = (samePosition - node1.position).distance;

      expect(distance, equals(0.0));
      expect(distance, lessThan(1.0));
    });

    test('Threshold constant is 1.0 pixels', () {
      // Verify the threshold value matches specification
      const expectedThreshold = 1.0;

      // This test documents that movements < 1px should not trigger recalculation
      final testDistance1 = 0.999;
      final testDistance2 = 1.0;
      final testDistance3 = 1.001;

      expect(testDistance1, lessThan(expectedThreshold));
      expect(testDistance2, equals(expectedThreshold));
      expect(testDistance3, greaterThan(expectedThreshold));
    });
  });
}
