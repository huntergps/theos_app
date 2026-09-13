import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

import '../../../features/clients/catalog_contracts.dart';

/// Compact, anchored catalog search intended for an editable table cell or
/// inline "new row" affordance.
///
/// Built on Fluent's own [AutoSuggestBox], which already owns the overlay
/// positioning, the arrow-key/Enter/Escape navigation and the row styling —
/// this widget only adapts a [CatalogController] (local-first, possibly
/// asynchronous search) to the synchronous `items` list [AutoSuggestBox]
/// expects.
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
  late final TextEditingController _search = TextEditingController(
    text: widget.controller.query.search,
  );
  final FocusNode _focus = FocusNode();
  final GlobalKey<AutoSuggestBoxState<CatalogEntity<T>>> _boxKey =
      GlobalKey();
  StreamSubscription<CatalogSnapshot<T>>? _subscription;

  // Whether an arrow key has highlighted one of the current items. Reset on
  // every build (a fresh, unhighlighted item list) and flipped by each
  // item's `onFocusChange`, which `AutoSuggestBoxState` calls with `true`
  // when arrows mark it (auto_suggest_box.dart:825) and `false` when arrows
  // unmark it (auto_suggest_box.dart:741).
  bool _hasHighlightedItem = false;
  List<AutoSuggestBoxItem<CatalogEntity<T>>> _currentItems = const [];

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _subscription = widget.controller.changes.listen(_onSnapshot);
  }

  @override
  void didUpdateWidget(covariant OrbiInlineCatalogPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _subscription?.cancel();
      _subscription = widget.controller.changes.listen(_onSnapshot);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSnapshot(CatalogSnapshot<T> _) {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    // AutoSuggestBox only opens its overlay on focus when there is already
    // text typed in. The inline picker is meant to show whatever the
    // controller already loaded (often the previous search) as soon as the
    // cell gets focus, so we ask it to open explicitly.
    if (_focus.hasFocus) _boxKey.currentState?.showOverlay();
  }

  void _onChanged(String value, TextChangedReason reason) {
    // `suggestionChosen` is handled by `_onSelected`, which owns clearing
    // and re-querying; reacting to it here would re-search for the picked
    // label right after it was cleared.
    if (reason == TextChangedReason.suggestionChosen) return;
    widget.controller.setSearch(value);
  }

  void _onSelected(AutoSuggestBoxItem<CatalogEntity<T>> item) {
    final entity = item.value;
    if (entity == null) return;
    widget.controller.select(entity);
    widget.onSelected(entity);
    widget.controller.setSearch('');
    // AutoSuggestBox sets the field text to the picked label and drops focus
    // right after this callback returns (see `onSelected` in
    // fluent_ui-4.16.1/lib/src/controls/form/auto_suggest_box.dart:687-706);
    // undo both in a microtask — which runs before that `unfocus()` call's
    // caller yields back to anything else, including a caller-driven focus
    // change on a different field — so the cell stays focused and empty,
    // ready for the next search, without racing whoever focuses next.
    scheduleMicrotask(() {
      if (!mounted) return;
      _search.clear();
      _focus.requestFocus();
    });
  }

  List<AutoSuggestBoxItem<CatalogEntity<T>>> _passthroughSorter(
    String text,
    List<AutoSuggestBoxItem<CatalogEntity<T>>> items,
  ) => items;

  List<AutoSuggestBoxItem<CatalogEntity<T>>> _items(
    BuildContext context,
    CatalogSnapshot<T> snapshot,
  ) {
    if (snapshot.status != CatalogLoadStatus.data) return const [];
    final theme = FluentTheme.of(context);
    return [
      for (final entity in snapshot.items)
        AutoSuggestBoxItem<CatalogEntity<T>>(
          value: entity,
          label: entity.title,
          semanticLabel: entity.subtitle == null
              ? entity.title
              : '${entity.title}, ${entity.subtitle}',
          onFocusChange: (highlighted) => _hasHighlightedItem = highlighted,
          child: entity.subtitle == null || entity.subtitle!.isEmpty
              ? Text(entity.title, maxLines: 1, overflow: TextOverflow.ellipsis)
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: entity.title),
                      TextSpan(
                        text: '   ${entity.subtitle}',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
    ];
  }

  // `AutoSuggestBoxState`'s own `Focus` (auto_suggest_box.dart:805) ignores
  // Enter, so it bubbles up here. If an arrow key already highlighted an
  // item, let it bubble further to Fluent's own `_onSubmitted`
  // (auto_suggest_box.dart:750), which is what the "arrow + Enter" test
  // exercises. Otherwise — the "type a code, hit Enter" fast-sale flow —
  // pick the first of the currently filtered matches ourselves, since
  // `_onSubmitted` does nothing when nothing is highlighted
  // (auto_suggest_box.dart:754).
  KeyEventResult _onEnterFallback(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (_hasHighlightedItem || _currentItems.isEmpty) {
      return KeyEventResult.ignored;
    }
    _onSelected(_currentItems.first);
    _boxKey.currentState?.dismissOverlay();
    return KeyEventResult.handled;
  }

  Widget _noResultsFound(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    return switch (snapshot.status) {
      CatalogLoadStatus.initial ||
      CatalogLoadStatus.loading => const SizedBox(
        height: 48,
        child: Center(child: ProgressRing(strokeWidth: 2)),
      ),
      CatalogLoadStatus.error => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No se pudo cargar el catálogo.'),
      ),
      CatalogLoadStatus.empty || CatalogLoadStatus.data => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Sin resultados'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.controller.snapshot;
    // A fresh item list each build starts unhighlighted; only a subsequent
    // arrow key (via `onFocusChange` above) flips this back to true.
    _hasHighlightedItem = false;
    _currentItems = _items(context, snapshot);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onEnterFallback,
      child: AutoSuggestBox<CatalogEntity<T>>(
        key: _boxKey,
        controller: _search,
        focusNode: _focus,
        items: _currentItems,
        sorter: _passthroughSorter,
        onChanged: _onChanged,
        onSelected: _onSelected,
        noResultsFoundBuilder: _noResultsFound,
        placeholder: widget.label,
        leadingIcon: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(FluentIcons.search, size: 18),
        ),
      ),
    );
  }
}
