import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reactive_field_base.dart';

/// A generic master data selector widget
///
/// Can be used for selecting from any master table:
/// - Warehouses
/// - Pricelists
/// - Payment terms
/// - Salespeople
/// - Products
/// - UoM
/// - etc.
///
/// Usage:
/// ```dart
/// ReactiveMasterSelector<Warehouse>(
///   config: ReactiveFieldConfig(
///     label: 'Bodega',
///     isEditing: isEditMode,
///     prefixIcon: FluentIcons.warehouse,
///   ),
///   value: warehouseId,
///   displayValue: warehouseName,
///   itemsProvider: warehousesProvider,
///   getId: (w) => w.id,
///   getName: (w) => w.name,
///   onChanged: (id) => notifier.updateField('warehouse_id', id),
/// )
/// ```
class ReactiveMasterSelector<T> extends ConsumerWidget {
  /// Field configuration
  final ReactiveFieldConfig config;

  /// Currently selected ID
  final int? value;

  /// Display text for current value (shown in view mode)
  final String? displayValue;

  /// Provider that supplies the list of items
  final StreamProvider<List<T>> itemsProvider;

  /// Extract ID from item
  final int Function(T) getId;

  /// Extract display name from item
  final String Function(T) getName;

  /// Optional: Extract secondary info (shown below name)
  final String Function(T)? getSecondaryInfo;

  /// Optional: Extract icon for item
  final IconData? Function(T)? getIcon;

  /// Callback when selection changes
  final ValueChanged<int?>? onChanged;

  /// Optional filter function
  final bool Function(T)? filter;

  /// Show search box
  final bool searchable;

  /// Placeholder when no value selected
  final String placeholder;

  /// Show clear button
  final bool clearable;

  /// Use autocomplete instead of dropdown
  final bool useAutocomplete;

  /// Maximum items to show in dropdown
  final int maxDropdownItems;

  const ReactiveMasterSelector({
    super.key,
    required this.config,
    required this.value,
    this.displayValue,
    required this.itemsProvider,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
    this.getIcon,
    this.onChanged,
    this.filter,
    this.searchable = false,
    this.placeholder = 'Seleccionar...',
    this.clearable = false,
    this.useAutocomplete = false,
    this.maxDropdownItems = 50,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing || !config.isEnabled) {
      return _buildViewMode(context, theme);
    }

    final itemsAsync = ref.watch(itemsProvider);

    return itemsAsync.when(
      data: (items) {
        final filteredItems = filter != null
            ? items.where(filter!).toList()
            : items;

        if (useAutocomplete) {
          return _buildAutocomplete(context, theme, filteredItems);
        }
        return _buildComboBox(context, theme, filteredItems);
      },
      loading: () => _buildLoading(theme),
      error: (e, _) => _buildError(theme, e.toString()),
    );
  }

  Widget _buildViewMode(BuildContext context, FluentThemeData theme) {
    final isEmpty = displayValue == null || displayValue!.isEmpty;
    final responsive = ResponsiveValues(context.deviceType);

    // Inline layout: [Icon] Label: Value
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14, color: theme.inactiveColor),
          const SizedBox(width: 8),
        ],
        if (config.label.isNotEmpty && !config.isCompact) ...[
          SizedBox(
            width: responsive.labelWidth > 0 ? responsive.labelWidth : null,
            child: Text(
              '${config.label}:',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ),
          if (responsive.labelWidth <= 0) const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            isEmpty ? '-' : displayValue!,
            style: theme.typography.body?.copyWith(
              color: isEmpty ? theme.inactiveColor : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComboBox(
    BuildContext context,
    FluentThemeData theme,
    List<T> items,
  ) {
    final isEmpty = displayValue == null || displayValue!.isEmpty;

    // Inline layout: [Icon] Label: [Selection]
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14, color: theme.inactiveColor),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 130,
          child: Text(
            '${config.label}:',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ),
        Expanded(
          child: _InlineSelector(
            displayValue: isEmpty ? placeholder : displayValue!,
            isEmpty: isEmpty,
            onPressed: () => _showSelectionDialog(context, items),
          ),
        ),
      ],
    );
  }

  Widget _buildAutocomplete(
    BuildContext context,
    FluentThemeData theme,
    List<T> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  config.label,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (config.isRequired)
                  Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        AutoSuggestBox<int>(
          controller: TextEditingController(text: displayValue ?? ''),
          items: items.map((item) {
            return AutoSuggestBoxItem<int>(
              value: getId(item),
              label: getName(item),
            );
          }).toList(),
          onSelected: (item) => onChanged?.call(item.value),
          placeholder: placeholder,
          clearButtonEnabled: clearable,
        ),
      ],
    );
  }

  Widget _buildLoading(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              config.label,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        const SizedBox(
          height: 32,
          child: Center(child: ProgressRing(strokeWidth: 2)),
        ),
      ],
    );
  }

  Widget _buildError(FluentThemeData theme, String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              config.label,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Row(
          children: [
            Icon(FluentIcons.error, size: 14, color: Colors.red),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Error: $error',
                style: theme.typography.caption?.copyWith(color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showSelectionDialog(BuildContext context, List<T> items) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _SelectionDialog<T>(
        items: items,
        currentValue: value,
        getId: getId,
        getName: getName,
        getSecondaryInfo: getSecondaryInfo,
        searchable: searchable,
      ),
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}

/// Widget de selector inline con hover effect (estilo original)
class _InlineSelector extends StatelessWidget {
  final String displayValue;
  final bool isEmpty;
  final VoidCallback onPressed;

  const _InlineSelector({
    required this.displayValue,
    required this.isEmpty,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final isHovered = states.isHovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isHovered
                ? theme.accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: theme.typography.body?.copyWith(
                    color: isEmpty ? theme.inactiveColor : theme.accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHovered)
                Icon(
                  FluentIcons.chevron_down,
                  size: 10,
                  color: theme.accentColor,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Diálogo de selección con búsqueda
class _SelectionDialog<T> extends StatefulWidget {
  final List<T> items;
  final int? currentValue;
  final int Function(T) getId;
  final String Function(T) getName;
  final String Function(T)? getSecondaryInfo;
  final bool searchable;

  const _SelectionDialog({
    required this.items,
    this.currentValue,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
    this.searchable = true,
  });

  @override
  State<_SelectionDialog<T>> createState() => _SelectionDialogState<T>();
}

class _SelectionDialogState<T> extends State<_SelectionDialog<T>> {
  final _searchController = TextEditingController();
  List<T> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        _filteredItems = widget.items.where((item) {
          final name = widget.getName(item).toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: const Text('Seleccionar'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: Column(
          children: [
            if (widget.searchable) ...[
              TextBox(
                controller: _searchController,
                placeholder: 'Buscar...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(FluentIcons.search, size: 14),
                ),
                onChanged: _filterItems,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  final id = widget.getId(item);
                  final name = widget.getName(item);
                  final secondaryInfo = widget.getSecondaryInfo?.call(item);
                  final isSelected = id == widget.currentValue;

                  return ListTile.selectable(
                    title: Text(name),
                    subtitle: secondaryInfo != null
                        ? Text(secondaryInfo)
                        : null,
                    selected: isSelected,
                    onPressed: () => Navigator.of(context).pop(id),
                    trailing: isSelected
                        ? Icon(
                            FluentIcons.check_mark,
                            size: 14,
                            color: theme.accentColor,
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// A master selector that uses a provider with Map data
/// (for backward compatibility with existing providers that return List<Map>)
class ReactiveMasterSelectorMap extends ConsumerWidget {
  final ReactiveFieldConfig config;
  final int? value;
  final String? displayValue;
  final Provider<List<Map<String, dynamic>>> itemsProvider;
  final ValueChanged<int?>? onChanged;
  final bool Function(Map<String, dynamic>)? filter;
  final String idKey;
  final String nameKey;
  final String placeholder;
  final bool clearable;

  const ReactiveMasterSelectorMap({
    super.key,
    required this.config,
    required this.value,
    this.displayValue,
    required this.itemsProvider,
    this.onChanged,
    this.filter,
    this.idKey = 'id',
    this.nameKey = 'name',
    this.placeholder = 'Seleccionar...',
    this.clearable = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final items = ref.watch(itemsProvider);

    if (!config.isEditing || !config.isEnabled) {
      return _buildViewMode(theme);
    }

    final filteredItems = filter != null
        ? items.where(filter!).toList()
        : items;

    return _buildComboBox(context, theme, filteredItems);
  }

  Widget _buildViewMode(FluentThemeData theme) {
    final isEmpty = displayValue == null || displayValue!.isEmpty;

    return Row(
      children: [
        if (config.prefixIcon != null) ...[
          Icon(
            config.prefixIcon,
            size: 14,
            color: isEmpty ? theme.inactiveColor : null,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Builder(
            builder: (context) {
              final responsive = ResponsiveValues(context.deviceType);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (config.label.isNotEmpty && !config.isCompact) ...[
                    SizedBox(
                      width: responsive.labelWidth > 0
                          ? responsive.labelWidth
                          : null,
                      child: Text(
                        config.label,
                        style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor,
                        ),
                      ),
                    ),
                    if (responsive.labelWidth <= 0) const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      isEmpty ? '-' : displayValue!,
                      style: theme.typography.body,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildComboBox(
    BuildContext context,
    FluentThemeData theme,
    List<Map<String, dynamic>> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  config.label,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (config.isRequired)
                  Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ComboBox<int>(
                value: value,
                items: items.map((item) {
                  return ComboBoxItem<int>(
                    value: item[idKey] as int,
                    child: Text(item[nameKey]?.toString() ?? '-'),
                  );
                }).toList(),
                onChanged: onChanged,
                placeholder: Text(placeholder),
                isExpanded: true,
              ),
            ),
            if (clearable && value != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(FluentIcons.clear, size: 12),
                onPressed: () => onChanged?.call(null),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A related field with search dialog
///
/// For selecting from large datasets like partners, products
class ReactiveRelatedField<T> extends ConsumerWidget {
  final ReactiveFieldConfig config;
  final int? value;
  final String? displayValue;
  final Future<List<T>> Function(String query) searchFunction;
  final int Function(T) getId;
  final String Function(T) getName;
  final String Function(T)? getSecondaryInfo;
  final void Function(T) onSelect;
  final VoidCallback? onCreate;
  final String searchPlaceholder;
  final String dialogTitle;

  const ReactiveRelatedField({
    super.key,
    required this.config,
    required this.value,
    this.displayValue,
    required this.searchFunction,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
    required this.onSelect,
    this.onCreate,
    this.searchPlaceholder = 'Buscar...',
    this.dialogTitle = 'Seleccionar',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing || !config.isEnabled) {
      return _buildViewMode(theme);
    }

    return _buildEditMode(context, theme);
  }

  Widget _buildViewMode(FluentThemeData theme) {
    final isEmpty = displayValue == null || displayValue!.isEmpty;

    return Row(
      children: [
        if (config.prefixIcon != null) ...[
          Icon(
            config.prefixIcon,
            size: 14,
            color: isEmpty ? theme.inactiveColor : null,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Builder(
            builder: (context) {
              final responsive = ResponsiveValues(context.deviceType);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (config.label.isNotEmpty && !config.isCompact) ...[
                    SizedBox(
                      width: responsive.labelWidth > 0
                          ? responsive.labelWidth
                          : null,
                      child: Text(
                        config.label,
                        style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor,
                        ),
                      ),
                    ),
                    if (responsive.labelWidth <= 0) const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      isEmpty ? '-' : displayValue!,
                      style: theme.typography.body,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context, FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  config.label,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (config.isRequired)
                  Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: () => _showSearchDialog(context),
                child: Row(
                  children: [
                    const Icon(FluentIcons.search, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayValue ?? searchPlaceholder,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onCreate != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(FluentIcons.add, size: 14),
                onPressed: onCreate,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final result = await showDialog<T>(
      context: context,
      builder: (context) => _SearchDialog<T>(
        title: dialogTitle,
        searchPlaceholder: searchPlaceholder,
        searchFunction: searchFunction,
        getId: getId,
        getName: getName,
        getSecondaryInfo: getSecondaryInfo,
      ),
    );

    if (result != null) {
      onSelect(result);
    }
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final String title;
  final String searchPlaceholder;
  final Future<List<T>> Function(String) searchFunction;
  final int Function(T) getId;
  final String Function(T) getName;
  final String Function(T)? getSecondaryInfo;

  const _SearchDialog({
    required this.title,
    required this.searchPlaceholder,
    required this.searchFunction,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final _controller = TextEditingController();
  List<T> _results = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search(''); // Initial load
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await widget.searchFunction(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text(widget.title),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextBox(
            controller: _controller,
            placeholder: widget.searchPlaceholder,
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search, size: 14),
            ),
            onChanged: (value) => _search(value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: ProgressRing())
                : _error != null
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: Text(
                      'No se encontraron resultados',
                      style: theme.typography.body?.copyWith(
                        color: theme.inactiveColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final secondary = widget.getSecondaryInfo?.call(item);

                      return ListTile.selectable(
                        title: Text(widget.getName(item)),
                        subtitle: secondary != null ? Text(secondary) : null,
                        onPressed: () {
                          Navigator.of(context).pop(item);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
