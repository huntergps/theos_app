import 'package:fluent_ui/fluent_ui.dart';

/// Overlay de carga que se superpone sobre contenido existente.
///
/// Muestra un indicador de progreso con fondo semi-transparente sobre
/// el contenido hijo, bloqueando la interaccion del usuario mientras
/// una operacion esta en progreso.
///
/// Ejemplo de uso:
/// ```dart
/// LoadingOverlay(
///   isLoading: state.isSubmitting,
///   message: 'Guardando cambios...',
///   child: MyForm(),
/// )
/// ```
class LoadingOverlay extends StatelessWidget {
  /// Si es true, muestra el overlay de carga.
  final bool isLoading;

  /// Mensaje opcional para mostrar debajo del indicador de progreso.
  final String? message;

  /// El contenido sobre el cual se muestra el overlay.
  final Widget child;

  /// Color del fondo del overlay.
  /// Por defecto usa negro semi-transparente.
  final Color? overlayColor;

  /// Opacidad del overlay.
  /// Por defecto es 0.5.
  final double overlayOpacity;

  /// Si es true, bloquea la interaccion con el contenido hijo.
  /// Por defecto es true.
  final bool blockInteraction;

  /// Widget personalizado para mostrar en el overlay.
  /// Si es null, se muestra un ProgressRing con mensaje.
  final Widget? customIndicator;

  /// Duracion de la animacion de aparicion/desaparicion.
  final Duration animationDuration;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
    this.overlayOpacity = 0.5,
    this.blockInteraction = true,
    this.customIndicator,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveOverlayColor =
        overlayColor ??
        (isDark
            ? Colors.black.withValues(alpha: overlayOpacity)
            : Colors.white.withValues(alpha: overlayOpacity));

    return Stack(
      children: [
        // Contenido principal
        child,

        // Overlay de carga con animacion
        AnimatedSwitcher(
          duration: animationDuration,
          child: isLoading
              ? _LoadingOverlayContent(
                  key: const ValueKey('loading_overlay'),
                  overlayColor: effectiveOverlayColor,
                  message: message,
                  blockInteraction: blockInteraction,
                  customIndicator: customIndicator,
                  theme: theme,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ],
    );
  }
}

class _LoadingOverlayContent extends StatelessWidget {
  final Color overlayColor;
  final String? message;
  final bool blockInteraction;
  final Widget? customIndicator;
  final FluentThemeData theme;

  const _LoadingOverlayContent({
    super.key,
    required this.overlayColor,
    required this.message,
    required this.blockInteraction,
    required this.customIndicator,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: blockInteraction,
        child: Container(
          color: overlayColor,
          child: Center(child: customIndicator ?? _buildDefaultIndicator()),
        ),
      ),
    );
  }

  Widget _buildDefaultIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
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

/// Version compacta del LoadingOverlay sin fondo de tarjeta.
///
/// Util para indicar carga en secciones pequenas o cuando se
/// necesita un indicador mas sutil.
///
/// Ejemplo de uso:
/// ```dart
/// CompactLoadingOverlay(
///   isLoading: isRefreshing,
///   child: DataTable(...),
/// )
/// ```
class CompactLoadingOverlay extends StatelessWidget {
  /// Si es true, muestra el overlay de carga.
  final bool isLoading;

  /// El contenido sobre el cual se muestra el overlay.
  final Widget child;

  /// Tamano del ProgressRing.
  final double ringSize;

  /// Grosor del trazo del ProgressRing.
  final double strokeWidth;

  const CompactLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.ringSize = 24,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.6),
                child: Center(
                  child: SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: ProgressRing(strokeWidth: strokeWidth),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
