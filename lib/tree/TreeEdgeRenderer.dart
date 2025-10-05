part of graphview;

class TreeEdgeRenderer extends EdgeRenderer {
  BuchheimWalkerConfiguration configuration;

  TreeEdgeRenderer(this.configuration);

  void render(Canvas canvas, Graph graph, Paint paint) {
    graph.edges.forEach((edge) {
      renderEdge(canvas, edge, paint);
    });
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final edgePaint = (edge.paint ?? paint)..style = PaintingStyle.stroke;
    var node = edge.source;
    var child = edge.destination;

    final parentPos = getNodePosition(node);
    final childPos = getNodePosition(child);

    final orientation = getEffectiveOrientation(node, child);
    final path = _buildEdgePath(node, child, parentPos, childPos, orientation);

    // Check if the destination node has a specific line type
    final lineType = child.lineType;

    if (lineType != LineType.Default) {
      // For styled lines, we need to draw path segments with the appropriate style
      _drawStyledPath(canvas, path, edgePaint, lineType);
    } else {
      canvas.drawPath(path, edgePaint);
    }

    paintLabelOnPath(canvas, edge, path);
  }

  /// Draws a path with the specified line type by converting it to line segments
  void _drawStyledPath(
    Canvas canvas,
    Path path,
    Paint paint,
    LineType lineType,
  ) {
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
    // This is a simplified extraction that works for the L-shaped and curved paths
    // For more complex paths, you might need a more sophisticated approach
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

  int getEffectiveOrientation(Node node, Node child) {
    return configuration.orientation;
  }

  /// Builds the path for the edge based on orientation
  Path _buildEdgePath(
    Node node,
    Node child,
    Offset parentPos,
    Offset childPos,
    int orientation,
  ) {
    final path = Path();
    final parentCenterX = parentPos.dx + node.width * 0.5;
    final parentCenterY = parentPos.dy + node.height * 0.5;
    final childCenterX = childPos.dx + child.width * 0.5;
    final childCenterY = childPos.dy + child.height * 0.5;

    if (parentCenterY == childCenterY && parentCenterX == childCenterX) {
      return path;
    }

    switch (orientation) {
      case BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM:
        buildTopBottomPath(
          path,
          node,
          child,
          parentPos,
          childPos,
          parentCenterX,
          parentCenterY,
          childCenterX,
          childCenterY,
        );
        break;

      case BuchheimWalkerConfiguration.ORIENTATION_BOTTOM_TOP:
        buildBottomTopPath(
          path,
          node,
          child,
          parentPos,
          childPos,
          parentCenterX,
          parentCenterY,
          childCenterX,
          childCenterY,
        );
        break;

      case BuchheimWalkerConfiguration.ORIENTATION_LEFT_RIGHT:
        buildLeftRightPath(
          path,
          node,
          child,
          parentPos,
          childPos,
          parentCenterX,
          parentCenterY,
          childCenterX,
          childCenterY,
        );
        break;

      case BuchheimWalkerConfiguration.ORIENTATION_RIGHT_LEFT:
        buildRightLeftPath(
          path,
          node,
          child,
          parentPos,
          childPos,
          parentCenterX,
          parentCenterY,
          childCenterX,
          childCenterY,
        );
        break;
    }

    return path;
  }

  /// Builds path for top-bottom orientation
  void buildTopBottomPath(
    Path path,
    Node node,
    Node child,
    Offset parentPos,
    Offset childPos,
    double parentCenterX,
    double parentCenterY,
    double childCenterX,
    double childCenterY,
  ) {
    final parentBottomY = parentPos.dy + node.height * 0.5;
    final childTopY = childPos.dy + child.height * 0.5;
    final midY = (parentBottomY + childTopY) * 0.5;

    if (configuration.useCurvedConnections) {
      // Curved connection
      path
        ..moveTo(childCenterX, childTopY)
        ..cubicTo(
          childCenterX,
          midY,
          parentCenterX,
          midY,
          parentCenterX,
          parentBottomY,
        );
    } else {
      // L-shaped connection
      path
        ..moveTo(parentCenterX, parentBottomY)
        ..lineTo(parentCenterX, midY)
        ..lineTo(childCenterX, midY)
        ..lineTo(childCenterX, childTopY);
    }
  }

  /// Builds path for bottom-top orientation
  void buildBottomTopPath(
    Path path,
    Node node,
    Node child,
    Offset parentPos,
    Offset childPos,
    double parentCenterX,
    double parentCenterY,
    double childCenterX,
    double childCenterY,
  ) {
    final parentTopY = parentPos.dy + node.height * 0.5;
    final childBottomY = childPos.dy + child.height * 0.5;
    final midY = (parentTopY + childBottomY) * 0.5;

    if (configuration.useCurvedConnections) {
      path
        ..moveTo(childCenterX, childBottomY)
        ..cubicTo(
          childCenterX,
          midY,
          parentCenterX,
          midY,
          parentCenterX,
          parentTopY,
        );
    } else {
      path
        ..moveTo(parentCenterX, parentTopY)
        ..lineTo(parentCenterX, midY)
        ..lineTo(childCenterX, midY)
        ..lineTo(childCenterX, childBottomY);
    }
  }

  /// Builds path for left-right orientation
  void buildLeftRightPath(
    Path path,
    Node node,
    Node child,
    Offset parentPos,
    Offset childPos,
    double parentCenterX,
    double parentCenterY,
    double childCenterX,
    double childCenterY,
  ) {
    final parentRightX = parentPos.dx + node.width * 0.5;
    final childLeftX = childPos.dx + child.width * 0.5;
    final midX = (parentRightX + childLeftX) * 0.5;

    if (configuration.useCurvedConnections) {
      path
        ..moveTo(childLeftX, childCenterY)
        ..cubicTo(
          midX,
          childCenterY,
          midX,
          parentCenterY,
          parentRightX,
          parentCenterY,
        );
    } else {
      path
        ..moveTo(parentRightX, parentCenterY)
        ..lineTo(midX, parentCenterY)
        ..lineTo(midX, childCenterY)
        ..lineTo(childLeftX, childCenterY);
    }
  }

  /// Builds path for right-left orientation
  void buildRightLeftPath(
    Path path,
    Node node,
    Node child,
    Offset parentPos,
    Offset childPos,
    double parentCenterX,
    double parentCenterY,
    double childCenterX,
    double childCenterY,
  ) {
    final parentLeftX = parentPos.dx + node.width * 0.5;
    final childRightX = childPos.dx + child.width * 0.5;
    final midX = (parentLeftX + childRightX) * 0.5;

    if (configuration.useCurvedConnections) {
      path
        ..moveTo(childRightX, childCenterY)
        ..cubicTo(
          midX,
          childCenterY,
          midX,
          parentCenterY,
          parentLeftX,
          parentCenterY,
        );
    } else {
      path
        ..moveTo(parentLeftX, parentCenterY)
        ..lineTo(midX, parentCenterY)
        ..lineTo(midX, childCenterY)
        ..lineTo(childRightX, childCenterY);
    }
  }

  @override
  Offset? getLabelPosition(Edge edge) {
    final node = edge.source;
    final child = edge.destination;
    final parentPos = getNodePosition(node);
    final childPos = getNodePosition(child);
    final orientation = getEffectiveOrientation(node, child);
    final path = _buildEdgePath(node, child, parentPos, childPos, orientation);
    return resolveLabelPosition(edge, path: path);
  }
}
