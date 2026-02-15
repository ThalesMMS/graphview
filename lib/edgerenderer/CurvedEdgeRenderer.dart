part of graphview;

class CurvedEdgeRenderer extends EdgeRenderer {
  /// The curvature factor for curved edges.
  /// Higher values create more pronounced curves.
  /// Default is 0.5 (moderate curve).
  final double curvature;

  CurvedEdgeRenderer({this.curvature = 0.5});

  var curvePath = Path();

  void render(Canvas canvas, Graph graph, Paint paint) {
    graph.edges.forEach((edge) {
      renderEdge(canvas, edge, paint);
    });
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    var source = edge.source;
    var destination = edge.destination;

    final currentPaint = (edge.paint ?? paint)..style = PaintingStyle.stroke;
    final lineType = _getLineType(destination);

    if (source == destination) {
      final loopResult = buildSelfLoopPath(edge, arrowLength: 0.0);

      if (loopResult != null) {
        drawStyledPath(canvas, loopResult.path, currentPaint, lineType: lineType);

        // Render label for self-loop edge
        if (edge.label != null && edge.label!.isNotEmpty) {
          final metrics = loopResult.path.computeMetrics().toList();
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

        return;
      }
    }

    var sourceOffset = getNodePosition(source);
    var destinationOffset = getNodePosition(destination);

    var startX = sourceOffset.dx + source.width * 0.5;
    var startY = sourceOffset.dy + source.height * 0.5;
    var stopX = destinationOffset.dx + destination.width * 0.5;
    var stopY = destinationOffset.dy + destination.height * 0.5;

    // Build curved path using quadratic bezier curve
    curvePath.reset();
    buildCurvedPath(startX, startY, stopX, stopY);

    // Draw the curved path with the appropriate style
    if (lineType != null && lineType != LineType.Default) {
      _drawStyledPath(canvas, curvePath, currentPaint, lineType);
    } else {
      canvas.drawPath(curvePath, currentPaint);
    }

    // Render label for curved edge
    if (edge.label != null && edge.label!.isNotEmpty) {
      final metrics = curvePath.computeMetrics().toList();
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

  /// Helper to get line type from node data if available
  LineType? _getLineType(Node node) {
    if (node is SugiyamaNodeData) {
      return node.lineType;
    }
    return null;
  }

  /// Builds a curved path using quadratic bezier curve
  void buildCurvedPath(double startX, double startY, double stopX, double stopY) {
    // Calculate control point for quadratic bezier curve
    // The control point is offset perpendicular to the line direction
    final midX = (startX + stopX) * 0.5;
    final midY = (startY + stopY) * 0.5;

    final dx = stopX - startX;
    final dy = stopY - startY;

    // Perpendicular vector (rotated 90 degrees)
    final perpX = -dy;
    final perpY = dx;

    // Normalize and scale by curvature factor
    final length = sqrt(dx * dx + dy * dy);
    if (length == 0) {
      // If start and end are the same, just draw a straight line
      curvePath
        ..moveTo(startX, startY)
        ..lineTo(stopX, stopY);
      return;
    }

    final normalizedPerpX = perpX / length;
    final normalizedPerpY = perpY / length;

    // Control point offset perpendicular to the line
    final controlX = midX + normalizedPerpX * length * curvature;
    final controlY = midY + normalizedPerpY * length * curvature;

    // Build the quadratic bezier curve
    curvePath
      ..moveTo(startX, startY)
      ..quadraticBezierTo(controlX, controlY, stopX, stopY);
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
}
