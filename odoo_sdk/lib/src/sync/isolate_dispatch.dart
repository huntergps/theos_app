/// Isolate dispatch shim for CPU-bound Odoo→modelo parsing.
///
/// Dispatches page parsing to a separate isolate on native platforms
/// (mobile/desktop), or runs it synchronously on Web (where Dart isolates
/// aren't available). This is a conditional-import shim — same pattern
/// already used elsewhere in this package
/// (`odoo_sdk/lib/src/websocket/platform/websocket_connect_stub.dart` +
/// `_web.dart` + `_io.dart`, selected from
/// `websocket_connection_manager.dart`) and in
/// `flutter_qweb/lib/src/services/report_file_manager.dart` +
/// `report_file_web.dart`.
///
/// Por qué existe: `theos_pos` compila para Flutter Web (tiene carpeta
/// `web/`). `Isolate.run()` lanza `UnsupportedError` en Web **en runtime**,
/// no en tiempo de compilación — si `GenericSyncRepository.syncModel()`
/// (código compartido, no platform-specific) llamara `Isolate.run()`
/// directo, la app Web rompería en producción de forma silenciosa (no hay
/// tests de integración Web para sync hoy). Este shim evita depender de
/// `package:flutter/foundation.dart` (`kIsWeb`) dentro de `odoo_sdk`,
/// manteniendo el sub-paquete `core.dart` libre de dependencias de Flutter.
library;

export 'isolate_dispatch_stub.dart'
    if (dart.library.js_interop) 'isolate_dispatch_web.dart'
    if (dart.library.io) 'isolate_dispatch_io.dart';
