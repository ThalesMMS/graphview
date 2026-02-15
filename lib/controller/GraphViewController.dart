part of graphview;

class GraphViewController {
  _GraphViewState? _state;
  final TransformationController? transformationController;

  final Map<Node, bool> collapsedNodes = {};
  final Map<Node, bool> expandingNodes = {};
  final Map<Node, Node> hiddenBy = {};

  Node? collapsedNode;
  Node? focusedNode;

  GraphViewController({
    this.transformationController,
  });

  void _attach(_GraphViewState? state) => _state = state;

  void _detach() => _state = null;

  void animateToNode(ValueKey key) => _state?.jumpToNodeUsingKey(key, true);

  void jumpToNode(ValueKey key) => _state?.jumpToNodeUsingKey(key, false);

  void animateToMatrix(Matrix4 target) => _state?.animateToMatrix(target);

  void resetView() => _state?.resetView();

  void zoomToFit() => _state?.zoomToFit();

  void forceRecalculation() => _state?.forceRecalculation();

  // Visibility management methods
  bool isNodeCollapsed(Node node) => collapsedNodes.containsKey(node);

  bool isNodeHidden(Node node) => hiddenBy.containsKey(node);

  bool isNodeVisible(Graph graph, Node node) {
    return graph.nodes.contains(node) && !hiddenBy.containsKey(node);
  }

  Node? findClosestVisibleAncestor(Graph graph, Node node) {
    var current = graph.predecessorsOf(node).firstOrNull;

    // Walk up until we find a visible ancestor
    while (current != null) {
      if (isNodeVisible(graph, current)) {
        return current; // Return the first (closest) visible ancestor
      }
      current = graph.predecessorsOf(current).firstOrNull;
    }

    return null;
  }

  void _markDescendantsHiddenBy(
      Graph graph, Node collapsedNode, Node currentNode) {
    for (final child in graph.successorsOf(currentNode)) {
      // Only mark as hidden if:
      // 1. Not already hidden, OR
      // 2. Was hidden by a node that's no longer collapsed
      if (!hiddenBy.containsKey(child) ||
          !collapsedNodes.containsKey(hiddenBy[child])) {
        hiddenBy[child] = collapsedNode;
      }

      // Recurse only if this child isn't itself a collapsed node
      if (!collapsedNodes.containsKey(child)) {
        _markDescendantsHiddenBy(graph, collapsedNode, child);
      }
    }
  }

  void _markExpandingDescendants(Graph graph, Node node) {
    for (final child in graph.successorsOf(node)) {
        expandingNodes[child] = true;
        if (!collapsedNodes.containsKey(child)) {
        _markExpandingDescendants(graph, child);
      }
    }
  }

  void expandNode(Graph graph, Node node, {animate = false}) {
    collapsedNodes.remove(node);
    hiddenBy.removeWhere((hiddenNode, hiddenBy) => hiddenBy == node);

    expandingNodes.clear();
    _markExpandingDescendants(graph, node);

    if (animate) {
      focusedNode = node;
    }
    forceRecalculation();
  }

  void collapseNode(Graph graph, Node node, {animate = false}) {
    expandingNodes.clear();
    if (graph.hasSuccessor(node)) {
      collapsedNodes[node] = true;
      collapsedNode = node;
      if (animate) {
        focusedNode = node;
      }
      _markDescendantsHiddenBy(graph, node, node);
      forceRecalculation();
    }
  }

  void toggleNodeExpanded(Graph graph, Node node, {animate = false}) {
    if (isNodeCollapsed(node)) {
      expandNode(graph, node, animate: animate);
    } else {
      collapseNode(graph, node, animate: animate);
    }
  }

  List<Edge> getCollapsingEdges(Graph graph) {
    if (collapsedNode == null) return [];

    return graph.edges.where((edge) {
      return hiddenBy[edge.destination] == collapsedNode;
    }).toList();
  }

  List<Edge> getExpandingEdges(Graph graph) {
    final expandingEdges = <Edge>[];

    for (final node in expandingNodes.keys) {
      // Get all incoming edges to expanding nodes
      for (final edge in graph.getInEdges(node)) {
        expandingEdges.add(edge);
      }
    }

    return expandingEdges;
  }

  // Additional convenience methods for setting initial state
  void setInitiallyCollapsedNodes(Graph graph, List<Node> nodes) {
    for (final node in nodes) {
      collapsedNodes[node] = true;
      // Mark descendants as hidden by this node
      _markDescendantsHiddenBy(graph, node, node);
    }
  }

  void setInitiallyCollapsedByKeys(Graph graph, Set<ValueKey> keys) {
    for (final key in keys) {
      final node = graph.nodes.firstWhereOrNull((element) => element.key == key);
      if (node == null) {
        assert(() {
          debugPrint(
              'GraphViewController.setInitiallyCollapsedByKeys: node with key $key not found');
          return true;
        }());
        continue;
      }
      collapsedNodes[node] = true;
      // Mark descendants as hidden by this node
      _markDescendantsHiddenBy(graph, node, node);
    }
  }

  bool isNodeExpanding(Node node) => expandingNodes.containsKey(node);

  void removeCollapsingNodes() {
    collapsedNode = null;
  }

  void jumpToFocusedNode() {
    if (focusedNode != null) {
      _state?.jumpToOffset(focusedNode!.position, true);
      focusedNode = null;
    }
  }
}
