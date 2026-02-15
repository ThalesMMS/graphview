part of graphview;

class GraphChildDelegate {
  static const double _defaultCenterViewportExtent = 2000;
  static const double _centerViewportPadding = 200;

  final Graph graph;
  final Algorithm algorithm;
  final NodeWidgetBuilder builder;
  GraphViewController? controller;
  final bool centerGraph;
  final Size? centerGraphViewportSize;
  final NodeDraggingConfiguration? nodeDraggingConfig;
  Graph? _cachedVisibleGraph;
  int? _cachedVisibleGraphGeneration;
  bool _needsRecalculation = true;

  GraphChildDelegate({
    required this.graph,
    required this.algorithm,
    required this.builder,
    required this.controller,
    this.centerGraph = false,
    this.centerGraphViewportSize,
    this.nodeDraggingConfig,
  });

  Graph getVisibleGraph() {
    if (_cachedVisibleGraphGeneration != null &&
        _cachedVisibleGraphGeneration != graph.generation) {
      _needsRecalculation = true;
    }

    if (_cachedVisibleGraph != null && !_needsRecalculation) {
      return _cachedVisibleGraph!;
    }

    final visibleGraph = getVisibleGraphOnly();

    final collapsingEdges = controller?.getCollapsingEdges(graph) ?? [];
    visibleGraph.addEdges(collapsingEdges);

    _cachedVisibleGraph = visibleGraph;
    _cachedVisibleGraphGeneration = graph.generation;
    _needsRecalculation = false;
    return visibleGraph;
  }

  Graph getVisibleGraphOnly() {
    final visibleGraph = Graph();
    for (final edge in graph.edges) {
      if (isNodeVisible(edge.source) && isNodeVisible(edge.destination)) {
        visibleGraph.addEdgeS(edge);
      }
    }

    if (visibleGraph.nodes.isEmpty && graph.nodes.isNotEmpty) {
      visibleGraph.addNode(graph.nodes.first);
    }
    return visibleGraph;
  }

  Widget? build(Node node) {
    var child = node.data ?? builder(node);
    return KeyedSubtree(key: node.key, child: child);
  }

  bool shouldRebuild(GraphChildDelegate oldDelegate) {
    final result = graph != oldDelegate.graph ||
        graph.generation != oldDelegate.graph.generation ||
        algorithm != oldDelegate.algorithm ||
        centerGraph != oldDelegate.centerGraph ||
        centerGraphViewportSize != oldDelegate.centerGraphViewportSize ||
        nodeDraggingConfig != oldDelegate.nodeDraggingConfig;
    if (result) _needsRecalculation = true;
    return result;
  }

  Size runAlgorithm(Size availableSize) {
    final visibleGraph = getVisibleGraphOnly();

    if (centerGraph) {
      final viewPortSize =
          _resolveCenterViewportSize(visibleGraph, availableSize);
      final centerX = viewPortSize.width / 2;
      final centerY = viewPortSize.height / 2;
      algorithm.run(visibleGraph, centerX, centerY);
      return viewPortSize;
    } else {
      // Use default algorithm behavior
      return algorithm.run(visibleGraph, 0, 0);
    }
  }

  Size _resolveCenterViewportSize(Graph visibleGraph, Size availableSize) {
    if (centerGraphViewportSize != null &&
        _isFinitePositive(centerGraphViewportSize!)) {
      return centerGraphViewportSize!;
    }

    // Prefer actual layout constraints when available to avoid oversized
    // synthetic viewports and precision issues.
    if (_isFinitePositive(availableSize)) {
      return availableSize;
    }

    // Fallback for unbounded constraints: estimate from graph size with padding.
    final measuredGraphSize = algorithm.run(visibleGraph, 0, 0);
    return _viewportFromGraphSize(measuredGraphSize);
  }

  bool _isFinitePositive(Size size) {
    return size.width.isFinite &&
        size.height.isFinite &&
        size.width > 0 &&
        size.height > 0;
  }

  Size _viewportFromGraphSize(Size graphSize) {
    final width = graphSize.width.isFinite
        ? max(graphSize.width + _centerViewportPadding * 2,
            _defaultCenterViewportExtent)
        : _defaultCenterViewportExtent;
    final height = graphSize.height.isFinite
        ? max(graphSize.height + _centerViewportPadding * 2,
            _defaultCenterViewportExtent)
        : _defaultCenterViewportExtent;
    return Size(width, height);
  }

  bool isNodeVisible(Node node) {
    return controller?.isNodeVisible(graph, node) ?? true;
  }

  Node? findClosestVisibleAncestor(Node node) {
    return controller?.findClosestVisibleAncestor(graph, node);
  }
}
