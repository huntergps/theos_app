import 'package:fluent_ui/fluent_ui.dart';

import '../envases_enviar_form.dart' show EnvasesProductoOption;

/// Selector de envase con búsqueda, para una línea de envío.
///
/// 🔴 Antes era un `ComboBox`, cuyo desplegable NO respeta el ancho del
/// control — mide lo que pide el contenido, y con nombres largos llegó a
/// tapar los 1.200 px del formulario entero (queja del dueño, 14-sep-2026).
/// `AutoSuggestBox` sí lo hace: fija el ancho de su overlay al del propio
/// control (`fluent_ui-4.16.1/lib/src/controls/form/auto_suggest_box.dart`,
/// `PositionedDirectional(width: box.size.width, ...)`), así que basta con
/// darle a este widget el ancho de su columna en la tabla para que la lista
/// desplegada nunca la desborde.
///
/// Abre la lista al enfocar aunque no haya texto escrito todavía — igual que
/// el `ComboBox` que reemplaza — porque `AutoSuggestBox` de fábrica sólo la
/// abre sola cuando ya hay texto (`_handleFocusChanged` en el propio
/// paquete). Mismo truco que `OrbiInlineCatalogPicker`
/// (`ui/components/fields/orbi_inline_catalog_picker.dart`): un
/// `FocusNode` propio que llama a `showOverlay()` al ganar foco.
class EnvasesProductoField extends StatefulWidget {
  const EnvasesProductoField({
    super.key,
    required this.productos,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Elige un envase',
  });

  final List<EnvasesProductoOption> productos;
  final EnvasesProductoOption? value;
  final ValueChanged<EnvasesProductoOption?> onChanged;
  final String placeholder;

  @override
  State<EnvasesProductoField> createState() => _EnvasesProductoFieldState();
}

class _EnvasesProductoFieldState extends State<EnvasesProductoField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value?.name ?? '');
  final FocusNode _focus = FocusNode();
  final GlobalKey<AutoSuggestBoxState<EnvasesProductoOption>> _boxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant EnvasesProductoField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final name = widget.value?.name ?? '';
    if (_controller.text != name) _controller.text = name;
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) _boxKey.currentState?.showOverlay();
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AutoSuggestBox<EnvasesProductoOption>(
      key: _boxKey,
      controller: _controller,
      focusNode: _focus,
      placeholder: widget.placeholder,
      items: [
        for (final producto in widget.productos)
          AutoSuggestBoxItem<EnvasesProductoOption>(
            value: producto,
            label: producto.name,
            child: Text(producto.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onSelected: (item) {
        final producto = item.value;
        widget.onChanged(producto);
        if (producto != null) {
          _controller
            ..text = producto.name
            ..selection = TextSelection.collapsed(offset: producto.name.length);
        }
      },
      onChanged: (text, reason) {
        // Sólo cuando el usuario borra el texto a mano se limpia la
        // selección — `suggestionChosen` ya la puso `onSelected`, y no hay
        // que deshacerla aquí.
        if (reason == TextChangedReason.userInput && text.isEmpty && widget.value != null) {
          widget.onChanged(null);
        }
      },
    );
  }
}
