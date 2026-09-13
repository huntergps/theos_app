import 'package:odoo_sdk/odoo_sdk.dart' show OfflineReplayPolicy;
import 'package:theos_pos_core/theos_pos_core.dart';

import '../sales/sale_runtime_adapters.dart' show SaleOdooActions;

/// `res.users.im_status` / `manual_im_status` — el mismo estado que muestra
/// theos_pos (`theos_pos/lib/shared/models/im_status.dart`). Sin íconos ni
/// colores aquí: eso es UI y no le corresponde a `orbi_runtime`.
enum OdooPresence {
  online,
  away,
  busy,
  offline;

  /// Valor exacto que espera `res.users`/`mobile_set_im_status`.
  String get odooValue => name;

  /// Un valor que el servidor no reconoce NO se interpreta como `online`
  /// ni como ningún otro miembro: se devuelve `null` para que el llamador
  /// decida, en vez de fingir un estado que no fue el que mandó el servidor.
  static OdooPresence? fromOdoo(String? value) {
    for (final presence in OdooPresence.values) {
      if (presence.odooValue == value) return presence;
    }
    return null;
  }
}

/// Leer y cambiar el estado de presencia del usuario de Odoo.
///
/// [read] es ONLINE-ONLY de verdad: `manual_im_status` de OTRO usuario es un
/// dato en vivo, no algo que este runtime pueda cachear sin tocar el esquema
/// local (`ResUsers` no trae esa columna, y no se le puede agregar sin subir
/// `schemaVersion` — fuera de alcance de este cambio).
///
/// [set] SIEMPRE es local-primero: escribe MI propio estado en la cola
/// durable y devuelve en cuanto quedó encolado — nunca llama al servidor
/// directamente. El RPC real (`mobile_set_im_status`) lo hace el
/// despachador (`OdooOfflineOperationAdapter` en
/// `../sales/sale_runtime_adapters.dart`) al drenar la cola, esté el
/// dispositivo en línea o no en el momento de elegir el estado.
final class UserPresencePort {
  const UserPresencePort({required this.actions, required this.queue});

  final SaleOdooActions actions;
  final OfflineQueueDataSource queue;

  static String _operationKey(int userId) => 'presence:$userId';

  /// Deliberadamente NO lee `res.users.im_status`: ese campo es COMPUTADO a
  /// partir de `presence_ids.status` (`mail/models/res_users.py:129-142`),
  /// que se alimenta de los heartbeats de `update_presence` por websocket.
  /// Orbi habla JSON-2 con Bearer y nunca manda esos heartbeats, así que
  /// `im_status` mostraría a un usuario activo como "offline"/"away" —
  /// mentira, no presencia real.
  ///
  /// Lo que se muestra en Orbi es lo que el usuario ELIGIÓ:
  /// `manual_im_status` (`mail/models/res_users.py:65-68`), que sólo admite
  /// `away`/`busy`/`offline`/`False`. `False` significa "sin estado manual",
  /// y eso es "en línea" — el mismo criterio que usa el propio
  /// `mobile_set_im_status` al guardar (`l10n_ec_collection_box_pos/models/
  /// res_users.py:270`: `manual_im_status = False if status == "online" else
  /// status`). Si el campo no viene en la respuesta, o no es ni `String` ni
  /// `false`, se devuelve `null`.
  Future<OdooPresence?> read(int userId) async {
    final result = await actions.call(
      model: 'res.users',
      method: 'read',
      ids: [userId],
      kwargs: const {
        'fields': ['manual_im_status'],
      },
    );
    if (result is! List || result.isEmpty) return null;
    final record = result.first;
    if (record is! Map || !record.containsKey('manual_im_status')) return null;
    final value = record['manual_im_status'];
    if (value == false) return OdooPresence.online;
    if (value is String) return OdooPresence.fromOdoo(value);
    return null;
  }

  /// Encola MI cambio de estado. Si ya hay una operación pendiente para
  /// este usuario (todavía no se drenó), REEMPLAZA su valor en vez de
  /// encolar una segunda — gana la ÚLTIMA elección, no la primera. Sin esto,
  /// `queueOperation` con el mismo `operationKey` conserva la fila
  /// EXISTENTE y descarta la nueva (`OfflineQueueDataSource.queueOperation`,
  /// `theos_pos_core/lib/src/database/datasources/offline_queue_datasource.dart:60-71`)
  /// — exactamente al revés de lo que presencia necesita. `write`/`unlink`
  /// tienen a `compressQueue()` para esto; un método como
  /// `mobile_set_im_status` no pasa por ese compresor (sólo agrupa
  /// `method=='write'`), así que hay que resolverlo acá, con el mismo
  /// patrón que ya usa `theos_pos/lib/features/collection/repositories/
  /// collection_repository.dart:543,1359` (`replaceOperationValues`).
  Future<void> set(int userId, OdooPresence status) async {
    final key = _operationKey(userId);
    final values = {'status': status.odooValue};
    final pending = await queue.getOperationsForModel('res.users');
    for (final operation in pending) {
      if (operation.operationKey == key &&
          operation.method == 'mobile_set_im_status') {
        await queue.replaceOperationValues(operation.id, values);
        return;
      }
    }
    await queue.queueOperation(
      model: 'res.users',
      method: 'mobile_set_im_status',
      recordId: userId,
      values: values,
      operationKey: key,
      // Repetir el mismo estado es inofensivo — no hay documento ni
      // contabilidad de por medio, a diferencia de un pago.
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
  }

  /// El estado que el usuario eligió y todavía no se sincronizó — lo que
  /// [set] dejó en la cola. `null` si no hay ninguna operación pendiente
  /// (el último estado ya se aplicó, o nunca se cambió).
  Future<OdooPresence?> readPending(int userId) async {
    final key = _operationKey(userId);
    final pending = await queue.getOperationsForModel('res.users');
    for (final operation in pending) {
      if (operation.operationKey == key &&
          operation.method == 'mobile_set_im_status') {
        final status = operation.values['status'];
        return OdooPresence.fromOdoo(status is String ? status : null);
      }
    }
    return null;
  }
}
