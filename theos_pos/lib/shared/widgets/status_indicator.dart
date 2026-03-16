import 'package:fluent_ui/fluent_ui.dart';

/// Tipo de indicador de estado
enum StatusIndicatorType {
  /// Información (azul)
  info,

  /// Advertencia (amarillo/naranja)
  warning,

  /// Error (rojo)
  error,

  /// Éxito (verde)
  success,

  /// Neutral/Inactivo (gris)
  neutral,
}

/// Estilo del indicador
enum StatusIndicatorStyle {
  /// Badge compacto (solo icono o icono+texto corto)
  badge,

  /// Alerta completa (título + descripción)
  alert,

  /// Inline (icono + texto en una línea)
  inline,
}

/// Widget unificado para mostrar estados, badges y alertas
///
/// Reemplaza múltiples widgets similares:
/// - _PendingSyncBadge
/// - _LockedBadge
/// - _FinalConsumerInfoAlert
/// - _FinalConsumerWarningAlert
///
/// Uso como badge:
/// ```dart
/// StatusIndicator(
///   type: StatusIndicatorType.warning,
///   style: StatusIndicatorStyle.badge,
///   icon: FluentIcons.cloud_upload,
///   label: 'Sincronizar',
///   onTap: () => syncOrder(),
/// )
/// ```
///
/// Uso como alerta:
/// ```dart
/// StatusIndicator(
///   type: StatusIndicatorType.warning,
///   style: StatusIndicatorStyle.alert,
///   icon: FluentIcons.warning,
///   title: '¡Atención!',
///   message: 'El monto excede el límite permitido.',
///   details: ['Opción 1: Cambiar cliente', 'Opción 2: Reducir monto'],
/// )
/// ```
class StatusIndicator extends StatelessWidget {
  /// Tipo de indicador (determina colores)
  final StatusIndicatorType type;

  /// Estilo de presentación
  final StatusIndicatorStyle style;

  /// Icono a mostrar
  final IconData icon;

  /// Texto corto para badges/inline
  final String? label;

  /// Título para alertas
  final String? title;

  /// Mensaje principal para alertas
  final String? message;

  /// Detalles adicionales (lista de bullets para alertas)
  final List<String>? details;

  /// Callback al hacer tap/click
  final VoidCallback? onTap;

  /// Si es true, muestra un spinner en lugar del icono
  final bool isLoading;

  /// Modo compacto (oculta label en badges)
  final bool isCompact;

  /// Color personalizado (override del color del tipo)
  final Color? customColor;

  /// Widget hijo personalizado (reemplaza el contenido por defecto)
  final Widget? child;

  const StatusIndicator({
    super.key,
    required this.type,
    this.style = StatusIndicatorStyle.badge,
    required this.icon,
    this.label,
    this.title,
    this.message,
    this.details,
    this.onTap,
    this.isLoading = false,
    this.isCompact = false,
    this.customColor,
    this.child,
  });

  /// Constructor conveniente para badge de envio pendiente
  factory StatusIndicator.pendingSync({
    Key? key,
    VoidCallback? onTap,
    bool isLoading = false,
    bool isCompact = false,
  }) {
    return StatusIndicator(
      key: key,
      type: StatusIndicatorType.warning,
      style: StatusIndicatorStyle.badge,
      icon: FluentIcons.cloud_upload,
      label: isLoading ? 'Sincronizando...' : 'Sincronizar',
      onTap: onTap,
      isLoading: isLoading,
      isCompact: isCompact,
      customColor: Colors.orange,
    );
  }

  /// Constructor conveniente para badge de bloqueado
  factory StatusIndicator.locked({
    Key? key,
    bool isCompact = false,
  }) {
    return StatusIndicator(
      key: key,
      type: StatusIndicatorType.neutral,
      style: StatusIndicatorStyle.badge,
      icon: FluentIcons.lock,
      label: 'Bloqueada',
      isCompact: isCompact,
    );
  }

  /// Constructor conveniente para alerta informativa
  factory StatusIndicator.infoAlert({
    Key? key,
    required String title,
    required String message,
    List<String>? details,
  }) {
    return StatusIndicator(
      key: key,
      type: StatusIndicatorType.info,
      style: StatusIndicatorStyle.alert,
      icon: FluentIcons.info,
      title: title,
      message: message,
      details: details,
    );
  }

  /// Constructor conveniente para alerta de advertencia
  factory StatusIndicator.warningAlert({
    Key? key,
    required String title,
    required String message,
    List<String>? details,
  }) {
    return StatusIndicator(
      key: key,
      type: StatusIndicatorType.warning,
      style: StatusIndicatorStyle.alert,
      icon: FluentIcons.warning,
      title: title,
      message: message,
      details: details,
    );
  }

  /// Constructor conveniente para alerta de error
  factory StatusIndicator.errorAlert({
    Key? key,
    required String title,
    required String message,
    List<String>? details,
  }) {
    return StatusIndicator(
      key: key,
      type: StatusIndicatorType.error,
      style: StatusIndicatorStyle.alert,
      icon: FluentIcons.error,
      title: title,
      message: message,
      details: details,
    );
  }

  Color _getColor(FluentThemeData theme) {
    if (customColor != null) return customColor!;

    return switch (type) {
      StatusIndicatorType.info => Colors.blue,
      StatusIndicatorType.warning => Colors.orange,
      StatusIndicatorType.error => Colors.red,
      StatusIndicatorType.success => Colors.green,
      StatusIndicatorType.neutral => theme.inactiveColor,
    };
  }

  InfoBarSeverity _getSeverity() {
    return switch (type) {
      StatusIndicatorType.info => InfoBarSeverity.info,
      StatusIndicatorType.warning => InfoBarSeverity.warning,
      StatusIndicatorType.error => InfoBarSeverity.error,
      StatusIndicatorType.success => InfoBarSeverity.success,
      StatusIndicatorType.neutral => InfoBarSeverity.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      StatusIndicatorStyle.badge => _buildBadge(context),
      StatusIndicatorStyle.alert => _buildAlert(context),
      StatusIndicatorStyle.inline => _buildInline(context),
    };
  }

  Widget _buildBadge(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = _getColor(theme);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 12,
            height: 12,
            child: ProgressRing(strokeWidth: 2, activeColor: color),
          )
        else
          Icon(icon, size: 12, color: color),
        if (!isCompact && label != null) ...[
          const SizedBox(width: 4),
          Text(
            label!,
            style: theme.typography.caption?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (onTap != null) {
      return Tooltip(
        message: label ?? '',
        child: Button(
          onPressed: isLoading ? null : onTap,
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(
                horizontal: isCompact ? 4 : 8,
                vertical: 4,
              ),
            ),
            backgroundColor: WidgetStateProperty.all(
              color.withValues(alpha: 0.15),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: color),
              ),
            ),
          ),
          child: content,
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: content,
    );
  }

  Widget _buildAlert(BuildContext context) {
    final hasDetails = details != null && details!.isNotEmpty;

    return InfoBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(title ?? label ?? ''),
        ],
      ),
      content: hasDetails
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null) Text(message!),
                if (message != null && hasDetails) const SizedBox(height: 8),
                ...details!.map(
                  (detail) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $detail'),
                  ),
                ),
              ],
            )
          : message != null
              ? Text(message!)
              : null,
      severity: _getSeverity(),
      isLong: hasDetails || (message != null && message!.length > 80),
    );
  }

  Widget _buildInline(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = _getColor(theme);

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 14,
            height: 14,
            child: ProgressRing(strokeWidth: 2, activeColor: color),
          )
        else
          Icon(icon, size: 14, color: color),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(
            label!,
            style: theme.typography.body?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );

    if (onTap != null) {
      content = GestureDetector(
        onTap: isLoading ? null : onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: content,
        ),
      );
    }

    return content;
  }
}
