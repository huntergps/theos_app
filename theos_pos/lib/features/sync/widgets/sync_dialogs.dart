import 'package:fluent_ui/fluent_ui.dart';

import '../../../shared/widgets/dialogs/copyable_info_bar.dart';

/// Helper class para mostrar diálogos de confirmación relacionados con sincronización
class SyncDialogs {
  /// Muestra un diálogo de confirmación genérico
  static Future<bool> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String content,
    String cancelText = 'Cancelar',
    String confirmText = 'Confirmar',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          Button(
            child: Text(cancelText),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: isDangerous
                ? ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.red),
                  )
                : null,
            child: Text(confirmText),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Muestra diálogo de confirmación para forzar sincronización completa
  static Future<bool> confirmForceFullSync(BuildContext context) {
    return showConfirmDialog(
      context: context,
      title: 'Forzar Sincronizacion Completa',
      content:
          'Esto descargara todos los registros desde cero, ignorando la fecha de '
          'ultima sincronizacion. Este proceso puede tomar varios minutos dependiendo '
          'de la cantidad de datos.',
      confirmText: 'Sincronizar Todo',
    );
  }

  /// Muestra diálogo de confirmación para sincronizar todos los catálogos
  static Future<bool> confirmSyncAll(BuildContext context) {
    return showConfirmDialog(
      context: context,
      title: 'Sincronizar Todos los Catalogos',
      content:
          'Esto sincronizara todos los catalogos de forma incremental, '
          'descargando solo los registros modificados desde la ultima sincronizacion.',
      confirmText: 'Sincronizar',
    );
  }

  /// Muestra diálogo de confirmación para vaciar todas las tablas
  static Future<bool> confirmClearAllTables(BuildContext context) {
    return showConfirmDialog(
      context: context,
      title: 'Vaciar Todas las Tablas',
      content:
          'ADVERTENCIA: Esta accion eliminara TODOS los datos locales de los catalogos:\n\n'
          '• Productos\n'
          '• Categorias\n'
          '• Impuestos\n'
          '• Unidades de Medida\n'
          '• Listas de Precios\n'
          '• Terminos de Pago\n'
          '• Clientes\n'
          '• Ordenes de Venta\n\n'
          'Debera sincronizar nuevamente para recuperar los datos.',
      confirmText: 'Vaciar Todo',
      isDangerous: true,
    );
  }

  /// Muestra diálogo de confirmación para vaciar una tabla específica
  static Future<bool> confirmClearTable({
    required BuildContext context,
    required String description,
    required int localCount,
  }) {
    return showConfirmDialog(
      context: context,
      title: 'Vaciar $description',
      content:
          'ADVERTENCIA: Esta accion eliminara todos los registros locales de "$description".\n\n'
          'Registros a eliminar: $localCount\n\n'
          'Debera sincronizar nuevamente para recuperar los datos.',
      confirmText: 'Vaciar',
      isDangerous: true,
    );
  }
}

/// Extensión para mostrar notificaciones de éxito/error usando CopyableInfoBar
extension SyncNotifications on BuildContext {
  /// Muestra una notificación de éxito
  void showSyncSuccess(String message) {
    CopyableInfoBar.showSuccess(this, title: 'Exito', message: message);
  }

  /// Muestra una notificación de error
  void showSyncError(String message) {
    CopyableInfoBar.showError(this, title: 'Error', message: message);
  }
}
