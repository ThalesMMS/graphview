part of graphview;

class Graph {
  final List<Node> _nodes = [];
  final Set<Node> _nodeSet = {};
  final List<Edge> _edges = [];
  List<GraphObserver> graphObserver = [];

  // Generation counter for tracking mutations
  int _generation = 0;
  int get generation => _generation;

  // Cache
  final Map<Node, List<Node>> _successorCache = {};
  final Map<Node, List<Node>> _predecessorCache = {};
  bool _cacheValid = false;

  List<Node> get nodes => _nodes;

  List<Edge> get edges => _edges;

  var isTree = false;

  int nodeCount() => _nodes.length;

  void addNode(Node node) {
    _nodes.add(node);
    _nodeSet.add(node);
    _cacheValid = false;
    _generation++;
    notifyGraphObserver();
  }

  void addNodes(List<Node> nodes) => nodes.forEach((it) => addNode(it));

  void removeNode(Node? node) {
    if (!_nodeSet.contains(node)) return;

    if (isTree) {
      successorsOf(node).forEach((element) => removeNode(element));
    }

    _nodes.remove(node);
    _nodeSet.remove(node);
    _edges
        .removeWhere((edge) => edge.source == node || edge.destination == node);
    _cacheValid = false;
    _generation++;
    notifyGraphObserver();
  }

  void removeNodes(List<Node> nodes) => nodes.forEach((it) => removeNode(it));

  Edge addEdge(Node source, Node destination, {Paint? paint, String? label, TextStyle? labelStyle, EdgeLabelPosition? labelPosition, bool? labelFollowsEdgeDirection, Widget? labelWidget, EdgeRenderer? renderer}) {
    final edge = Edge(source, destination, paint: paint, label: label, labelStyle: labelStyle, labelPosition: labelPosition, labelFollowsEdgeDirection: labelFollowsEdgeDirection, labelWidget: labelWidget, renderer: renderer);
    addEdgeS(edge);
    return edge;
  }

  void addEdgeS(Edge edge) {
    var sourceSet = false;
    var destinationSet = false;

    // Use Set lookup for O(1) existence check
    if (_nodeSet.contains(edge.source)) {
      edge.source = _nodes.firstWhere((node) => node == edge.source);
      sourceSet = true;
    }

    if (_nodeSet.contains(edge.destination)) {
      edge.destination = _nodes.firstWhere((node) => node == edge.destination);
      destinationSet = true;
    }

    if (!sourceSet) {
      _nodes.add(edge.source);
      _nodeSet.add(edge.source);
      sourceSet = true;
      if (!destinationSet && edge.destination == edge.source) {
        destinationSet = true;
      }
    }
    if (!destinationSet) {
      _nodes.add(edge.destination);
      _nodeSet.add(edge.destination);
      destinationSet = true;
    }

    if (!_edges.contains(edge)) {
      _edges.add(edge);
      _cacheValid = false;
      _generation++;
      notifyGraphObserver();
    }
  }

  void addEdges(List<Edge> edges) => edges.forEach((it) => addEdgeS(it));

  void removeEdge(Edge edge) {
    _edges.remove(edge);
    _cacheValid = false;
    _generation++;
  }

  void removeEdges(List<Edge> edges) => edges.forEach((it) => removeEdge(it));

  void removeEdgeFromPredecessor(Node? predecessor, Node? current) {
    _edges.removeWhere(
        (edge) => edge.source == predecessor && edge.destination == current);
    _cacheValid = false;
    _generation++;
  }

  // Called by algorithms after modifying node positions in-place
  void markModified() {
    _generation++;
  }

  bool hasNodes() => _nodes.isNotEmpty;

  Edge? getEdgeBetween(Node source, Node? destination) =>
      _edges.firstWhereOrNull((element) =>
          element.source == source && element.destination == destination);

  bool hasSuccessor(Node? node) => successorsOf(node).isNotEmpty;

  List<Node> successorsOf(Node? node) {
    if (node == null) return [];
    if (!_cacheValid) _buildCache();
    return _successorCache[node] ?? [];
  }

  bool hasPredecessor(Node node) => predecessorsOf(node).isNotEmpty;

  List<Node> predecessorsOf(Node? node) {
    if (node == null) return [];
    if (!_cacheValid) _buildCache();
    return _predecessorCache[node] ?? [];
  }

  void _buildCache() {
    _successorCache.clear();
    _predecessorCache.clear();

    for (var node in _nodes) {
      _successorCache[node] = [];
      _predecessorCache[node] = [];
    }

    for (var edge in _edges) {
      _successorCache[edge.source]!.add(edge.destination);
      _predecessorCache[edge.destination]!.add(edge.source);
    }

    _cacheValid = true;
  }

  bool contains({Node? node, Edge? edge}) =>
      node != null && _nodeSet.contains(node) ||
      edge != null && _edges.contains(edge);

  bool containsData(data) => _nodes.any((element) => element.data == data);

  Node getNodeAtPosition(int position) {
    if (position < 0) {
//            throw IllegalArgumentException("position can't be negative")
    }

    final size = _nodes.length;
    if (position >= size) {
//            throw IndexOutOfBoundsException("Position: $position, Size: $size")
    }

    return _nodes[position];
  }

  @Deprecated('Use Node.Id(id) constructor and getNodeUsingId(id) instead. See MIGRATION.md for details.')
  Node getNodeAtUsingData(Widget data) =>
      _nodes.firstWhere((element) => element.data == data);

  Node getNodeUsingKey(ValueKey key) =>
      _nodes.firstWhere((element) => element.key == key);

  Node getNodeUsingId(dynamic id) =>
      _nodes.firstWhere((element) => element.key == ValueKey(id));

  List<Edge> getOutEdges(Node node) =>
      _edges.where((element) => element.source == node).toList();

  List<Edge> getInEdges(Node node) =>
      _edges.where((element) => element.destination == node).toList();

  void notifyGraphObserver() => graphObserver.forEach((element) {
        element.notifyGraphInvalidated();
      });

  String toJson() {
    var jsonString = {
      'nodes': [..._nodes.map((e) => e.hashCode.toString())],
      'edges': [
        ..._edges.map((e) => {
              'from': e.source.hashCode.toString(),
              'to': e.destination.hashCode.toString()
            })
      ]
    };

    return json.encode(jsonString);
  }

}

extension GraphExtension on Graph {
  Rect calculateGraphBounds() {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    for (final node in nodes) {
        minX = min(minX, node.x);
        minY = min(minY, node.y);
        maxX = max(maxX, node.x + node.width);
        maxY = max(maxY, node.y + node.height);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Size calculateGraphSize() {
    final bounds = calculateGraphBounds();
    return bounds.size;
  }
}

enum LineType {
  Default,
  DottedLine,
  DashedLine,
  SineLine,
}

class Node {
  ValueKey? key;

  @Deprecated('Use Node.Id(id) constructor and GraphView.builder with builder pattern instead. See MIGRATION.md for details.')
  Widget? data;

  @Deprecated('Use Node.Id(id) constructor and GraphView.builder with builder pattern instead. See MIGRATION.md for details.')
  Node(this.data, {Key? key}) {
    this.key = ValueKey(key?.hashCode ?? data.hashCode);
  }

  Node.Id(dynamic id) {
    key = ValueKey(id);
  }

  Size size = Size(0, 0);

  Offset position = Offset(0, 0);

  LineType lineType = LineType.Default;

  bool locked = false;

  double get height => size.height;

  double get width => size.width;

  double get x => position.dx;

  double get y => position.dy;

  set y(double value) {
    position = Offset(position.dx, value);
  }

  set x(double value) {
    position = Offset(value, position.dy);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Node && hashCode == other.hashCode;

  @override
  int get hashCode {
    return key?.value.hashCode ?? key.hashCode;
  }

  @override
  String toString() {
    return 'Node{position: $position, key: $key, _size: $size, lineType: $lineType, locked: $locked}';
  }
}

/// Position of label along edge path
enum EdgeLabelPosition {
  /// Label at start of edge (20% along path)
  start,
  /// Label at middle of edge (50% along path)
  middle,
  /// Label at end of edge (80% along path)
  end,
}

class Edge {
  Node source;
  Node destination;

  Key? key;
  Paint? paint;

  // Label fields
  String? label;
  TextStyle? labelStyle;
  EdgeLabelPosition? labelPosition;
  bool? labelFollowsEdgeDirection;
  Widget? labelWidget;

  // Custom renderer
  EdgeRenderer? renderer;

  Edge(this.source, this.destination, {this.key, this.paint, this.label, this.labelStyle, this.labelPosition, this.labelFollowsEdgeDirection, this.labelWidget, this.renderer});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Edge) {
      return false;
    }

    // If either edge has an explicit key, key identity defines equality.
    if (key != null || other.key != null) {
      return key == other.key;
    }

    // Otherwise, compare structural edge identity.
    return source == other.source && destination == other.destination;
  }

  @override
  int get hashCode => key?.hashCode ?? Object.hash(source, destination);
}

abstract class GraphObserver {
  void notifyGraphInvalidated();
}
