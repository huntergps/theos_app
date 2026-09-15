/// Lectura pura del `user-agent`, sin ningún import de plataforma —
/// deliberado: `device_name_factory_web.dart` importa `dart:js_interop`, que
/// no compila para la VM (misma restricción documentada en
/// `unlock_backend_factory.dart`), así que la parte que sí se puede probar
/// con `flutter test` normal vive aquí, separada.
library;

/// El nombre por omisión del equipo en la web, cuando no hay hostname que
/// leer (orden del dueño, 14-sep-2026): «Chrome en macOS», por ejemplo.
/// Nunca lanza — un `user-agent` que no reconoce ningún navegador ni sistema
/// cae a una frase genérica, nunca a una excepción que tumbe el arranque.
String describeUserAgentDeviceName(String userAgent) {
  final browser = _browserFrom(userAgent);
  final os = _osFrom(userAgent);
  if (browser == null && os == null) return 'Este navegador';
  if (browser == null) return os!;
  if (os == null) return browser;
  return '$browser en $os';
}

/// El orden importa: Edge y Opera también incluyen "Chrome/" en su
/// `user-agent` (son basados en Chromium), así que sus marcadores propios se
/// comprueban primero.
String? _browserFrom(String userAgent) {
  if (userAgent.contains('Edg/')) return 'Edge';
  if (userAgent.contains('OPR/') || userAgent.contains('Opera')) {
    return 'Opera';
  }
  if (userAgent.contains('Firefox/')) return 'Firefox';
  if (userAgent.contains('Chrome/')) return 'Chrome';
  // Safari también anuncia "Safari/" en Chrome; por eso se comprueba de
  // último, sólo cuando ninguno de los basados en Chromium coincidió.
  if (userAgent.contains('Safari/')) return 'Safari';
  return null;
}

String? _osFrom(String userAgent) {
  if (userAgent.contains('Android')) return 'Android';
  if (userAgent.contains('iPhone') || userAgent.contains('iPad')) {
    return 'iOS';
  }
  if (userAgent.contains('Mac OS X') || userAgent.contains('Macintosh')) {
    return 'macOS';
  }
  if (userAgent.contains('Windows')) return 'Windows';
  if (userAgent.contains('Linux')) return 'Linux';
  return null;
}
