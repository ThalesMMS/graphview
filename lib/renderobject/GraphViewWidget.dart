part of graphview;

class GraphViewWidget extends RenderObjectWidget {
  final GraphChildDelegate delegate;
  final Paint? paint;
  final AnimationController nodeAnimationController;
  final Curve nodeAnimationCurve;
  final bool enableAnimation;
  final Listenable? repaint;

  const GraphViewWidget({
    Key? key,
    required this.delegate,
    this.paint,
    required this.nodeAnimationController,
    required this.nodeAnimationCurve,
    required this.enableAnimation,
    this.repaint,
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
      nodeAnimationCurve: nodeAnimationCurve,
      repaint: repaint,
      childManager: context as GraphChildManager,
    )
      ..nodeDraggingConfiguration = delegate.nodeDraggingConfig
      ..repaint = repaint;
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderCustomLayoutBox renderObject) {
    renderObject
      ..delegate = delegate
      ..edgePaint = paint
      ..nodeAnimationController = nodeAnimationController
      ..nodeAnimationCurve = nodeAnimationCurve
      ..enableAnimation = enableAnimation
      ..nodeDraggingConfiguration = delegate.nodeDraggingConfig
      ..repaint = repaint;
  }
}
