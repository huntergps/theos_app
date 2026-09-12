import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// Si el aparato tiene transporte de red, vigilado en el tiempo.
///
/// Por defecto **no emite nada**, y eso es deliberado: sin emisión el estado
/// de conexión queda en «sin verificar», que es la verdad en una prueba de
/// widget o en una plataforma sin el complemento. Arrancarlo con un valor
/// optimista fabricaría salud donde no se ha medido nada.
///
/// `bootstrap.dart` lo sustituye por el monitor real, igual que ya hace con
/// [networkPresenceProbeProvider] para la pantalla de acceso.
final networkSignalProvider = StreamProvider<NetworkSignal>(
  (ref) => const Stream<NetworkSignal>.empty(),
);

/// La sustitución que registra `bootstrap.dart` en un aparato de verdad.
///
/// ⚠️ Esto dice si hay una interfaz de red, **no** si hay internet ni si el
/// Odoo está vivo. En el navegador es casi siempre que sí, con el servidor
/// caído o no. Quien lo consuma tiene que combinarlo con el sondeo del
/// servidor; por sí solo no autoriza a decir «conectado».
final networkSignalOverride = networkSignalProvider.overrideWith((ref) {
  try {
    return ConnectivityMonitor().watch();
  } catch (_) {
    // Sin complemento en esta plataforma: mejor callar que inventar.
    return const Stream<NetworkSignal>.empty();
  }
});
