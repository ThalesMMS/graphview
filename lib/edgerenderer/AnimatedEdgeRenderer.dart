part of graphview;

/// Configuration for animated edge rendering
class AnimatedEdgeConfiguration {
  /// Speed multiplier for the animation (higher = faster)
  final double animationSpeed;

  /// Number of particles to render along each edge
  final int particleCount;

  /// Size (radius) of each particle in pixels
  final double particleSize;

  /// Color of the particles (defaults to edge color)
  final Color? particleColor;

  const AnimatedEdgeConfiguration({
    this.animationSpeed = 1.0,
    this.particleCount = 3,
    this.particleSize = 3.0,
    this.particleColor,
  });
}

/// Edge renderer that displays animated flow indicators (particles) moving along edges
/// to visualize direction of flow. Extends ArrowEdgeRenderer to preserve arrow functionality.
class AnimatedEdgeRenderer extends ArrowEdgeRenderer {
  /// Configuration for animation appearance
  final AnimatedEdgeConfiguration animationConfig;

  /// Animation value that drives particle movement (0.0 to 1.0)
  /// Should be updated externally via AnimationController
  double animationValue;

  AnimatedEdgeRenderer({
    this.animationConfig = const AnimatedEdgeConfiguration(),
    this.animationValue = 0.0,
    bool noArrow = false,
  }) : super(noArrow: noArrow);

  /// Updates the animation value (typically called from animation listener)
  void setAnimationValue(double value) {
    animationValue = value;
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    // Keep this guard so we do not draw animated particles for edges rendered
    // by a different custom per-edge renderer.
    if (edge.renderer != null && edge.renderer != this) {
      edge.renderer!.renderEdge(canvas, edge, paint);
      return;
    }

    // First render the base edge with arrow using parent implementation
    super.renderEdge(canvas, edge, paint);

    // Then render animated particles on top
    _renderAnimatedParticles(canvas, edge, paint);
  }

  /// Renders animated particles flowing along the edge
  void _renderAnimatedParticles(Canvas canvas, Edge edge, Paint paint) {
    final particlePaint = Paint()
      ..color =
          animationConfig.particleColor ?? edge.paint?.color ?? paint.color
      ..style = PaintingStyle.fill;

    final edgePath = _buildParticlePath(edge);
    if (edgePath == null) return;

    // Compute metrics to get positions along the path
    final metrics = edgePath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final pathLength = metric.length;

    // Render particles at different positions along the path
    for (var i = 0; i < animationConfig.particleCount; i++) {
      // Distribute particles evenly along the path
      final basePosition = i / animationConfig.particleCount;

      // Add animation offset (with speed multiplier)
      final animatedPosition =
          (basePosition + animationValue * animationConfig.animationSpeed) %
              1.0;

      // Convert to actual path offset
      final offset = animatedPosition * pathLength;

      // Get the tangent at this position
      final tangent = metric.getTangentForOffset(offset);
      if (tangent != null) {
        // Draw particle as a circle
        canvas.drawCircle(
          tangent.position,
          animationConfig.particleSize,
          particlePaint,
        );
      }
    }
  }

  Path? _buildParticlePath(Edge edge) {
    final source = edge.source;
    final destination = edge.destination;

    if (source == destination) {
      final loopResult = buildSelfLoopPath(
        edge,
        arrowLength: noArrow ? 0.0 : ARROW_LENGTH,
      );
      return loopResult?.path;
    }

    double startX;
    double startY;
    double stopX;
    double stopY;

    if (_shouldUseAdaptiveAnchors()) {
      final edgeIndex = _calculateEdgeIndex(edge);
      final sourceCenter = _getNodeCenter(source);
      final destCenter = _getNodeCenter(destination);
      final sourcePoint =
          calculateSourceConnectionPoint(edge, destCenter, edgeIndex);
      final destPoint =
          calculateDestinationConnectionPoint(edge, sourceCenter, edgeIndex);
      startX = sourcePoint.dx;
      startY = sourcePoint.dy;
      stopX = destPoint.dx;
      stopY = destPoint.dy;
    } else {
      final sourceOffset = getNodePosition(source);
      final destinationOffset = getNodePosition(destination);
      startX = sourceOffset.dx + source.width * 0.5;
      startY = sourceOffset.dy + source.height * 0.5;
      stopX = destinationOffset.dx + destination.width * 0.5;
      stopY = destinationOffset.dy + destination.height * 0.5;
    }

    final clippedLine = _shouldUseAdaptiveAnchors()
        ? [startX, startY, stopX, stopY]
        : clipLineEnd(
            startX,
            startY,
            stopX,
            stopY,
            getNodePosition(destination).dx,
            getNodePosition(destination).dy,
            destination.width,
            destination.height,
          );

    final particleEnd = noArrow
        ? Offset(clippedLine[2], clippedLine[3])
        : _calculateArrowTriangleCentroid(
            clippedLine[0],
            clippedLine[1],
            clippedLine[2],
            clippedLine[3],
          );

    return Path()
      ..moveTo(clippedLine[0], clippedLine[1])
      ..lineTo(particleEnd.dx, particleEnd.dy);
  }

  Offset _calculateArrowTriangleCentroid(
    double lineStartX,
    double lineStartY,
    double arrowTipX,
    double arrowTipY,
  ) {
    final lineDirection =
        (atan2(arrowTipY - lineStartY, arrowTipX - lineStartX) + pi);
    final leftWingX =
        (arrowTipX + ARROW_LENGTH * cos((lineDirection - ARROW_DEGREES)));
    final leftWingY =
        (arrowTipY + ARROW_LENGTH * sin((lineDirection - ARROW_DEGREES)));
    final rightWingX =
        (arrowTipX + ARROW_LENGTH * cos((lineDirection + ARROW_DEGREES)));
    final rightWingY =
        (arrowTipY + ARROW_LENGTH * sin((lineDirection + ARROW_DEGREES)));

    return Offset(
      (arrowTipX + leftWingX + rightWingX) / 3,
      (arrowTipY + leftWingY + rightWingY) / 3,
    );
  }
}
