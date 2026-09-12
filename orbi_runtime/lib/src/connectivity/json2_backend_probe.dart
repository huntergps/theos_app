import 'package:odoo_sdk/odoo_sdk.dart';

import '../contracts.dart';
import '../read/json2_read_adapters.dart';
import 'connectivity_monitor.dart';

/// Pregunta al Odoo si está vivo, en vez de suponerlo.
///
/// 🔴 Por qué existe. `BackendProbe` era una interfaz que **nadie
/// implementaba**, y el coordinador de sincronización se construía siempre
/// pasándole nulo. Así que el sondeo no es que no llegara a la pantalla: **no
/// corría nunca**. El pie de la aplicación mostraba una cadena escrita a mano,
/// «Red sin verificar», con el servidor respondiendo perfectamente. Medido el
/// 12-sep-2026.
///
/// La lectura es deliberadamente la más barata que existe y sobre un modelo que
/// cualquier usuario autenticado puede leer: **un sondeo que sólo funciona para
/// un administrador diría «sin servidor» a media plantilla**. No lee datos de
/// negocio ni deja rastro.
final class Json2BackendProbe implements BackendProbe {
  Json2BackendProbe(this.reader);

  final Json2ReadPort reader;

  @override
  Future<BackendProbeResult> probe(AppScope scope) async {
    try {
      await reader.searchRead(
        model: 'res.users',
        fields: const ['id'],
        limit: 1,
      );
      return BackendProbeResult.reachable();
    } on OdooAuthenticationException catch (error) {
      // El servidor CONTESTÓ, y dijo que no. Eso no es falta de red: es una
      // credencial caducada o revocada, y confundirlo con estar sin cobertura
      // manda a la persona a mirar el wifi en vez de a volver a entrar.
      return BackendProbeResult.unauthorized(errorCode: error.runtimeType.toString());
    } on OdooAccessDeniedException catch (error) {
      return BackendProbeResult.unauthorized(errorCode: error.runtimeType.toString());
    } on OdooException catch (error) {
      // Cualquier otro fallo del servidor cuenta como inalcanzable: **no se
      // presenta como que todo va bien**. Es preferible decir que no llegamos
      // que afirmar una salud que no se ha comprobado.
      return BackendProbeResult.unreachable(errorCode: error.runtimeType.toString());
    } catch (_) {
      return BackendProbeResult.unreachable();
    }
  }
}
