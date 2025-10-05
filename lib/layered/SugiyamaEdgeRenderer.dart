part of graphview;

class SugiyamaEdgeRenderer extends ArrowEdgeRenderer {
  Map<Node, SugiyamaNodeData> nodeData;
  Map<Edge, SugiyamaEdgeData> edgeData;
  BendPointShape bendPointShape;
  bool addTriangleToEdge;
  SugiyamaEdgeRenderer(
    this.nodeData,
    this.edgeData,
    this.bendPointShape,
    this.addTriangleToEdge,
  );

  bool hasBendEdges(Edge edge) =>
      edgeData.containsKey(edge) && edgeData[edge]!.bendPoints.isNotEmpty;

  @override
  void render(Canvas canvas, Graph graph, Paint paint) {
    graph.edges.forEach((edge) {
      renderEdge(canvas, edge, paint);
    });
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    var trianglePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    Paint? edgeTrianglePaint;
    if (edge.paint != null) {
      edgeTrianglePaint = Paint()
        ..color = edge.paint?.color ?? paint.color
        ..style = PaintingStyle.fill;
    }

    var currentPaint = edge.paint ?? paint
      ..style = PaintingStyle.stroke;

    if (hasBendEdges(edge)) {
      _renderEdgeWithBendPoints(
        canvas,
        edge,
        currentPaint,
        edgeTrianglePaint ?? trianglePaint,
      );
    } else {
      _renderStraightEdge(
        canvas,
        edge,
        currentPaint,
        edgeTrianglePaint ?? trianglePaint,
      );
    }
  }

  void _renderEdgeWithBendPoints(
    Canvas canvas,
    Edge edge,
    Paint currentPaint,
    Paint trianglePaint,
  ) {
    final result = _buildBendPath(edge);

    if (addTriangleToEdge &&
        result.triangleStart != null &&
        result.triangleTip != null) {
      drawTriangle(
        canvas,
        trianglePaint,
        result.triangleStart!.dx,
        result.triangleStart!.dy,
        result.triangleTip!.dx,
        result.triangleTip!.dy,
      );
    }

    canvas.drawPath(result.path, currentPaint);
    paintLabelOnPath(canvas, edge, result.path);
  }

  void _renderStraightEdge(
    Canvas canvas,
    Edge edge,
    Paint currentPaint,
    Paint trianglePaint,
  ) {
    final geometry = _computeStraightEdgeGeometry(edge);
    Offset endPoint = geometry.end;

    if (addTriangleToEdge &&
        geometry.triangleStart != null &&
        geometry.triangleTip != null) {
      endPoint = drawTriangle(
        canvas,
        trianglePaint,
        geometry.triangleStart!.dx,
        geometry.triangleStart!.dy,
        geometry.triangleTip!.dx,
        geometry.triangleTip!.dy,
      );
    }

    final lineType = nodeData[edge.destination]?.lineType;
    drawStyledLine(
      canvas,
      geometry.start,
      endPoint,
      currentPaint,
      lineType: lineType,
    );
    paintLabelOnLine(canvas, edge, geometry.start, endPoint);
  }

  _BendPathResult _buildBendPath(Edge edge) {
    final source = edge.source;
    final destination = edge.destination;
    final bendPoints = edgeData[edge]!.bendPoints;

    final sourceCenter = _getNodeCenter(source);
    final transitionDx = sourceCenter.dx - bendPoints[0];
    final transitionDy = sourceCenter.dy - bendPoints[1];

    final path = Path()..moveTo(sourceCenter.dx, sourceCenter.dy);
    final bendPointsWithoutDuplication = <Offset>[];

    for (var i = 0; i < bendPoints.length; i += 2) {
      final isLastPoint = i == bendPoints.length - 2;

      final x = bendPoints[i] + transitionDx;
      final y = bendPoints[i + 1] + transitionDy;
      final x2 = isLastPoint ? -1 : bendPoints[i + 2] + transitionDx;
      final y2 = isLastPoint ? -1 : bendPoints[i + 3] + transitionDy;

      if (x == x2 && y == y2) {
        continue;
      }
      bendPointsWithoutDuplication.add(Offset(x, y));
    }

    if (bendPointShape is MaxCurvedBendPointShape) {
      _drawMaxCurvedBendPointsEdge(path, bendPointsWithoutDuplication);
    } else if (bendPointShape is CurvedBendPointShape) {
      final shape = bendPointShape as CurvedBendPointShape;
      _drawCurvedBendPointsEdge(
        path,
        bendPointsWithoutDuplication,
        shape.curveLength,
      );
    } else {
      _drawSharpBendPointsEdge(path, bendPointsWithoutDuplication);
    }

    final descOffset = getNodePosition(destination);
    final stopX = descOffset.dx + destination.width * 0.5;
    final stopY = descOffset.dy + destination.height * 0.5;

    Offset? triangleStart;
    Offset? triangleTip;

    if (addTriangleToEdge) {
      final size = bendPoints.length;
      late final List<double> clippedLine;
      if (nodeData[source]!.isReversed) {
        clippedLine = clipLineEnd(
          bendPoints[2],
          bendPoints[3],
          stopX,
          stopY,
          destination.x,
          destination.y,
          destination.width,
          destination.height,
        );
      } else {
        clippedLine = clipLineEnd(
          bendPoints[size - 4],
          bendPoints[size - 3],
          stopX,
          stopY,
          descOffset.dx,
          descOffset.dy,
          destination.width,
          destination.height,
        );
      }

      triangleStart = Offset(clippedLine[0], clippedLine[1]);
      triangleTip = Offset(clippedLine[2], clippedLine[3]);
      final centroid = _computeTriangleGeometry(
        triangleStart.dx,
        triangleStart.dy,
        triangleTip.dx,
        triangleTip.dy,
      ).centroid;
      path.lineTo(centroid.dx, centroid.dy);
    } else {
      path.lineTo(stopX, stopY);
    }

    return _BendPathResult(
      path,
      triangleStart: triangleStart,
      triangleTip: triangleTip,
    );
  }

  _LineGeometry _computeStraightEdgeGeometry(Edge edge) {
    final sourceCenter = _getNodeCenter(edge.source);
    final destinationCenter = _getNodeCenter(edge.destination);

    if (!addTriangleToEdge) {
      return _LineGeometry(
        start: sourceCenter,
        end: destinationCenter,
      );
    }

    final clippedLine = clipLineEnd(
      sourceCenter.dx,
      sourceCenter.dy,
      destinationCenter.dx,
      destinationCenter.dy,
      edge.destination.x,
      edge.destination.y,
      edge.destination.width,
      edge.destination.height,
    );

    final triangleStart = Offset(clippedLine[0], clippedLine[1]);
    final triangleTip = Offset(clippedLine[2], clippedLine[3]);
    final centroid = _computeTriangleGeometry(
      triangleStart.dx,
      triangleStart.dy,
      triangleTip.dx,
      triangleTip.dy,
    ).centroid;

    return _LineGeometry(
      start: sourceCenter,
      end: centroid,
      triangleStart: triangleStart,
      triangleTip: triangleTip,
    );
  }

  @override
  Offset? getLabelPosition(Edge edge) {
    if (hasBendEdges(edge)) {
      final result = _buildBendPath(edge);
      return resolveLabelPosition(edge, path: result.path);
    }

    final geometry = _computeStraightEdgeGeometry(edge);
    return resolveLabelPosition(
      edge,
      start: geometry.start,
      end: geometry.end,
    );
  }

  void _drawSharpBendPointsEdge(Path target, List<Offset> bendPoints) {
    for (var i = 1; i < bendPoints.length - 1; i++) {
      target.lineTo(bendPoints[i].dx, bendPoints[i].dy);
    }
  }

  void _drawMaxCurvedBendPointsEdge(Path target, List<Offset> bendPoints) {
    for (var i = 1; i < bendPoints.length - 1; i++) {
      final nextNode = bendPoints[i];
      final afterNextNode = bendPoints[i + 1];
      final curveEndPoint = Offset(
        (nextNode.dx + afterNextNode.dx) / 2,
        (nextNode.dy + afterNextNode.dy) / 2,
      );
      target.quadraticBezierTo(
        nextNode.dx,
        nextNode.dy,
        curveEndPoint.dx,
        curveEndPoint.dy,
      );
    }
  }

  void _drawCurvedBendPointsEdge(
    Path target,
    List<Offset> bendPoints,
    double curveLength,
  ) {
    for (var i = 1; i < bendPoints.length - 1; i++) {
      final previousNode = i == 1 ? null : bendPoints[i - 2];
      final currentNode = bendPoints[i - 1];
      final nextNode = bendPoints[i];
      final afterNextNode = bendPoints[i + 1];

      final arcStartPointRadians = atan2(
        nextNode.dy - currentNode.dy,
        nextNode.dx - currentNode.dx,
      );
      final arcStartPoint =
          nextNode - Offset.fromDirection(arcStartPointRadians, curveLength);
      final arcEndPointRadians = atan2(
        nextNode.dy - afterNextNode.dy,
        nextNode.dx - afterNextNode.dx,
      );
      final arcEndPoint =
          nextNode - Offset.fromDirection(arcEndPointRadians, curveLength);

      if (previousNode != null &&
          ((currentNode.dx == nextNode.dx && nextNode.dx == afterNextNode.dx) ||
              (currentNode.dy == nextNode.dy &&
                  nextNode.dy == afterNextNode.dy))) {
        target.lineTo(nextNode.dx, nextNode.dy);
      } else {
        target.lineTo(arcStartPoint.dx, arcStartPoint.dy);
        target.quadraticBezierTo(
          nextNode.dx,
          nextNode.dy,
          arcEndPoint.dx,
          arcEndPoint.dy,
        );
      }
    }
  }
}

class _BendPathResult {
  final Path path;
  final Offset? triangleStart;
  final Offset? triangleTip;

  _BendPathResult(
    this.path, {
    this.triangleStart,
    this.triangleTip,
  });
}
