import 'package:fluent_ui/fluent_ui.dart';

/// Factory methods para crear InfoBars con estilos consistentes.
///
/// Uso:
/// ```dart
/// TheosInfoBars.error(message: 'Error al guardar')
/// TheosInfoBars.warning(message: 'Datos incompletos')
/// TheosInfoBars.success(message: 'Guardado correctamente')
/// TheosInfoBars.info(message: 'Información importante')
/// ```
///
/// Con título personalizado:
/// ```dart
/// TheosInfoBars.error(
///   title: 'Error de conexión',
///   message: 'No se pudo conectar al servidor',
///   onClose: () => setState(() => _error = null),
/// )
/// ```
class TheosInfoBars {
  TheosInfoBars._();

  /// InfoBar de error (severity: error)
  static Widget error({
    required String message,
    String? title,
    VoidCallback? onClose,
    bool isLong = false,
  }) {
    return InfoBar(
      title: Text(title ?? 'Error'),
      content: Text(message),
      severity: InfoBarSeverity.error,
      isLong: isLong,
      onClose: onClose,
    );
  }

  /// InfoBar de advertencia (severity: warning)
  static Widget warning({
    required String message,
    String? title,
    VoidCallback? onClose,
    bool isLong = false,
  }) {
    return InfoBar(
      title: Text(title ?? 'Advertencia'),
      content: Text(message),
      severity: InfoBarSeverity.warning,
      isLong: isLong,
      onClose: onClose,
    );
  }

  /// InfoBar de éxito (severity: success)
  static Widget success({
    required String message,
    String? title,
    VoidCallback? onClose,
    bool isLong = false,
  }) {
    return InfoBar(
      title: Text(title ?? 'Éxito'),
      content: Text(message),
      severity: InfoBarSeverity.success,
      isLong: isLong,
      onClose: onClose,
    );
  }

  /// InfoBar informativo (severity: info)
  static Widget info({
    required String message,
    String? title,
    VoidCallback? onClose,
    bool isLong = false,
  }) {
    return InfoBar(
      title: Text(title ?? 'Información'),
      content: Text(message),
      severity: InfoBarSeverity.info,
      isLong: isLong,
      onClose: onClose,
    );
  }

  /// InfoBar con acción personalizada
  static Widget withAction({
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    String? title,
    InfoBarSeverity severity = InfoBarSeverity.info,
    VoidCallback? onClose,
    bool isLong = false,
  }) {
    return InfoBar(
      title: Text(title ?? 'Información'),
      content: Text(message),
      severity: severity,
      isLong: isLong,
      onClose: onClose,
      action: Button(
        onPressed: onAction,
        child: Text(actionLabel),
      ),
    );
  }

  /// InfoBar para mostrar estado de validación de formulario
  static Widget validation({
    required List<String> errors,
    VoidCallback? onClose,
  }) {
    final message = errors.length == 1
        ? errors.first
        : errors.map((e) => '• $e').join('\n');

    return InfoBar(
      title: Text(errors.length == 1 ? 'Error de validación' : 'Errores de validación'),
      content: Text(message),
      severity: InfoBarSeverity.error,
      isLong: errors.length > 1,
      onClose: onClose,
    );
  }

  /// InfoBar para estado de conexión
  static Widget connectionStatus({
    required bool isConnected,
    String? serverName,
    VoidCallback? onRetry,
  }) {
    if (isConnected) {
      return InfoBar(
        title: const Text('Conectado'),
        content: Text(serverName != null ? 'Servidor: $serverName' : 'Conexión establecida'),
        severity: InfoBarSeverity.success,
      );
    }

    return InfoBar(
      title: const Text('Sin conexión'),
      content: const Text('Trabajando en modo offline'),
      severity: InfoBarSeverity.warning,
      action: onRetry != null
          ? Button(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            )
          : null,
    );
  }

  /// InfoBar para mostrar estado de sincronización
  static Widget syncStatus({
    required int pendingCount,
    bool isSyncing = false,
    VoidCallback? onSync,
  }) {
    if (isSyncing) {
      return const InfoBar(
        title: Text('Sincronizando'),
        content: Text('Enviando datos al servidor...'),
        severity: InfoBarSeverity.info,
      );
    }

    if (pendingCount == 0) {
      return const InfoBar(
        title: Text('Sincronizado'),
        content: Text('Todos los datos están actualizados'),
        severity: InfoBarSeverity.success,
      );
    }

    return InfoBar(
      title: const Text('Pendiente de sincronizar'),
      content: Text('$pendingCount ${pendingCount == 1 ? 'registro' : 'registros'} pendientes'),
      severity: InfoBarSeverity.warning,
      action: onSync != null
          ? Button(
              onPressed: onSync,
              child: const Text('Sincronizar'),
            )
          : null,
    );
  }
}

/// Extension para mostrar InfoBar como snackbar temporal
extension InfoBarExtension on BuildContext {
  /// Muestra un InfoBar temporal en la parte superior
  void showInfoBar({
    required String message,
    String? title,
    InfoBarSeverity severity = InfoBarSeverity.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    displayInfoBar(
      this,
      builder: (context, close) => InfoBar(
        title: Text(title ?? _getTitleForSeverity(severity)),
        content: Text(message),
        severity: severity,
        onClose: close,
      ),
      duration: duration,
    );
  }

  /// Muestra InfoBar de error temporal
  void showErrorBar(String message, {String? title}) {
    showInfoBar(
      message: message,
      title: title ?? 'Error',
      severity: InfoBarSeverity.error,
    );
  }

  /// Muestra InfoBar de éxito temporal
  void showSuccessBar(String message, {String? title}) {
    showInfoBar(
      message: message,
      title: title ?? 'Éxito',
      severity: InfoBarSeverity.success,
    );
  }

  /// Muestra InfoBar de advertencia temporal
  void showWarningBar(String message, {String? title}) {
    showInfoBar(
      message: message,
      title: title ?? 'Advertencia',
      severity: InfoBarSeverity.warning,
    );
  }

  String _getTitleForSeverity(InfoBarSeverity severity) {
    return switch (severity) {
      InfoBarSeverity.info => 'Información',
      InfoBarSeverity.warning => 'Advertencia',
      InfoBarSeverity.error => 'Error',
      InfoBarSeverity.success => 'Éxito',
    };
  }
}
