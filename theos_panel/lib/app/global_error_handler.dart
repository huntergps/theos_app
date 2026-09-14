import 'package:flutter/foundation.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

/// Firma del registro de errores no atrapados. Se inyecta en las pruebas
/// para no depender del logger real — mismo patrón que
/// `theos_pos/lib/core/services/global_error_handler.dart`.
typedef UnhandledErrorReporter = void Function(
  String source,
  Object error,
  StackTrace stackTrace,
);

/// Instala las fronteras de error de Flutter y del dispatcher de la
/// plataforma para todo el proceso de Orbi.
///
/// Los errores de zona (asíncronos, sin try/catch alrededor) NO se instalan
/// aquí: los atrapa `runZonedGuarded` en `main.dart`, porque tienen que
/// arrancar en la MISMA zona donde se inicializa el binding de Flutter y se
/// llama `runApp` — si no, Flutter avisa "Zone mismatch".
void installGlobalErrorHandlers({UnhandledErrorReporter? reporter}) {
  final report = reporter ?? reportUnhandledError;

  FlutterError.onError = (details) {
    // En debug conservamos la consola roja de Flutter: no queremos esconder
    // errores mientras se está desarrollando.
    FlutterError.presentError(details);
    report(
      'Flutter framework',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    report('Platform dispatcher', error, stackTrace);
    return true;
  };
}

/// Reporta un error no atrapado a través del logger centralizado (que ya
/// redacta datos sensibles), sea que venga del framework, del dispatcher de
/// la plataforma o de la zona protegida de `runZonedGuarded` en `main.dart`.
void reportUnhandledError(String source, Object error, StackTrace stackTrace) {
  logger.e('[Unhandled]', source, error, stackTrace);
}
