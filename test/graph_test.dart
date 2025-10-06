import 'package:flutter/widgets.dart';
import 'package:graphview/GraphView.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Graph', () {
    test('Graph Node counts are correct', () {
      final graph = Graph();
      var node1 = Node.Id('One');
      var node2 = Node.Id('Two');
      var node3 = Node.Id('Three');
      var node4 = Node.Id('Four');
      var node5 = Node.Id('Five');
      var node6 = Node.Id('Six');
      var node7 = Node.Id('Seven');
      var node8 = Node.Id('Eight');
      var node9 = Node.Id('Nine');

      graph.addEdge(node1, node2);
      graph.addEdge(node1, node4);
      graph.addEdge(node2, node3);
      graph.addEdge(node2, node5);
      graph.addEdge(node3, node6);
      graph.addEdge(node4, node5);
      graph.addEdge(node4, node7);
      graph.addEdge(node5, node6);
      graph.addEdge(node5, node8);
      graph.addEdge(node6, node9);
      graph.addEdge(node7, node8);
      graph.addEdge(node8, node9);

      expect(graph.nodeCount(), 9);

      graph.removeNode(Node.Id('One'));
      graph.removeNode(Node.Id('Ten'));

      expect(graph.nodeCount(), 8);

      graph.addNode(Node.Id('Ten'));

      expect(graph.nodeCount(), 9);
    });

    test('Node Hash Implementation is performant', () {
      final graph = Graph();

      var rows = 1000000;

      var integerNode = Node.Id(1);
      var stringNode = Node.Id('123');
      var stringNode2 = Node.Id('G9Q84H1R9-1619338713.000900');
      var widgetNode = Node.Id(Text('Lovely'));
      var widgetNode2 = Node.Id(Text('Lovely'));
      var doubleNode = Node.Id(5.6);

      var edge = graph.addEdge(integerNode, Node.Id(4));

      var nodes = [
        integerNode,
        stringNode,
        stringNode2,
        widgetNode,
        widgetNode2,
        doubleNode
      ];

      for (var node in nodes) {
        var stopwatch = Stopwatch()
          ..start();
        for (var i = 1; i <= rows; i++) {
          var hash = node.hashCode;
        }
        var timeTaken = stopwatch.elapsed.inMilliseconds;
        print('Time taken: $timeTaken ms for ${node.runtimeType} node');
        expect(timeTaken < 100, true);
      }
    });

    test('Graph does not duplicate nodes for self loops', () {
      final graph = Graph();
      final node = Node.Id('self');

      graph.addEdge(node, node);

      expect(graph.nodes.length, 1);
      expect(graph.edges.length, 1);
      expect(graph.nodes.single, node);
    });

    test('ArrowEdgeRenderer builds self-loop path', () {
      final renderer = ArrowEdgeRenderer();
      final node = Node.Id('self')
        ..size = const Size(40, 40)
        ..position = const Offset(100, 100);

      final edge = Edge(node, node);
      final result = renderer.buildSelfLoopPath(edge, arrowLength: 0);

      expect(result, isNotNull);

      final metrics = result!.path.computeMetrics().toList();
      expect(metrics, isNotEmpty);
      expect(metrics.first.length, greaterThan(0));

      final loopPadding = 16.0;
      final horizontalRadius = node.width * 0.5 + loopPadding;
      final verticalRadius = node.height * 0.5 + loopPadding;

      final ellipseCenter = Offset(
        node.position.dx + node.width * 0.5,
        node.position.dy - verticalRadius,
      );

      final expectedBounds = Rect.fromLTRB(
        ellipseCenter.dx - horizontalRadius,
        ellipseCenter.dy - verticalRadius,
        ellipseCenter.dx + horizontalRadius,
        node.position.dy,
      );

      final bounds = result.path.getBounds();
      expect(bounds.left, closeTo(expectedBounds.left, 0.01));
      expect(bounds.top, closeTo(expectedBounds.top, 0.01));
      expect(bounds.right, closeTo(expectedBounds.right, 0.01));
      expect(bounds.bottom, closeTo(expectedBounds.bottom, 0.01));

      final metric = metrics.first;
      final tangent = metric.getTangentForOffset(metric.length);
      expect(tangent, isNotNull);
      expect(tangent!.vector.dx, closeTo(0, 1e-3));
      expect(tangent.vector.dy, greaterThan(0));

      final expectedEnd = Offset(
        ellipseCenter.dx - horizontalRadius,
        ellipseCenter.dy,
      );
      expect(result.arrowTip.dx, closeTo(expectedEnd.dx, 0.01));
      expect(result.arrowTip.dy, closeTo(expectedEnd.dy, 0.01));
    });

    test('SugiyamaAlgorithm handles single node self loop', () {
      final graph = Graph();
      final node = Node.Id('self')
        ..size = const Size(40, 40);

      graph.addEdge(node, node);

      final config = SugiyamaConfiguration()
        ..nodeSeparation = 20
        ..levelSeparation = 20;

      final algorithm = SugiyamaAlgorithm(config);

      expect(() => algorithm.run(graph, 0, 0), returnsNormally);
      expect(graph.nodes.length, 1);
    });
  });
}
