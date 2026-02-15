part of graphview;

/// Edge renderer that generates orthogonal (L-shaped Manhattan) paths.
///
/// This renderer creates paths with right angles, routing edges horizontally
/// and vertically. The routing algorithm chooses between horizontal-first and
/// vertical-first based on the relative positions of the nodes.
class OrthogonalEdgeRenderer extends EdgeRenderer {
  EdgeRoutingConfig configuration;

  OrthogonalEdgeRenderer(this.configuration);

  void render(Canvas canvas, Graph graph, Paint paint) {
    graph.edges.forEach((edge) {
      renderEdge(canvas, edge, paint);
    });
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final edgePaint = (edge.paint ?? paint)..style = PaintingStyle.stroke;
    var source = edge.source;
    var destination = edge.destination;

    // Handle self-loops
    if (source == destination) {
      final loopPath = buildSelfLoopPath(edge, arrowLength: 0.0);
      if (loopPath != null) {
        drawStyledPath(canvas, loopPath.path, edgePaint,
            lineType: destination.lineType);
        _renderPathLabel(canvas, edge, loopPath.path);
      }
      return;
    }

    final sourcePos = getNodePosition(source);
    final destinationPos = getNodePosition(destination);

    final linePath =
        buildOrthogonalPath(source, destination, sourcePos, destinationPos);

    // Check if the destination node has a specific line type
    final lineType = destination.lineType;

    if (lineType != LineType.Default) {
      // For styled lines, we need to draw path segments with the appropriate style
      _drawStyledPath(canvas, linePath, edgePaint, lineType);
    } else {
      canvas.drawPath(linePath, edgePaint);
    }

    _renderPathLabel(canvas, edge, linePath);
  }

  void _renderPathLabel(Canvas canvas, Edge edge, Path path) {
    if (edge.label == null || edge.label!.isEmpty) {
      return;
    }

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) {
      return;
    }

    final metric = metrics.first;
    final labelPos = edge.labelPosition ?? EdgeLabelPosition.middle;
    final positionFactor = labelPos == EdgeLabelPosition.start
        ? 0.2
        : labelPos == EdgeLabelPosition.end
            ? 0.8
            : 0.5;
    final position = metric.length * positionFactor;
    final tangent = metric.getTangentForOffset(position);
    if (tangent == null) {
      return;
    }

    final rotationAngle =
        (edge.labelFollowsEdgeDirection ?? true) ? tangent.angle : null;
    renderEdgeLabel(canvas, edge, tangent.position, rotationAngle);
  }

  /// Draws a path with the specified line type by converting it to line segments
  void _drawStyledPath(
      Canvas canvas, Path path, Paint paint, LineType lineType) {
    // Extract path points for styled rendering
    final points = _extractPathPoints(path);

    // Draw each segment with the appropriate style
    for (var i = 0; i < points.length - 1; i++) {
      drawStyledLine(
        canvas,
        points[i],
        points[i + 1],
        paint,
        lineType: lineType,
      );
    }
  }

  /// Extracts key points from a path for segment drawing
  List<Offset> _extractPathPoints(Path path) {
    final points = <Offset>[];
    final metrics = path.computeMetrics();

    for (var metric in metrics) {
      final length = metric.length;
      const sampleDistance = 10.0; // Sample every 10 pixels
      const epsilon = 0.001;
      var distance = 0.0;

      while (distance <= length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          points.add(tangent.position);
        }
        distance += sampleDistance;
      }

      // Add the final point only if it was not already sampled.
      final sampledDistance = distance - sampleDistance;
      if (sampledDistance < length - epsilon) {
        final finalTangent = metric.getTangentForOffset(length);
        if (finalTangent != null &&
            (points.isEmpty ||
                (points.last - finalTangent.position).distance > epsilon)) {
          points.add(finalTangent.position);
        }
      }
    }

    return points;
  }

  /// Builds an orthogonal (L-shaped Manhattan) path between two nodes.
  Path buildOrthogonalPath(
    Node source,
    Node destination,
    Offset sourcePos,
    Offset destinationPos,
  ) {
    final path = Path();
    final sourceCenterX = sourcePos.dx + source.width * 0.5;
    final sourceCenterY = sourcePos.dy + source.height * 0.5;
    final destinationCenterX = destinationPos.dx + destination.width * 0.5;
    final destinationCenterY = destinationPos.dy + destination.height * 0.5;

    // Handle case where nodes are at same position
    if ((sourceCenterX - destinationCenterX).abs() < 0.001 &&
        (sourceCenterY - destinationCenterY).abs() < 0.001) {
      path
        ..moveTo(sourceCenterX, sourceCenterY)
        ..lineTo(destinationCenterX, destinationCenterY);
      return path;
    }

    // Calculate start and end points for the path
    final startX = sourceCenterX;
    final startY = sourceCenterY;
    final endX = destinationCenterX;
    final endY = destinationCenterY;

    // Determine routing direction based on relative positions
    // Use horizontal-first if horizontal distance is greater, vertical-first otherwise
    final horizontalDistance = (endX - startX).abs();
    final verticalDistance = (endY - startY).abs();

    if (horizontalDistance >= verticalDistance) {
      // Horizontal-first routing: go horizontal to midpoint, then vertical, then horizontal
      final midX = (startX + endX) * 0.5;

      // Handle collinear nodes (same Y coordinate) with a straight segment
      if ((endY - startY).abs() < 0.001) {
        // Nodes are horizontally aligned; avoid detours that can introduce spikes.
        path
          ..moveTo(startX, startY)
          ..lineTo(endX, endY);
      } else {
        // Normal L-shaped path
        path
          ..moveTo(startX, startY)
          ..lineTo(midX, startY)
          ..lineTo(midX, endY)
          ..lineTo(endX, endY);
      }
    } else {
      // Vertical-first routing: go vertical to midpoint, then horizontal, then vertical
      final midY = (startY + endY) * 0.5;

      // Handle collinear nodes (same X coordinate) by adding a minimal horizontal offset
      if ((endX - startX).abs() < 0.001) {
        // Nodes are vertically aligned, keep the offset consistent through the bend.
        final offset = 10.0;
        final offsetSign = endY >= startY ? 1.0 : -1.0;
        final offsetX = startX + (offset * offsetSign);
        path
          ..moveTo(startX, startY)
          ..lineTo(startX, midY)
          ..lineTo(offsetX, midY)
          ..lineTo(offsetX, endY)
          ..lineTo(endX, endY);
      } else {
        // Normal L-shaped path
        path
          ..moveTo(startX, startY)
          ..lineTo(startX, midY)
          ..lineTo(endX, midY)
          ..lineTo(endX, endY);
      }
    }

    return path;
  }
}
