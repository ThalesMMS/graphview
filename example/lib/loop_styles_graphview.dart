import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class LoopStylesGraphViewPage extends StatefulWidget {
  const LoopStylesGraphViewPage({super.key});

  @override
  State<LoopStylesGraphViewPage> createState() => _LoopStylesGraphViewPageState();
}

class _LoopStylesGraphViewPageState extends State<LoopStylesGraphViewPage> {
  final Graph _graph = Graph()..isTree = false;
  late final SugiyamaConfiguration _configuration;
  late final SugiyamaAlgorithm _algorithm;

  @override
  void initState() {
    super.initState();
    _configuration = SugiyamaConfiguration()
      ..nodeSeparation = 80
      ..levelSeparation = 120
      ..orientation = SugiyamaConfiguration.ORIENTATION_TOP_BOTTOM;
    _algorithm = SugiyamaAlgorithm(_configuration);
    _buildGraph();
  }

  void _buildGraph() {
    final center = Node.Id('Center');
    final top = Node.Id('Top loop');
    final right = Node.Id('Right loop');
    final bottom = Node.Id('Bottom loop');
    final left = Node.Id('Left loop');

    _graph.addNode(center);
    _graph.addNode(top);
    _graph.addNode(right);
    _graph.addNode(bottom);
    _graph.addNode(left);

    _graph.addEdge(center, top);
    _graph.addEdge(center, right);
    _graph.addEdge(center, bottom);
    _graph.addEdge(center, left);

    _graph.addEdge(
      top,
      top,
      loopStyle: const LoopEdgeStyle(
        orientation: LoopOrientation.topRight,
        radius: 48,
        tension: 0.7,
      ),
      paint: Paint()
        ..color = Colors.deepPurple
        ..strokeWidth = 2.4,
    );

    _graph.addEdge(
      right,
      right,
      loopStyle: const LoopEdgeStyle(
        orientation: LoopOrientation.bottomRight,
        radius: 56,
        tension: 0.55,
        offset: Offset(24, 0),
      ),
      paint: Paint()
        ..color = Colors.teal
        ..strokeWidth = 2.4,
    );

    _graph.addEdge(
      bottom,
      bottom,
      loopStyle: const LoopEdgeStyle(
        orientation: LoopOrientation.bottomLeft,
        radius: 40,
        tension: 0.4,
      ),
      paint: Paint()
        ..color = Colors.orange
        ..strokeWidth = 2.4,
    );

    _graph.addEdge(
      left,
      left,
      loopStyle: const LoopEdgeStyle(
        orientation: LoopOrientation.topLeft,
        radius: 64,
        tension: 0.8,
        offset: Offset(-16, -12),
      ),
      paint: Paint()
        ..color = Colors.indigo
        ..strokeWidth = 2.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loop edge styles'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Self loops now support orientation, radius, tension and offset. '
              'Adjust the style to create compact, circular or elongated loops.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(64),
              minScale: 0.2,
              maxScale: 4,
              child: GraphView(
                graph: _graph,
                algorithm: _algorithm,
                paint: Paint()
                  ..color = Colors.black
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: (Node node) {
                  return _buildNodeWidget(node.key?.value);
                },
                edgePaintBuilder: (edge) => (edge.paint ?? Paint())
                  ..style = PaintingStyle.stroke,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(dynamic label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$label',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
