import 'dart:io';

/// Escritorio/móvil nativo: el hostname del sistema operativo, tal como
/// pidió el dueño (14-sep-2026). `Platform.localHostname` puede fallar en
/// plataformas o sandboxes que no lo exponen — nunca deja el arranque sin
/// nombre, cae a una frase genérica.
///
/// [hostnameReader] es el gancho de prueba: `Platform.localHostname` es un
/// `static final` de `dart:io` que NO pasa por `IOOverrides` (a diferencia
/// de `Platform.operatingSystem` y otros), así que no hay forma de
/// sobreescribirlo desde fuera — de ahí este parámetro, en vez de depender
/// de un mecanismo que este SDK no ofrece para este getter en particular.
String defaultDeviceName({String Function()? hostnameReader}) {
  final read = hostnameReader ?? () => Platform.localHostname;
  try {
    final hostname = read().trim();
    return hostname.isEmpty ? 'Este equipo' : hostname;
  } catch (_) {
    return 'Este equipo';
  }
}
