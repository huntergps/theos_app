import 'package:fluent_ui/fluent_ui.dart';

/// Product description widget - shows name and opens modal for editing
class ProductDescriptionCell extends StatelessWidget {
  final String productName;
  final String fullDescription;
  final bool isEditable;
  final void Function(String newDescription)? onDescriptionChanged;
  final VoidCallback? onShowProductInfo;
  final void Function(bool isExpanded, int lineCount)? onExpandChanged;

  const ProductDescriptionCell({
    super.key,
    required this.productName,
    required this.fullDescription,
    this.isEditable = false,
    this.onDescriptionChanged,
    this.onShowProductInfo,
    this.onExpandChanged,
  });

  /// Extrae el texto adicional (sin el nombre del producto)
  String _extractCustomText() {
    if (fullDescription == productName) return '';
    if (fullDescription.startsWith(productName)) {
      return fullDescription.substring(productName.length).trim();
    }
    if (fullDescription.contains('\n')) {
      final lines = fullDescription.split('\n');
      if (lines.length > 1) return lines.sublist(1).join('\n').trim();
    }
    return '';
  }

  Future<void> _showEditDescriptionDialog(BuildContext context) async {
    final customText = _extractCustomText();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditDescriptionDialog(
        productName: productName,
        initialText: customText,
      ),
    );

    if (result != null && onDescriptionChanged != null) {
      final newDescription = result.isEmpty
          ? productName
          : '$productName\n$result';
      onDescriptionChanged!(newDescription);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final customText = _extractCustomText();
    final hasCustomText = customText.isNotEmpty;
    final customLines = hasCustomText ? customText.split('\n') : <String>[];

    // Construir el texto completo para el tooltip
    final fullText = hasCustomText
        ? '$productName\n${customLines.join('\n')}'
        : productName;

    return Row(
      children: [
        // Product name and custom description preview
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Product name con tooltip si está truncado
              _TruncatedTextWithTooltip(
                text: productName,
                fullText: fullText,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.typography.body?.color,
                ),
                maxLines: 1,
              ),
              // Mostrar cada línea de descripción adicional
              for (final line in customLines)
                _TruncatedTextWithTooltip(
                  text: line,
                  fullText: fullText,
                  style: TextStyle(
                    color: theme.accentColor,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                ),
            ],
          ),
        ),
        SizedBox(width: 8),
        // Edit description button - opens modal
        if (isEditable && onDescriptionChanged != null)
          Tooltip(
            message: hasCustomText
                ? 'Editar descripcion'
                : 'Agregar descripcion',
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: IconButton(
                icon: Icon(
                  FluentIcons.text_field,
                  size: 20,
                  color: hasCustomText
                      ? theme.accentColor
                      : theme.inactiveColor,
                ),
                onPressed: () => _showEditDescriptionDialog(context),
              ),
            ),
          ),
        SizedBox(width: 18),
        // Show product info button
        if (onShowProductInfo != null)
          Tooltip(
            message: 'Ver informacion del producto',
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              child: IconButton(
                icon: Icon(
                  FluentIcons.info,
                  size: 20,
                  color: theme.inactiveColor,
                ),
                onPressed: onShowProductInfo,
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog modal para editar descripcion multilínea
class _EditDescriptionDialog extends StatefulWidget {
  final String productName;
  final String initialText;

  const _EditDescriptionDialog({
    required this.productName,
    required this.initialText,
  });

  @override
  State<_EditDescriptionDialog> createState() => _EditDescriptionDialogState();
}

class _EditDescriptionDialogState extends State<_EditDescriptionDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Calculate height based on lines, but keeping it simple for now as per original
    return ContentDialog(
      title: const Text('Editar Descripcion'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name (read-only)
            Text(
              'Producto: ${widget.productName}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.typography.body?.color,
              ),
            ),
            const SizedBox(height: 12),
            // Description text area
            Text(
              'Descripcion adicional:',
              style: TextStyle(
                fontSize: 12,
                color: theme.typography.caption?.color,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 200,
              child: TextBox(
                controller: _controller,
                placeholder: 'Ingrese descripcion adicional...',
                maxLines: null,
                minLines: 8,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                autofocus: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use Enter para agregar nuevas lineas',
              style: TextStyle(
                fontSize: 11,
                color: theme.inactiveColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: const Text('Guardar'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}

/// Widget que muestra un texto con tooltip si está truncado
/// Funciona con hover (mouse) y long press (tablets)
class _TruncatedTextWithTooltip extends StatefulWidget {
  final String text;
  final String fullText;
  final TextStyle? style;
  final int maxLines;

  const _TruncatedTextWithTooltip({
    required this.text,
    required this.fullText,
    this.style,
    this.maxLines = 1,
  });

  @override
  State<_TruncatedTextWithTooltip> createState() =>
      _TruncatedTextWithTooltipState();
}

class _TruncatedTextWithTooltipState extends State<_TruncatedTextWithTooltip> {
  final GlobalKey _textKey = GlobalKey();
  bool _isTruncated = false;

  @override
  void initState() {
    super.initState();
    // Verificar si el texto está truncado después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTruncation());
  }

  void _checkTruncation() {
    final RenderBox? renderBox =
        _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: renderBox.constraints.maxWidth);

    final isTruncated =
        textPainter.didExceedMaxLines ||
        textPainter.size.width > renderBox.size.width;

    if (mounted && isTruncated != _isTruncated) {
      setState(() {
        _isTruncated = isTruncated;
      });
    }
  }

  @override
  void didUpdateWidget(_TruncatedTextWithTooltip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.style != oldWidget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTruncation());
    }
  }

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      key: _textKey,
      widget.text,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
    );

    // Solo mostrar tooltip si el texto está truncado
    if (!_isTruncated) {
      return textWidget;
    }

    // Tooltip que funciona con hover (mouse) y long press (tablets)
    // Sin triggerMode específico, el Tooltip funciona con hover en mouse
    // y también responde a long press en tablets automáticamente
    return Tooltip(
      message: widget.fullText,
      // triggerMode por defecto permite hover y long press
      child: textWidget,
    );
  }
}
