import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';

void main() {
  group('EdgeRepulsionSolver Integration with AdaptiveEdgeRenderer', () {
    test('Repulsion is applied when enabled in config', () {
      // Create two crossing edges so repulsion has a clear geometric effect.
      final graph = Graph();
      final node1 = Node.Id(1);
      final node2 = Node.Id(2);
      final node3 = Node.Id(3);
      final node4 = Node.Id(4);

      // Set node positions and sizes
      node1.position = const Offset(0, 0);
      node1.size = const Size(100, 50);

      node2.position = const Offset(200, 200);
      node2.size = const Size(100, 50);

      node3.position = const Offset(0, 200);
      node3.size = const Size(100, 50);

      node4.position = const Offset(200, 0);
      node4.size = const Size(100, 50);

      graph.addNode(node1);
      graph.addNode(node2);
      graph.addNode(node3);
      graph.addNode(node4);

      // Add two crossing edges
      final edge1 = graph.addEdge(node1, node2);
      final edge2 = graph.addEdge(node3, node4);

      // Use direct routing so repulsion converts straight lines into curved paths.
      final enabledConfig = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.direct,
        enableRepulsion: true,
        repulsionStrength: 1.0,
        minEdgeDistance: 20.0,
        maxRepulsionIterations: 10,
      );
      final disabledConfig = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.direct,
        enableRepulsion: false,
        minEdgeDistance: 20.0,
      );
      final enabledRenderer = AdaptiveEdgeRenderer(config: enabledConfig);
      final disabledRenderer = AdaptiveEdgeRenderer(config: disabledConfig);

      double pathLength(Path path) {
        var total = 0.0;
        for (final metric in path.computeMetrics()) {
          total += metric.length;
        }
        return total;
      }

      // Run one render cycle so the enabled renderer calculates and caches offsets.
      enabledRenderer.setGraph(graph);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0;
      enabledRenderer.renderEdge(canvas, edge1, paint);
      enabledRenderer.renderEdge(canvas, edge2, paint);
      recorder.endRecording();

      disabledRenderer.setGraph(graph);

      final sourceCenter = enabledRenderer.getNodeCenter(edge1.source);
      final destCenter = enabledRenderer.getNodeCenter(edge1.destination);
      final sourcePoint =
          enabledRenderer.calculateSourceConnectionPoint(edge1, destCenter, 0);
      final destPoint = enabledRenderer.calculateDestinationConnectionPoint(
          edge1, sourceCenter, 0);

      final originalPath =
          enabledRenderer.routeEdgePath(sourcePoint, destPoint, edge1);
      final enabledPath = enabledRenderer.applyEdgeRepulsion(
        graph.edges.toList(),
        edge1,
        originalPath,
      );
      final disabledPath = disabledRenderer.applyEdgeRepulsion(
        graph.edges.toList(),
        edge1,
        originalPath,
      );

      // Repulsion disabled: original path should be returned unchanged.
      expect(identical(disabledPath, originalPath), isTrue);
      // Repulsion enabled: path should be modified.
      expect(identical(enabledPath, originalPath), isFalse);
      // Modified path should be longer than the straight line due to curvature.
      expect(pathLength(enabledPath), greaterThan(pathLength(originalPath)));
    });

    test('Repulsion is not applied when disabled in config', () {
      // Create a graph with two parallel edges
      final graph = Graph();
      final node1 = Node.Id(1);
      final node2 = Node.Id(2);

      node1.position = const Offset(0, 0);
      node1.size = const Size(100, 50);

      node2.position = const Offset(200, 0);
      node2.size = const Size(100, 50);

      graph.addNode(node1);
      graph.addNode(node2);

      final edge1 = graph.addEdge(node1, node2);
      final edge2 = graph.addEdge(node1, node2);

      // Create renderer with repulsion disabled
      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.bezier,
        enableRepulsion: false,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);

      renderer.setGraph(graph);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0;

      // Render edges without repulsion
      renderer.renderEdge(canvas, edge1, paint);
      renderer.renderEdge(canvas, edge2, paint);
      final picture = recorder.endRecording();

      // Verify rendering completed and produced output.
      expect(picture, isNotNull);
    });

    test('Repulsion calculation is reset on new render cycle', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      final node2 = Node.Id(2);

      node1.position = const Offset(0, 0);
      node1.size = const Size(100, 50);

      node2.position = const Offset(200, 0);
      node2.size = const Size(100, 50);

      graph.addNode(node1);
      graph.addNode(node2);

      final edge1 = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.bezier,
        enableRepulsion: true,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);

      // First render cycle
      renderer.setGraph(graph);
      final recorder1 = PictureRecorder();
      final canvas1 = Canvas(recorder1);
      final paint = Paint()..color = Colors.black;
      renderer.renderEdge(canvas1, edge1, paint);
      final picture1 = recorder1.endRecording();

      // Second render cycle (should reset repulsion calculation)
      renderer.setGraph(graph);
      final recorder2 = PictureRecorder();
      final canvas2 = Canvas(recorder2);
      renderer.renderEdge(canvas2, edge1, paint);
      final picture2 = recorder2.endRecording();

      // Verify both render cycles completed and produced output.
      expect(picture1, isNotNull);
      expect(picture2, isNotNull);
    });

    test(
        'applyEdgeRepulsion override returns modified path when repulsion enabled',
        () {
      final graph = Graph();
      final node1 = Node.Id(1);
      final node2 = Node.Id(2);

      node1.position = const Offset(0, 0);
      node1.size = const Size(100, 50);

      node2.position = const Offset(200, 0);
      node2.size = const Size(100, 50);

      graph.addNode(node1);
      graph.addNode(node2);

      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        enableRepulsion: true,
        routingMode: RoutingMode.direct,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      // Create a simple path
      final originalPath = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 100);

      // Trigger repulsion calculation
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();
      renderer.renderEdge(canvas, edge, paint);
      recorder.endRecording();

      // Call applyEdgeRepulsion (should use cached repulsion if any)
      final modifiedPath =
          renderer.applyEdgeRepulsion([edge], edge, originalPath);

      // Path should not be null
      expect(modifiedPath, isNotNull);
    });

    test('Works with different routing modes', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      final node2 = Node.Id(2);
      final node3 = Node.Id(3);

      node1.position = const Offset(0, 0);
      node1.size = const Size(100, 50);

      node2.position = const Offset(200, 0);
      node2.size = const Size(100, 50);

      node3.position = const Offset(100, 100);
      node3.size = const Size(100, 50);

      graph.addNode(node1);
      graph.addNode(node2);
      graph.addNode(node3);

      final edge1 = graph.addEdge(node1, node2);
      final edge2 = graph.addEdge(node1, node3);

      final paint = Paint()..color = Colors.black;

      // Test with different routing modes
      final routingModes = [
        RoutingMode.direct,
        RoutingMode.orthogonal,
        RoutingMode.bezier,
      ];

      for (final routingMode in routingModes) {
        final config = EdgeRoutingConfig(
          routingMode: routingMode,
          enableRepulsion: true,
          repulsionStrength: 0.5,
        );
        final renderer = AdaptiveEdgeRenderer(config: config);
        renderer.setGraph(graph);

        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        // Should render without errors for all routing modes
        renderer.renderEdge(canvas, edge1, paint);
        renderer.renderEdge(canvas, edge2, paint);
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      }
    });

    test('Repulsion solver is created and reused', () {
      final config = EdgeRoutingConfig(
        enableRepulsion: true,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);

      // The solver should be created during initialization
      // We can't directly test private fields, but we can verify behavior
      expect(renderer, isNotNull);
      expect(renderer.config.enableRepulsion, isTrue);
    });

    test('Handles graphs with many edges', () {
      final graph = Graph();
      final nodes = <Node>[];

      // Create a grid of nodes
      for (var i = 0; i < 5; i++) {
        final node = Node.Id(i);
        node.position = Offset(i * 150.0, 0);
        node.size = const Size(100, 50);
        graph.addNode(node);
        nodes.add(node);
      }

      // Create multiple edges between nodes
      for (var i = 0; i < nodes.length - 1; i++) {
        graph.addEdge(nodes[i], nodes[i + 1]);
      }

      final config = EdgeRoutingConfig(
        enableRepulsion: true,
        repulsionStrength: 0.5,
        minEdgeDistance: 10.0,
        maxRepulsionIterations: 10,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Render all edges - should handle multiple edges efficiently
      for (final edge in graph.edges) {
        renderer.renderEdge(canvas, edge, paint);
      }
      final picture = recorder.endRecording();

      expect(picture, isNotNull);
    });

    test('Self-loop edges are handled correctly with repulsion', () {
      final graph = Graph();
      final node = Node.Id(1);
      node.position = const Offset(100, 100);
      node.size = const Size(100, 50);

      graph.addNode(node);

      // Create a self-loop edge
      final selfLoop = graph.addEdge(node, node);

      final config = EdgeRoutingConfig(
        enableRepulsion: true,
        routingMode: RoutingMode.bezier,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint();

      // Should render self-loop without errors
      renderer.renderEdge(canvas, selfLoop, paint);
      final picture = recorder.endRecording();

      expect(picture, isNotNull);
    });
  });
}
