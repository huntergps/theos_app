import 'package:dartz/dartz.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Widget para manejar `Either<L, R>` del paquete dartz.
///
/// Proporciona una forma declarativa de manejar resultados que pueden ser
/// un exito (Right) o un fallo (Left), siguiendo el patron funcional.
///
/// Ejemplo de uso:
/// ```dart
/// EitherResultHandler<Failure, User>(
///   either: userResult,
///   onSuccess: (user) => UserProfile(user: user),
///   onFailure: (failure) => ErrorDisplay(message: failure.message),
/// )
/// ```
class EitherResultHandler<L, R> extends StatelessWidget {
  /// El Either a evaluar.
  final Either<L, R> either;

  /// Constructor que recibe el valor de exito (Right).
  final Widget Function(R success) onSuccess;

  /// Constructor que recibe el valor de fallo (Left).
  final Widget Function(L failure) onFailure;

  const EitherResultHandler({
    super.key,
    required this.either,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  Widget build(BuildContext context) {
    return either.fold(
      (failure) => onFailure(failure),
      (success) => onSuccess(success),
    );
  }
}

/// Widget para manejar Either con un InfoBar de error predeterminado.
///
/// Simplifica el caso comun donde el fallo debe mostrarse como un InfoBar
/// de error estandar con opcion de reintentar.
///
/// Ejemplo de uso:
/// ```dart
/// EitherResultWithErrorBar<AppFailure, List<Product>>(
///   either: productsResult,
///   failureToMessage: (f) => f.message,
///   onSuccess: (products) => ProductGrid(products: products),
///   onRetry: () => ref.refresh(productsProvider),
/// )
/// ```
class EitherResultWithErrorBar<L, R> extends StatelessWidget {
  /// El Either a evaluar.
  final Either<L, R> either;

  /// Constructor que recibe el valor de exito (Right).
  final Widget Function(R success) onSuccess;

  /// Funcion para convertir el fallo en un mensaje de error.
  final String Function(L failure) failureToMessage;

  /// Titulo del InfoBar de error.
  final String errorTitle;

  /// Callback para reintentar la operacion.
  final VoidCallback? onRetry;

  const EitherResultWithErrorBar({
    super.key,
    required this.either,
    required this.onSuccess,
    required this.failureToMessage,
    this.errorTitle = 'Error',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return either.fold((failure) {
      final message = failureToMessage(failure);
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InfoBar(
                  title: Text(errorTitle),
                  content: SelectableText(
                    message,
                    style: theme.typography.caption,
                  ),
                  severity: InfoBarSeverity.error,
                  isLong: message.length > 80,
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
    }, (success) => onSuccess(success));
  }
}

/// Extension para facilitar el uso de EitherResultHandler con Either.
extension EitherWidgetExtension<L, R> on Either<L, R> {
  /// Construye un widget basado en el resultado del Either.
  ///
  /// Ejemplo:
  /// ```dart
  /// userResult.toWidget(
  ///   onSuccess: (user) => UserProfile(user: user),
  ///   onFailure: (failure) => ErrorText(failure.message),
  /// )
  /// ```
  Widget toWidget({
    required Widget Function(R success) onSuccess,
    required Widget Function(L failure) onFailure,
  }) {
    return EitherResultHandler<L, R>(
      either: this,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  /// Construye un widget con InfoBar de error predeterminado.
  ///
  /// Ejemplo:
  /// ```dart
  /// userResult.toWidgetWithErrorBar(
  ///   onSuccess: (user) => UserProfile(user: user),
  ///   failureToMessage: (f) => f.message,
  /// )
  /// ```
  Widget toWidgetWithErrorBar({
    required Widget Function(R success) onSuccess,
    required String Function(L failure) failureToMessage,
    String errorTitle = 'Error',
    VoidCallback? onRetry,
  }) {
    return EitherResultWithErrorBar<L, R>(
      either: this,
      onSuccess: onSuccess,
      failureToMessage: failureToMessage,
      errorTitle: errorTitle,
      onRetry: onRetry,
    );
  }
}
