import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphview/GraphView.dart';

void main() {
  group('AdaptiveEdgeRenderer geometry', () {
    late Graph graph;
    late Node source;
    late Node destination;
    late AdaptiveEdgeRenderer renderer;

    setUp(() {
      graph = Graph();
      source = Node.Id('source')
        ..position = const Offset(0, 0)
        ..size = const Size(100, 60);
      destination = Node.Id('destination')
        ..position = const Offset(220, 0)
        ..size = const Size(100, 60);

      graph
        ..addNode(source)
        ..addNode(destination);

      renderer = AdaptiveEdgeRenderer(
        config: EdgeRoutingConfig(
          anchorMode: AnchorMode.dynamic,
          routingMode: RoutingMode.bezier,
          enableRepulsion: true,
          minEdgeDistance: 14.0,
        ),
      )..setGraph(graph);
    });

    test(
      'explicit control points override auto routing while clipping to node boundaries',
      () {
        final edge = graph.addEdge(
          source,
          destination,
          controlPoint: const Offset(160, -80),
          label: 'manual',
        );

        final geometry = renderer.buildEdgeGeometry(edge);

        expect(geometry, isNotNull);
        expect(geometry!.start.dx, closeTo(80, 0.1));
        expect(geometry.start.dy, closeTo(0, 0.1));
        expect(geometry.end.dx, closeTo(240, 0.1));
        expect(geometry.end.dy, closeTo(0, 0.1));

        final midpoint =
            geometry.path.computeMetrics().first.getTangentForOffset(
                  geometry.path.computeMetrics().first.length * 0.5,
                );
        expect(midpoint, isNotNull);
        expect(midpoint!.position.dy, lessThan(0));
      },
    );

    test(
        'label geometry is derived from the final auto, manual, and self-loop paths',
        () {
      final autoEdge = graph.addEdge(source, destination, label: 'auto');
      final autoGeometry = renderer.buildEdgeGeometry(autoEdge)!;
      final autoLabel =
          renderer.buildLabelGeometry(autoEdge, autoGeometry.path);

      expect(autoLabel, isNotNull);
      expect(autoLabel!.angle, isNotNull);
      expect(autoLabel.position.dx, greaterThan(autoGeometry.start.dx));
      expect(autoLabel.position.dx, lessThan(autoGeometry.end.dx));

      final manualEdge = graph.addEdge(
        source,
        destination,
        label: 'manual',
        labelFollowsEdgeDirection: false,
        controlPoint: const Offset(160, -80),
      );
      final manualGeometry = renderer.buildEdgeGeometry(manualEdge)!;
      final manualLabel = renderer.buildLabelGeometry(
        manualEdge,
        manualGeometry.path,
      );

      expect(manualLabel, isNotNull);
      expect(manualLabel!.angle, isNull);
      expect(manualLabel.position.dy, lessThan(0));

      final selfLoop = graph.addEdge(source, source, label: 'loop');
      final selfLoopGeometry = renderer.buildEdgeGeometry(selfLoop)!;
      final selfLoopLabel = renderer.buildLabelGeometry(
        selfLoop,
        selfLoopGeometry.path,
      );

      expect(selfLoopGeometry.isSelfLoop, isTrue);
      expect(selfLoopLabel, isNotNull);
      expect(selfLoopLabel!.position.dy, lessThan(30));
    });

    test(
      'parallel non-manual edges remain separated while manual edges keep explicit anchors',
      () {
        final parallelRenderer = AdaptiveEdgeRenderer(
          config: EdgeRoutingConfig(
            anchorMode: AnchorMode.cardinal,
            routingMode: RoutingMode.direct,
            enableRepulsion: true,
            minEdgeDistance: 20.0,
          ),
        )..setGraph(graph);

        final autoEdgeA = graph.addEdge(source, destination, label: 'auto-a');
        final autoEdgeB = graph.addEdge(source, destination, label: 'auto-b');
        final manualEdge = graph.addEdge(
          source,
          destination,
          controlPoint: const Offset(160, -80),
          label: 'manual',
        );

        final sourceCenter = parallelRenderer.getNodeCenter(source);
        final destCenter = parallelRenderer.getNodeCenter(destination);
        final autoSourceA = parallelRenderer.calculateSourceConnectionPoint(
          autoEdgeA,
          destCenter,
          0,
        );
        final autoSourceB = parallelRenderer.calculateSourceConnectionPoint(
          autoEdgeB,
          destCenter,
          1,
        );
        final autoDestA = parallelRenderer.calculateDestinationConnectionPoint(
          autoEdgeA,
          sourceCenter,
          0,
        );
        final autoDestB = parallelRenderer.calculateDestinationConnectionPoint(
          autoEdgeB,
          sourceCenter,
          1,
        );
        final manualGeometry = parallelRenderer.buildEdgeGeometry(manualEdge)!;

        expect((autoSourceA - autoSourceB).distance, greaterThan(5));
        expect((autoDestA - autoDestB).distance, greaterThan(5));
        expect(manualGeometry.start.dx, closeTo(80, 0.1));
        expect(manualGeometry.start.dy, closeTo(0, 0.1));
        expect(manualGeometry.end.dx, closeTo(240, 0.1));
        expect(manualGeometry.end.dy, closeTo(0, 0.1));
      },
    );

    test(
        'default geometry is unchanged when no explicit control point is provided',
        () {
      final edge = graph.addEdge(source, destination, label: 'default');
      final geometry = renderer.buildEdgeGeometry(edge)!;

      final destCenter = renderer.getNodeCenter(destination);
      final sourceCenter = renderer.getNodeCenter(source);
      final sourcePoint = renderer.calculateSourceConnectionPoint(
        edge,
        destCenter,
        0,
      );
      final destPoint = renderer.calculateDestinationConnectionPoint(
        edge,
        sourceCenter,
        0,
      );
      final expectedPath = renderer.routeEdgePath(sourcePoint, destPoint, edge);
      final expectedGeometry = renderer.buildPathGeometry(expectedPath);

      expect(geometry.start.dx, closeTo(expectedGeometry.start.dx, 0.1));
      expect(geometry.start.dy, closeTo(expectedGeometry.start.dy, 0.1));
      expect(geometry.end.dx, closeTo(expectedGeometry.end.dx, 0.1));
      expect(geometry.end.dy, closeTo(expectedGeometry.end.dy, 0.1));
      expect(
          geometry.arrowBase.dx, closeTo(expectedGeometry.arrowBase.dx, 0.1));
      expect(
          geometry.arrowBase.dy, closeTo(expectedGeometry.arrowBase.dy, 0.1));
    });
  });

  group('AnimatedAdaptiveEdgeRenderer', () {
    late Graph graph;
    late Node source;
    late Node destination;
    late AnimatedAdaptiveEdgeRenderer renderer;

    setUp(() {
      graph = Graph();
      source = Node.Id('source')
        ..position = const Offset(0, 0)
        ..size = const Size(100, 60);
      destination = Node.Id('destination')
        ..position = const Offset(220, 0)
        ..size = const Size(100, 60);

      graph
        ..addNode(source)
        ..addNode(destination);

      renderer = AnimatedAdaptiveEdgeRenderer(
        config: EdgeRoutingConfig(
          anchorMode: AnchorMode.dynamic,
          routingMode: RoutingMode.bezier,
          enableRepulsion: true,
        ),
        animationConfig: const AnimatedEdgeConfiguration(
          particleCount: 3,
          particleSize: 2,
        ),
        animationValue: 0.25,
      )..setGraph(graph);
    });

    test('particle positions follow curved manual and self-loop paths', () {
      final manualEdge = graph.addEdge(
        source,
        destination,
        controlPoint: const Offset(160, -80),
        label: 'manual',
      );
      final manualGeometry = renderer.buildEdgeGeometry(manualEdge)!;
      final manualParticles = renderer.computeParticlePositions(
        manualGeometry.path,
      );

      expect(manualParticles, hasLength(3));
      expect(manualParticles.any((position) => position.dy < 0), isTrue);

      final selfLoop = graph.addEdge(source, source, label: 'loop');
      final selfLoopGeometry = renderer.buildEdgeGeometry(selfLoop)!;
      final selfLoopParticles = renderer.computeParticlePositions(
        selfLoopGeometry.path,
      );

      expect(selfLoopParticles, hasLength(3));
      expect(selfLoopParticles.any((position) => position.dy < 0), isTrue);

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..color = Colors.blue;

      expect(
        () => renderer.renderAnimatedParticlesOnPath(
          canvas,
          manualEdge,
          paint,
          manualGeometry.path,
        ),
        returnsNormally,
      );
    });
  });
}
