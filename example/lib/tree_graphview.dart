import 'dart:math';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class TreeViewPage extends StatefulWidget {
  @override
  _TreeViewPageState createState() => _TreeViewPageState();
}

class _TreeViewPageState extends State<TreeViewPage> with TickerProviderStateMixin {
  final GraphViewController _controller = GraphViewController();
  final Random r = Random();
  int nextNodeId = 1;
  bool _useEditableLabels = true;
  String? _lastEditedLabelSummary;

  EdgeWidgetBuilder? get _editableEdgeBuilder =>
      _useEditableLabels ? _buildEditableEdgeLabel : null;

  Widget _buildEditableEdgeLabel(
    Edge edge,
    EdgeLabelBuilderParams params,
  ) {
    final textStyle = edge.labelStyle ??
        const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.indigo,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 14, color: Colors.indigo),
            const SizedBox(width: 6),
            // Tapping the chip enters edit mode; EditableEdgeLabel updates the
            // edge text and forces a layout recalculation for us.
            EditableEdgeLabel(
              edge: edge,
              graph: params.graph,
              graphViewController: params.graphViewController,
              onChanged: (value) {
                params.onChanged(value);
              },
              onSubmitted: (value) {
                params.onSubmitted(value);
                setState(() {
                  _lastEditedLabelSummary =
                      '${_formatEdgeName(edge)} → "${value.trim().isEmpty ? 'sem rótulo' : value}"';
                });
              },
              placeholder: 'Toque para editar',
              textStyle: textStyle,
              placeholderStyle: textStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEdgeName(Edge edge) {
    final source = edge.source.key?.value ?? '?';
    final target = edge.destination.key?.value ?? '?';
    return '$source → $target';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Tree View'),
        ),
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Configuration controls
            Wrap(
              children: [
                Container(
                  width: 100,
                  child: TextFormField(
                    initialValue: builder.siblingSeparation.toString(),
                    decoration: InputDecoration(labelText: 'Sibling Separation'),
                    onChanged: (text) {
                      builder.siblingSeparation = int.tryParse(text) ?? 100;
                      this.setState(() {});
                    },
                  ),
                ),
                Container(
                  width: 100,
                  child: TextFormField(
                    initialValue: builder.levelSeparation.toString(),
                    decoration: InputDecoration(labelText: 'Level Separation'),
                    onChanged: (text) {
                      builder.levelSeparation = int.tryParse(text) ?? 100;
                      this.setState(() {});
                    },
                  ),
                ),
                Container(
                  width: 100,
                  child: TextFormField(
                    initialValue: builder.subtreeSeparation.toString(),
                    decoration: InputDecoration(labelText: 'Subtree separation'),
                    onChanged: (text) {
                      builder.subtreeSeparation = int.tryParse(text) ?? 100;
                      this.setState(() {});
                    },
                  ),
                ),
                Container(
                  width: 100,
                  child: TextFormField(
                    initialValue: builder.orientation.toString(),
                    decoration: InputDecoration(labelText: 'Orientation'),
                    onChanged: (text) {
                      builder.orientation = int.tryParse(text) ?? 100;
                      this.setState(() {});
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final node12 = Node.Id(r.nextInt(100));
                    var edge = graph.getNodeAtPosition(r.nextInt(graph.nodeCount()));
                    print(edge);
                    graph.addEdge(edge, node12);
                    setState(() {});
                  },
                  child: Text('Add'),
                ),
                ElevatedButton(
                  onPressed: _navigateToRandomNode,
                  child: Text('Go to Node $nextNodeId'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resetView,
                  child: Text('Reset View'),
                ),
                SizedBox(width: 8,),
                ElevatedButton(onPressed: (){
                  _controller.zoomToFit();
                }, child: Text('Zoom to fit'))
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Switch(
                    value: _useEditableLabels,
                    onChanged: (value) {
                      setState(() {
                        _useEditableLabels = value;
                      });
                      // Forcing a recalculation ensures the layout is updated
                      // when we swap between painted labels and editable widgets.
                      _controller.forceRecalculation();
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Usar rótulos de aresta editáveis (toque no chip do rótulo para editar).',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (_lastEditedLabelSummary != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Última alteração: $_lastEditedLabelSummary',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.indigo.shade700),
                ),
              ),

            Expanded(
              child: GraphView.builder(
                controller: _controller,
                graph: graph,
                algorithm: algorithm,
                paint: Paint()
                  ..color = Colors.blueGrey.shade200
                  ..strokeWidth = 1.2,
                // When `_useEditableLabels` is true we provide the edgeBuilder so
                // every connection renders an editable chip instead of static text.
                edgeBuilder: _editableEdgeBuilder,
                initialNode: ValueKey(1),
                panAnimationDuration: Duration(milliseconds: 600),
                toggleAnimationDuration: Duration(milliseconds: 600),
                centerGraph: true,
                builder: (Node node) => GestureDetector(
                  onTap: () => _toggleCollapse(node),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: Colors.blue[100]!, spreadRadius: 1)],
                    ),
                    child: Text(
                      'Node ${node.key?.value}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
  }

  final Graph graph = Graph()..isTree = true;
  BuchheimWalkerConfiguration builder = BuchheimWalkerConfiguration();
  late final algorithm = BuchheimWalkerAlgorithm(builder, TreeEdgeRenderer(builder));

  void _toggleCollapse(Node node) {
    _controller.toggleNodeExpanded(graph, node, animate: true);
  }

  void _navigateToRandomNode() {
    if (graph.nodes.isEmpty) return;

    final randomNode = graph.nodes.firstWhere(
      (node) => node.key != null && node.key!.value == nextNodeId,
      orElse: () => graph.nodes.first,
    );
    final nodeId = randomNode.key!;
    _controller.animateToNode(nodeId);

    setState(() {
      // nextNodeId = r.nextInt(graph.nodes.length) + 1;
    });
  }

  void _resetView() {
    _controller.animateToNode(ValueKey(1));
  }

  @override
  void initState() {
    super.initState();



// Create all nodes
    final root = Node.Id(1);  // Central topic

// Left side - Technology branch (will be large)
    final tech = Node.Id(2);
    final ai = Node.Id(3);
    final web = Node.Id(4);
    final mobile = Node.Id(5);
    final aiSubtopics = [
      Node.Id(6),   // Machine Learning
      Node.Id(7),   // Deep Learning
      Node.Id(8),   // NLP
      Node.Id(9),   // Computer Vision
    ];
    final webSubtopics = [
      Node.Id(10),  // Frontend
      Node.Id(11),  // Backend
      Node.Id(12),  // DevOps
    ];
    final frontendDetails = [
      Node.Id(13),  // React
      Node.Id(14),  // Vue
      Node.Id(15),  // Angular
    ];
    final backendDetails = [
      Node.Id(16),  // Node.js
      Node.Id(17),  // Python
      Node.Id(18),  // Java
      Node.Id(19),  // Go
    ];

// Right side - Business branch (will be smaller to test balancing)
    final business = Node.Id(20);
    final marketing = Node.Id(21);
    final sales = Node.Id(22);
    final finance = Node.Id(23);
    final marketingDetails = [
      Node.Id(24),  // Digital Marketing
      Node.Id(25),  // Content Strategy
    ];
    final salesDetails = [
      Node.Id(26),  // B2B Sales
      Node.Id(27),  // Customer Success
    ];

// Additional right side - Personal branch
    final personal = Node.Id(28);
    final health = Node.Id(29);
    final hobbies = Node.Id(30);
    final healthDetails = [
      Node.Id(31),  // Exercise
      Node.Id(32),  // Nutrition
      Node.Id(33),  // Mental Health
    ];
    final exerciseDetails = [
      Node.Id(34),  // Cardio
      Node.Id(35),  // Strength Training
      Node.Id(36),  // Yoga
    ];

    // Build the graph structure
    final labelStyle = const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: Colors.indigo,
    );

    graph.addEdge(root, tech,
        label: 'Estratégia técnica',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -18));
    graph.addEdge(root, business,
        paint: Paint()..color = Colors.blue,
        label: 'Iniciativas de negócio',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -18));
    graph.addEdge(root, personal,
        paint: Paint()..color = Colors.green,
        label: 'Bem-estar da equipe',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -18));

// // Technology branch (left side - large subtree)
    graph.addEdge(tech, ai,
        label: 'IA', labelStyle: labelStyle, labelOffset: const Offset(0, -16));
    graph.addEdge(tech, web,
        label: 'Web', labelStyle: labelStyle, labelOffset: const Offset(0, -16));
    graph.addEdge(tech, mobile,
        label: 'Mobile',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -16));

// AI subtree
    for (final aiNode in aiSubtopics) {
      graph.addEdge(ai, aiNode,
          paint: Paint()..color = Colors.purple,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -14));
    }

// Web subtree with deep nesting
    for (final webNode in webSubtopics) {
      graph.addEdge(web, webNode,
          paint: Paint()..color = Colors.orange,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -14));
    }

// Frontend details (3rd level)
    for (final frontendNode in frontendDetails) {
      graph.addEdge(webSubtopics[0], frontendNode,
          paint: Paint()..color = Colors.cyan,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -12));
    }

// Backend details (3rd level) - even deeper
    for (final backendNode in backendDetails) {
      graph.addEdge(webSubtopics[1], backendNode,
          paint: Paint()..color = Colors.teal,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -12));
    }

// Business branch (right side - smaller subtree)
    graph.addEdge(business, marketing,
        label: 'Marketing',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -16));
    graph.addEdge(business, sales,
        label: 'Vendas',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -16));
    graph.addEdge(business, finance,
        label: 'Finanças',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -16));

// Marketing details
    for (final marketingNode in marketingDetails) {
      graph.addEdge(marketing, marketingNode,
          paint: Paint()..color = Colors.red,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -12));
    }

// Sales details
    for (final salesNode in salesDetails) {
      graph.addEdge(sales, salesNode,
          paint: Paint()..color = Colors.indigo,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -12));
    }

// Personal branch (right side - medium subtree)
    graph.addEdge(personal, health,
        label: 'Saúde',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -16));
    graph.addEdge(personal, hobbies,
        label: 'Hobbies',
        labelStyle: labelStyle,
        labelOffset: const Offset(0, -16));

// Health details
    for (final healthNode in healthDetails) {
      graph.addEdge(health, healthNode,
          paint: Paint()..color = Colors.lightGreen,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -12));
    }

// Exercise details (3rd level)
    for (final exerciseNode in exerciseDetails) {
      graph.addEdge(healthDetails[0], exerciseNode,
          paint: Paint()..color = Colors.amber,
          labelStyle: labelStyle,
          labelOffset: const Offset(0, -12));
    }
    _controller.setInitiallyCollapsedNodes(graph, [tech, business, personal]);

    builder
      ..siblingSeparation = (100)
      ..levelSeparation = (150)
      ..subtreeSeparation = (150)
      ..useCurvedConnections = true
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }

}