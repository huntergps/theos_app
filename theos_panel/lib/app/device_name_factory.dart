/// El valor por omisión del nombre del equipo cuando nadie lo editó todavía
/// (`DeviceNameStore`) — elegido en COMPILACIÓN, igual que
/// `unlock_backend_factory.dart`: la variante web importa `dart:js_interop`,
/// que no compila para la VM ni para ningún destino nativo, y la nativa
/// importa `dart:io`, cuyo `Platform.localHostname` no existe en la web.
library;

export 'device_name_factory_io.dart'
    if (dart.library.js_interop) 'device_name_factory_web.dart';
