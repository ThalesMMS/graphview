library graphview;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

part 'Algorithm.dart';
part 'Graph.dart';
part 'edgerenderer/ArrowEdgeRenderer.dart';
part 'edgerenderer/EdgeRenderer.dart';
part 'forcedirected/FruchtermanReingoldAlgorithm.dart';
part 'forcedirected/FruchtermanReingoldConfiguration.dart';
part 'layered/EiglspergerAlgorithm.dart';
part 'layered/SugiyamaAlgorithm.dart';
part 'layered/SugiyamaConfiguration.dart';
part 'layered/SugiyamaEdgeData.dart';
part 'layered/SugiyamaEdgeRenderer.dart';
part 'layered/SugiyamaNodeData.dart';
part 'mindmap/MindMapAlgorithm.dart';
part 'mindmap/MindmapEdgeRenderer.dart';
part 'tree/BaloonLayoutAlgorithm.dart';
part 'tree/BuchheimWalkerAlgorithm.dart';
part 'tree/BuchheimWalkerConfiguration.dart';
part 'tree/BuchheimWalkerNodeData.dart';
part 'tree/CircleLayoutAlgorithm.dart';
part 'tree/RadialTreeLayoutAlgorithm.dart';
part 'tree/TidierTreeLayoutAlgorithm.dart';
part 'tree/TreeEdgeRenderer.dart';

typedef NodeWidgetBuilder = Widget Function(Node node);
typedef EdgeWidgetBuilder = Widget Function(Edge edge);

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
    return !hiddenBy.containsKey(node);
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
    if (graph.hasSuccessor(node)) {
      collapsedNodes[node] = true;
      collapsedNode = node;
      if (animate) {
        focusedNode = node;
      }
      _markDescendantsHiddenBy(graph, node, node);
      forceRecalculation();
    }
    expandingNodes.clear();
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
      try {
        final node = graph.getNodeUsingKey(key);
        collapsedNodes[node] = true;
        // Mark descendants as hidden by this node
        _markDescendantsHiddenBy(graph, node, node);
      } catch (e) {
        // Node with key not found, ignore
      }
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

class GraphChildDelegate {
  final Graph graph;
  final Algorithm algorithm;
  final NodeWidgetBuilder builder;
  final EdgeWidgetBuilder? edgeBuilder;
  GraphViewController? controller;
  final bool centerGraph;
  Graph? _cachedVisibleGraph;
  bool _needsRecalculation = true;

  GraphChildDelegate({
    required this.graph,
    required this.algorithm,
    required this.builder,
    required this.controller,
    this.edgeBuilder,
    this.centerGraph = false,
  });

  Graph getVisibleGraph() {
    if (_cachedVisibleGraph != null && !_needsRecalculation) {
      return _cachedVisibleGraph!;
    }

    final visibleGraph = getVisibleGraphOnly();

    final collapsingEdges = controller?.getCollapsingEdges(graph) ?? [];
    visibleGraph.addEdges(collapsingEdges);

    _cachedVisibleGraph = visibleGraph;
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
    final child = (node
            // ignore: deprecated_member_use_from_same_package
            .data) ??
        builder(node);
    return KeyedSubtree(key: node.key, child: child);
  }

  Widget? buildEdgeLabel(Edge edge) {
    final builder = edgeBuilder;
    if (builder == null) {
      return null;
    }
    final child = builder(edge);
    if (child == null) {
      return null;
    }
    return KeyedSubtree(key: edge.key, child: child);
  }

  bool shouldRebuild(GraphChildDelegate oldDelegate) {
    final result =
        graph != oldDelegate.graph ||
        algorithm != oldDelegate.algorithm ||
        edgeBuilder != oldDelegate.edgeBuilder;
    if (result) _needsRecalculation = true;
    return result;
  }

  Size runAlgorithm() {
    final visibleGraph = getVisibleGraphOnly();

    if (centerGraph) {
      // Use large viewport and center the graph
      var viewPortSize = Size(200000, 200000);
      var centerX = viewPortSize.width / 2;
      var centerY = viewPortSize.height / 2;
      algorithm.run(visibleGraph, centerX, centerY);
      return viewPortSize;
    } else {
      // Use default algorithm behavior
      return algorithm.run(visibleGraph, 0, 0);
    }
  }

  bool isNodeVisible(Node node) {
    return controller?.isNodeVisible(graph, node) ?? true;
  }

  Node? findClosestVisibleAncestor(Node node) {
    return controller?.findClosestVisibleAncestor(graph, node);
  }
}

class GraphView extends StatefulWidget {
  final Graph graph;
  final Algorithm algorithm;
  final Paint? paint;
  final NodeWidgetBuilder builder;
  final EdgeWidgetBuilder? edgeBuilder;
  final bool animated;
  final GraphViewController? controller;
  final bool _isBuilder;

  final Duration? panAnimationDuration;
  final Duration? toggleAnimationDuration;
  final ValueKey? initialNode;
  final bool autoZoomToFit;
  final GraphChildDelegate delegate;
  final bool centerGraph;

  GraphView({
    Key? key,
    required this.graph,
    required this.algorithm,
    this.paint,
    required this.builder,
    this.edgeBuilder,
    this.animated = true,
    this.controller,
    this.toggleAnimationDuration,
    this.centerGraph = false,
  })  : _isBuilder = false,
        panAnimationDuration = null,
        initialNode = null,
        autoZoomToFit = false,
        delegate = GraphChildDelegate(
            graph: graph,
            algorithm: algorithm,
            builder: builder,
            controller: null,
            edgeBuilder: edgeBuilder),
        super(key: key);

  GraphView.builder({
    Key? key,
    required this.graph,
    required this.algorithm,
    this.paint,
    required this.builder,
    this.edgeBuilder,
    this.controller,
    this.animated = true,
    this.initialNode,
    this.autoZoomToFit = false,
    this.panAnimationDuration,
    this.toggleAnimationDuration,
    this.centerGraph = false,
  })  : _isBuilder = true,
        delegate = GraphChildDelegate(
            graph: graph,
            algorithm: algorithm,
            builder: builder,
            controller: controller,
            edgeBuilder: edgeBuilder,
            centerGraph: centerGraph),
        assert(!(autoZoomToFit && initialNode != null),
            'Cannot use both autoZoomToFit and initialNode together. Choose one.'),
        super(key: key);

  @override
  _GraphViewState createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> with TickerProviderStateMixin {
  late TransformationController _transformationController;
  late final AnimationController _cameraController;
  late final AnimationController _nodeController;
  Animation<Matrix4>? _cameraAnimation;

  @override
  void initState() {
    super.initState();

    _transformationController = widget.controller?.transformationController ??
        TransformationController();

    _cameraController = AnimationController(
      vsync: this,
      duration:
          widget.panAnimationDuration ?? const Duration(milliseconds: 600),
    );

    _nodeController = AnimationController(
      vsync: this,
      duration:
          widget.toggleAnimationDuration ?? const Duration(milliseconds: 600),
    );

    widget.controller?._attach(this);

    if (widget.autoZoomToFit || widget.initialNode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.autoZoomToFit) {
          zoomToFit();
        } else if (widget.initialNode != null) {
          jumpToNodeUsingKey(widget.initialNode!, false);
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _cameraController.dispose();
    _nodeController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = GraphViewWidget(
      paint: widget.paint,
      nodeAnimationController: _nodeController,
      enableAnimation: widget.animated,
      delegate: widget.delegate,
      edgeBuilder: widget.delegate.edgeBuilder,
    );

    if (widget._isBuilder) {
      return InteractiveViewer.builder(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.all(double.infinity),
          minScale: 0.01,
          maxScale: 10,
          builder: (context, viewport) {
            return view;
          });
    }

    return view;
  }

  void jumpToNodeUsingKey(ValueKey key, bool animated) {
    final node = widget.graph.nodes.firstWhereOrNull((n) => n.key == key);
    if (node == null) return;

    jumpToNode(node, animated);
  }

  void jumpToNode(Node node, bool animated) {
    final nodeCenter = Offset(
        node.position.dx + node.width / 2, node.position.dy + node.height / 2);

    jumpToOffset(nodeCenter, animated);
  }

  void jumpToOffset(Offset offset, bool animated) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final viewport = renderBox.size;
    final center = Offset(viewport.width / 2, viewport.height / 2);

    final currentScale = _transformationController.value.getMaxScaleOnAxis();

    final scaledNodeCenter = offset * currentScale;
    final translation = center - scaledNodeCenter;

    final target = Matrix4.identity()
      ..translateByVector3(vm.Vector3(translation.dx, translation.dy, 0))
      ..scaleByVector3(vm.Vector3(currentScale, currentScale, 1));

    if (animated) {
      animateToMatrix(target);
    } else {
      _transformationController.value = target;
    }
  }

  void resetView() => animateToMatrix(Matrix4.identity());

  void zoomToFit() {
    var graph = widget.delegate.getVisibleGraphOnly();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final vp = renderBox.size;
    final bounds = graph.calculateGraphBounds();

    const paddingFactor = 0.95;
    final scaleX = (vp.width / bounds.width) * paddingFactor;
    final scaleY = (vp.height / bounds.height) * paddingFactor;
    final scale = min(scaleX, scaleY);

    final scaledWidth = bounds.width * scale;
    final scaledHeight = bounds.height * scale;

    final centerOffset = Offset(
        (vp.width - scaledWidth) * 0.5 - bounds.left * scale,
        (vp.height - scaledHeight) * 0.5 - bounds.top * scale);

    final target = Matrix4.identity()
      ..translateByVector3(vm.Vector3(centerOffset.dx, centerOffset.dy, 0))
      ..scaleByVector3(vm.Vector3(scale, scale, 1));
    animateToMatrix(target);
  }

  void animateToMatrix(Matrix4 target) {
    _cameraController.reset();
    _cameraAnimation = Matrix4Tween(
            begin: _transformationController.value, end: target)
        .animate(
            CurvedAnimation(parent: _cameraController, curve: Curves.linear));
    _cameraAnimation!.addListener(_onCameraTick);
    _cameraController.forward();
  }

  void _onCameraTick() {
    if (_cameraAnimation == null) return;
    _transformationController.value = _cameraAnimation!.value;
    if (!_cameraController.isAnimating) {
      _cameraAnimation!.removeListener(_onCameraTick);
      _cameraAnimation = null;
      _cameraController.reset();
    }
  }

  void forceRecalculation() {
    // Invalidate the delegate's cached graph
    widget.delegate._needsRecalculation = true;

    setState(() {});
  }
}

abstract class GraphChildManager {
  void startLayout();

  void buildChild(Node node);

  void reuseChild(Node node);

  void buildEdgeLabel(Edge edge);

  void reuseEdgeLabel(Edge edge);

  void endLayout();
}

class GraphViewWidget extends RenderObjectWidget {
  final GraphChildDelegate delegate;
  final Paint? paint;
  final AnimationController nodeAnimationController;
  final bool enableAnimation;
  final EdgeWidgetBuilder? edgeBuilder;

  const GraphViewWidget({
    Key? key,
    required this.delegate,
    this.paint,
    required this.nodeAnimationController,
    required this.enableAnimation,
    this.edgeBuilder,
  }) : super(key: key);

  @override
  GraphViewElement createElement() => GraphViewElement(this);

  @override
  RenderCustomLayoutBox createRenderObject(BuildContext context) {
    return RenderCustomLayoutBox(
      delegate,
      paint,
      enableAnimation,
      nodeAnimationController: nodeAnimationController,
      childManager: context as GraphChildManager,
      edgeLabelBuilder: edgeBuilder,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCustomLayoutBox renderObject) {
    renderObject
      ..delegate = delegate
      ..edgePaint = paint
      ..nodeAnimationController = nodeAnimationController
      ..enableAnimation = enableAnimation
      ..edgeLabelBuilder = edgeBuilder;
  }
}

class GraphViewElement extends RenderObjectElement
    implements GraphChildManager {
  GraphViewElement(GraphViewWidget super.widget);

  @override
  GraphViewWidget get widget => super.widget as GraphViewWidget;

  @override
  RenderCustomLayoutBox get renderObject =>
      super.renderObject as RenderCustomLayoutBox;

  // Contains all children, including those that are keyed
  Map<Node, Element> _nodeToElement = <Node, Element>{};
  Map<Edge, Element> _edgeToElement = <Edge, Element>{};
  Map<Key, Element> _keyToElement = <Key, Element>{};

  // Used between startLayout() & endLayout() to compute the new values
  Map<Node, Element>? _newNodeToElement;
  Map<Edge, Element>? _newEdgeToElement;
  Map<Key, Element>? _newKeyToElement;

  bool get _debugIsDoingLayout =>
      _newNodeToElement != null &&
      _newEdgeToElement != null &&
      _newKeyToElement != null;

  @override
  void performRebuild() {
    super.performRebuild();
    // Children list is updated during layout since we only know during layout
    // which children will be visible
    renderObject.markNeedsLayout();
  }

  @override
  void forgetChild(Element child) {
    assert(!_debugIsDoingLayout);
    super.forgetChild(child);
    final slot = child.slot;
    if (slot is Node) {
      _nodeToElement.remove(slot);
    } else if (slot is Edge) {
      _edgeToElement.remove(slot);
    }
    if (child.widget.key != null) {
      _keyToElement.remove(child.widget.key);
    }
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object slot) {
    if (slot is Node) {
      renderObject._insertChild(child, slot);
    } else if (slot is Edge) {
      renderObject._insertEdgeLabel(child, slot);
    } else {
      throw FlutterError('Unsupported slot type: ${slot.runtimeType}');
    }
  }

  @override
  void moveRenderObjectChild(RenderBox child, Object? oldSlot, Object? newSlot) {
    if (oldSlot is Node && newSlot is Node) {
      renderObject._moveChild(child, from: oldSlot, to: newSlot);
    } else if (oldSlot is Edge && newSlot is Edge) {
      renderObject._moveEdgeLabel(child, from: oldSlot, to: newSlot);
    }
  }

  @override
  void removeRenderObjectChild(RenderBox child, Object slot) {
    if (slot is Node) {
      renderObject._removeChild(child, slot);
    } else if (slot is Edge) {
      renderObject._removeEdgeLabel(child, slot);
    }
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _nodeToElement.values.forEach(visitor);
    _edgeToElement.values.forEach(visitor);
  }

  // ---- GraphChildManager implementation ----

  @override
  void startLayout() {
    assert(!_debugIsDoingLayout);
    _newNodeToElement = <Node, Element>{};
    _newEdgeToElement = <Edge, Element>{};
    _newKeyToElement = <Key, Element>{};
  }

  @override
  void buildChild(Node node) {
    assert(_debugIsDoingLayout);
    owner!.buildScope(this, () {
      final newWidget = widget.delegate.build(node);
      if (newWidget == null) {
        return;
      }

      final oldElement = _retrieveOldElement(newWidget, node: node);
      final newChild = updateChild(oldElement, newWidget, node);

      if (newChild != null) {
        // Ensure we are not overwriting an existing child
        assert(_newNodeToElement![node] == null);
        _newNodeToElement![node] = newChild;
        if (newWidget.key != null) {
          // Ensure we are not overwriting an existing key
          assert(_newKeyToElement![newWidget.key!] == null);
          _newKeyToElement![newWidget.key!] = newChild;
        }
      }
    });
  }

  @override
  void reuseChild(Node node) {
    assert(_debugIsDoingLayout);
    final elementToReuse = _nodeToElement.remove(node);
    assert(
      elementToReuse != null,
      'Expected to re-use an element at $node, but none was found.',
    );
    _newNodeToElement![node] = elementToReuse!;
    if (elementToReuse.widget.key != null) {
      assert(_keyToElement.containsKey(elementToReuse.widget.key));
      assert(_keyToElement[elementToReuse.widget.key] == elementToReuse);
      _newKeyToElement![elementToReuse.widget.key!] =
          _keyToElement.remove(elementToReuse.widget.key)!;
    }
  }

  @override
  void buildEdgeLabel(Edge edge) {
    assert(_debugIsDoingLayout);
    owner!.buildScope(this, () {
      final newWidget = widget.delegate.buildEdgeLabel(edge);
      if (newWidget == null) {
        return;
      }

      final oldElement = _retrieveOldElement(newWidget, edge: edge);
      final newChild = updateChild(oldElement, newWidget, edge);

      if (newChild != null) {
        assert(_newEdgeToElement![edge] == null);
        _newEdgeToElement![edge] = newChild;
        if (newWidget.key != null) {
          assert(_newKeyToElement![newWidget.key!] == null);
          _newKeyToElement![newWidget.key!] = newChild;
        }
      }
    });
  }

  @override
  void reuseEdgeLabel(Edge edge) {
    assert(_debugIsDoingLayout);
    final elementToReuse = _edgeToElement.remove(edge);
    assert(
      elementToReuse != null,
      'Expected to re-use an edge element at $edge, but none was found.',
    );
    final reusedElement = elementToReuse!;
    _newEdgeToElement![edge] = reusedElement;
    if (reusedElement.widget.key != null) {
      assert(_keyToElement.containsKey(reusedElement.widget.key));
      assert(_keyToElement[reusedElement.widget.key] == reusedElement);
      _newKeyToElement![reusedElement.widget.key!] =
          _keyToElement.remove(reusedElement.widget.key)!;
    }
  }

  Element? _retrieveOldElement(Widget newWidget, {Node? node, Edge? edge}) {
    if (newWidget.key != null) {
      final result = _keyToElement.remove(newWidget.key);
      if (result != null) {
        final slot = result.slot;
        if (slot is Node) {
          _nodeToElement.remove(slot);
        } else if (slot is Edge) {
          _edgeToElement.remove(slot);
        }
      }
      return result;
    }

    if (node != null) {
      final potentialOldElement = _nodeToElement[node];
      if (potentialOldElement != null && potentialOldElement.widget.key == null) {
        return _nodeToElement.remove(node);
      }
    }

    if (edge != null) {
      final potentialOldElement = _edgeToElement[edge];
      if (potentialOldElement != null && potentialOldElement.widget.key == null) {
        return _edgeToElement.remove(edge);
      }
    }
    return null;
  }

  @override
  void endLayout() {
    assert(_debugIsDoingLayout);

    // Unmount all elements that have not been reused in the layout cycle
    for (final element in _nodeToElement.values) {
      if (element.widget.key == null) {
        // If it has a key, we handle it below
        updateChild(element, null, null);
      } else {
        assert(_keyToElement.containsValue(element));
      }
    }
    for (final element in _edgeToElement.values) {
      if (element.widget.key == null) {
        updateChild(element, null, null);
      } else {
        assert(_keyToElement.containsValue(element));
      }
    }
    for (final element in _keyToElement.values) {
      assert(element.widget.key != null);
      updateChild(element, null, null);
    }

    _nodeToElement = _newNodeToElement!;
    _edgeToElement = _newEdgeToElement!;
    _keyToElement = _newKeyToElement!;
    _newNodeToElement = null;
    _newEdgeToElement = null;
    _newKeyToElement = null;
    assert(!_debugIsDoingLayout);

    centerNodeWhileToggling();
  }

  void centerNodeWhileToggling() {
    widget.delegate.controller?.jumpToFocusedNode();
  }
}

class RenderCustomLayoutBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, NodeBoxData>,
        RenderBoxContainerDefaultsMixin<RenderBox, NodeBoxData> {
  late Paint _paint;
  late AnimationController _nodeAnimationController;
  late GraphChildDelegate _delegate;
  GraphChildManager? childManager;

  Size? _cachedSize;
  bool _isInitialized = false;
  bool _needsFullRecalculation = false;
  late bool enableAnimation;
  final opacityPaint = Paint();

  final animatedPositions = <Node, Offset>{};
  final _children = <Node, RenderBox>{};
  final _activeChildrenForLayoutPass = <Node, RenderBox>{};
  final _edgeLabels = <Edge, RenderBox>{};
  EdgeWidgetBuilder? _edgeLabelBuilder;

  RenderCustomLayoutBox(
    GraphChildDelegate delegate,
    Paint? paint,
    bool enableAnimation, {
    required AnimationController nodeAnimationController,
    this.childManager,
    EdgeWidgetBuilder? edgeLabelBuilder,
  }) {
    _nodeAnimationController = nodeAnimationController;
    _delegate = delegate;
    edgePaint = paint;
    this.enableAnimation = enableAnimation;
    _edgeLabelBuilder = edgeLabelBuilder;
  }

  RenderBox? buildOrObtainChildFor(Node node) {
    assert(debugDoingThisLayout);

    if (_needsFullRecalculation || !_children.containsKey(node)) {
      invokeLayoutCallback<BoxConstraints>((BoxConstraints _) {
        childManager!.buildChild(node);
      });
    } else {
      childManager!.reuseChild(node);
    }

    if (!_children.containsKey(node)) {
      // There is no child for this node, the delegate may not provide one
      return null;
    }

    assert(_children.containsKey(node));
    final child = _children[node]!;
    _activeChildrenForLayoutPass[node] = child;
    return child;
  }

  RenderBox? buildOrObtainEdgeLabel(Edge edge) {
    assert(debugDoingThisLayout);

    if (_edgeLabelBuilder == null || childManager == null) {
      return null;
    }

    if (_needsFullRecalculation || !_edgeLabels.containsKey(edge)) {
      invokeLayoutCallback<BoxConstraints>((BoxConstraints _) {
        childManager!.buildEdgeLabel(edge);
      });
    } else {
      childManager!.reuseEdgeLabel(edge);
    }

    if (!_edgeLabels.containsKey(edge)) {
      return null;
    }

    return _edgeLabels[edge]!;
  }

  GraphChildDelegate get delegate => _delegate;

  Graph get graph => _delegate.getVisibleGraph();

  Algorithm get algorithm => _delegate.algorithm;

  EdgeWidgetBuilder? get edgeLabelBuilder => _edgeLabelBuilder;

  set delegate(GraphChildDelegate value) {
    // if (value != _delegate) {
    _needsFullRecalculation = true;
    _isInitialized = false;
    _delegate = value;
    markNeedsLayout();
    // }
  }

  void markNeedsRecalculation() {
    _needsFullRecalculation = false;
    _isInitialized = false;
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _nodeAnimationController.addListener(_onAnimationTick);
    for (final child in _children.values) {
      child.attach(owner);
    }
    for (final child in _edgeLabels.values) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    _nodeAnimationController.removeListener(_onAnimationTick);
    super.detach();
    for (final child in _children.values) {
      child.detach();
    }
    for (final child in _edgeLabels.values) {
      child.detach();
    }
  }

  void forceRecalculation() {
    _needsFullRecalculation = true;
    _isInitialized = false;
    markNeedsLayout();
  }

  Paint get edgePaint => _paint;

  set edgePaint(Paint? value) {
    final newPaint = value ??
        (Paint()
          ..color = Colors.black
          ..strokeWidth = 3)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    _paint = newPaint;
    markNeedsPaint();
  }

  set edgeLabelBuilder(EdgeWidgetBuilder? value) {
    if (_edgeLabelBuilder == value) {
      return;
    }
    _edgeLabelBuilder = value;
    markNeedsLayout();
  }

  AnimationController get nodeAnimationController => _nodeAnimationController;

  set nodeAnimationController(AnimationController value) {
    if (identical(_nodeAnimationController, value)) return;
    _nodeAnimationController.removeListener(_onAnimationTick);
    _nodeAnimationController = value;
    _nodeAnimationController.addListener(_onAnimationTick);
    markNeedsLayout();
  }

  void _onAnimationTick() {
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_children.isEmpty && _edgeLabels.isEmpty) return;

    algorithm.renderer?.setHasEdgeLabelBuilder(_edgeLabelBuilder != null);

    if (enableAnimation) {
      final t = _nodeAnimationController.value;
      animatedPositions.clear();

      for (final entry in _children.entries) {
        final node = entry.key;
        final child = entry.value;
        final nodeData = child.parentData as NodeBoxData;
        final pos =
            Offset.lerp(nodeData.startOffset, nodeData.targetOffset, t)!;
        animatedPositions[node] = pos;
      }

      context.canvas.save();
      context.canvas.translate(offset.dx, offset.dy);
      algorithm.renderer?.setAnimatedPositions(animatedPositions);

      final collapsingEdges =
          _delegate.controller?.getCollapsingEdges(graph).toSet() ?? {};
      final expandingEdges =
          _delegate.controller?.getExpandingEdges(graph).toSet() ?? {};

      for (final edge in graph.edges) {
        var edgePaintWithOpacity = Paint.from(edge.paint ?? edgePaint);

        // Apply fade effect for collapsing edges (fade out)
        if (collapsingEdges.contains(edge)) {
          edgePaintWithOpacity.color =
              edgePaint.color.withValues(alpha: 1.0 - t);
        }
        // Apply fade effect for expanding edges (fade in)
        else if (expandingEdges.contains(edge)) {
          edgePaintWithOpacity.color = edgePaint.color.withValues(alpha: t);
        }

        algorithm.renderer?.renderEdge(
          context.canvas,
          edge,
          edgePaintWithOpacity,
        );
      }

      context.canvas.restore();

      _paintEdgeLabels(
        context,
        offset,
        collapsingEdges: collapsingEdges,
        expandingEdges: expandingEdges,
        t: t,
      );

      _paintNodes(context, offset, t);
    } else {
      context.canvas.save();
      context.canvas.translate(offset.dx, offset.dy);
      graph.edges.forEach((edge) {
        algorithm.renderer?.renderEdge(context.canvas, edge, edgePaint);
      });
      context.canvas.restore();

      _paintEdgeLabels(
        context,
        offset,
        collapsingEdges: const <Edge>{},
        expandingEdges: const <Edge>{},
        t: 1.0,
      );

      for (final entry in _children.entries) {
        final node = entry.key;
        final child = entry.value;

        if (_delegate.isNodeVisible(node)) {
          context.paintChild(child, offset + node.position);
        }
      }
    }
  }

  @override
  void performLayout() {
    _activeChildrenForLayoutPass.clear();
    childManager!.startLayout();

    final looseConstraints = BoxConstraints.loose(constraints.biggest);

    if (_needsFullRecalculation || !_isInitialized) {
      _layoutNodesLazily(looseConstraints);
      _cachedSize = _delegate.runAlgorithm();
      _isInitialized = true;
      _needsFullRecalculation = false;
    }

    size = _cachedSize ?? Size.zero;

    _layoutEdgeLabels(looseConstraints);

    invokeLayoutCallback<BoxConstraints>((BoxConstraints _) {
      childManager!.endLayout();
    });

    if (enableAnimation) {
      _updateAnimationStates();
    } else {
      _updateNodePositions();
    }
  }

  void _paintEdgeLabels(
    PaintingContext context,
    Offset offset, {
    required Set<Edge> collapsingEdges,
    required Set<Edge> expandingEdges,
    required double t,
  }) {
    if (_edgeLabels.isEmpty || _edgeLabelBuilder == null) {
      return;
    }

    for (final entry in _edgeLabels.entries) {
      final edge = entry.key;
      final child = entry.value;
      final data = child.parentData as EdgeBoxData;

      final sourceVisible = _delegate.isNodeVisible(edge.source);
      final destinationVisible = _delegate.isNodeVisible(edge.destination);
      final shouldPaint = (sourceVisible && destinationVisible) ||
          collapsingEdges.contains(edge) ||
          expandingEdges.contains(edge);

      if (!shouldPaint) {
        continue;
      }

      Offset paintOffset;
      if (enableAnimation) {
        paintOffset =
            _edgeLabelOffsetFor(edge, child, positions: animatedPositions);
      } else {
        paintOffset = data.offset;
      }

      int alpha = 255;
      if (enableAnimation) {
        if (collapsingEdges.contains(edge)) {
          alpha = max(0, min(255, ((1.0 - t) * 255).round()));
        } else if (expandingEdges.contains(edge)) {
          alpha = max(0, min(255, (t * 255).round()));
        }
      }

      if (alpha == 0) {
        continue;
      }

      final paintPosition = offset + paintOffset;

      if (alpha != 255) {
        context.pushOpacity(paintPosition, alpha, (context, innerOffset) {
          context.paintChild(child, innerOffset);
        });
      } else {
        context.paintChild(child, paintPosition);
      }

      if (!enableAnimation || _nodeAnimationController.isCompleted) {
        final target = data.targetOffset ?? paintOffset;
        data.offset = target;
        data.startOffset = target;
      }
    }
  }

  void _paintNodes(PaintingContext context, Offset offset, double t) {
    for (final entry in _children.entries) {
      final node = entry.key;
      final child = entry.value;
      final nodeData = child.parentData as NodeBoxData;
      final pos = animatedPositions[node]!;

      final isVisible = _delegate.isNodeVisible(node);
      if (isVisible) {
        final isExpanding =
            _delegate.controller?.isNodeExpanding(node) ?? false;
        if (_nodeAnimationController.isAnimating && isExpanding) {
          _paintExpandingNode(context, child, offset, pos, t);
        } else {
          context.paintChild(child, offset + pos);
        }
      } else {
        if (_nodeAnimationController.isAnimating &&
            nodeData.startOffset != nodeData.targetOffset) {
          _paintCollapsingNode(context, child, offset, pos, t);
        } else if (_nodeAnimationController.isCompleted) {
          nodeData.startOffset = nodeData.targetOffset;
        }
      }

      if (_nodeAnimationController.isCompleted) {
        nodeData.offset = node.position;
      }
    }

    if (_nodeAnimationController.isCompleted) {
      _delegate.controller?.removeCollapsingNodes();
    }
  }

  void _paintExpandingNode(PaintingContext context, RenderBox child,
      Offset offset, Offset pos, double t) {
    final center =
        pos + offset + Offset(child.size.width * 0.5, child.size.height * 0.5);

    context.canvas.save();

    // Apply scaling from center
    context.canvas.translate(center.dx, center.dy);
    context.canvas.scale(t, t);
    context.canvas.translate(-center.dx, -center.dy);

    // Paint with opacity using saveLayer
    opacityPaint
      ..color = Color.fromRGBO(255, 255, 255, t)
      ..colorFilter = ColorFilter.mode(
          Colors.white.withValues(alpha: t), BlendMode.modulate);

    context.canvas.saveLayer(
        Rect.fromLTWH(pos.dx + offset.dx - 20, pos.dy + offset.dy - 20,
            child.size.width + 40, child.size.height + 40),
        opacityPaint);

    context.paintChild(child, offset + pos);

    context.canvas.restore(); // Restore saveLayer
    context.canvas.restore(); // Restore main save
  }

  void _paintCollapsingNode(PaintingContext context, RenderBox child,
      Offset offset, Offset pos, double t) {
    final progress = (1.0 - t);
    final center =
        pos + offset + Offset(child.size.width * 0.5, child.size.height * 0.5);

    context.canvas.save();

    // Apply scaling from center
    context.canvas.translate(center.dx, center.dy);
    context.canvas.scale(progress, progress);
    context.canvas.translate(-center.dx, -center.dy);

    // Paint with opacity using saveLayer
    opacityPaint
      ..color = Color.fromRGBO(255, 255, 255, progress)
      ..colorFilter = ColorFilter.mode(
          Colors.white.withValues(alpha: progress), BlendMode.modulate);

    context.canvas.saveLayer(
        Rect.fromLTWH(pos.dx + offset.dx - 20, pos.dy + offset.dy - 20,
            child.size.width + 40, child.size.height + 40),
        opacityPaint);

    context.paintChild(child, offset + pos);

    context.canvas.restore(); // Restore saveLayer
    context.canvas.restore(); // Restore main save
  }

  void _updateNodePositions() {
    for (final entry in _children.entries) {
      final node = entry.key;
      final child = entry.value;
      final nodeData = child.parentData as NodeBoxData;

      if (_delegate.isNodeVisible(node)) {
        nodeData.offset = node.position;
      } else {
        final parent = delegate.findClosestVisibleAncestor(node);
        nodeData.offset = parent?.position ?? node.position;
      }
    }
  }

  void _layoutNodesLazily(BoxConstraints constraints) {
    for (final node in graph.nodes) {
      final child = buildOrObtainChildFor(node);
      if (child != null) {
        child.layout(constraints, parentUsesSize: true);
        node.size = Size(child.size.width.ceilToDouble(), child.size.height);
      }
    }
  }

  void _layoutEdgeLabels(BoxConstraints constraints) {
    algorithm.renderer?.setHasEdgeLabelBuilder(_edgeLabelBuilder != null);

    if (_edgeLabelBuilder == null) {
      return;
    }

    for (final edge in graph.edges) {
      final child = buildOrObtainEdgeLabel(edge);
      if (child == null) {
        continue;
      }

      child.layout(constraints, parentUsesSize: true);
      final data = child.parentData as EdgeBoxData;
      final newOffset = _edgeLabelOffsetFor(edge, child);
      final previousTarget = data.targetOffset;

      if (previousTarget == null) {
        data.startOffset = newOffset;
      } else if (previousTarget != newOffset) {
        data.startOffset = previousTarget;
      }

      data.targetOffset = newOffset;

      if (!enableAnimation) {
        data.offset = newOffset;
      } else if (data.startOffset == null) {
        data.startOffset = newOffset;
      }
    }
  }

  Offset _edgeLabelOffsetFor(Edge edge, RenderBox child,
      {Map<Node, Offset>? positions}) {
    final renderer = algorithm.renderer;
    Offset? position = renderer?.getLabelPosition(edge);

    if (position == null) {
      Offset sourcePosition = positions?[edge.source] ?? edge.source.position;
      Offset destinationPosition =
          positions?[edge.destination] ?? edge.destination.position;

      final sourceCenter = Offset(
        sourcePosition.dx + edge.source.width * 0.5,
        sourcePosition.dy + edge.source.height * 0.5,
      );
      final destinationCenter = Offset(
        destinationPosition.dx + edge.destination.width * 0.5,
        destinationPosition.dy + edge.destination.height * 0.5,
      );

      final t = edge.labelPosition;
      position = Offset(
        sourceCenter.dx + (destinationCenter.dx - sourceCenter.dx) * t,
        sourceCenter.dy + (destinationCenter.dy - sourceCenter.dy) * t,
      );
    }

    position ??= Offset.zero;

    final adjustedCenter = position + edge.labelOffset;

    return adjustedCenter -
        Offset(child.size.width * 0.5, child.size.height * 0.5);
  }

  void _updateAnimationStates() {
    for (final entry in _children.entries) {
      final node = entry.key;
      final child = entry.value;
      final nodeData = child.parentData as NodeBoxData;
      final isVisible = _delegate.isNodeVisible(node);

      if (isVisible) {
        _updateVisibleNodeAnimation(nodeData, node);
      } else {
        _updateCollapsedNodeAnimation(nodeData, node);
      }
    }

    _nodeAnimationController.reset();
    _nodeAnimationController.forward();
  }

  void _updateVisibleNodeAnimation(NodeBoxData nodeData, Node graphNode) {
    final prevTarget = nodeData.targetOffset;
    var newPos = graphNode.position;

    if (prevTarget == null) {
      final parent = graph.predecessorsOf(graphNode).firstOrNull;
      final pastParentPosition = animatedPositions[parent];
      nodeData.startOffset = pastParentPosition ?? parent?.position ?? newPos;
      nodeData.targetOffset = newPos;
    } else if (prevTarget != newPos) {
      nodeData.startOffset = prevTarget;
      nodeData.targetOffset = newPos;
    } else {
      nodeData.startOffset = newPos;
      nodeData.targetOffset = newPos;
    }
  }

  void _updateCollapsedNodeAnimation(NodeBoxData nodeData, Node graphNode) {
    final parent = delegate.findClosestVisibleAncestor(graphNode);
    final parentPos = parent?.position ?? Offset.zero;

    final prevTarget = nodeData.targetOffset;

    if (nodeData.startOffset == nodeData.targetOffset) {
      nodeData.targetOffset = parentPos;
    } else if (prevTarget != null && prevTarget != parentPos) {
      // Just collapsed now → animate toward parent
      nodeData.startOffset = graphNode.position;
      nodeData.targetOffset = parentPos;
    } else {
      // animation finished → lock to parent
      nodeData.startOffset = parentPos;
      nodeData.targetOffset = parentPos;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (enableAnimation && !_nodeAnimationController.isCompleted) return false;

    for (final entry in _children.entries) {
      final node = entry.key;

      if (delegate.isNodeVisible(node)) {
        final child = entry.value;

        final childParentData = child.parentData as BoxParentData;
        final isHit = result.addWithPaintOffset(
          offset: childParentData.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) {
            return child.hitTest(result, position: transformed);
          },
        );
        if (isHit) return true;
      }
    }

    for (final entry in _edgeLabels.entries) {
      final edge = entry.key;
      final child = entry.value;
      final edgeData = child.parentData as EdgeBoxData;

      if (!_delegate.isNodeVisible(edge.source) ||
          !_delegate.isNodeVisible(edge.destination)) {
        continue;
      }

      final isHit = result.addWithPaintOffset(
        offset: edgeData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          return child.hitTest(result, position: transformed);
        },
      );
      if (isHit) return true;
    }
    return false;
  }

  @override
  void setupParentData(RenderBox child) {
    if (_edgeLabels.containsValue(child)) {
      if (child.parentData is! EdgeBoxData) {
        child.parentData = EdgeBoxData();
      }
      return;
    }
    if (child.parentData is! NodeBoxData) {
      child.parentData = NodeBoxData();
    }
  }

  // ---- Called from GraphViewElement ----
  void _insertChild(RenderBox child, Node slot) {
    _children[slot] = child;
    adoptChild(child);
  }

  void _moveChild(RenderBox child, {required Node from, required Node to}) {
    if (_children[from] == child) {
      _children.remove(from);
    }
    _children[to] = child;
  }

  void _removeChild(RenderBox child, Node slot) {
    if (_children[slot] == child) {
      _children.remove(slot);
    }
    dropChild(child);
  }

  void _insertEdgeLabel(RenderBox child, Edge slot) {
    _edgeLabels[slot] = child;
    adoptChild(child);
  }

  void _moveEdgeLabel(RenderBox child, {required Edge from, required Edge to}) {
    if (_edgeLabels[from] == child) {
      _edgeLabels.remove(from);
    }
    _edgeLabels[to] = child;
  }

  void _removeEdgeLabel(RenderBox child, Edge slot) {
    if (_edgeLabels[slot] == child) {
      _edgeLabels.remove(slot);
    }
    dropChild(child);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    for (final child in _children.values) {
      visitor(child);
    }
    for (final child in _edgeLabels.values) {
      visitor(child);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Graph>('graph', graph));
    properties.add(DiagnosticsProperty<Algorithm>('algorithm', algorithm));
    properties.add(DiagnosticsProperty<Paint>('paint', edgePaint));
  }
}

class NodeBoxData extends ContainerBoxParentData<RenderBox> {
  Offset? startOffset;
  Offset? targetOffset;
}

class EdgeBoxData extends BoxParentData {
  Offset? startOffset;
  Offset? targetOffset;
}

class GraphViewCustomPainter extends StatefulWidget {
  final Graph graph;
  final FruchtermanReingoldAlgorithm algorithm;
  final Paint? paint;
  final NodeWidgetBuilder builder;
  final stepMilis = 25;

  GraphViewCustomPainter({
    Key? key,
    required this.graph,
    required this.algorithm,
    this.paint,
    required this.builder,
  }) : super(key: key);

  @override
  _GraphViewCustomPainterState createState() => _GraphViewCustomPainterState();
}

class _GraphViewCustomPainterState extends State<GraphViewCustomPainter> {
  late Timer timer;
  late Graph graph;
  late FruchtermanReingoldAlgorithm algorithm;

  @override
  void initState() {
    graph = widget.graph;

    algorithm = widget.algorithm;
    algorithm.init(graph);
    startTimer();

    super.initState();
  }

  void startTimer() {
    timer = Timer.periodic(Duration(milliseconds: widget.stepMilis), (timer) {
      algorithm.step(graph);
      update();
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    algorithm.setDimensions(
        MediaQuery.of(context).size.width, MediaQuery.of(context).size.height);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: MediaQuery.of(context).size,
          painter: EdgeRender(algorithm, graph, Offset(20, 20), widget.paint),
        ),
        ...List<Widget>.generate(graph.nodeCount(), (index) {
          return Positioned(
            child: GestureDetector(
              child: (graph
                      .nodes[index]
                      // ignore: deprecated_member_use_from_same_package
                      .data) ??
                  widget.builder(graph.nodes[index]),
              onPanUpdate: (details) {
                graph.getNodeAtPosition(index).position += details.delta;
                update();
              },
            ),
            top: graph.getNodeAtPosition(index).position.dy,
            left: graph.getNodeAtPosition(index).position.dx,
          );
        }),
      ],
    );
  }

  Future<void> update() async {
    setState(() {});
  }
}

class EdgeRender extends CustomPainter {
  Algorithm algorithm;
  Graph graph;
  Offset offset;
  Paint? customPaint;

  EdgeRender(this.algorithm, this.graph, this.offset, this.customPaint);

  @override
  void paint(Canvas canvas, Size size) {
    var edgePaint = customPaint ??
        (Paint()
          ..color = Colors.black
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    for (var value in graph.edges) {
      algorithm.renderer?.renderEdge(canvas, value, edgePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
