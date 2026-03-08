import 'package:fluent_ui/fluent_ui.dart';

/// Tamaño del chip
enum ChipSize { small, medium, large }

/// Chip base unificado con múltiples variantes.
///
/// Uso:
/// ```dart
/// // Chip de estado (fondo coloreado)
/// TheosChip.state(label: 'Confirmado', color: Colors.green)
///
/// // Chip seleccionable (toggle)
/// TheosChip.filter(
///   label: 'Activo',
///   isSelected: _showActive,
///   onTap: () => setState(() => _showActive = !_showActive),
/// )
///
/// // Chip removible (con X)
/// TheosChip.removable(
///   label: 'Filtro: Enero',
///   onClose: () => _removeFilter('enero'),
/// )
///
/// // Chip con icono
/// TheosChip(
///   label: 'Urgente',
///   color: Colors.red,
///   icon: FluentIcons.warning,
/// )
/// ```
class TheosChip extends StatelessWidget {
  /// Texto del chip
  final String label;

  /// Color del chip (fondo o borde según variante)
  final Color? color;

  /// Icono opcional
  final IconData? icon;

  /// Callback al hacer tap
  final VoidCallback? onTap;

  /// Callback al cerrar (si es removible)
  final VoidCallback? onClose;

  /// Si está seleccionado (para filtros)
  final bool isSelected;

  /// Tamaño del chip
  final ChipSize size;

  /// Si el fondo es sólido o solo outline
  final bool isSolid;

  /// Si está deshabilitado
  final bool isDisabled;

  const TheosChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
    this.onClose,
    this.isSelected = false,
    this.size = ChipSize.medium,
    this.isSolid = true,
    this.isDisabled = false,
  });

  /// Constructor para chip de estado (fondo coloreado)
  const TheosChip.state({
    super.key,
    required this.label,
    required Color this.color,
    this.icon,
    this.size = ChipSize.medium,
  })  : onTap = null,
        onClose = null,
        isSelected = false,
        isSolid = true,
        isDisabled = false;

  /// Constructor para chip seleccionable/filtro
  const TheosChip.filter({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
    this.size = ChipSize.medium,
    this.isDisabled = false,
  })  : color = null,
        onClose = null,
        isSolid = false;

  /// Constructor para chip removible
  const TheosChip.removable({
    super.key,
    required this.label,
    required this.onClose,
    this.color,
    this.icon,
    this.size = ChipSize.medium,
    this.isDisabled = false,
  })  : onTap = null,
        isSelected = false,
        isSolid = false;

  /// Constructor para chip de acción (clickeable)
  const TheosChip.action({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
    this.size = ChipSize.medium,
    this.isDisabled = false,
  })  : onClose = null,
        isSelected = false,
        isSolid = false;

  double get _fontSize => switch (size) {
        ChipSize.small => 10,
        ChipSize.medium => 12,
        ChipSize.large => 14,
      };

  double get _iconSize => switch (size) {
        ChipSize.small => 10,
        ChipSize.medium => 12,
        ChipSize.large => 14,
      };

  EdgeInsets get _padding => switch (size) {
        ChipSize.small => const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ChipSize.medium => const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ChipSize.large => const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      };

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final effectiveColor = color ?? theme.accentColor;
    
    final backgroundColor = _getBackgroundColor(theme, effectiveColor);
    final textColor = _getTextColor(theme, effectiveColor);
    final borderColor = _getBorderColor(theme, effectiveColor);

    Widget chip = Container(
      padding: _padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize, color: textColor),
            SizedBox(width: size == ChipSize.small ? 4 : 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: isSelected || isSolid ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          if (onClose != null) ...[
            SizedBox(width: size == ChipSize.small ? 4 : 6),
            GestureDetector(
              onTap: isDisabled ? null : onClose,
              child: Icon(
                FluentIcons.chrome_close,
                size: _iconSize,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null && !isDisabled) {
      chip = HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          final isHovered = states.isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: _padding,
            decoration: BoxDecoration(
              color: isHovered
                  ? effectiveColor.withValues(alpha: isSelected ? 0.3 : 0.15)
                  : backgroundColor,
              borderRadius: BorderRadius.circular(4),
              border: borderColor != null ? Border.all(color: borderColor) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: _iconSize, color: textColor),
                  SizedBox(width: size == ChipSize.small ? 4 : 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: isSelected || isSolid ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (isDisabled) {
      chip = Opacity(opacity: 0.5, child: chip);
    }

    return chip;
  }

  Color _getBackgroundColor(FluentThemeData theme, Color effectiveColor) {
    if (isSolid) {
      return effectiveColor.withValues(alpha: 0.15);
    }
    if (isSelected) {
      return effectiveColor.withValues(alpha: 0.1);
    }
    return Colors.transparent;
  }

  Color _getTextColor(FluentThemeData theme, Color effectiveColor) {
    if (isSolid || isSelected) {
      return effectiveColor;
    }
    return theme.typography.body?.color ?? Colors.black;
  }

  Color? _getBorderColor(FluentThemeData theme, Color effectiveColor) {
    if (isSolid) {
      return null;
    }
    if (isSelected) {
      return effectiveColor;
    }
    return theme.inactiveColor.withValues(alpha: 0.5);
  }
}

/// Lista de chips para filtros
///
/// Uso:
/// ```dart
/// TheosChipList.filters(
///   items: [
///     ChipItem(value: 'draft', label: 'Borrador'),
///     ChipItem(value: 'sale', label: 'Confirmado'),
///     ChipItem(value: 'cancel', label: 'Cancelado'),
///   ],
///   selected: _selectedStatus,
///   onSelectionChanged: (value) => setState(() => _selectedStatus = value),
/// )
/// ```
class TheosChipList<T> extends StatelessWidget {
  /// Items a mostrar
  final List<ChipItem<T>> items;

  /// Valor seleccionado
  final T? selected;

  /// Callback al cambiar selección
  final ValueChanged<T?>? onSelectionChanged;

  /// Permitir deseleccionar
  final bool allowDeselect;

  /// Espaciado entre chips
  final double spacing;

  /// Tamaño de los chips
  final ChipSize chipSize;

  const TheosChipList.filters({
    super.key,
    required this.items,
    this.selected,
    this.onSelectionChanged,
    this.allowDeselect = true,
    this.spacing = 8,
    this.chipSize = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: spacing / 2,
      children: items.map((item) {
        final isSelected = selected == item.value;
        return TheosChip.filter(
          label: item.label,
          icon: item.icon,
          isSelected: isSelected,
          size: chipSize,
          onTap: onSelectionChanged != null
              ? () {
                  if (isSelected && allowDeselect) {
                    onSelectionChanged!(null);
                  } else {
                    onSelectionChanged!(item.value);
                  }
                }
              : null,
        );
      }).toList(),
    );
  }
}

/// Item para TheosChipList
class ChipItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;

  const ChipItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });
}

/// Grupo de chips removibles (para filtros activos)
///
/// Uso:
/// ```dart
/// TheosChipGroup.removable(
///   chips: activeFilters.map((f) => ChipItem(
///     value: f.key,
///     label: '${f.name}: ${f.value}',
///   )).toList(),
///   onRemove: (value) => _removeFilter(value),
///   onClearAll: _clearFilters,
/// )
/// ```
class TheosChipGroup<T> extends StatelessWidget {
  /// Chips a mostrar
  final List<ChipItem<T>> chips;

  /// Callback al remover un chip
  final ValueChanged<T>? onRemove;

  /// Callback para limpiar todos
  final VoidCallback? onClearAll;

  /// Texto del botón limpiar
  final String clearAllLabel;

  /// Espaciado entre chips
  final double spacing;

  /// Tamaño de los chips
  final ChipSize chipSize;

  const TheosChipGroup.removable({
    super.key,
    required this.chips,
    this.onRemove,
    this.onClearAll,
    this.clearAllLabel = 'Limpiar filtros',
    this.spacing = 8,
    this.chipSize = ChipSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: spacing / 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips.map((chip) => TheosChip.removable(
              label: chip.label,
              icon: chip.icon,
              color: chip.color,
              size: chipSize,
              onClose: onRemove != null ? () => onRemove!(chip.value) : null,
            )),
        if (onClearAll != null && chips.length > 1)
          TheosChip.action(
            label: clearAllLabel,
            icon: FluentIcons.clear,
            size: chipSize,
            onTap: onClearAll,
          ),
      ],
    );
  }
}
