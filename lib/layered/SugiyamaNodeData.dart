part of graphview;

class SugiyamaNodeData implements LayeredNodeData {
  @override
  Set<Node> reversed = {};
  @override
  bool isDummy = false;
  int median = -1;
  @override
  int layer = -1;
  int position = -1;
  List<Node> predecessorNodes = [];
  List<Node> successorNodes = [];
  LineType lineType;

  SugiyamaNodeData(this.lineType);

  @override
  bool get isReversed => reversed.isNotEmpty;

  @override
  String toString() {
    return 'SugiyamaNodeData{reversed: $reversed, isDummy: $isDummy, median: $median, layer: $layer, position: $position, lineType: $lineType}';
  }
}
