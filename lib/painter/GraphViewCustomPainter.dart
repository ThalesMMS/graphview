part of graphview;

class GraphViewCustomPainter extends StatefulWidget {
  final Graph graph;
  final FruchtermanReingoldAlgorithm algorithm;
  final Paint? paint;
  final NodeWidgetBuilder builder;
  final bool animate;
  final int stepMilis;

  GraphViewCustomPainter({
    Key? key,
    required this.graph,
    required this.algorithm,
    this.paint,
    this.animate = true,
    this.stepMilis = 25,
    required this.builder,
  }) : super(key: key);

  @override
  _GraphViewCustomPainterState createState() => _GraphViewCustomPainterState();
}

class _GraphViewCustomPainterState extends State<GraphViewCustomPainter> {
  // Keeps a small margin so edges near (0,0) are not clipped by the canvas.
  static const Offset _edgeLayerOffset = Offset(20, 20);

  Timer? timer;
  late Graph graph;
  late FruchtermanReingoldAlgorithm algorithm;

  @override
  void initState() {
    graph = widget.graph;

    algorithm = widget.algorithm;
    algorithm.init(graph);
    if (widget.animate) {
      startTimer();
    }

    super.initState();
  }

  void startTimer() {
    timer?.cancel();
    timer =
        Timer.periodic(Duration(milliseconds: widget.stepMilis), (tickTimer) {
      if (!widget.animate) return;
      final moved = algorithm.step(graph);
      update();
      if (!moved) {
        tickTimer.cancel();
      }
    });
  }

  @override
  void didUpdateWidget(covariant GraphViewCustomPainter oldWidget) {
    super.didUpdateWidget(oldWidget);
    graph = widget.graph;

    if (widget.algorithm != algorithm) {
      algorithm = widget.algorithm;
      algorithm.init(graph);
    }

    if (oldWidget.stepMilis != widget.stepMilis) {
      if (timer != null && timer!.isActive) {
        timer!.cancel();
      }
      if (widget.animate) {
        startTimer();
      }
      return;
    }

    if (widget.animate) {
      if (timer == null || !timer!.isActive) {
        startTimer();
      }
    } else {
      if (timer != null && timer!.isActive) {
        timer!.cancel();
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
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
          painter: EdgeRender(algorithm, graph, _edgeLayerOffset, widget.paint),
        ),
        ...List<Widget>.generate(graph.nodeCount(), (index) {
          return Positioned(
            child: GestureDetector(
              child:
                  graph.nodes[index].data ?? widget.builder(graph.nodes[index]),
              onPanUpdate: (details) {
                graph.getNodeAtPosition(index).position += details.delta;
                graph.markModified();
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
