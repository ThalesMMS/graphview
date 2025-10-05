part of graphview;

class EdgeLabelBuilderParams {
  EdgeLabelBuilderParams({
    required this.edge,
    required this.graph,
    required this.graphViewController,
    required this.onChanged,
    required this.onSubmitted,
    required this.refreshGraph,
    this.placeholder = EditableEdgeLabel.defaultPlaceholder,
  });

  final Edge edge;
  final Graph graph;
  final GraphViewController? graphViewController;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback refreshGraph;
  final String placeholder;

  TextEditingController createController({String? initialValue}) {
    return TextEditingController(text: initialValue ?? edge.label ?? '');
  }

  void updateLabel(String value, {bool submit = false}) {
    if (submit) {
      onSubmitted(value);
    } else {
      onChanged(value);
    }
  }

  void requestRepaint() => refreshGraph();
}

class EditableEdgeLabel extends StatefulWidget {
  static const String defaultPlaceholder = 'Toque para editar';

  const EditableEdgeLabel({
    super.key,
    required this.edge,
    required this.graph,
    this.graphViewController,
    this.onChanged,
    this.onSubmitted,
    this.placeholder = defaultPlaceholder,
    this.textStyle,
    this.placeholderStyle,
  });

  factory EditableEdgeLabel.fromParams({
    Key? key,
    required Edge edge,
    required EdgeLabelBuilderParams params,
    String? placeholder,
    TextStyle? textStyle,
    TextStyle? placeholderStyle,
  }) {
    return EditableEdgeLabel(
      key: key,
      edge: edge,
      graph: params.graph,
      graphViewController: params.graphViewController,
      onChanged: params.onChanged,
      onSubmitted: params.onSubmitted,
      placeholder: placeholder ?? params.placeholder,
      textStyle: textStyle,
      placeholderStyle: placeholderStyle,
    );
  }

  final Edge edge;
  final Graph graph;
  final GraphViewController? graphViewController;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final TextStyle? textStyle;
  final TextStyle? placeholderStyle;

  @override
  State<EditableEdgeLabel> createState() => _EditableEdgeLabelState();
}

class _EditableEdgeLabelState extends State<EditableEdgeLabel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.edge.label ?? '');
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant EditableEdgeLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.edge != widget.edge) {
      _controller.text = widget.edge.label ?? '';
      return;
    }

    final newText = widget.edge.label ?? '';
    if (!_isEditing && _controller.text != newText) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _submitAndExit();
    }
  }

  void _enterEditingMode() {
    if (_isEditing) {
      return;
    }
    setState(() {
      _isEditing = true;
      _controller.text = widget.edge.label ?? '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });
  }

  void _exitEditingMode() {
    if (!_isEditing) {
      return;
    }
    setState(() {
      _isEditing = false;
    });
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void _handleChanged(String value) {
    final handler = widget.onChanged ?? _updateLabel;
    handler(value);
  }

  void _handleSubmitted(String value) {
    final handler = widget.onSubmitted ?? widget.onChanged ?? _updateLabel;
    handler(value);
    _exitEditingMode();
  }

  void _submitAndExit() {
    final value = _controller.text;
    _handleSubmitted(value);
  }

  void _updateLabel(String value) {
    if (widget.edge.label == value) {
      return;
    }
    widget.edge.label = value;
    widget.graph.notifyGraphObserver();
    widget.graphViewController?.forceRecalculation();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          onChanged: _handleChanged,
          onSubmitted: _handleSubmitted,
          textInputAction: TextInputAction.done,
          style: widget.edge.labelStyle ?? widget.textStyle,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: const OutlineInputBorder(),
            hintText: widget.placeholder,
          ),
        ),
      );
    }

    final label = widget.edge.label;
    final isEmpty = label == null || label.isEmpty;
    final displayText = isEmpty ? widget.placeholder : label;
    final theme = Theme.of(context);
    final placeholderStyle = widget.placeholderStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.hintColor,
          fontStyle: FontStyle.italic,
        );

    return GestureDetector(
      onTap: _enterEditingMode,
      onDoubleTap: _enterEditingMode,
      behavior: HitTestBehavior.opaque,
      child: Text(
        displayText,
        style: isEmpty
            ? placeholderStyle
            : widget.edge.labelStyle ?? widget.textStyle,
      ),
    );
  }
}
