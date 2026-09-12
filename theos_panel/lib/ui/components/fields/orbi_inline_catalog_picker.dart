import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../../features/clients/catalog_contracts.dart';

/// Compact, anchored catalog search intended for an editable table cell or
/// inline "new row" affordance. Results are rendered in an overlay so the
/// editor does not grow a large search panel while the user types.
class OrbiInlineCatalogPicker<T> extends StatefulWidget {
  const OrbiInlineCatalogPicker({
    super.key,
    required this.controller,
    required this.label,
    required this.onSelected,
  });

  final CatalogController<T> controller;
  final String label;
  final ValueChanged<CatalogEntity<T>> onSelected;

  @override
  State<OrbiInlineCatalogPicker<T>> createState() =>
      _OrbiInlineCatalogPickerState<T>();
}

class _OrbiInlineCatalogPickerState<T>
    extends State<OrbiInlineCatalogPicker<T>> {
  final _link = LayerLink();
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query.search,
  );
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKeyEvent)
    ..addListener(_onFocusChanged);
  OverlayEntry? _entry;

  @override
  void dispose() {
    _hide();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _hide();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final items = widget.controller.snapshot.items;
      final first = items.isEmpty ? null : items.first;
      if (first != null) {
        _select(first);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChanged() {
    if (_focus.hasFocus) _show();
  }

  void _onChanged(String value) {
    widget.controller.setSearch(value);
    _show();
  }

  void _show() {
    if (!mounted || _entry != null) {
      _entry?.markNeedsBuild();
      return;
    }
    _entry = OverlayEntry(builder: _overlay);
    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  void _select(CatalogEntity<T> entity) {
    widget.controller.select(entity);
    widget.onSelected(entity);
    _search.clear();
    widget.controller.setSearch('');
    _hide();
    _focus.requestFocus();
  }

  Widget _overlay(BuildContext context) {
    final box = this.context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 280;
    final theme = FluentTheme.of(context);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: theme.resources.cardStrokeColorDefault),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: math.max(280, width),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  child: _results(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(BuildContext context) => StreamBuilder<CatalogSnapshot<T>>(
    stream: widget.controller.changes,
    initialData: widget.controller.snapshot,
    builder: (context, snapshot) {
      final state = snapshot.data ?? widget.controller.snapshot;
      final theme = FluentTheme.of(context);
      return switch (state.status) {
        CatalogLoadStatus.initial ||
        CatalogLoadStatus.loading => const SizedBox(
          height: 48,
          child: Center(child: ProgressRing(strokeWidth: 2)),
        ),
        CatalogLoadStatus.error => const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No se pudo cargar el catálogo.'),
        ),
        CatalogLoadStatus.empty => const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Sin resultados'),
        ),
        CatalogLoadStatus.data => ListView.builder(
          shrinkWrap: true,
          itemCount: state.items.length,
          itemBuilder: (context, index) {
            final item = state.items[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _select(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.title),
                      if (item.subtitle != null)
                        Text(item.subtitle!, style: theme.typography.caption),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      };
    },
  );

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: TextBox(
      controller: _search,
      focusNode: _focus,
      onChanged: _onChanged,
      placeholder: widget.label,
      prefix: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Icon(FluentIcons.search, size: 18),
      ),
    ),
  );
}
