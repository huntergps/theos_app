import 'package:fluent_ui/fluent_ui.dart';

/// Helpers para mostrar dialogos comunes en la aplicacion
/// Centraliza patrones de dialogo reutilizables
abstract class TheosDialogs {
  /// Muestra un dialogo de confirmacion simple (Si/No)
  /// Retorna true si el usuario confirmo, false si cancelo
  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Si',
    String cancelText = 'No',
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => ContentDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              Button(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              FilledButton(
                style: isDangerous
                    ? ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.red),
                      )
                    : null,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmText),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Muestra un dialogo de confirmacion para eliminar algo
  static Future<bool> showDeleteConfirm(
    BuildContext context, {
    required String itemName,
    String? customMessage,
  }) async {
    return await showConfirm(
      context,
      title: 'Confirmar eliminacion',
      message: customMessage ?? 'Esta seguro que desea eliminar "$itemName"?',
      confirmText: 'Eliminar',
      cancelText: 'Cancelar',
      isDangerous: true,
    );
  }

  /// Muestra un dialogo de cierre de app/sesion
  static Future<bool> showCloseConfirm(
    BuildContext context, {
    String title = 'Confirmar cierre',
    String message = 'Esta seguro de que desea cerrar la aplicacion?',
  }) async {
    return await showConfirm(
      context,
      title: title,
      message: message,
      confirmText: 'Si',
      cancelText: 'No',
    );
  }

  /// Muestra un dialogo de error con boton de cerrar
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Row(
          children: [
            Icon(FluentIcons.error_badge, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SelectableText(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Muestra un dialogo de cargando con indicador de progreso
  /// Retorna un completer que debe completarse cuando termine la operacion
  static Future<T> showLoading<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() operation,
    bool useRootNavigator = true,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) => ContentDialog(
        title: Text(message),
        content: const Center(
          child: Padding(padding: EdgeInsets.all(20), child: ProgressRing()),
        ),
      ),
    );

    try {
      // Execute operation
      final result = await operation();

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context, rootNavigator: useRootNavigator).pop();
      }

      return result;
    } catch (e) {
      // Close loading dialog on error
      if (context.mounted) {
        Navigator.of(context, rootNavigator: useRootNavigator).pop();
      }
      rethrow;
    }
  }

  /// Muestra un dialogo de informacion
  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: Row(
          children: [
            Icon(FluentIcons.info, color: Colors.blue),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SelectableText(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }
}
