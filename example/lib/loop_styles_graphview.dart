import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class LoopStylesGraphViewPage extends StatefulWidget {
  const LoopStylesGraphViewPage({super.key});

  @override
  State<LoopStylesGraphViewPage> createState() => _LoopStylesGraphViewPageState();
}

class _LoopStylesGraphViewPageState extends State<LoopStylesGraphViewPage> {
  final Graph _graph = Graph()..isTree = false;
  late final SugiyamaAlgorithm _algorithm;
  late final SugiyamaConfiguration _configuration;

  @override
  void initState() {
    super.initState();
    _configuration = SugiyamaConfiguration()
      ..nodeSeparation = 140
      ..levelSeparation = 80
      ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT;
    _algorithm = SugiyamaAlgorithm(_configuration);
    _buildAutomaton();
  }

  void _buildAutomaton() {
    final start = Node.Id('start');
    final state = Node.Id('q0');

    _graph.addNode(start);
    _graph.addNode(state);

    _graph.addEdge(
      start,
      state,
      paint: Paint()
        ..color = const Color(0xFF454E66)
        ..strokeWidth = 2.4,
    );

    _graph.addEdge(
      state,
      state,
      loopStyle: const LoopEdgeStyle.jflap(),
      paint: Paint()
        ..color = const Color(0xFF454E66)
        ..strokeWidth = 2.4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F4F8),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'FSA',
              style: TextStyle(
                color: Color(0xFF454E66),
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Finite State Automata',
              style: TextStyle(
                color: Color(0xFF7E88A5),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF454E66)),
            tooltip: 'Simulate',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF454E66)),
            tooltip: 'Add state',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 420,
                height: 420,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A1F2937),
                      blurRadius: 24,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(120),
                      minScale: 0.6,
                      maxScale: 2.4,
                      child: GraphView(
                        graph: _graph,
                        algorithm: _algorithm,
                        paint: Paint()
                          ..color = const Color(0xFF454E66)
                          ..strokeWidth = 2.4
                          ..style = PaintingStyle.stroke,
                        builder: (Node node) => _buildNodeWidget(node.key?.value),
                        edgePaintBuilder: (edge) => (edge.paint ?? Paint())
                          ..style = PaintingStyle.stroke,
                      ),
                    ),
                    Positioned(
                      right: 88,
                      top: 48,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E9F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ε',
                          style: TextStyle(
                            color: Color(0xFF454E66),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildNodeWidget(dynamic label) {
    if (label == 'start') {
      return _buildStartNode();
    }
    return _buildStateNode(label?.toString() ?? '');
  }

  Widget _buildStartNode() {
    return const SizedBox(
      width: 64,
      height: 64,
      child: _TriangleNode(),
    );
  }

  Widget _buildStateNode(String label) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3A6),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF454E66),
          width: 2.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1F2937),
            blurRadius: 12,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF454E66),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _toolbarButton(Icons.error_outline, 'No accepting states'),
          _toolbarButton(Icons.settings_suggest_outlined, 'Nondeterministic'),
          _toolbarButton(Icons.flash_on_outlined, 'λ-transitions'),
          _toolbarButton(Icons.circle_outlined, '1 state'),
          _toolbarButton(Icons.linear_scale, '1 transition'),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF7E88A5), size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7E88A5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _TriangleNode extends StatelessWidget {
  const _TriangleNode();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrianglePainter(),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF454E66)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    final path = Path()
      ..moveTo(size.width, size.height * 0.5)
      ..lineTo(0, 0)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
