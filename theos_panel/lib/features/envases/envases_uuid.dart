import 'dart:math';

/// Un identificador nuevo por cada operación de envases que la persona
/// confirma en pantalla (E01: `envases_operacion_uuid`, el MISMO en todos los
/// reintentos de esa operación — la app lo genera una sola vez, al confirmar,
/// nunca en cada reintento de la cola).
///
/// UUID v4 hecho a mano con `Random.secure()`: el paquete `uuid` no es
/// dependencia directa de este paquete (sólo llega transitivo vía
/// `odoo_sdk`/`theos_pos_core`), y añadirlo sólo para esto tocaría el
/// lockfile por un cambio ajeno al encargo — regla del repositorio.
String generateEnvasesOperacionUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
