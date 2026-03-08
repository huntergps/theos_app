import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';

import '../config/odoo_field_config.dart';
import '../theme/responsive.dart';

/// A generic master data selector widget.
///
/// State-management agnostic -- accepts a [Stream<List<T>>] instead of a provider.
/// Can be used for selecting from any master table (warehouses, pricelists, etc.)
///
/// Usage:
/// ```dart
/// OdooMasterSelector<Warehouse>(
///   config: OdooFieldConfig(label: 'Warehouse', isEditing: isEditMode),
///   value: warehouseId,
///   displayValue: warehouseName,
///   itemsStream: manager.watchAll(),
///   getId: (w) => w.id,
///   getName: (w) => w.name,
///   onChanged: (id) => updateField('warehouse_id', id),
/// )
/// ```
class OdooMasterSelector<T> extends StatelessWidget {
  final OdooFieldConfig config;
  final int? value;
  final String? displayValue;

  /// Stream that supplies the list of items.
  /// Use `manager.watchAll()` or any `Stream<List<T>>`.
  final Stream<List<T>> itemsStream;

  final int Function(T) getId;
  final String Function(T) getName;
  final String Function(T)? getSecondaryInfo;
  final IconData? Function(T)? getIcon;
  final ValueChanged<int?>? onChanged;
  final bool Function(T)? filter;
  final bool searchable;
  final String placeholder;
  final bool clearable;
  final bool useAutocomplete;
  final int maxDropdownItems;
  final String loadingLabel;
  final String errorPrefix;
  final String selectDialogTitle;
  final String searchPlaceholder;
  final String cancelLabel;

  const OdooMasterSelector({
    super.key,
    required this.config,
    required this.value,
    this.displayValue,
    required this.itemsStream,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
    this.getIcon,
    this.onChanged,
    this.filter,
    this.searchable = false,
    this.placeholder = 'Select...',
    this.clearable = false,
    this.useAutocomplete = false,
    this.maxDropdownItems = 50,
    this.loadingLabel = 'Loading...',
    this.errorPrefix = 'Error',
    this.selectDialogTitle = 'Select',
    this.searchPlaceholder = 'Search...',
    this.cancelLabel = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing || !config.isEnabled) {
      return _buildViewMode(context, theme);
    }

    return StreamBuilder<List<T>>(
      stream: itemsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(theme, snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return _buildLoading(theme);
        }

        final items = snapshot.data!;
        final filteredItems =
            filter != null ? items.where(filter!).toList() : items;

        if (useAutocomplete) {
          return _buildAutocomplete(context, theme, filteredItems);
        }
        return _buildComboBox(context, theme, filteredItems);
      },
    );
  }

  Widget _buildViewMode(BuildContext context, FluentThemeData theme) {
    final isEmpty = displayValue == null || displayValue!.isEmpty;
    final responsive = ResponsiveValues(context.deviceType);

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
                '$errorPrefix: $error',
                style: theme.typography.caption?.copyWith(color: Colors.red),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showSelectionDialog(
      BuildContext context, List<T> items) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => _SelectionDialog<T>(
        title: selectDialogTitle,
        items: items,
        currentValue: value,
        getId: getId,
        getName: getName,
        getSecondaryInfo: getSecondaryInfo,
        searchable: searchable,
        searchPlaceholder: searchPlaceholder,
        cancelLabel: cancelLabel,
      ),
    );

    if (result != null) {
      onChanged?.call(result);
    }
  }
}

/// Inline selector with hover effect.
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

/// Selection dialog with search.
class _SelectionDialog<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final int? currentValue;
  final int Function(T) getId;
  final String Function(T) getName;
  final String Function(T)? getSecondaryInfo;
  final bool searchable;
  final String searchPlaceholder;
  final String cancelLabel;

  const _SelectionDialog({
    required this.title,
    required this.items,
    this.currentValue,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
    this.searchable = true,
    required this.searchPlaceholder,
    required this.cancelLabel,
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
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: 300,
        child: Column(
          children: [
            if (widget.searchable) ...[
              TextBox(
                controller: _searchController,
                placeholder: widget.searchPlaceholder,
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
                    subtitle:
                        secondaryInfo != null ? Text(secondaryInfo) : null,
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
          child: Text(widget.cancelLabel),
        ),
      ],
    );
  }
}

/// A related field with async search dialog.
///
/// For selecting from large datasets like partners, products.
class OdooRelatedField<T> extends StatelessWidget {
  final OdooFieldConfig config;
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
  final String cancelLabel;
  final String noResultsLabel;

  const OdooRelatedField({
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
    this.searchPlaceholder = 'Search...',
    this.dialogTitle = 'Select',
    this.cancelLabel = 'Cancel',
    this.noResultsLabel = 'No results found',
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing || !config.isEnabled) {
      return _buildViewMode(context, theme);
    }

    return _buildEditMode(context, theme);
  }

  Widget _buildViewMode(BuildContext context, FluentThemeData theme) {
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
        cancelLabel: cancelLabel,
        noResultsLabel: noResultsLabel,
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
  final String cancelLabel;
  final String noResultsLabel;

  const _SearchDialog({
    required this.title,
    required this.searchPlaceholder,
    required this.searchFunction,
    required this.getId,
    required this.getName,
    this.getSecondaryInfo,
    required this.cancelLabel,
    required this.noResultsLabel,
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
    _search('');
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
                              widget.noResultsLabel,
                              style: theme.typography.body?.copyWith(
                                color: theme.inactiveColor,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              final secondary =
                                  widget.getSecondaryInfo?.call(item);

                              return ListTile.selectable(
                                title: Text(widget.getName(item)),
                                subtitle: secondary != null
                                    ? Text(secondary)
                                    : null,
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
          child: Text(widget.cancelLabel),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Backward-compatible aliases
// ---------------------------------------------------------------------------

/// @nodoc Deprecated: use [OdooMasterSelector] instead.
typedef ReactiveMasterSelector<T> = OdooMasterSelector<T>;

/// @nodoc Deprecated: use [OdooRelatedField] instead.
typedef ReactiveRelatedField<T> = OdooRelatedField<T>;
