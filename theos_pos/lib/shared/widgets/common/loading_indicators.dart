import 'package:fluent_ui/fluent_ui.dart';

/// Indicador de carga centrado con mensaje opcional.
///
/// Uso:
/// ```dart
/// // Simple
/// CenteredProgressRing()
///
/// // Con mensaje
/// CenteredProgressRing(message: 'Cargando datos...')
///
/// // Tamaño personalizado
/// CenteredProgressRing(size: 60, strokeWidth: 6)
/// ```
class CenteredProgressRing extends StatelessWidget {
  /// Tamaño del indicador (ancho y alto)
  final double size;

  /// Grosor del trazo (null para usar default basado en size)
  final double? strokeWidth;

  /// Mensaje opcional debajo del indicador
  final String? message;

  /// Color del indicador (null para usar accentColor del tema)
  final Color? color;

  const CenteredProgressRing({
    super.key,
    this.size = 40,
    this.strokeWidth,
    this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: ProgressRing(
              strokeWidth: strokeWidth ?? (size / 10).clamp(2, 6),
              activeColor: color,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Indicador de carga inline (para botones, celdas, etc.)
///
/// Uso:
/// ```dart
/// // En un botón
/// FilledButton(
///   onPressed: _isSaving ? null : _save,
///   child: _isSaving
///       ? const InlineProgressRing()
///       : const Text('Guardar'),
/// )
///
/// // Tamaño personalizado
/// InlineProgressRing(size: 20)
/// ```
class InlineProgressRing extends StatelessWidget {
  /// Tamaño del indicador
  final double size;

  /// Grosor del trazo
  final double strokeWidth;

  /// Color del indicador
  final Color? color;

  const InlineProgressRing({
    super.key,
    this.size = 16,
    this.strokeWidth = 2,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ProgressRing(
        strokeWidth: strokeWidth,
        activeColor: color,
      ),
    );
  }
}

/// Indicador de carga con overlay sobre contenido existente.
///
/// Uso:
/// ```dart
/// LoadingOverlayWidget(
///   isLoading: _isLoading,
///   message: 'Procesando...',
///   child: MyContent(),
/// )
/// ```
class LoadingOverlayWidget extends StatelessWidget {
  /// Si está cargando
  final bool isLoading;

  /// Contenido a mostrar debajo
  final Widget child;

  /// Mensaje de carga
  final String? message;

  /// Si oscurecer el fondo
  final bool dimBackground;

  /// Tamaño del indicador
  final double indicatorSize;

  const LoadingOverlayWidget({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.dimBackground = true,
    this.indicatorSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: dimBackground
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.transparent,
              child: CenteredProgressRing(
                size: indicatorSize,
                message: message,
              ),
            ),
          ),
      ],
    );
  }
}

/// Indicador de carga compacto para listas o cards
///
/// Uso:
/// ```dart
/// CompactLoadingIndicator()
/// CompactLoadingIndicator(label: 'Actualizando...')
/// ```
class CompactLoadingIndicator extends StatelessWidget {
  /// Etiqueta opcional
  final String? label;

  /// Tamaño del indicador
  final double size;

  const CompactLoadingIndicator({
    super.key,
    this.label,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ProgressRing(strokeWidth: 2),
        ),
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(
            label!,
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Indicador de progreso para tareas con porcentaje conocido
///
/// Uso:
/// ```dart
/// ProgressIndicatorWidget(
///   progress: 0.75,
///   label: 'Sincronizando...',
/// )
/// ```
class ProgressIndicatorWidget extends StatelessWidget {
  /// Progreso de 0.0 a 1.0
  final double progress;

  /// Etiqueta opcional
  final String? label;

  /// Mostrar porcentaje
  final bool showPercentage;

  const ProgressIndicatorWidget({
    super.key,
    required this.progress,
    this.label,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final percentage = (progress * 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (label != null)
                  Text(
                    label!,
                    style: theme.typography.body,
                  ),
                if (showPercentage)
                  Text(
                    '$percentage%',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
        ProgressBar(value: progress * 100),
      ],
    );
  }
}

/// Estado de carga para reemplazar contenido
///
/// Uso:
/// ```dart
/// if (isLoading) {
///   return LoadingState(message: 'Cargando pedidos...');
/// }
/// return MyContent();
/// ```
class LoadingState extends StatelessWidget {
  /// Mensaje de carga
  final String? message;

  /// Icono opcional
  final IconData? icon;

  /// Tamaño del indicador
  final double indicatorSize;

  const LoadingState({
    super.key,
    this.message,
    this.icon,
    this.indicatorSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: theme.inactiveColor),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: ProgressRing(strokeWidth: indicatorSize / 10),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: theme.typography.body?.copyWith(
                color: theme.inactiveColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado de error para reemplazar contenido
///
/// Uso:
/// ```dart
/// if (error != null) {
///   return ErrorState(
///     message: error,
///     onRetry: _loadData,
///   );
/// }
/// return MyContent();
/// ```
class ErrorState extends StatelessWidget {
  /// Mensaje de error
  final String message;

  /// Callback para reintentar
  final VoidCallback? onRetry;

  /// Icono de error
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = FluentIcons.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.typography.body?.copyWith(
              color: theme.inactiveColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            Button(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado vacío para listas sin contenido
///
/// Uso:
/// ```dart
/// if (items.isEmpty) {
///   return EmptyState(
///     title: 'Sin pedidos',
///     message: 'No hay pedidos para mostrar',
///     icon: FluentIcons.shopping_cart,
///     actionLabel: 'Crear pedido',
///     onAction: _createOrder,
///   );
/// }
/// ```
class EmptyState extends StatelessWidget {
  /// Título principal
  final String? title;

  /// Mensaje descriptivo
  final String message;

  /// Icono ilustrativo
  final IconData icon;

  /// Etiqueta del botón de acción
  final String? actionLabel;

  /// Callback de la acción
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    this.title,
    required this.message,
    this.icon = FluentIcons.info,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.inactiveColor),
          const SizedBox(height: 16),
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title!,
                style: theme.typography.subtitle?.copyWith(
                  color: theme.inactiveColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
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
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
