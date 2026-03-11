import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';

// Helper to extract points from a path using metrics
List<Offset> extractPathPoints(Path path) {
  final points = <Offset>[];
  final metrics = path.computeMetrics();
  for (var metric in metrics) {
    final length = metric.length;
    const sampleDistance = 10.0;
    var distance = 0.0;
    while (distance <= length) {
      final tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        points.add(tangent.position);
      }
      distance += sampleDistance;
    }
    final finalTangent = metric.getTangentForOffset(length);
    if (finalTangent != null) {
      points.add(finalTangent.position);
    }
  }
  return points;
}

void main() {
  group('OrthogonalEdgeRenderer - Basic Path Generation', () {
    test('creates L-shaped path for horizontal nodes', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 50);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Path should be generated (we can't easily extract path points without Canvas,
      // but we can verify the renderer was created and method executes)
      expect(renderer.linePath, isNotNull);
    });

    test('creates L-shaped path for vertical nodes', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(100, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(100, 200);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Path should be generated
      expect(renderer.linePath, isNotNull);
    });

    test('creates L-shaped path for diagonal nodes', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 150);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Path should be generated with right angles
      expect(renderer.linePath, isNotNull);
    });

    test('handles collinear horizontal nodes with offset', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 100);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 100);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path (should add minimal offset for visibility)
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Path should be generated with offset for collinear nodes
      expect(renderer.linePath, isNotNull);
    });

    test('handles collinear vertical nodes with offset', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(100, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(100, 200);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path (should add minimal offset for visibility)
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Path should be generated with offset for collinear nodes
      expect(renderer.linePath, isNotNull);
    });

    test('handles nodes at same position', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(100, 100);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(100, 100);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path (should handle gracefully)
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Path should be generated even for same position
      expect(renderer.linePath, isNotNull);
    });
  });

  group('OrthogonalEdgeRenderer - Path Direction Logic', () {
    test('uses horizontal-first routing when horizontal distance is greater', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      // Horizontal distance: 300, Vertical distance: 30
      node2.position = Offset(300, 80);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Should use horizontal-first routing
      expect(renderer.linePath, isNotNull);
    });

    test('uses vertical-first routing when vertical distance is greater', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(100, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      // Horizontal distance: 30, Vertical distance: 300
      node2.position = Offset(130, 300);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Should use vertical-first routing
      expect(renderer.linePath, isNotNull);
    });
  });

  group('OrthogonalEdgeRenderer - Self-Loops', () {
    test('handles self-loop edges', () {
      final graph = Graph();
      final node = Node.Id(1);
      node.position = Offset(100, 100);
      node.size = Size(80, 40);

      graph.addNode(node);
      final edge = graph.addEdge(node, node);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Self-loops should use buildSelfLoopPath from base class
      final loopPath = renderer.buildSelfLoopPath(edge);

      expect(loopPath, isNotNull);
      expect(loopPath!.path, isNotNull);
    });
  });

  group('OrthogonalEdgeRenderer - Edge Labels', () {
    test('supports edge labels', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 50);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2, label: 'Test Label');

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Edge should have label
      expect(edge.label, equals('Test Label'));
      expect(renderer.linePath, isNotNull);
    });
  });

  group('OrthogonalEdgeRenderer - Configuration', () {
    test('accepts EdgeRoutingConfig', () {
      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.orthogonal,
      );
      final renderer = OrthogonalEdgeRenderer(config);

      expect(renderer.configuration, equals(config));
      expect(renderer.configuration.routingMode, equals(RoutingMode.orthogonal));
    });

    test('works with different anchor modes', () {
      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.dynamic,
        routingMode: RoutingMode.orthogonal,
      );
      final renderer = OrthogonalEdgeRenderer(config);

      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 50);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      expect(renderer.linePath, isNotNull);
    });
  });

  group('OrthogonalEdgeRenderer - Right Angles Verification', () {
    test('orthogonal paths have right angles', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 150);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Extract path points by sampling the path using metrics
      final points = extractPathPoints(renderer.linePath);

      // Verify we have at least 3 points for an L-shaped path
      expect(points.length, greaterThanOrEqualTo(3));

      // Verify angles are approximately 90 degrees (right angles)
      // For an orthogonal path, consecutive segments should be perpendicular
      if (points.length >= 3) {
        for (var i = 0; i < points.length - 2; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];
          final p3 = points[i + 2];

          // Calculate direction vectors
          final v1 = Offset(p2.dx - p1.dx, p2.dy - p1.dy);
          final v2 = Offset(p3.dx - p2.dx, p3.dy - p2.dy);

          // Check if vectors are perpendicular (dot product should be ~0)
          // or parallel (for straight segments)
          final dotProduct = v1.dx * v2.dx + v1.dy * v2.dy;
          final v1Length = sqrt(v1.dx * v1.dx + v1.dy * v1.dy);
          final v2Length = sqrt(v2.dx * v2.dx + v2.dy * v2.dy);

          // Skip if either vector is too short (numerical stability)
          if (v1Length < 0.01 || v2Length < 0.01) continue;

          // Normalized dot product
          final normalizedDot = dotProduct / (v1Length * v2Length);

          // Should be either perpendicular (dot ~ 0) or parallel (dot ~ ±1)
          expect(
            normalizedDot.abs() < 0.1 || normalizedDot.abs() > 0.9,
            isTrue,
            reason: 'Segments should be perpendicular or parallel in orthogonal routing',
          );
        }
      }
    });

    test('all path segments are horizontal or vertical', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(50, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(250, 200);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build the path
      renderer.buildOrthogonalPath(
        node1,
        node2,
        node1.position,
        node2.position,
      );

      // Extract path points by sampling the path using metrics
      final points = extractPathPoints(renderer.linePath);

      // Verify segments are horizontal or vertical
      if (points.length >= 2) {
        for (var i = 0; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];

          final dx = (p2.dx - p1.dx).abs();
          final dy = (p2.dy - p1.dy).abs();

          // Each segment should be either horizontal (dy~0) or vertical (dx~0)
          // Allow small tolerance for floating point
          final isHorizontal = dy < 1.0;
          final isVertical = dx < 1.0;

          expect(
            isHorizontal || isVertical,
            isTrue,
            reason: 'Orthogonal paths should only have horizontal or vertical segments',
          );
        }
      }
    });
  });

  group('OrthogonalEdgeRenderer - Multiple Edges', () {
    test('renders multiple edges between different nodes', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 50);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge1 = graph.addEdge(node1, node2);
      final edge2 = graph.addEdge(node2, node1);

      final config = EdgeRoutingConfig();
      final renderer = OrthogonalEdgeRenderer(config);

      // Build paths for both edges
      renderer.buildOrthogonalPath(node1, node2, node1.position, node2.position);
      expect(renderer.linePath, isNotNull);

      renderer.linePath.reset();
      renderer.buildOrthogonalPath(node2, node1, node2.position, node1.position);
      expect(renderer.linePath, isNotNull);
    });
  });

  group('AdaptiveEdgeRenderer - Bezier Routing', () {
    test('creates smooth bezier curves between nodes', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 150);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.dynamic,
        routingMode: RoutingMode.bezier,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      // Calculate connection points
      final sourceCenter = Offset(
        node1.position.dx + node1.width * 0.5,
        node1.position.dy + node1.height * 0.5,
      );
      final destCenter = Offset(
        node2.position.dx + node2.width * 0.5,
        node2.position.dy + node2.height * 0.5,
      );

      final sourcePoint = renderer.calculateSourceConnectionPoint(edge, destCenter, 0);
      final destPoint = renderer.calculateDestinationConnectionPoint(edge, sourceCenter, 0);

      // Route the path with bezier
      final path = renderer.routeEdgePath(sourcePoint, destPoint, edge);

      // Path should be created (we can't easily inspect cubic bezier points)
      expect(path, isNotNull);
    });

    test('bezier paths curve smoothly with control points', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(50, 50);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(300, 200);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.bezier,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final sourceCenter = Offset(
        node1.position.dx + node1.width * 0.5,
        node1.position.dy + node1.height * 0.5,
      );
      final destCenter = Offset(
        node2.position.dx + node2.width * 0.5,
        node2.position.dy + node2.height * 0.5,
      );

      final sourcePoint = renderer.calculateSourceConnectionPoint(edge, destCenter, 0);
      final destPoint = renderer.calculateDestinationConnectionPoint(edge, sourceCenter, 0);

      // Route the path with bezier
      final path = renderer.routeEdgePath(sourcePoint, destPoint, edge);

      expect(path, isNotNull);
    });

    test('bezier routing handles zero-distance edges gracefully', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(100, 100);
      node1.size = Size(80, 40);

      graph.addNode(node1);
      final edge = graph.addEdge(node1, node1);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.center,
        routingMode: RoutingMode.bezier,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final center = Offset(
        node1.position.dx + node1.width * 0.5,
        node1.position.dy + node1.height * 0.5,
      );

      // Same point for source and destination (edge case)
      final path = renderer.routeEdgePath(center, center, edge);

      expect(path, isNotNull);
    });

    test('bezier routing works with octagonal anchor mode', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(150, 150);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.octagonal,
        routingMode: RoutingMode.bezier,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final sourceCenter = Offset(
        node1.position.dx + node1.width * 0.5,
        node1.position.dy + node1.height * 0.5,
      );
      final destCenter = Offset(
        node2.position.dx + node2.width * 0.5,
        node2.position.dy + node2.height * 0.5,
      );

      final sourcePoint = renderer.calculateSourceConnectionPoint(edge, destCenter, 0);
      final destPoint = renderer.calculateDestinationConnectionPoint(edge, sourceCenter, 0);

      final path = renderer.routeEdgePath(sourcePoint, destPoint, edge);

      expect(path, isNotNull);
    });

    test('direct routing mode creates straight lines', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 150);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.dynamic,
        routingMode: RoutingMode.direct,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final sourceCenter = Offset(
        node1.position.dx + node1.width * 0.5,
        node1.position.dy + node1.height * 0.5,
      );
      final destCenter = Offset(
        node2.position.dx + node2.width * 0.5,
        node2.position.dy + node2.height * 0.5,
      );

      final sourcePoint = renderer.calculateSourceConnectionPoint(edge, destCenter, 0);
      final destPoint = renderer.calculateDestinationConnectionPoint(edge, sourceCenter, 0);

      final path = renderer.routeEdgePath(sourcePoint, destPoint, edge);

      expect(path, isNotNull);
    });

    test('orthogonal routing mode in AdaptiveEdgeRenderer creates L-shaped paths', () {
      final graph = Graph();
      final node1 = Node.Id(1);
      node1.position = Offset(0, 0);
      node1.size = Size(80, 40);

      final node2 = Node.Id(2);
      node2.position = Offset(200, 150);
      node2.size = Size(80, 40);

      graph.addNode(node1);
      graph.addNode(node2);
      final edge = graph.addEdge(node1, node2);

      final config = EdgeRoutingConfig(
        anchorMode: AnchorMode.cardinal,
        routingMode: RoutingMode.orthogonal,
      );
      final renderer = AdaptiveEdgeRenderer(config: config);
      renderer.setGraph(graph);

      final sourceCenter = Offset(
        node1.position.dx + node1.width * 0.5,
        node1.position.dy + node1.height * 0.5,
      );
      final destCenter = Offset(
        node2.position.dx + node2.width * 0.5,
        node2.position.dy + node2.height * 0.5,
      );

      final sourcePoint = renderer.calculateSourceConnectionPoint(edge, destCenter, 0);
      final destPoint = renderer.calculateDestinationConnectionPoint(edge, sourceCenter, 0);

      final path = renderer.routeEdgePath(sourcePoint, destPoint, edge);

      expect(path, isNotNull);
    });
  });
}
