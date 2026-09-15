import 'package:web/web.dart' as web;

import 'user_agent_device_name.dart';

/// Web: no hay hostname que leer, así que el valor por omisión sale del
/// `user-agent` del navegador (orden del dueño, 14-sep-2026) — «Chrome en
/// macOS», por ejemplo. El análisis en sí es puro y vive en
/// `user_agent_device_name.dart`, que sí se puede probar con `flutter test`
/// normal; este archivo sólo lo conecta al navegador real.
///
/// [hostnameReader] no aplica en la web (no hay hostname) — se acepta sólo
/// para que `DeviceNameStore` pueda llamar a la misma firma sin importar
/// qué variante resolvió la exportación condicional.
String defaultDeviceName({String Function()? hostnameReader}) =>
    describeUserAgentDeviceName(web.window.navigator.userAgent);
