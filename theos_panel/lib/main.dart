import 'dart:async';

import 'app/bootstrap.dart';
import 'app/global_error_handler.dart';

/// El arranque entero vive DENTRO de la misma zona protegida: `bootstrap()`
/// hace `WidgetsFlutterBinding.ensureInitialized()` y `runApp()`, y los dos
/// tienen que quedar en la zona que crea `runZonedGuarded` — si `bootstrap()`
/// se llamara fuera de este callback, Flutter avisaría "Zone mismatch". Los
/// manejadores de Flutter y del dispatcher se instalan ANTES, para no perder
/// ningún error de los primeros milisegundos del arranque.
void main() {
  runZonedGuarded(
    () async {
      installGlobalErrorHandlers();
      await bootstrap();
    },
    (error, stackTrace) => reportUnhandledError(
      'Uncaught asynchronous error',
      error,
      stackTrace,
    ),
  );
}
