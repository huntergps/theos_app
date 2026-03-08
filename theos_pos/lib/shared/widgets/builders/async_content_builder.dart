import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Widget generico para manejar estados de carga/error/exito de AsyncValue.
///
/// Proporciona una experiencia de usuario consistente para estados asincronos:
/// - **Loading**: Muestra un indicador de progreso centrado con mensaje opcional
/// - **Error**: Muestra un InfoBar de error con opcion de reintentar
/// - **Data**: Renderiza el contenido mediante el builder proporcionado
///
/// Ejemplo de uso:
/// ```dart
/// AsyncContentBuilder<List<Product>>(
///   asyncValue: ref.watch(productsProvider),
///   builder: (products) => ProductList(products: products),
///   onRetry: () => ref.refresh(productsProvider),
/// )
/// ```
class AsyncContentBuilder<T> extends StatelessWidget {
  /// El valor asincrono de Riverpod a observar.
  final AsyncValue<T> asyncValue;

  /// Constructor que recibe los datos cuando estan disponibles.
  final Widget Function(T data) builder;

  /// Widget personalizado para mostrar durante la carga.
  /// Si es null, se muestra un ProgressRing centrado con mensaje opcional.
  final Widget? loading;

  /// Mensaje opcional para mostrar durante la carga.
  /// Solo se usa si [loading] es null.
  final String? loadingMessage;

  /// Constructor personalizado para errores.
  /// Si es null, se muestra un InfoBar de error estandar.
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;

  /// Callback para reintentar la operacion despues de un error.
  /// Si se proporciona, se muestra un boton de reintentar.
  final VoidCallback? onRetry;

  /// Si es true, muestra los datos anteriores mientras se actualiza.
  /// Por defecto es true para evitar parpadeos en actualizaciones.
  final bool skipLoadingOnRefresh;

  /// Si es true, muestra los datos anteriores mientras hay un error.
  /// Util para mantener el contenido visible mientras se muestra el error.
  final bool skipErrorOnRefresh;

  const AsyncContentBuilder({
    super.key,
    required this.asyncValue,
    required this.builder,
    this.loading,
    this.loadingMessage,
    this.errorBuilder,
    this.onRetry,
    this.skipLoadingOnRefresh = true,
    this.skipErrorOnRefresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipError: skipErrorOnRefresh,
      data: (data) => builder(data),
      loading: () => _buildLoading(context),
      error: (error, stack) => _buildError(context, error, stack),
    );
  }

  Widget _buildLoading(BuildContext context) {
    if (loading != null) {
      return loading!;
    }

    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          if (loadingMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              loadingMessage!,
              style: theme.typography.body?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error, StackTrace? stack) {
    if (errorBuilder != null) {
      return errorBuilder!(error, stack);
    }

    final theme = FluentTheme.of(context);
    final errorMessage = error.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoBar(
                title: const Text('Error al cargar los datos'),
                content: SelectableText(
                  errorMessage,
                  style: theme.typography.caption,
                ),
                severity: InfoBarSeverity.error,
                isLong: errorMessage.length > 80,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.refresh, size: 16),
                      SizedBox(width: 8),
                      Text('Reintentar'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension para facilitar el uso de AsyncContentBuilder con AsyncValue.
extension AsyncValueBuilderExtension<T> on AsyncValue<T> {
  /// Construye un widget basado en el estado del AsyncValue.
  ///
  /// Ejemplo:
  /// ```dart
  /// ref.watch(productsProvider).buildContent(
  ///   builder: (products) => ProductList(products: products),
  ///   onRetry: () => ref.refresh(productsProvider),
  /// )
  /// ```
  Widget buildContent({
    required Widget Function(T data) builder,
    Widget? loading,
    String? loadingMessage,
    Widget Function(Object error, StackTrace? stack)? errorBuilder,
    VoidCallback? onRetry,
    bool skipLoadingOnRefresh = true,
    bool skipErrorOnRefresh = false,
  }) {
    return AsyncContentBuilder<T>(
      asyncValue: this,
      builder: builder,
      loading: loading,
      loadingMessage: loadingMessage,
      errorBuilder: errorBuilder,
      onRetry: onRetry,
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      skipErrorOnRefresh: skipErrorOnRefresh,
    );
  }
}
