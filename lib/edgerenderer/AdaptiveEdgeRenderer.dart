part of graphview;

/// An edge renderer that implements adaptive connection points and intelligent routing.
///
/// This renderer calculates optimal connection points on node boundaries based on
/// edge direction and the configured [AnchorMode]. It supports cardinal, octagonal,
/// and dynamic anchor modes for precise edge positioning.
///
/// Example usage:
/// ```dart
/// final config = EdgeRoutingConfig(
///   anchorMode: AnchorMode.cardinal,
///   routingMode: RoutingMode.direct,
/// );
/// final renderer = AdaptiveEdgeRenderer(config: config);
/// final builder = GraphView(
///   graph: graph,
///   algorithm: BuchheimWalkerAlgorithm(builder, config),
///   renderer: renderer,
/// );
/// ```
class AdaptiveEdgeRenderer extends EdgeRenderer {
  final EdgeRoutingConfig config;
  final bool noArrow;

  /// Solver for calculating edge-to-edge repulsion forces.
  final EdgeRepulsionSolver _repulsionSolver = EdgeRepulsionSolver();

  /// Cache for repulsion offsets calculated for each edge.
  /// This cache is invalidated on each render cycle to ensure fresh calculations.
  Map<Edge, Offset> _repulsionOffsets = {};

  /// Flag to track if repulsion has been calculated for the current render cycle.
  bool _repulsionCalculated = false;

  AdaptiveEdgeRenderer({
    required this.config,
    this.noArrow = false,
  });

  @override
  void setGraph(Graph graph) {
    super.setGraph(graph);
    // Reset repulsion calculation flag when graph is set (start of new render cycle)
    _repulsionCalculated = false;
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    // Check if edge has a custom renderer - if so, delegate to it
    if (edge.renderer != null) {
      edge.renderer!.renderEdge(canvas, edge, paint);
      return;
    }

    // Calculate repulsion offsets for all edges once per render cycle
    if (!_repulsionCalculated && config.enableRepulsion && _graph != null) {
      _calculateRepulsionForAllEdges();
      _repulsionCalculated = true;
    }

    var source = edge.source;
    var destination = edge.destination;

    final currentPaint = (edge.paint ?? paint)..style = PaintingStyle.stroke;

    // Handle self-loops
    if (source == destination) {
      final loopResult = buildSelfLoopPath(
        edge,
        arrowLength: noArrow ? 0.0 : 10.0,
      );

      if (loopResult != null) {
        canvas.drawPath(loopResult.path, currentPaint);

        if (!noArrow) {
          final trianglePaint = Paint()
            ..color = edge.paint?.color ?? paint.color
            ..style = PaintingStyle.fill;
          drawTriangle(
            canvas,
            trianglePaint,
            loopResult.arrowBase.dx,
            loopResult.arrowBase.dy,
            loopResult.arrowTip.dx,
            loopResult.arrowTip.dy,
          );
        }

        return;
      }
    }

    // Calculate connection points based on anchor mode
    final destCenter = getNodeCenter(destination);
    final sourceCenter = getNodeCenter(source);

    // Calculate edge index for parallel edge distribution
    final edgeIndex = _calculateEdgeIndex(edge);

    final sourcePoint = calculateSourceConnectionPoint(edge, destCenter, edgeIndex);
    final destPoint = calculateDestinationConnectionPoint(edge, sourceCenter, edgeIndex);

    // Route the edge path based on routing mode
    var path = routeEdgePath(sourcePoint, destPoint, edge);

    // Apply edge repulsion if enabled
    if (config.enableRepulsion && _graph != null) {
      path = _applyRepulsionToPath(edge, path, sourcePoint, destPoint);
    }

    // Draw the path
    canvas.drawPath(path, currentPaint);

    // Draw arrow if not disabled
    if (!noArrow) {
      final trianglePaint = Paint()
        ..color = edge.paint?.color ?? paint.color
        ..style = PaintingStyle.fill;

      final arrowPoints = _resolveArrowPoints(path, sourcePoint, destPoint);
      drawTriangle(
        canvas,
        trianglePaint,
        arrowPoints[0].dx,
        arrowPoints[0].dy,
        arrowPoints[1].dx,
        arrowPoints[1].dy,
      );
    }
  }

  @override
  Offset calculateSourceConnectionPoint(Edge edge, Offset destinationCenter, int edgeIndex) {
    final sourceCenter = getNodeCenter(edge.source);

    Offset baseAnchor;
    switch (config.anchorMode) {
      case AnchorMode.center:
        baseAnchor = sourceCenter;
        break;

      case AnchorMode.cardinal:
        baseAnchor = _calculateCardinalAnchor(
          edge.source,
          sourceCenter,
          destinationCenter,
        );
        break;

      case AnchorMode.octagonal:
        baseAnchor = _calculateOctagonalAnchor(
          edge.source,
          sourceCenter,
          destinationCenter,
        );
        break;

      case AnchorMode.dynamic:
        baseAnchor = _calculateDynamicAnchor(
          edge.source,
          sourceCenter,
          destinationCenter,
        );
        break;
    }

    // Apply perpendicular offset for parallel edges
    return _applyParallelEdgeOffset(baseAnchor, sourceCenter, destinationCenter, edgeIndex);
  }

  @override
  Offset calculateDestinationConnectionPoint(Edge edge, Offset sourceCenter, int edgeIndex) {
    final destCenter = getNodeCenter(edge.destination);

    Offset baseAnchor;
    switch (config.anchorMode) {
      case AnchorMode.center:
        baseAnchor = destCenter;
        break;

      case AnchorMode.cardinal:
        baseAnchor = _calculateCardinalAnchor(
          edge.destination,
          destCenter,
          sourceCenter,
        );
        break;

      case AnchorMode.octagonal:
        baseAnchor = _calculateOctagonalAnchor(
          edge.destination,
          destCenter,
          sourceCenter,
        );
        break;

      case AnchorMode.dynamic:
        baseAnchor = _calculateDynamicAnchor(
          edge.destination,
          destCenter,
          sourceCenter,
        );
        break;
    }

    // Apply perpendicular offset for parallel edges
    return _applyParallelEdgeOffset(baseAnchor, destCenter, sourceCenter, edgeIndex);
  }

  @override
  Path routeEdgePath(Offset sourcePoint, Offset destinationPoint, Edge edge) {
    switch (config.routingMode) {
      case RoutingMode.direct:
        return _buildDirectPath(sourcePoint, destinationPoint);

      case RoutingMode.orthogonal:
        return _buildOrthogonalPath(sourcePoint, destinationPoint);

      case RoutingMode.bezier:
        return _buildBezierPath(sourcePoint, destinationPoint, edge);

      case RoutingMode.bundling:
        // TODO: Implement edge bundling in phase 4
        // For now, fall back to bezier routing
        return _buildBezierPath(sourcePoint, destinationPoint, edge);
    }
  }

  @override
  Path applyEdgeRepulsion(List<Edge> edges, Edge currentEdge, Path path) {
    // If repulsion is disabled, return the original path
    if (!config.enableRepulsion) {
      return path;
    }

    // Get the repulsion offset for the current edge
    final repulsionOffset = _repulsionOffsets[currentEdge] ?? Offset.zero;

    // If no repulsion offset, return original path
    if (repulsionOffset.distance < VectorUtils.epsilon) {
      return path;
    }

    // Get connection points for the edge
    final sourceCenter = getNodeCenter(currentEdge.source);
    final destCenter = getNodeCenter(currentEdge.destination);
    final edgeIndex = _calculateEdgeIndex(currentEdge);
    final sourcePoint = calculateSourceConnectionPoint(currentEdge, destCenter, edgeIndex);
    final destPoint = calculateDestinationConnectionPoint(currentEdge, sourceCenter, edgeIndex);

    // Apply repulsion to the path
    return _applyRepulsionToPath(currentEdge, path, sourcePoint, destPoint);
  }

  /// Builds a direct straight-line path between source and destination.
  Path _buildDirectPath(Offset sourcePoint, Offset destinationPoint) {
    return Path()
      ..moveTo(sourcePoint.dx, sourcePoint.dy)
      ..lineTo(destinationPoint.dx, destinationPoint.dy);
  }

  /// Builds an orthogonal L-shaped path between source and destination.
  ///
  /// Creates Manhattan-style paths with right angles, choosing between
  /// horizontal-first or vertical-first routing based on the distance ratio.
  Path _buildOrthogonalPath(Offset sourcePoint, Offset destinationPoint) {
    final path = Path();
    path.moveTo(sourcePoint.dx, sourcePoint.dy);

    final dx = destinationPoint.dx - sourcePoint.dx;
    final dy = destinationPoint.dy - sourcePoint.dy;

    // Handle collinear nodes by adding a small offset for visibility
    if (dx.abs() < VectorUtils.epsilon) {
      // Vertical line - add horizontal offset
      final offset = 10.0;
      path.lineTo(sourcePoint.dx + offset, sourcePoint.dy);
      path.lineTo(sourcePoint.dx + offset, destinationPoint.dy);
      path.lineTo(destinationPoint.dx, destinationPoint.dy);
      return path;
    }

    if (dy.abs() < VectorUtils.epsilon) {
      // Horizontal line - add vertical offset
      final offset = 10.0;
      path.lineTo(sourcePoint.dx, sourcePoint.dy + offset);
      path.lineTo(destinationPoint.dx, sourcePoint.dy + offset);
      path.lineTo(destinationPoint.dx, destinationPoint.dy);
      return path;
    }

    // Choose routing direction based on distance ratio
    // Horizontal-first if horizontal distance >= vertical distance
    if (dx.abs() >= dy.abs()) {
      final midX = sourcePoint.dx + dx * 0.5;
      path.lineTo(midX, sourcePoint.dy);
      path.lineTo(midX, destinationPoint.dy);
    } else {
      // Vertical-first if vertical distance > horizontal distance
      final midY = sourcePoint.dy + dy * 0.5;
      path.lineTo(sourcePoint.dx, midY);
      path.lineTo(destinationPoint.dx, midY);
    }

    path.lineTo(destinationPoint.dx, destinationPoint.dy);
    return path;
  }

  /// Builds a bezier path with control points for smooth curves.
  ///
  /// Creates cubic bezier curves with control points offset 1/3 of the
  /// total edge length from the start and end points along the edge direction.
  /// This creates smooth, natural-looking curves that respect the edge direction.
  Path _buildBezierPath(Offset sourcePoint, Offset destinationPoint, Edge edge) {
    final path = Path();
    path.moveTo(sourcePoint.dx, sourcePoint.dy);

    // Calculate direction vector from source to destination
    final direction = destinationPoint - sourcePoint;
    final distance = direction.distance;

    // Handle zero-distance edges (nodes at same position)
    if (distance < VectorUtils.epsilon) {
      path.lineTo(destinationPoint.dx, destinationPoint.dy);
      return path;
    }

    // Normalize direction vector
    final normalized = VectorUtils.normalize(direction);

    // Calculate control points offset 1/3 of the edge length from start/end
    // This creates a smooth curve that respects the edge direction
    final controlPointDistance = distance / 3.0;

    // First control point: offset from source along edge direction
    final controlPoint1 = Offset(
      sourcePoint.dx + normalized.dx * controlPointDistance,
      sourcePoint.dy + normalized.dy * controlPointDistance,
    );

    // Second control point: offset from destination back along edge direction
    final controlPoint2 = Offset(
      destinationPoint.dx - normalized.dx * controlPointDistance,
      destinationPoint.dy - normalized.dy * controlPointDistance,
    );

    // Create cubic bezier curve
    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      destinationPoint.dx,
      destinationPoint.dy,
    );

    return path;
  }

  /// Calculates a cardinal anchor point (N, E, S, W) on the node boundary.
  ///
  /// The direction is determined by the angle from [nodeCenter] to [targetCenter].
  /// The angle is binned into 4 sectors (90 degrees each):
  /// - East: [-45°, 45°)
  /// - South: [45°, 135°)
  /// - West: [135°, 225°) or [-180°, -135°)
  /// - North: [-135°, -45°)
  ///
  /// Note: In Flutter's coordinate system, positive Y is down, so:
  /// - North (up) has angle around -90°
  /// - South (down) has angle around 90°
  Offset _calculateCardinalAnchor(Node node, Offset nodeCenter, Offset targetCenter) {
    final nodePosition = getNodePosition(node);

    // Calculate direction vector from node center to target center
    final direction = targetCenter - nodeCenter;

    // Calculate angle in radians (-π to π)
    final angle = VectorUtils.angle(direction);

    // Convert to degrees for easier binning
    final degrees = angle * 180 / pi;

    // Bin into 4 cardinal directions (90-degree sectors)
    // Note: In Flutter, +Y is down, so angle interpretations:
    // East (right): -45 to 45 degrees
    // South (down): 45 to 135 degrees
    // West (left): 135 to 180 or -180 to -135 degrees
    // North (up): -135 to -45 degrees

    if (degrees >= -45 && degrees < 45) {
      // East - right edge
      return Offset(
        nodePosition.dx + node.width,
        nodePosition.dy + node.height * 0.5,
      );
    } else if (degrees >= 45 && degrees < 135) {
      // South - bottom edge (positive Y is down)
      return Offset(
        nodePosition.dx + node.width * 0.5,
        nodePosition.dy + node.height,
      );
    } else if (degrees >= -135 && degrees < -45) {
      // North - top edge (negative Y is up)
      return Offset(
        nodePosition.dx + node.width * 0.5,
        nodePosition.dy,
      );
    } else {
      // West - left edge (135 to 180 or -180 to -135)
      return Offset(
        nodePosition.dx,
        nodePosition.dy + node.height * 0.5,
      );
    }
  }

  /// Calculates an octagonal anchor point (8 compass points) on the node boundary.
  ///
  /// The direction is determined by the angle from [nodeCenter] to [targetCenter].
  /// The angle is binned into 8 sectors (45 degrees each):
  /// - East (E): [-22.5°, 22.5°)
  /// - Southeast (SE): [22.5°, 67.5°)
  /// - South (S): [67.5°, 112.5°)
  /// - Southwest (SW): [112.5°, 157.5°)
  /// - West (W): [157.5°, 180°] or [-180°, -157.5°]
  /// - Northwest (NW): [-157.5°, -112.5°)
  /// - North (N): [-112.5°, -67.5°)
  /// - Northeast (NE): [-67.5°, -22.5°)
  ///
  /// Note: In Flutter's coordinate system, positive Y is down, so:
  /// - North (up) has angle around -90°
  /// - South (down) has angle around 90°
  /// - Diagonal directions use corner points
  Offset _calculateOctagonalAnchor(Node node, Offset nodeCenter, Offset targetCenter) {
    final nodePosition = getNodePosition(node);

    // Calculate direction vector from node center to target center
    final direction = targetCenter - nodeCenter;

    // Calculate angle in radians (-π to π)
    final angle = VectorUtils.angle(direction);

    // Convert to degrees for easier binning
    final degrees = angle * 180 / pi;

    // Bin into 8 octagonal directions (45-degree sectors)
    // Note: In Flutter, +Y is down, so angle interpretations:
    // East (right): -22.5 to 22.5 degrees
    // Southeast (bottom-right): 22.5 to 67.5 degrees
    // South (down): 67.5 to 112.5 degrees
    // Southwest (bottom-left): 112.5 to 157.5 degrees
    // West (left): 157.5 to 180 or -180 to -157.5 degrees
    // Northwest (top-left): -157.5 to -112.5 degrees
    // North (up): -112.5 to -67.5 degrees
    // Northeast (top-right): -67.5 to -22.5 degrees

    if (degrees >= -22.5 && degrees < 22.5) {
      // East - right edge, center height
      return Offset(
        nodePosition.dx + node.width,
        nodePosition.dy + node.height * 0.5,
      );
    } else if (degrees >= 22.5 && degrees < 67.5) {
      // Southeast - bottom-right corner
      return Offset(
        nodePosition.dx + node.width,
        nodePosition.dy + node.height,
      );
    } else if (degrees >= 67.5 && degrees < 112.5) {
      // South - bottom edge, center width
      return Offset(
        nodePosition.dx + node.width * 0.5,
        nodePosition.dy + node.height,
      );
    } else if (degrees >= 112.5 && degrees < 157.5) {
      // Southwest - bottom-left corner
      return Offset(
        nodePosition.dx,
        nodePosition.dy + node.height,
      );
    } else if (degrees >= -157.5 && degrees < -112.5) {
      // Northwest - top-left corner
      return Offset(
        nodePosition.dx,
        nodePosition.dy,
      );
    } else if (degrees >= -112.5 && degrees < -67.5) {
      // North - top edge, center width
      return Offset(
        nodePosition.dx + node.width * 0.5,
        nodePosition.dy,
      );
    } else if (degrees >= -67.5 && degrees < -22.5) {
      // Northeast - top-right corner
      return Offset(
        nodePosition.dx + node.width,
        nodePosition.dy,
      );
    } else {
      // West - left edge, center height (157.5 to 180 or -180 to -157.5)
      return Offset(
        nodePosition.dx,
        nodePosition.dy + node.height * 0.5,
      );
    }
  }

  /// Calculates a dynamic anchor point using exact ray-rectangle intersection.
  ///
  /// This method calculates the precise point where the ray from [nodeCenter]
  /// to [targetCenter] intersects the rectangular boundary of the node.
  /// Unlike cardinal and octagonal modes which snap to fixed directions,
  /// dynamic mode provides pixel-perfect intersection calculation.
  ///
  /// The algorithm:
  /// 1. Calculate the direction ray from node center to target center
  /// 2. Compute slope of the ray
  /// 3. Test intersection with vertical edges (left/right)
  /// 4. Test intersection with horizontal edges (top/bottom)
  /// 5. Return the intersection point on the node's perimeter
  ///
  /// This is based on the `clipLineEnd` algorithm from ArrowEdgeRenderer,
  /// but adapted to work with node boundaries in the adaptive rendering context.
  Offset _calculateDynamicAnchor(Node node, Offset nodeCenter, Offset targetCenter) {
    final nodePosition = getNodePosition(node);

    // If source and target are at the same position, return the center
    if ((nodeCenter - targetCenter).distance < VectorUtils.epsilon) {
      return nodeCenter;
    }

    final halfWidth = node.width * 0.5;
    final halfHeight = node.height * 0.5;

    // Calculate the slope of the ray from node center to target center
    final dx = targetCenter.dx - nodeCenter.dx;
    final dy = targetCenter.dy - nodeCenter.dy;

    // Handle vertical line (infinite slope)
    if (dx.abs() < VectorUtils.epsilon) {
      if (dy > 0) {
        // Ray points downward - intersect bottom edge
        return Offset(
          nodeCenter.dx,
          nodePosition.dy + node.height,
        );
      } else {
        // Ray points upward - intersect top edge
        return Offset(
          nodeCenter.dx,
          nodePosition.dy,
        );
      }
    }

    final slope = dy / dx;

    // Check vertical edge intersections (left/right edges)
    final halfSlopeWidth = slope * halfWidth;
    if (halfSlopeWidth.abs() <= halfHeight) {
      if (dx > 0) {
        // Ray points right - intersect right edge
        return Offset(
          nodePosition.dx + node.width,
          nodeCenter.dy + halfSlopeWidth,
        );
      } else {
        // Ray points left - intersect left edge
        return Offset(
          nodePosition.dx,
          nodeCenter.dy - halfSlopeWidth,
        );
      }
    }

    // Check horizontal edge intersections (top/bottom edges)
    if (slope != 0) {
      final halfSlopeHeight = halfHeight / slope;
      if (halfSlopeHeight.abs() <= halfWidth) {
        if (dy > 0) {
          // Ray points downward - intersect bottom edge
          return Offset(
            nodeCenter.dx + halfSlopeHeight,
            nodePosition.dy + node.height,
          );
        } else {
          // Ray points upward - intersect top edge
          return Offset(
            nodeCenter.dx - halfSlopeHeight,
            nodePosition.dy,
          );
        }
      }
    }

    // Fallback to center if no intersection found (should not happen in practice)
    return nodeCenter;
  }

  /// Calculates the index of this edge among parallel edges between the same nodes.
  /// Returns 0 if there are no parallel edges, or the index (0, 1, 2, ...) for distribution.
  int _calculateEdgeIndex(Edge edge) {
    // If no graph reference, return 0 (no distribution)
    if (_graph == null) {
      return 0;
    }

    // Get all outgoing edges from the source node
    final outEdges = _graph!.getOutEdges(edge.source);

    // Filter for edges going to the same destination
    final parallelEdges = outEdges.where((e) => e.destination == edge.destination).toList();

    // If only one edge, no distribution needed
    if (parallelEdges.length <= 1) {
      return 0;
    }

    // Use graph insertion order for deterministic distribution and locate by identity.
    // Do not rely on Edge.hashCode/== here because parallel edges may compare equal.
    final index = parallelEdges.indexWhere((candidate) => identical(candidate, edge));
    if (index == -1) {
      return 0;
    }

    // Return centered index: for N edges, indices are -(N-1)/2, ..., -1, 0, 1, ..., (N-1)/2
    // This centers the edges around the base anchor point
    final centerOffset = (parallelEdges.length - 1) / 2;
    return index - centerOffset.floor();
  }

  /// Applies a perpendicular offset to the anchor point for parallel edge distribution.
  /// The offset is perpendicular to the edge direction, scaled by edgeIndex * minEdgeDistance.
  Offset _applyParallelEdgeOffset(
    Offset anchor,
    Offset nodeCenter,
    Offset targetCenter,
    int edgeIndex,
  ) {
    // If edgeIndex is 0, no offset needed
    if (edgeIndex == 0) {
      return anchor;
    }

    // Calculate direction vector from node to target
    final direction = targetCenter - nodeCenter;

    // If nodes are at same position, no offset possible
    if (direction.distance < VectorUtils.epsilon) {
      return anchor;
    }

    // Calculate perpendicular vector (rotated 90 degrees)
    final perpendicular = VectorUtils.perpendicular(direction);

    // Normalize and scale by edgeIndex * minEdgeDistance
    final normalized = VectorUtils.normalize(perpendicular);
    final offset = normalized * (edgeIndex * config.minEdgeDistance);

    // Apply offset to anchor point
    return anchor + offset;
  }

  /// Calculates repulsion forces for all edges in the graph.
  ///
  /// This method is called once per render cycle before rendering individual edges.
  /// It uses the EdgeRepulsionSolver to calculate repulsion offsets for all edges
  /// and caches the results for use during rendering.
  void _calculateRepulsionForAllEdges() {
    if (_graph == null) {
      _repulsionOffsets = {};
      return;
    }

    // Calculate repulsion offsets for all edges using the solver
    _repulsionOffsets = _repulsionSolver.applyRepulsionForces(
      _graph!.edges.toList(),
      this,
      config,
    );
  }

  /// Applies repulsion offset to an edge path by modifying its control points.
  ///
  /// For bezier paths, the offset is applied to the control points.
  /// For orthogonal paths, the offset is applied to the midpoint.
  /// For direct paths, the offset creates a slight curve.
  Path _applyRepulsionToPath(
    Edge edge,
    Path originalPath,
    Offset sourcePoint,
    Offset destPoint,
  ) {
    // Get the repulsion offset for this edge
    final repulsionOffset = _repulsionOffsets[edge] ?? Offset.zero;

    // If no repulsion offset, return original path
    if (repulsionOffset.distance < VectorUtils.epsilon) {
      return originalPath;
    }

    // Apply repulsion based on routing mode
    switch (config.routingMode) {
      case RoutingMode.bezier:
      case RoutingMode.bundling:
        return _applyRepulsionToBezierPath(sourcePoint, destPoint, repulsionOffset);

      case RoutingMode.orthogonal:
        return _applyRepulsionToOrthogonalPath(sourcePoint, destPoint, repulsionOffset);

      case RoutingMode.direct:
        // Convert direct path to bezier with repulsion offset
        return _applyRepulsionToDirectPath(sourcePoint, destPoint, repulsionOffset);
    }
  }

  /// Applies repulsion to a bezier path by offsetting the control points.
  Path _applyRepulsionToBezierPath(Offset sourcePoint, Offset destPoint, Offset repulsionOffset) {
    final path = Path();
    path.moveTo(sourcePoint.dx, sourcePoint.dy);

    final direction = destPoint - sourcePoint;
    final distance = direction.distance;

    if (distance < VectorUtils.epsilon) {
      path.lineTo(destPoint.dx, destPoint.dy);
      return path;
    }

    final normalized = VectorUtils.normalize(direction);
    final controlPointDistance = distance / 3.0;

    // Calculate base control points
    final baseControlPoint1 = Offset(
      sourcePoint.dx + normalized.dx * controlPointDistance,
      sourcePoint.dy + normalized.dy * controlPointDistance,
    );

    final baseControlPoint2 = Offset(
      destPoint.dx - normalized.dx * controlPointDistance,
      destPoint.dy - normalized.dy * controlPointDistance,
    );

    // Apply repulsion offset to control points
    final controlPoint1 = baseControlPoint1 + repulsionOffset;
    final controlPoint2 = baseControlPoint2 + repulsionOffset;

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      destPoint.dx,
      destPoint.dy,
    );

    return path;
  }

  /// Applies repulsion to an orthogonal path by offsetting the midpoint.
  Path _applyRepulsionToOrthogonalPath(Offset sourcePoint, Offset destPoint, Offset repulsionOffset) {
    final path = Path();
    path.moveTo(sourcePoint.dx, sourcePoint.dy);

    final dx = destPoint.dx - sourcePoint.dx;
    final dy = destPoint.dy - sourcePoint.dy;

    // Apply repulsion offset to midpoint
    if (dx.abs() >= dy.abs()) {
      // Horizontal-first routing
      final midX = sourcePoint.dx + dx * 0.5 + repulsionOffset.dx;
      final midY = sourcePoint.dy + repulsionOffset.dy;
      path.lineTo(midX, midY);
      path.lineTo(midX, destPoint.dy);
    } else {
      // Vertical-first routing
      final midX = sourcePoint.dx + repulsionOffset.dx;
      final midY = sourcePoint.dy + dy * 0.5 + repulsionOffset.dy;
      path.lineTo(midX, midY);
      path.lineTo(destPoint.dx, midY);
    }

    path.lineTo(destPoint.dx, destPoint.dy);
    return path;
  }

  /// Applies repulsion to a direct path by converting it to a bezier with offset.
  Path _applyRepulsionToDirectPath(Offset sourcePoint, Offset destPoint, Offset repulsionOffset) {
    final path = Path();
    path.moveTo(sourcePoint.dx, sourcePoint.dy);

    // Calculate midpoint with repulsion offset
    final midpoint = Offset(
      (sourcePoint.dx + destPoint.dx) / 2 + repulsionOffset.dx,
      (sourcePoint.dy + destPoint.dy) / 2 + repulsionOffset.dy,
    );

    // Use quadratic bezier for simpler curved path
    path.quadraticBezierTo(
      midpoint.dx,
      midpoint.dy,
      destPoint.dx,
      destPoint.dy,
    );

    return path;
  }

  /// Resets the repulsion calculation flag to allow recalculation in the next render cycle.
  ///
  /// This should be called by the render system when starting a new frame.
  void resetRepulsionCalculation() {
    _repulsionCalculated = false;
  }

  /// Resolves arrow base and tip from the rendered path end tangent.
  ///
  /// Falls back to source/destination points when path tangent extraction fails.
  List<Offset> _resolveArrowPoints(Path path, Offset sourcePoint, Offset destPoint) {
    const arrowLength = 10.0;
    final metrics = path.computeMetrics().toList();

    for (var i = metrics.length - 1; i >= 0; i--) {
      final metric = metrics[i];
      if (metric.length < VectorUtils.epsilon) {
        continue;
      }

      final arrowBaseOffset = max(0.0, metric.length - arrowLength);
      final arrowBaseTangent = metric.getTangentForOffset(arrowBaseOffset);
      final arrowTipTangent = metric.getTangentForOffset(metric.length);

      if (arrowBaseTangent != null && arrowTipTangent != null) {
        final arrowBase = arrowBaseTangent.position;
        final arrowTip = arrowTipTangent.position;

        if ((arrowTip - arrowBase).distance >= VectorUtils.epsilon) {
          return [arrowBase, arrowTip];
        }
      }
    }

    return [sourcePoint, destPoint];
  }

  /// Draws a triangle (arrow head) at the end of an edge.
  ///
  /// Returns the centroid of the triangle for connecting the edge line.
  Offset drawTriangle(Canvas canvas, Paint paint, double startX, double startY,
      double stopX, double stopY) {
    const arrowDegrees = 0.5;
    const arrowLength = 10.0;

    var angle = atan2(stopY - startY, stopX - startX);

    var path = Path();
    path.moveTo(stopX, stopY);
    path.lineTo(
      stopX - arrowLength * cos(angle - arrowDegrees),
      stopY - arrowLength * sin(angle - arrowDegrees),
    );
    path.lineTo(
      stopX - arrowLength * cos(angle + arrowDegrees),
      stopY - arrowLength * sin(angle + arrowDegrees),
    );
    path.close();

    canvas.drawPath(path, paint);

    // Calculate centroid of the triangle
    var x1 = stopX;
    var y1 = stopY;
    var x2 = stopX - arrowLength * cos(angle - arrowDegrees);
    var y2 = stopY - arrowLength * sin(angle - arrowDegrees);
    var x3 = stopX - arrowLength * cos(angle + arrowDegrees);
    var y3 = stopY - arrowLength * sin(angle + arrowDegrees);

    var centroidX = (x1 + x2 + x3) / 3;
    var centroidY = (y1 + y2 + y3) / 3;

    return Offset(centroidX, centroidY);
  }
}
