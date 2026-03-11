import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';

class _StaticAlgorithm extends Algorithm {
  @override
  void init(Graph? graph) {}

  @override
  Size run(Graph? graph, double shiftX, double shiftY) {
    if (graph == null || graph.nodes.isEmpty) {
      return Size.zero;
    }

    var maxX = 0.0;
    var maxY = 0.0;
    for (final node in graph.nodes) {
      maxX = math.max(maxX, node.position.dx + node.width);
      maxY = math.max(maxY, node.position.dy + node.height);
    }

    return Size(maxX + 32, maxY + 32);
  }

  @override
  void setDimensions(double width, double height) {}
}

class _TrackingEdgeRenderer extends EdgeRenderer {
  Offset? lastSourceCenter;
  Offset? lastDestinationCenter;

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    lastSourceCenter = getNodeCenter(edge.source);
    lastDestinationCenter = getNodeCenter(edge.destination);
  }
}

void main() {
  group('GraphView Controller Tests', () {
    testWidgets('animateToNode centers the target node', (
      WidgetTester tester,
    ) async {
      // Setup graph
      final graph = Graph();
      final targetNode = Node.Id('target');
      targetNode.key = const ValueKey('target');
      final otherNode = Node.Id('other');

      graph.addEdge(targetNode, otherNode);

      final transformationController = TransformationController();
      final controller = GraphViewController(
        transformationController: transformationController,
      );
      final configuration = BuchheimWalkerConfiguration();
      final algorithm = BuchheimWalkerAlgorithm(
        configuration,
        TreeEdgeRenderer(configuration),
      );

      // Build widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: GraphView.builder(
                graph: graph,
                algorithm: algorithm,
                controller: controller,
                builder: (node) => Container(
                  width: 100,
                  height: 50,
                  color: Colors.blue,
                  child: Text(node.key?.value ?? ''),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get the actual position of target node after algorithm runs
      final actualNodePosition = targetNode.position;
      final nodeCenter = Offset(
        actualNodePosition.dx + targetNode.width / 2,
        actualNodePosition.dy + targetNode.height / 2,
      );

      // Get initial transformation
      final initialMatrix = transformationController.value;

      // Animate to target node
      controller.animateToNode(const ValueKey('target'));

      // Let animation complete
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify transformation changed
      final finalMatrix = transformationController.value;
      expect(finalMatrix, isNot(equals(initialMatrix)));

      // With viewport size 400x600, center should be at (200, 300)
      // Expected translation should center the node at viewport center
      final expectedTranslationX =
          200 - nodeCenter.dx; // viewport_center_x - node_center_x
      final expectedTranslationY =
          300 - nodeCenter.dy; // viewport_center_y - node_center_y

      expect(finalMatrix.getTranslation().x, closeTo(expectedTranslationX, 5));
      expect(finalMatrix.getTranslation().y, closeTo(expectedTranslationY, 5));
    });

    testWidgets('animateToNode handles non-existent node gracefully', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      final node = Node.Id('exists');
      graph.nodes.add(node);

      final transformationController = TransformationController();
      final controller = GraphViewController(
        transformationController: transformationController,
      );
      final algorithm = BuchheimWalkerAlgorithm(
        BuchheimWalkerConfiguration(),
        TreeEdgeRenderer(BuchheimWalkerConfiguration()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: GraphView.builder(
            graph: graph,
            algorithm: algorithm,
            controller: controller,
            builder: (node) => Container(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialMatrix = transformationController.value;

      // Try to animate to non-existent node
      controller.animateToNode(const ValueKey('nonexistent'));
      await tester.pumpAndSettle();

      // Matrix should remain unchanged
      final finalMatrix = transformationController.value;
      expect(finalMatrix, equals(initialMatrix));
    });

    testWidgets('panAnimationCurve delays matrix interpolation when provided', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      final targetNode = Node.Id('target');
      targetNode.key = const ValueKey('target');
      final otherNode = Node.Id('other');
      graph.addEdge(targetNode, otherNode);

      final transformationController = TransformationController();
      final controller = GraphViewController(
        transformationController: transformationController,
      );
      final algorithm = BuchheimWalkerAlgorithm(
        BuchheimWalkerConfiguration(),
        TreeEdgeRenderer(BuchheimWalkerConfiguration()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: GraphView.builder(
                graph: graph,
                algorithm: algorithm,
                controller: controller,
                panAnimationDuration: const Duration(milliseconds: 600),
                panAnimationCurve: const Threshold(0.8),
                builder: (node) => Container(
                  width: 100,
                  height: 50,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final initialMatrix = List<double>.from(
        transformationController.value.storage,
      );

      controller.animateToNode(const ValueKey('target'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        List<double>.from(transformationController.value.storage),
        equals(initialMatrix),
      );

      await tester.pumpAndSettle();

      expect(
        List<double>.from(transformationController.value.storage),
        isNot(equals(initialMatrix)),
      );
    });

    testWidgets('pan animation defaults to linear interpolation', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      final targetNode = Node.Id('target');
      targetNode.key = const ValueKey('target');
      final otherNode = Node.Id('other');
      graph.addEdge(targetNode, otherNode);

      final transformationController = TransformationController();
      final controller = GraphViewController(
        transformationController: transformationController,
      );
      final algorithm = BuchheimWalkerAlgorithm(
        BuchheimWalkerConfiguration(),
        TreeEdgeRenderer(BuchheimWalkerConfiguration()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: GraphView.builder(
                graph: graph,
                algorithm: algorithm,
                controller: controller,
                panAnimationDuration: const Duration(milliseconds: 600),
                builder: (node) => Container(
                  width: 100,
                  height: 50,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      controller.animateToNode(const ValueKey('target'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final halfwayMatrix = Matrix4.copy(transformationController.value);

      await tester.pumpAndSettle();

      final finalMatrix = transformationController.value;
      expect(
        halfwayMatrix.getTranslation().x,
        closeTo(finalMatrix.getTranslation().x / 2, 5),
      );
      expect(
        halfwayMatrix.getTranslation().y,
        closeTo(finalMatrix.getTranslation().y / 2, 5),
      );
    });

    testWidgets('nodeAnimationCurve changes intermediate node positions', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      final node = Node.Id('moving');
      node.position = Offset.zero;
      graph.addNode(node);

      final controller = GraphViewController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: GraphView.builder(
                graph: graph,
                algorithm: _StaticAlgorithm(),
                controller: controller,
                includeAllVisibleNodes: true,
                toggleAnimationDuration: const Duration(milliseconds: 600),
                nodeAnimationCurve: const Threshold(0.8),
                builder: (current) => Container(
                  key: ValueKey(current.key?.value ?? 'node'),
                  width: 80,
                  height: 40,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final renderObject = tester.renderObject<RenderCustomLayoutBox>(
        find.byType(GraphViewWidget),
      );

      node.position = const Offset(200, 0);
      controller.forceRecalculation();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final halfwayPosition = renderObject.animatedPositions[node];
      expect(halfwayPosition, isNotNull);
      expect(halfwayPosition!.dx, closeTo(0, 0.1));

      await tester.pumpAndSettle();

      final finalPosition = renderObject.animatedPositions[node];
      expect(finalPosition, isNotNull);
      expect(finalPosition!.dx, closeTo(200, 0.1));
    });

    testWidgets('node animation defaults to linear interpolation', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      final node = Node.Id('moving');
      node.position = Offset.zero;
      graph.addNode(node);

      final controller = GraphViewController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: GraphView.builder(
                graph: graph,
                algorithm: _StaticAlgorithm(),
                controller: controller,
                includeAllVisibleNodes: true,
                toggleAnimationDuration: const Duration(milliseconds: 600),
                builder: (current) => Container(
                  key: ValueKey(current.key?.value ?? 'node'),
                  width: 80,
                  height: 40,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final renderObject = tester.renderObject<RenderCustomLayoutBox>(
        find.byType(GraphViewWidget),
      );

      node.position = const Offset(200, 0);
      controller.forceRecalculation();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final halfwayPosition = renderObject.animatedPositions[node];
      expect(halfwayPosition, isNotNull);
      expect(halfwayPosition!.dx, closeTo(100, 1));

      await tester.pumpAndSettle();

      final finalPosition = renderObject.animatedPositions[node];
      expect(finalPosition, isNotNull);
      expect(finalPosition!.dx, closeTo(200, 0.1));
    });

    testWidgets(
      're-enabling animation after direct position updates does not animate from stale offsets',
      (WidgetTester tester) async {
        final graph = Graph();
        final node = Node.Id('moving');
        node.position = Offset.zero;
        graph.addNode(node);

        final controller = GraphViewController();
        var animated = true;
        late StateSetter setAnimated;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  setAnimated = setState;
                  return SizedBox(
                    width: 400,
                    height: 300,
                    child: GraphView.builder(
                      graph: graph,
                      algorithm: _StaticAlgorithm(),
                      controller: controller,
                      animated: animated,
                      includeAllVisibleNodes: true,
                      toggleAnimationDuration: const Duration(
                        milliseconds: 600,
                      ),
                      builder: (current) => Container(
                        key: ValueKey(current.key?.value ?? 'node'),
                        width: 80,
                        height: 40,
                        color: Colors.teal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        node.position = const Offset(120, 0);
        setAnimated(() {
          animated = false;
        });
        controller.forceRecalculation();
        await tester.pumpAndSettle();

        setAnimated(() {
          animated = true;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final renderObject = tester.renderObject<RenderCustomLayoutBox>(
          find.byType(GraphViewWidget),
        );
        final halfwayPosition = renderObject.animatedPositions[node];
        expect(halfwayPosition, isNotNull);
        expect(halfwayPosition!.dx, closeTo(120, 0.1));

        await tester.pumpAndSettle();

        final finalPosition = renderObject.animatedPositions[node];
        expect(finalPosition, isNotNull);
        expect(finalPosition!.dx, closeTo(120, 0.1));
      },
    );

    testWidgets(
      'non-animated paints use current node positions for edge rendering',
      (WidgetTester tester) async {
        final graph = Graph();
        final source = Node.Id('source')
          ..position = Offset.zero
          ..size = const Size(80, 40);
        final destination = Node.Id('destination')
          ..position = const Offset(220, 0)
          ..size = const Size(80, 40);
        graph
          ..addNode(source)
          ..addNode(destination)
          ..addEdge(source, destination);

        final controller = GraphViewController();
        final renderer = _TrackingEdgeRenderer();
        final algorithm = _StaticAlgorithm()..renderer = renderer;
        var animated = true;
        late StateSetter setAnimated;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  setAnimated = setState;
                  return SizedBox(
                    width: 400,
                    height: 300,
                    child: GraphView.builder(
                      graph: graph,
                      algorithm: algorithm,
                      controller: controller,
                      animated: animated,
                      includeAllVisibleNodes: true,
                      toggleAnimationDuration: const Duration(
                        milliseconds: 600,
                      ),
                      builder: (current) => Container(
                        key: ValueKey(current.key?.value ?? 'node'),
                        width: 80,
                        height: 40,
                        color: Colors.teal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        source.position = const Offset(120, 0);
        setAnimated(() {
          animated = false;
        });
        controller.forceRecalculation();
        await tester.pump();

        expect(renderer.lastSourceCenter, isNotNull);
        expect(renderer.lastSourceCenter!.dx, closeTo(160, 0.1));
        expect(renderer.lastDestinationCenter, isNotNull);
        expect(renderer.lastDestinationCenter!.dx, closeTo(260, 0.1));
      },
    );

    testWidgets('includeAllVisibleNodes renders disconnected nodes', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      graph.addNode(Node.Id('alpha'));
      graph.addNode(Node.Id('beta'));

      final algorithm = BuchheimWalkerAlgorithm(
        BuchheimWalkerConfiguration(),
        TreeEdgeRenderer(BuchheimWalkerConfiguration()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: GraphView.builder(
                graph: graph,
                algorithm: algorithm,
                includeAllVisibleNodes: true,
                builder: (node) => Text(node.key?.value.toString() ?? ''),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
    });

    testWidgets('default builder excludes extra disconnected nodes', (
      WidgetTester tester,
    ) async {
      final graph = Graph();
      graph.addNode(Node.Id('alpha'));
      graph.addNode(Node.Id('beta'));

      final algorithm = BuchheimWalkerAlgorithm(
        BuchheimWalkerConfiguration(),
        TreeEdgeRenderer(BuchheimWalkerConfiguration()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: GraphView.builder(
                graph: graph,
                algorithm: algorithm,
                builder: (node) => Text(node.key?.value.toString() ?? ''),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsNothing);
    });
  });

  group('Collapse Tests', () {
    late GraphViewController controller;

    setUp(() {
      controller = GraphViewController();
    });

    // Helper function to create a graph with multiple branches
    Graph createComplexGraph() {
      final g = Graph();

      final root = Node.Id(0);
      final branch1 = Node.Id(1);
      final branch2 = Node.Id(2);
      final leaf1 = Node.Id(3);
      final leaf2 = Node.Id(4);
      final leaf3 = Node.Id(5);
      final leaf4 = Node.Id(6);

      g.addEdge(root, branch1);
      g.addEdge(root, branch2);
      g.addEdge(branch1, leaf1);
      g.addEdge(branch1, leaf2);
      g.addEdge(branch2, leaf3);
      g.addEdge(branch2, leaf4);

      return g;
    }

    test('Complex graph - multiple branches', () {
      final g = createComplexGraph();
      final root = g.getNodeAtPosition(0);

      controller.collapseNode(g, root);

      final edges = controller.getCollapsingEdges(g);

      // Should get all 6 edges (root->branch1, root->branch2, branch1->leaf1, branch1->leaf2, branch2->leaf3, branch2->leaf4)
      expect(edges.length, 6);
    });

    test('Nested collapse preserves original hide relationships', () {
      final graph = Graph();
      final parent = Node.Id(0);
      final child = Node.Id(1);
      final grandchild = Node.Id(2);

      graph.addEdge(parent, child);
      graph.addEdge(child, grandchild);

      final controller = GraphViewController();

      // Step 1: Collapse child
      controller.collapseNode(graph, child);

      expect(controller.isNodeVisible(graph, parent), true);
      expect(controller.isNodeVisible(graph, child), true);
      expect(controller.isNodeVisible(graph, grandchild), false);
      expect(
        controller.hiddenBy[grandchild],
        child,
      ); // grandchild hidden by child

      // Step 2: Collapse parent
      controller.collapseNode(graph, parent);

      expect(controller.isNodeVisible(graph, parent), true);
      expect(controller.isNodeVisible(graph, child), false);
      expect(controller.isNodeVisible(graph, grandchild), false);
      expect(controller.hiddenBy[child], parent); // child hidden by parent
      expect(
        controller.hiddenBy[grandchild],
        child,
      ); // grandchild STILL hidden by child!

      // Step 3: Get collapsing edges for parent
      controller.collapsedNode = parent;
      final parentEdges = controller.getCollapsingEdges(graph);

      // Should only include parent -> child, NOT child -> grandchild
      expect(parentEdges.length, 1);
      expect(parentEdges.first.source, parent);
      expect(parentEdges.first.destination, child);

      // Step 4: Expand parent
      controller.expandNode(graph, parent);

      expect(controller.isNodeVisible(graph, parent), true);
      expect(controller.isNodeVisible(graph, child), true);
      expect(
        controller.isNodeVisible(graph, grandchild),
        false,
      ); // Still hidden!
      expect(controller.hiddenBy[grandchild], child); // Still hidden by child!

      // Step 5: Expand child
      controller.expandNode(graph, child);

      expect(controller.isNodeVisible(graph, parent), true);
      expect(controller.isNodeVisible(graph, child), true);
      expect(controller.isNodeVisible(graph, grandchild), true); // Now visible!
      expect(controller.hiddenBy.containsKey(grandchild), false);
    });

    test('includeAllVisibleNodes excludes hidden descendants', () {
      final graph = Graph();
      final parent = Node.Id('parent');
      final child = Node.Id('child');
      final disconnected = Node.Id('disconnected');

      graph.addEdge(parent, child);
      graph.addNode(disconnected);

      controller.collapseNode(graph, parent);

      final delegate = GraphChildDelegate(
        graph: graph,
        algorithm: BuchheimWalkerAlgorithm(
          BuchheimWalkerConfiguration(),
          TreeEdgeRenderer(BuchheimWalkerConfiguration()),
        ),
        builder: (_) => Container(),
        controller: controller,
        includeAllVisibleNodes: true,
      );

      final visibleGraph = delegate.getVisibleGraphOnly();

      expect(visibleGraph.nodes, contains(parent));
      expect(visibleGraph.nodes, contains(disconnected));
      expect(visibleGraph.nodes, isNot(contains(child)));
    });
  });
}
