import 'dart:math';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class GraphClusterViewPage extends StatefulWidget {
  @override
  _GraphClusterViewPageState createState() => _GraphClusterViewPageState();
}

class _GraphClusterViewPageState extends State<GraphClusterViewPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: EdgeInsets.all(8),
              minScale: 0.001,
              maxScale: 10000,
              child: GraphViewCustomPainter(
                graph: graph,
                algorithm: algorithm,
                paint: Paint()
                  ..color = Colors.green
                  ..strokeWidth = 1
                  ..style = PaintingStyle.fill,
                builder: (Node node) {
                  // I can decide what widget should be shown here based on the id
                  var a = node.key!.value as int?;
                  if (a == 2) {
                    return rectangWidget(a);
                  }
                  return rectangWidget(a);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  int n = 8;
  Random r = Random();

  Widget rectangWidget(int? i) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: Colors.blue, spreadRadius: 1)],
      ),
      child: Text('Node $i'),
    );
  }

  final Graph graph = Graph();
  late FruchtermanReingoldAlgorithm algorithm;

  @override
  void initState() {
    super.initState();

    final a = Node.Id(1);
    final b = Node.Id(2);
    final c = Node.Id(3);
    final d = Node.Id(4);
    final e = Node.Id(5);
    final f = Node.Id(6);
    final g = Node.Id(7);
    final h = Node.Id(8);

    graph.addEdge(
      a,
      b,
      paint: Paint()..color = Colors.red,
      label: 'critical',
      labelStyle: TextStyle(
        color: Colors.red.shade700,
        fontWeight: FontWeight.bold,
      ),
      labelOffset: Offset(0, -18),
    );
    graph.addEdge(
      a,
      c,
      label: 'A→C',
      labelStyle: TextStyle(color: Colors.blueGrey.shade700),
      labelPosition: 0.25,
      labelOffset: Offset(0, -14),
    );
    graph.addEdge(
      a,
      d,
      label: 'A→D',
      labelOffset: Offset(0, 14),
      labelStyle: TextStyle(color: Colors.black87),
    );
    graph.addEdge(
      c,
      e,
      label: 'metrics',
      labelStyle: TextStyle(fontSize: 10, color: Colors.teal.shade700),
      labelOffset: Offset(-12, 0),
    );
    graph.addEdge(
      d,
      f,
      label: 'handoff',
      labelStyle: TextStyle(fontSize: 10, color: Colors.deepPurple),
      labelOffset: Offset(12, 0),
    );
    graph.addEdge(
      f,
      c,
      label: 'feedback',
      labelPosition: 0.7,
      labelStyle: TextStyle(color: Colors.indigo),
      labelOffset: Offset(0, 16),
    );
    graph.addEdge(g, c, label: 'support', labelOffset: Offset(-18, 0));
    graph.addEdge(
      h,
      g,
      label: 'sync',
      labelStyle: TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.grey.shade700,
      ),
    );
    var config = FruchtermanReingoldConfiguration()..iterations = 1000;
    algorithm = FruchtermanReingoldAlgorithm(config);
  }
}
