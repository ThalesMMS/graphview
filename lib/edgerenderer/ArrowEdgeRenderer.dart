part of graphview;

const double ARROW_DEGREES = 0.5;
const double ARROW_LENGTH = 10;

class ArrowEdgeRenderer extends EdgeRenderer {
  var trianglePath = Path();
  final bool noArrow;

  ArrowEdgeRenderer({this.noArrow = false});

  Offset _getNodeCenter(Node node) {
    final nodePosition = getNodePosition(node);
    return Offset(
      nodePosition.dx + node.width * 0.5,
      nodePosition.dy + node.height * 0.5,
    );
  }

  void render(Canvas canvas, Graph graph, Paint paint) {
    graph.edges.forEach((edge) {
      renderEdge(canvas, edge, paint);
    });
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    final geometry = _buildLineGeometry(edge);
    final currentPaint = edge.paint ?? paint;
    final lineType = _getLineType(edge.destination);

    Offset endPoint = geometry.end;

    if (!noArrow && geometry.triangleStart != null && geometry.triangleTip != null) {
      var trianglePaint = Paint()
        ..color = paint.color
        ..style = PaintingStyle.fill;

      Paint? edgeTrianglePaint;
      if (edge.paint != null) {
        edgeTrianglePaint = Paint()
          ..color = edge.paint?.color ?? paint.color
          ..style = PaintingStyle.fill;
      }

      endPoint = drawTriangle(
        canvas,
        edgeTrianglePaint ?? trianglePaint,
        geometry.triangleStart!.dx,
        geometry.triangleStart!.dy,
        geometry.triangleTip!.dx,
        geometry.triangleTip!.dy,
      );
    }

    drawStyledLine(
      canvas,
      geometry.start,
      endPoint,
      currentPaint,
      lineType: lineType,
    );

    paintLabelOnLine(canvas, edge, geometry.start, endPoint);
  }

  /// Helper to get line type from node data if available
  LineType? _getLineType(Node node) {
    // This assumes you have a way to access node data
    // You may need to adjust this based on your actual implementation
    if (node is SugiyamaNodeData) {
      return node.lineType;
    }
    return null;
  }

  Offset drawTriangle(
    Canvas canvas,
    Paint paint,
    double lineStartX,
    double lineStartY,
    double arrowTipX,
    double arrowTipY,
  ) {
    final geometry = _computeTriangleGeometry(
      lineStartX,
      lineStartY,
      arrowTipX,
      arrowTipY,
    );

    trianglePath.moveTo(arrowTipX, arrowTipY); // Arrow tip
    trianglePath.lineTo(geometry.leftWing.dx, geometry.leftWing.dy); // Left wing
    trianglePath.lineTo(geometry.rightWing.dx, geometry.rightWing.dy); // Right wing
    trianglePath.close(); // Back to tip
    canvas.drawPath(trianglePath, paint);

    trianglePath.reset();
    return geometry.centroid;
  }

  _TriangleGeometry _computeTriangleGeometry(
    double lineStartX,
    double lineStartY,
    double arrowTipX,
    double arrowTipY,
  ) {
    final lineDirection =
        (atan2(arrowTipY - lineStartY, arrowTipX - lineStartX) + pi);

    final leftWing = Offset(
      arrowTipX + ARROW_LENGTH * cos((lineDirection - ARROW_DEGREES)),
      arrowTipY + ARROW_LENGTH * sin((lineDirection - ARROW_DEGREES)),
    );
    final rightWing = Offset(
      arrowTipX + ARROW_LENGTH * cos((lineDirection + ARROW_DEGREES)),
      arrowTipY + ARROW_LENGTH * sin((lineDirection + ARROW_DEGREES)),
    );

    final centroid = Offset(
      (arrowTipX + leftWing.dx + rightWing.dx) / 3,
      (arrowTipY + leftWing.dy + rightWing.dy) / 3,
    );

    return _TriangleGeometry(
      leftWing: leftWing,
      rightWing: rightWing,
      centroid: centroid,
    );
  }

  _LineGeometry _buildLineGeometry(Edge edge) {
    final source = edge.source;
    final destination = edge.destination;

    final sourceOffset = getNodePosition(source);
    final destinationOffset = getNodePosition(destination);

    final startX = sourceOffset.dx + source.width * 0.5;
    final startY = sourceOffset.dy + source.height * 0.5;
    final stopX = destinationOffset.dx + destination.width * 0.5;
    final stopY = destinationOffset.dy + destination.height * 0.5;

    final clippedLine = clipLineEnd(
      startX,
      startY,
      stopX,
      stopY,
      destinationOffset.dx,
      destinationOffset.dy,
      destination.width,
      destination.height,
    );

    final startPoint = Offset(clippedLine[0], clippedLine[1]);

    if (noArrow) {
      return _LineGeometry(
        start: startPoint,
        end: Offset(clippedLine[2], clippedLine[3]),
      );
    }

    final triangleStart = Offset(clippedLine[0], clippedLine[1]);
    final triangleTip = Offset(clippedLine[2], clippedLine[3]);
    final centroid = _computeTriangleGeometry(
      triangleStart.dx,
      triangleStart.dy,
      triangleTip.dx,
      triangleTip.dy,
    ).centroid;

    return _LineGeometry(
      start: startPoint,
      end: centroid,
      triangleStart: triangleStart,
      triangleTip: triangleTip,
    );
  }

  @override
  Offset? getLabelPosition(Edge edge) {
    final geometry = _buildLineGeometry(edge);
    return resolveLabelPosition(
      edge,
      start: geometry.start,
      end: geometry.end,
    );
  }

  List<double> clipLineEnd(
    double startX,
    double startY,
    double stopX,
    double stopY,
    double destX,
    double destY,
    double destWidth,
    double destHeight,
  ) {
    var clippedStopX = stopX;
    var clippedStopY = stopY;

    if (startX == stopX && startY == stopY) {
      return [startX, startY, clippedStopX, clippedStopY];
    }

    var slope = (startY - stopY) / (startX - stopX);
    final halfHeight = destHeight * 0.5;
    final halfWidth = destWidth * 0.5;

    // Check vertical edge intersections
    if (startX != stopX) {
      final halfSlopeWidth = slope * halfWidth;
      if (halfSlopeWidth.abs() <= halfHeight) {
        if (destX > startX) {
          // Left edge intersection
          return [startX, startY, stopX - halfWidth, stopY - halfSlopeWidth];
        } else if (destX < startX) {
          // Right edge intersection
          return [startX, startY, stopX + halfWidth, stopY + halfSlopeWidth];
        }
      }
    }

    // Check horizontal edge intersections
    if (startY != stopY && slope != 0) {
      final halfSlopeHeight = halfHeight / slope;
      if (halfSlopeHeight.abs() <= halfWidth) {
        if (destY < startY) {
          // Bottom edge intersection
          clippedStopX = stopX + halfSlopeHeight;
          clippedStopY = stopY + halfHeight;
        } else if (destY > startY) {
          // Top edge intersection
          clippedStopX = stopX - halfSlopeHeight;
          clippedStopY = stopY - halfHeight;
        }
      }
    }

    return [startX, startY, clippedStopX, clippedStopY];
  }

  List<double> clipLine(
    double startX,
    double startY,
    double stopX,
    double stopY,
    Node destination,
  ) {
    final resultLine = [startX, startY, stopX, stopY];

    if (startX == stopX && startY == stopY) return resultLine;

    var slope = (startY - stopY) / (startX - stopX);
    final halfHeight = destination.height * 0.5;
    final halfWidth = destination.width * 0.5;

    // Check vertical edge intersections
    if (startX != stopX) {
      final halfSlopeWidth = slope * halfWidth;
      if (halfSlopeWidth.abs() <= halfHeight) {
        if (destination.x > startX) {
          // Left edge intersection
          resultLine[2] = stopX - halfWidth;
          resultLine[3] = stopY - halfSlopeWidth;
          return resultLine;
        } else if (destination.x < startX) {
          // Right edge intersection
          resultLine[2] = stopX + halfWidth;
          resultLine[3] = stopY + halfSlopeWidth;
          return resultLine;
        }
      }
    }

    // Check horizontal edge intersections
    if (startY != stopY && slope != 0) {
      final halfSlopeHeight = halfHeight / slope;
      if (halfSlopeHeight.abs() <= halfWidth) {
        if (destination.y < startY) {
          // Bottom edge intersection
          resultLine[2] = stopX + halfSlopeHeight;
          resultLine[3] = stopY + halfHeight;
        } else if (destination.y > startY) {
          // Top edge intersection
          resultLine[2] = stopX - halfSlopeHeight;
          resultLine[3] = stopY - halfHeight;
        }
      }
    }

    return resultLine;
  }
}

class _TriangleGeometry {
  final Offset leftWing;
  final Offset rightWing;
  final Offset centroid;

  const _TriangleGeometry({
    required this.leftWing,
    required this.rightWing,
    required this.centroid,
  });
}

class _LineGeometry {
  final Offset start;
  final Offset end;
  final Offset? triangleStart;
  final Offset? triangleTip;

  const _LineGeometry({
    required this.start,
    required this.end,
    this.triangleStart,
    this.triangleTip,
  });
}
