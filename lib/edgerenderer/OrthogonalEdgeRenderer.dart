part of graphview;

/// Edge renderer that generates orthogonal (L-shaped Manhattan) paths.
///
/// This renderer creates paths with right angles, routing edges horizontally
/// and vertically. The routing algorithm chooses between horizontal-first and
/// vertical-first based on the relative positions of the nodes.
class OrthogonalEdgeRenderer extends EdgeRenderer {
  EdgeRoutingConfig configuration;

  OrthogonalEdgeRenderer(this.configuration);

  var linePath = Path();

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
        drawStyledPath(canvas, loopPath.path, edgePaint, lineType: destination.lineType);

        // Render label for self-loop edge
        if (edge.label != null && edge.label!.isNotEmpty) {
          final metrics = loopPath.path.computeMetrics().toList();
          if (metrics.isNotEmpty) {
            final metric = metrics.first;

            // Calculate position based on labelPosition
            final labelPos = edge.labelPosition ?? EdgeLabelPosition.middle;
            double positionFactor;
            if (labelPos == EdgeLabelPosition.start) {
              positionFactor = 0.2;
            } else if (labelPos == EdgeLabelPosition.end) {
              positionFactor = 0.8;
            } else {
              positionFactor = 0.5; // middle (default)
            }

            final position = metric.length * positionFactor;
            final tangent = metric.getTangentForOffset(position);
            if (tangent != null) {
              final rotationAngle = (edge.labelFollowsEdgeDirection ?? true)
                ? tangent.angle
                : null; // null means no rotation (horizontal)
              renderEdgeLabel(
                canvas,
                edge,
                tangent.position,
                rotationAngle,
              );
            }
          }
        }
      }
      return;
    }

    final sourcePos = getNodePosition(source);
    final destinationPos = getNodePosition(destination);

    linePath.reset();
    buildOrthogonalPath(source, destination, sourcePos, destinationPos);

    // Check if the destination node has a specific line type
    final lineType = destination.lineType;

    if (lineType != LineType.Default) {
      // For styled lines, we need to draw path segments with the appropriate style
      _drawStyledPath(canvas, linePath, edgePaint, lineType);
    } else {
      canvas.drawPath(linePath, edgePaint);
    }

    // Render label for regular edge
    if (edge.label != null && edge.label!.isNotEmpty) {
      final metrics = linePath.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final metric = metrics.first;

        // Calculate position based on labelPosition
        final labelPos = edge.labelPosition ?? EdgeLabelPosition.middle;
        double positionFactor;
        if (labelPos == EdgeLabelPosition.start) {
          positionFactor = 0.2;
        } else if (labelPos == EdgeLabelPosition.end) {
          positionFactor = 0.8;
        } else {
          positionFactor = 0.5; // middle (default)
        }

        final position = metric.length * positionFactor;
        final tangent = metric.getTangentForOffset(position);
        if (tangent != null) {
          final rotationAngle = (edge.labelFollowsEdgeDirection ?? true)
            ? tangent.angle
            : null; // null means no rotation (horizontal)
          renderEdgeLabel(
            canvas,
            edge,
            tangent.position,
            rotationAngle,
          );
        }
      }
    }
  }

  /// Draws a path with the specified line type by converting it to line segments
  void _drawStyledPath(Canvas canvas, Path path, Paint paint, LineType lineType) {
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
      var distance = 0.0;

      while (distance <= length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          points.add(tangent.position);
        }
        distance += sampleDistance;
      }

      // Add the final point
      final finalTangent = metric.getTangentForOffset(length);
      if (finalTangent != null) {
        points.add(finalTangent.position);
      }
    }

    return points;
  }

  /// Builds an orthogonal (L-shaped Manhattan) path between two nodes
  void buildOrthogonalPath(Node source, Node destination, Offset sourcePos, Offset destinationPos) {
    final sourceCenterX = sourcePos.dx + source.width * 0.5;
    final sourceCenterY = sourcePos.dy + source.height * 0.5;
    final destinationCenterX = destinationPos.dx + destination.width * 0.5;
    final destinationCenterY = destinationPos.dy + destination.height * 0.5;

    // Handle case where nodes are at same position
    if ((sourceCenterX - destinationCenterX).abs() < 0.001 &&
        (sourceCenterY - destinationCenterY).abs() < 0.001) {
      linePath
        ..moveTo(sourceCenterX, sourceCenterY)
        ..lineTo(destinationCenterX, destinationCenterY);
      return;
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

      // Handle collinear nodes (same Y coordinate) by adding a minimal vertical offset
      if ((endY - startY).abs() < 0.001) {
        // Nodes are horizontally aligned, add a small vertical offset for visibility
        final offset = 10.0;
        linePath
          ..moveTo(startX, startY)
          ..lineTo(midX, startY)
          ..lineTo(midX, startY + offset)
          ..lineTo(midX, endY)
          ..lineTo(endX, endY);
      } else {
        // Normal L-shaped path
        linePath
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
        // Nodes are vertically aligned, add a small horizontal offset for visibility
        final offset = 10.0;
        linePath
          ..moveTo(startX, startY)
          ..lineTo(startX, midY)
          ..lineTo(startX + offset, midY)
          ..lineTo(endX, midY)
          ..lineTo(endX, endY);
      } else {
        // Normal L-shaped path
        linePath
          ..moveTo(startX, startY)
          ..lineTo(startX, midY)
          ..lineTo(endX, midY)
          ..lineTo(endX, endY);
      }
    }
  }
}
