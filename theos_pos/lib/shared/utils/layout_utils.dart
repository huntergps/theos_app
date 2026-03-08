import 'package:fluent_ui/fluent_ui.dart';

/// Utilidades centralizadas para construcción de layouts comunes
///
/// Provee métodos factory para patrones de UI que se repiten:
/// - Secciones con headers
/// - Filas de información label/value
/// - Layouts inline para formularios
/// - Cards con headers
class LayoutUtils {
  LayoutUtils._();

  // =============================================================================
  // SECTION HEADERS
  // =============================================================================

  /// Construye un header de sección con barra de color y etiqueta
  static Widget buildSectionHeader(
    BuildContext context,
    String label, {
    Color? color,
    IconData? icon,
  }) {
    final theme = FluentTheme.of(context);
    final headerColor = color ?? theme.accentColor;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: headerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        if (icon != null) ...[
          Icon(icon, size: 14, color: headerColor),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: headerColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // =============================================================================
  // INFORMATION ROWS
  // =============================================================================

  /// Construye una fila de información: [Icon] Label: Value
  static Widget buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    bool isHighlighted = false,
  }) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: iconColor ?? theme.inactiveColor,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '$label:',
            style: labelStyle ??
                theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  (isHighlighted
                      ? theme.typography.bodyStrong
                      : theme.typography.body),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye una fila de información vertical (label arriba, valor abajo)
  static Widget buildInfoColumn(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    Color? iconColor,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 12,
                color: iconColor ?? theme.inactiveColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.typography.body),
      ],
    );
  }

  // =============================================================================
  // FORM LAYOUTS
  // =============================================================================

  /// Construye un layout de campo de formulario inline
  /// [Icon] Label: [Widget]
  static Widget buildInlineFieldLayout(
    BuildContext context, {
    required String label,
    required Widget child,
    IconData? icon,
    double labelWidth = 130,
  }) {
    final theme = FluentTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: theme.inactiveColor),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: labelWidth,
          child: Text(
            '$label:',
            style: theme.typography.caption,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// Construye un layout de campo de formulario stacked (label arriba)
  static Widget buildStackedFieldLayout(
    BuildContext context, {
    required String label,
    required Widget child,
    IconData? icon,
    bool isRequired = false,
  }) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: theme.inactiveColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.typography.caption,
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: theme.typography.caption?.copyWith(
                  color: Colors.red,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  // =============================================================================
  // CARD LAYOUTS
  // =============================================================================

  /// Construye un card con header y contenido
  static Widget buildCardWithHeader(
    BuildContext context, {
    required String title,
    required Widget content,
    IconData? titleIcon,
    Color? iconColor,
    List<Widget>? actions,
    EdgeInsetsGeometry? padding,
  }) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Icon(
                  titleIcon,
                  size: 18,
                  color: iconColor ?? theme.accentColor,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.typography.subtitle,
                ),
              ),
              if (actions != null) ...actions,
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  /// Construye un card de información compacto
  static Widget buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    IconData? icon,
    Color? backgroundColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final theme = FluentTheme.of(context);

    Widget content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.cardStrokeColorDefault,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? theme.accentColor).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 18,
                color: iconColor ?? theme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.typography.bodyStrong,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              FluentIcons.chevron_right,
              size: 14,
              color: theme.inactiveColor,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  // =============================================================================
  // DIALOG LAYOUTS
  // =============================================================================

  /// Construye el título estándar para un ContentDialog
  static Widget buildDialogTitle(
    BuildContext context, {
    required String title,
    IconData? icon,
  }) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: theme.accentColor),
          const SizedBox(width: 10),
        ],
        Text(title),
      ],
    );
  }

  // =============================================================================
  // STATUS INDICATORS
  // =============================================================================

  /// Construye un badge de estado
  static Widget buildStatusBadge(
    BuildContext context, {
    required String label,
    required Color color,
    IconData? icon,
    bool outlined = false,
  }) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: outlined
            ? Border.all(color: color, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.typography.caption?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================================================
  // DIVIDERS
  // =============================================================================

  /// Construye un divider con label centrado
  static Widget buildLabeledDivider(
    BuildContext context,
    String label,
  ) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  // =============================================================================
  // EMPTY STATES
  // =============================================================================

  /// Construye un estado vacío con icono, mensaje y acción opcional
  static Widget buildEmptyState(
    BuildContext context, {
    required String message,
    IconData icon = FluentIcons.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.inactiveColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.typography.body?.copyWith(
                color: theme.inactiveColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
