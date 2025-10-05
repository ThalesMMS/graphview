part of graphview;

abstract class EdgeRenderer {
  Map<Node, Offset>? _animatedPositions;
  bool _hasEdgeLabelBuilder = false;

  static const TextStyle _defaultLabelStyle = TextStyle(
    color: Colors.black,
    fontSize: 12,
  );

  void setAnimatedPositions(Map<Node, Offset> positions) =>
      _animatedPositions = positions;

  void setHasEdgeLabelBuilder(bool value) =>
      _hasEdgeLabelBuilder = value;

  Offset getNodePosition(Node node) =>
      _animatedPositions?[node] ?? node.position;

  void renderEdge(Canvas canvas, Edge edge, Paint paint);

  void paintLabelOnLine(Canvas canvas, Edge edge, Offset start, Offset end) {
    final position = resolveLabelPosition(
      edge,
      start: start,
      end: end,
    );
    if (position == null) return;

    if (!_hasEdgeLabelBuilder) {
      _paintLabel(canvas, edge, position);
    }
  }

  void paintLabelOnPath(Canvas canvas, Edge edge, Path path) {
    final position = resolveLabelPosition(edge, path: path);
    if (position == null) return;

    if (!_hasEdgeLabelBuilder) {
      _paintLabel(canvas, edge, position);
    }
  }

  Offset? resolveLabelPosition(
    Edge edge, {
    Offset? start,
    Offset? end,
    Path? path,
  }) {
    if (!_hasEdgeLabelBuilder) {
      final label = edge.label;
      if (label == null || label.isEmpty) return null;
    }

    if (path != null) {
      final metrics = path.computeMetrics().toList();
      if (metrics.isEmpty) return null;

      final totalLength = metrics.fold<double>(
        0.0,
        (sum, metric) => sum + metric.length,
      );
      if (totalLength == 0.0) {
        final fallbackTangent = metrics.first.getTangentForOffset(0);
        return fallbackTangent?.position;
      }

      final target = totalLength * edge.labelPosition;
      var traversed = 0.0;
      Offset? position;

      for (final metric in metrics) {
        final nextTraversed = traversed + metric.length;
        if (target <= nextTraversed) {
          final localOffset = (target - traversed).clamp(0.0, metric.length);
          final tangent = metric.getTangentForOffset(localOffset.toDouble());
          if (tangent != null) {
            position = tangent.position;
          }
          break;
        }
        traversed = nextTraversed;
      }

      position ??=
          metrics.last.getTangentForOffset(metrics.last.length)?.position;
      return position;
    }

    if (start != null && end != null) {
      final t = edge.labelPosition;
      return Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
    }

    return null;
  }

  void _paintLabel(Canvas canvas, Edge edge, Offset position) {
    final label = edge.label;
    if (label == null || label.isEmpty) return;

    final effectiveStyle = edge.labelStyle == null
        ? _defaultLabelStyle
        : _defaultLabelStyle.merge(edge.labelStyle);

    final painter = TextPainter(
      text: TextSpan(text: label, style: effectiveStyle),
      textDirection: edge.labelTextDirection ?? TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.layout();

    final drawOffset = position -
        Offset(painter.width * 0.5, painter.height * 0.5) +
        edge.labelOffset;

    painter.paint(canvas, drawOffset);
  }

  Offset getNodeCenter(Node node) {
    final nodePosition = getNodePosition(node);
    return Offset(
      nodePosition.dx + node.width * 0.5,
      nodePosition.dy + node.height * 0.5,
    );
  }

  Offset? getLabelPosition(Edge edge) => null;

  /// Draws a line between two points respecting the node's line type
  void drawStyledLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    LineType? lineType,
  }) {
    switch (lineType) {
      case LineType.DashedLine:
        drawDashedLine(canvas, start, end, paint, 0.6);
        break;
      case LineType.DottedLine:
        drawDashedLine(canvas, start, end, paint, 0.0);
        break;
      case LineType.SineLine:
        drawSineLine(canvas, start, end, paint);
        break;
      default:
        canvas.drawLine(start, end, paint);
        break;
    }
  }

  /// Draws a styled path respecting the node's line type
  void drawStyledPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    LineType? lineType,
  }) {
    if (lineType == null || lineType == LineType.Default) {
      canvas.drawPath(path, paint);
    } else {
      // For non-solid lines, we need to convert the path to segments
      // This is a simplified approach - for complex paths with curves,
      // you might need a more sophisticated solution
      canvas.drawPath(path, paint);
    }
  }

  /// Draws a dashed line between two points
  void drawDashedLine(
    Canvas canvas,
    Offset source,
    Offset destination,
    Paint paint,
    double lineLength,
  ) {
    final dx = destination.dx - source.dx;
    final dy = destination.dy - source.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance == 0) return;

    final numLines = lineLength == 0.0 ? (distance / 5).ceil() : 14;
    final stepX = dx / numLines;
    final stepY = dy / numLines;

    if (lineLength == 0.0) {
      // Draw dots
      final circleRadius = 1.0;
      final circlePaint = Paint()
        ..color = paint.color
        ..strokeWidth = 1.0
        ..style = PaintingStyle.fill;

      for (var i = 0; i < numLines; i++) {
        final x = source.dx + (i * stepX);
        final y = source.dy + (i * stepY);
        canvas.drawCircle(Offset(x, y), circleRadius, circlePaint);
      }
    } else {
      // Draw dashes
      for (var i = 0; i < numLines; i++) {
        final startX = source.dx + (i * stepX);
        final startY = source.dy + (i * stepY);
        final endX = startX + (stepX * lineLength);
        final endY = startY + (stepY * lineLength);
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      }
    }
  }

  /// Draws a sine wave line between two points
  void drawSineLine(
    Canvas canvas,
    Offset source,
    Offset destination,
    Paint paint,
  ) {
    final originalStrokeWidth = paint.strokeWidth;
    paint.strokeWidth = 1.5;

    final dx = destination.dx - source.dx;
    final dy = destination.dy - source.dy;
    final distance = sqrt(dx * dx + dy * dy);

    if (distance == 0 || (dx == 0 && dy == 0)) {
      paint.strokeWidth = originalStrokeWidth;
      return;
    }

    const lineLength = 6.0;
    const phaseOffset = 2.0;
    var distanceTraveled = 0.0;
    var phase = 0.0;

    final path = Path()..moveTo(source.dx, source.dy);

    while (distanceTraveled < distance) {
      final segmentLength = min(lineLength, distance - distanceTraveled);
      final segmentFraction = (distanceTraveled + segmentLength) / distance;
      final segmentDestination = Offset(
        source.dx + dx * segmentFraction,
        source.dy + dy * segmentFraction,
      );

      final waveAmplitude = sin(phase + phaseOffset) * segmentLength;

      double perpX, perpY;
      if ((dx > 0 && dy < 0) || (dx < 0 && dy > 0)) {
        perpX = waveAmplitude;
        perpY = waveAmplitude;
      } else {
        perpX = -waveAmplitude;
        perpY = waveAmplitude;
      }

      path.lineTo(segmentDestination.dx + perpX, segmentDestination.dy + perpY);

      distanceTraveled += segmentLength;
      phase += pi * segmentLength / lineLength;
    }

    canvas.drawPath(path, paint);
    paint.strokeWidth = originalStrokeWidth;
  }
}
