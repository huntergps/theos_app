import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show logger;

import '../../../core/constants/app_constants.dart';
import '../../utils/error_utils.dart';

/// Configuración para BaseSearchDialog
class SearchDialogConfig {
  /// Título del diálogo
  final String title;

  /// Placeholder del campo de búsqueda
  final String searchPlaceholder;

  /// Mensaje cuando no hay búsqueda
  final String emptySearchMessage;

  /// Mensaje cuando no hay resultados
  final String noResultsMessage;

  /// Ancho máximo del diálogo
  final double maxWidth;

  /// Alto máximo del diálogo
  final double maxHeight;

  /// Retraso de debounce en milisegundos
  final int debounceMs;

  /// Longitud mínima para iniciar búsqueda
  final int minSearchLength;

  /// Término de búsqueda inicial
  final String? initialSearch;

  const SearchDialogConfig({
    required this.title,
    this.searchPlaceholder = 'Buscar...',
    this.emptySearchMessage = 'Escriba para buscar',
    this.noResultsMessage = 'No se encontraron resultados',
    this.maxWidth = DialogSizes.mediumWidth,
    this.maxHeight = DialogSizes.mediumHeight,
    this.debounceMs = 300,
    this.minSearchLength = 1,
    this.initialSearch,
  });
}

/// Base abstracta para diálogos de búsqueda y selección
///
/// Elimina duplicación de código entre SelectPartnerDialog, SelectProductDialog,
/// SelectUomDialog, etc.
///
/// Uso:
/// ```dart
/// class SelectPartnerDialog extends BaseSearchDialog<Map<String, dynamic>> {
///   const SelectPartnerDialog({super.key});
///
///   @override
///   SearchDialogConfig get config => const SearchDialogConfig(
///     title: 'Seleccionar Cliente',
///     searchPlaceholder: 'Buscar por nombre, email o RUC...',
///   );
///
///   @override
///   Future<List<Map<String, dynamic>>> performSearch(WidgetRef ref, String query) async {
///     return ref.read(userRepositoryProvider)?.searchPartners(query) ?? [];
///   }
///
///   @override
///   Widget buildResultItem(BuildContext context, Map<String, dynamic> item, VoidCallback onSelect) {
///     return ListTile.selectable(
///       title: Text(item['name'] ?? ''),
///       onPressed: onSelect,
///     );
///   }
/// }
/// ```
abstract class BaseSearchDialog<T> extends ConsumerStatefulWidget {
  const BaseSearchDialog({super.key});

  /// Configuración del diálogo
  SearchDialogConfig get config;

  /// Ejecuta la búsqueda y retorna los resultados
  Future<List<T>> performSearch(WidgetRef ref, String query);

  /// Construye el widget para cada resultado
  /// [onSelect] debe llamarse cuando el usuario selecciona el item
  Widget buildResultItem(BuildContext context, T item, VoidCallback onSelect);

  /// Convierte el item seleccionado al valor de retorno del diálogo
  /// Por defecto retorna el item tal cual
  dynamic getReturnValue(T item) => item;

  /// Widget opcional para mostrar encima de la lista de resultados
  Widget? buildHeader(BuildContext context) => null;

  /// Widget opcional para el leading de cada item (ícono, imagen, etc.)
  Widget? buildItemLeading(BuildContext context, T item) => null;

  @override
  ConsumerState<BaseSearchDialog<T>> createState() =>
      _BaseSearchDialogState<T>();
}

class _BaseSearchDialogState<T> extends ConsumerState<BaseSearchDialog<T>> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  List<T> _results = [];
  bool _isLoading = false;
  String? _searchError;
  String _lastQuery = '';
  int _searchGeneration = 0;
  Timer? _debounceTimer;
  int _selectedIndex = -1;

  // GlobalKeys for each item to enable precise scrolling
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    if (widget.config.initialSearch != null &&
        widget.config.initialSearch!.isNotEmpty) {
      _searchController.text = widget.config.initialSearch!;
      // Trigger search immediately via post frame callback to ensure widget is built
      // Also select all text so user can easily type to replace
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(widget.config.initialSearch!);
        // Select all text so user can type to replace
        _searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchController.text.length,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_results.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % _results.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = _selectedIndex <= 0
            ? _results.length - 1
            : _selectedIndex - 1;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter &&
        _selectedIndex >= 0 &&
        _selectedIndex < _results.length) {
      final item = _results[_selectedIndex];
      Navigator.of(context).pop(widget.getReturnValue(item));
    }
  }

  void _scrollToSelected() {
    if (_selectedIndex < 0) return;

    // Schedule after frame to ensure keys are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _itemKeys[_selectedIndex];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          alignment: 0.3, // Position item at 30% from top
        );
      }
    });
  }

  Future<void> _search(String query, {bool force = false}) async {
    // Si la query es igual a la anterior, no hacer nada
    if (!force && query == _lastQuery) return;

    // Cancelar timer anterior solo cuando esta llamada realmente lo reemplaza.
    _debounceTimer?.cancel();
    _lastQuery = query;
    final generation = ++_searchGeneration;

    // Si la query es muy corta, limpiar resultados
    if (query.length < widget.config.minSearchLength) {
      setState(() {
        _results = [];
        _selectedIndex = -1;
        _isLoading = false;
        _searchError = null;
      });
      return;
    }

    // Debounce
    _debounceTimer = Timer(
      Duration(milliseconds: widget.config.debounceMs),
      () async {
        if (!mounted || generation != _searchGeneration) return;

        setState(() {
          _isLoading = true;
          _searchError = null;
        });

        try {
          final results = await widget.performSearch(ref, query);
          if (mounted && generation == _searchGeneration) {
            setState(() {
              _results = results;
              _selectedIndex = results.isNotEmpty ? 0 : -1;
              _itemKeys.clear(); // Clear keys for new results
            });
          }
        } catch (e, stackTrace) {
          logger.e('[SearchDialog]', 'Search failed', e, stackTrace);
          if (mounted && generation == _searchGeneration) {
            setState(() {
              _results = [];
              _selectedIndex = -1;
              _itemKeys.clear();
              _searchError = friendlyErrorMessage(e);
            });
          }
        } finally {
          if (mounted && generation == _searchGeneration) {
            setState(() => _isLoading = false);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final config = widget.config;

    return FocusScope(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        // Return handled if we processed arrow keys or enter on selected item
        if (event is KeyDownEvent &&
            _results.isNotEmpty &&
            (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowUp ||
                (event.logicalKey == LogicalKeyboardKey.enter &&
                    _selectedIndex >= 0))) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ContentDialog(
        title: Text(config.title),
        constraints: BoxConstraints(
          maxWidth: config.maxWidth,
          maxHeight: config.maxHeight,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Campo de búsqueda
            TextBox(
              controller: _searchController,
              placeholder: config.searchPlaceholder,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(FluentIcons.search, size: 14),
              ),
              suffix: _searchController.text.isNotEmpty
                  ? Tooltip(
                      message: 'Limpiar búsqueda',
                      child: IconButton(
                        icon: const Icon(FluentIcons.clear, size: 12),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      ),
                    )
                  : null,
              onChanged: _search,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // Header opcional
            if (widget.buildHeader(context) != null) ...[
              widget.buildHeader(context)!,
              const SizedBox(height: 8),
            ],

            // Lista de resultados
            Expanded(child: _buildContent(theme, config)),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(FluentThemeData theme, SearchDialogConfig config) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    if (_searchError case final error?) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.error, size: 32),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Button(
              onPressed: () => _search(_lastQuery, force: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          _lastQuery.isEmpty || _lastQuery.length < config.minSearchLength
              ? config.emptySearchMessage
              : config.noResultsMessage,
          style: theme.typography.body?.copyWith(color: theme.inactiveColor),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _results.length,
      itemBuilder: (context, index) {
        // Get or create GlobalKey for this index
        _itemKeys[index] ??= GlobalKey();
        final item = _results[index];
        final isSelected = index == _selectedIndex;
        return Container(
          key: _itemKeys[index],
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentColor.withAlpha(51) // 20% opacity
                : null,
            border: isSelected
                ? Border.all(color: theme.accentColor, width: 1)
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: widget.buildResultItem(
            context,
            item,
            () => Navigator.of(context).pop(widget.getReturnValue(item)),
          ),
        );
      },
    );
  }
}

/// Extensión para crear diálogos de búsqueda simples con callbacks
class SimpleSearchDialog<T> extends BaseSearchDialog<T> {
  final SearchDialogConfig _config;
  final Future<List<T>> Function(WidgetRef ref, String query) _searchFn;
  final Widget Function(BuildContext context, T item, VoidCallback onSelect)
  _buildItemFn;
  final dynamic Function(T item)? _getReturnValueFn;

  const SimpleSearchDialog({
    super.key,
    required this._config,
    required Future<List<T>> Function(WidgetRef ref, String query) onSearch,
    required Widget Function(
      BuildContext context,
      T item,
      VoidCallback onSelect,
    )
    buildItem,
    dynamic Function(T item)? getReturnValue,
  }) : _searchFn = onSearch,
       _buildItemFn = buildItem,
       _getReturnValueFn = getReturnValue;

  @override
  SearchDialogConfig get config => _config;

  @override
  Future<List<T>> performSearch(WidgetRef ref, String query) =>
      _searchFn(ref, query);

  @override
  Widget buildResultItem(BuildContext context, T item, VoidCallback onSelect) =>
      _buildItemFn(context, item, onSelect);

  @override
  dynamic getReturnValue(T item) => _getReturnValueFn?.call(item) ?? item;
}
