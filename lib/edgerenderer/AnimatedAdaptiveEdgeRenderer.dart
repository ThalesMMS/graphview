part of graphview;

/// Adaptive edge renderer with animated flow particles that follow the final
/// rendered path.
class AnimatedAdaptiveEdgeRenderer extends AdaptiveEdgeRenderer {
  final AnimatedEdgeConfiguration animationConfig;
  double animationValue;

  AnimatedAdaptiveEdgeRenderer({
    required super.config,
    this.animationConfig = const AnimatedEdgeConfiguration(),
    this.animationValue = 0.0,
    bool noArrow = false,
  }) : super(noArrow: noArrow);

  /// Updates the animation progress in the `[0, 1]` range.
  void setAnimationValue(double value) {
    animationValue = value;
  }

  @override
  void renderEdge(Canvas canvas, Edge edge, Paint paint) {
    if (edge.renderer != null) {
      edge.renderer!.renderEdge(canvas, edge, paint);
      return;
    }

    final currentPaint = (edge.paint ?? paint)..style = PaintingStyle.stroke;
    prepareForRenderCycle();

    final geometry = buildEdgeGeometry(
      edge,
      arrowLength: noArrow ? 0.0 : 10.0,
    );
    if (geometry == null) {
      return;
    }

    paintEdgeGeometry(canvas, edge, currentPaint, geometry);

    if (!noArrow) {
      final trianglePaint = Paint()
        ..color = edge.paint?.color ?? paint.color
        ..style = PaintingStyle.fill;
      paintEdgeArrow(canvas, edge, trianglePaint, geometry);
    }

    final labelGeometry = buildLabelGeometry(edge, geometry.path);
    if (labelGeometry != null) {
      paintEdgeLabel(canvas, edge, labelGeometry);
    }

    renderAnimatedParticlesOnPath(canvas, edge, paint, geometry.path);
  }

  /// Paints flow particles following the supplied [path].
  void renderAnimatedParticlesOnPath(
    Canvas canvas,
    Edge edge,
    Paint paint,
    Path path,
  ) {
    final particlePaint = Paint()
      ..color =
          animationConfig.particleColor ?? edge.paint?.color ?? paint.color
      ..style = PaintingStyle.fill;

    for (final position in computeParticlePositions(path)) {
      canvas.drawCircle(
        position,
        animationConfig.particleSize,
        particlePaint,
      );
    }
  }

  /// Resolves particle centers along [path] for the current animation tick.
  ///
  /// Exposed so callers can validate animation behavior against the actual
  /// rendered geometry instead of assuming a straight-line fallback.
  List<Offset> computeParticlePositions(Path path) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty || animationConfig.particleCount <= 0) {
      return const <Offset>[];
    }

    final metric = metrics.first;
    final pathLength = metric.length;
    if (pathLength <= 0) {
      return const <Offset>[];
    }

    final positions = <Offset>[];
    for (var i = 0; i < animationConfig.particleCount; i++) {
      final basePosition = i / animationConfig.particleCount;
      final animatedPosition =
          (basePosition + animationValue * animationConfig.animationSpeed) %
              1.0;
      final tangent = metric.getTangentForOffset(animatedPosition * pathLength);
      if (tangent != null) {
        positions.add(tangent.position);
      }
    }
    return positions;
  }
}
