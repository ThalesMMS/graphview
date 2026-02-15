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
    final visited = <Node>{};

    // Walk up until we find a visible ancestor
    while (current != null) {
      if (!visited.add(current)) {
        return null;
      }

      if (isNodeVisible(graph, current)) {
        return current; // Return the first (closest) visible ancestor
      }

      final next = graph.predecessorsOf(current).firstOrNull;
      if (next != null && visited.contains(next)) {
        return null;
      }
      current = next;
    }

    return null;
  }

  void _markDescendantsHiddenBy(
      Graph graph, Node collapsedNode, Node currentNode) {
    final stack = <Node>[currentNode];
    final visitedNodes = <Node>{};

    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (!visitedNodes.add(node)) {
        continue;
      }

      for (final child in graph.successorsOf(node)) {
        // Only mark as hidden if:
        // 1. Not already hidden, OR
        // 2. Was hidden by a node that's no longer collapsed
        if (!hiddenBy.containsKey(child) ||
            !collapsedNodes.containsKey(hiddenBy[child])) {
          hiddenBy[child] = collapsedNode;
        }

        // Traverse deeper only if this child isn't itself a collapsed node.
        if (!collapsedNodes.containsKey(child)) {
          stack.add(child);
        }
      }
    }
  }

  void _markExpandingDescendants(Graph graph, Node node) {
    final stack = <Node>[node];
    final visitedNodes = <Node>{};

    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (!visitedNodes.add(current)) {
        continue;
      }

      for (final child in graph.successorsOf(current)) {
        expandingNodes[child] = true;
        if (!collapsedNodes.containsKey(child)) {
          stack.add(child);
        }
      }
    }
  }

  void expandNode(Graph graph, Node node, {animate = false}) {
    collapsedNodes.remove(node);
    hiddenBy.removeWhere((hiddenNode, hiddenBy) => hiddenBy == node);

    _clearExpandingNodesWhenIdle();
    _markExpandingDescendants(graph, node);

    if (animate) {
      focusedNode = node;
    }
    forceRecalculation();
  }

  void collapseNode(Graph graph, Node node, {animate = false}) {
    _clearExpandingNodesWhenIdle();
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
      final node =
          graph.nodes.firstWhereOrNull((element) => element.key == key);
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
    expandingNodes.clear();
  }

  void _clearExpandingNodesWhenIdle() {
    final isNodeTransitionAnimating =
        _state?._nodeController.isAnimating ?? false;
    if (!isNodeTransitionAnimating) {
      expandingNodes.clear();
    }
  }

  void jumpToFocusedNode() {
    if (focusedNode != null) {
      _state?.jumpToOffset(focusedNode!.position, true);
      focusedNode = null;
    }
  }
}
