import 'package:fluent_ui/fluent_ui.dart';
import '../../../core/theme/spacing.dart';

/// Card para mostrar informacion con icono destacado.
///
/// Proporciona una forma consistente de mostrar informacion agrupada
/// con un icono visual, titulo y contenido, con acciones opcionales.
///
/// Ejemplo de uso:
/// ```dart
/// InfoDisplayCard(
///   icon: FluentIcons.contact,
///   iconColor: Colors.blue,
///   title: 'Informacion del cliente',
///   content: Column(
///     children: [
///       TheosInfoRow(label: 'Nombre', value: customer.name),
///       TheosInfoRow(label: 'Email', value: customer.email),
///     ],
///   ),
///   actions: [
///     Button(
///       onPressed: () => editCustomer(),
///       child: Text('Editar'),
///     ),
///   ],
/// )
/// ```
class InfoDisplayCard extends StatelessWidget {
  /// Icono principal del card.
  final IconData icon;

  /// Color del icono.
  /// Si es null, usa el color de acento del tema.
  final Color? iconColor;

  /// Titulo del card.
  final String title;

  /// Contenido principal del card.
  final Widget content;

  /// Lista opcional de acciones (botones) en la parte inferior.
  final List<Widget>? actions;

  /// Padding interno del card (default: Spacing.all.md).
  final EdgeInsets padding;

  /// Si es true, muestra una linea divisoria entre el contenido y las acciones.
  final bool showActionsDivider;

  /// Tamano del icono.
  final double iconSize;

  /// Color de fondo del card.
  /// Si es null, usa el color de tarjeta del tema.
  final Color? backgroundColor;

  /// Borde redondeado del card.
  final BorderRadius borderRadius;

  /// Elevacion de la sombra del card.
  final double elevation;

  /// Widget adicional para mostrar junto al titulo.
  final Widget? trailing;

  const InfoDisplayCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    required this.content,
    this.actions,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.showActionsDivider = true,
    this.iconSize = 24,
    this.backgroundColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.elevation = 1,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final effectiveIconColor = iconColor ?? theme.accentColor;
    final effectiveBackgroundColor = backgroundColor ?? theme.cardColor;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: borderRadius,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con icono y titulo
          Padding(
            padding: padding,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(Spacing.sm),
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(Spacing.sm),
                  ),
                  child: Icon(icon, size: iconSize, color: effectiveIconColor),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: theme.typography.subtitle?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),

          // Linea divisora
          Container(
            height: 1,
            color: theme.resources.dividerStrokeColorDefault,
          ),

          // Contenido
          Padding(padding: padding, child: content),

          // Acciones (si hay)
          if (actions != null && actions!.isNotEmpty) ...[
            if (showActionsDivider)
              Container(
                height: 1,
                color: theme.resources.dividerStrokeColorDefault,
              ),
            Padding(
              padding: padding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (int i = 0; i < actions!.length; i++) ...[
                    if (i > 0) const SizedBox(width: Spacing.sm),
                    actions![i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card compacto para mostrar estadisticas o valores numericos.
///
/// Ideal para dashboards y vistas de resumen.
///
/// Ejemplo de uso:
/// ```dart
/// StatCard(
///   icon: FluentIcons.shopping_cart,
///   iconColor: Colors.green,
///   label: 'Ventas del dia',
///   value: '\$12,450.00',
///   trend: '+15%',
///   trendIsPositive: true,
/// )
/// ```
class StatCard extends StatelessWidget {
  /// Icono del stat.
  final IconData icon;

  /// Color del icono.
  final Color? iconColor;

  /// Etiqueta descriptiva.
  final String label;

  /// Valor a mostrar (puede ser numero, monto, etc).
  final String value;

  /// Tendencia opcional (ej: '+15%', '-5%').
  final String? trend;

  /// Si es true, el trend se muestra en verde; si es false, en rojo.
  final bool? trendIsPositive;

  /// Callback al tocar el card.
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    required this.value,
    this.trend,
    this.trendIsPositive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final effectiveIconColor = iconColor ?? theme.accentColor;

    Widget cardContent = Container(
      padding: Spacing.all.md,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: Spacing.all.sm,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 20, color: effectiveIconColor),
              ),
              const Spacer(),
              if (trend != null) _buildTrendBadge(theme),
            ],
          ),
          Spacing.vertical.ms,
          Text(
            label,
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          Spacing.vertical.xs,
          Text(
            value,
            style: theme.typography.title?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      cardContent = GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }

  Widget _buildTrendBadge(FluentThemeData theme) {
    final isPositive = trendIsPositive ?? true;
    final color = isPositive ? Colors.green : Colors.red;
    final icon = isPositive ? FluentIcons.up : FluentIcons.down;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: Spacing.xs),
          Text(
            trend!,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card para mostrar estados vacios con icono y accion.
///
/// Util para indicar que no hay datos disponibles con una
/// accion sugerida para agregar contenido.
///
/// Ejemplo de uso:
/// ```dart
/// EmptyStateCard(
///   icon: FluentIcons.document,
///   title: 'No hay documentos',
///   message: 'Crea tu primer documento para comenzar.',
///   actionLabel: 'Crear documento',
///   onAction: () => createDocument(),
/// )
/// ```
class EmptyStateCard extends StatelessWidget {
  /// Icono a mostrar.
  final IconData icon;

  /// Color del icono.
  final Color? iconColor;

  /// Titulo del estado vacio.
  final String title;

  /// Mensaje descriptivo.
  final String? message;

  /// Etiqueta del boton de accion.
  final String? actionLabel;

  /// Callback del boton de accion.
  final VoidCallback? onAction;

  /// Tamano del icono.
  final double iconSize;

  const EmptyStateCard({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final effectiveIconColor =
        iconColor ?? theme.inactiveColor.withValues(alpha: 0.5);

    return Center(
      child: Padding(
        padding: Spacing.all.xl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: Spacing.all.ml,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: iconSize, color: effectiveIconColor),
            ),
            Spacing.vertical.lg,
            Text(
              title,
              style: theme.typography.subtitle?.copyWith(
                color: theme.inactiveColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              Spacing.vertical.sm,
              Text(
                message!,
                style: theme.typography.body?.copyWith(
                  color: theme.inactiveColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              Spacing.vertical.lg,
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
