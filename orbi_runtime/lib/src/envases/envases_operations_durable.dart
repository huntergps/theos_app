/// Escritura sin conexión de envases: guarda en local y encola, siguiendo el
/// molde de `../sales/durable_collection_producers.dart`.
///
/// Decisión E01 (`docs/orbi_panel/decisions/E01-envases-capa-sobre-odoo.md`,
/// sección «Escritura sin conexión»): el servidor manda. Esta clase nunca
/// calcula existencias ni corrige un rechazo — sólo persiste la intención del
/// usuario y la encola con el `operationKey` acordado
/// (`envases.envio:<uuid>` / `envases.recepcion:<uuid>` / `envases.perdido:<uuid>`).
///
/// La tabla `orbi_envases_operations` es de Orbi, no de `theos_pos_core`: se
/// crea aquí mismo con SQL crudo, igual que `orbi_envases_dashboard_cache` en
/// `../storage/runtime_database_owner.dart` — nunca se toca `schemaVersion`
/// del esquema compartido. `ensureEnvasesOperationsSchema` queda expuesta para
/// que el dueño de `RuntimeDatabaseOwner.open()` la llame junto a las demás.
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OfflinePriority, OfflineReplayPolicy;
import 'package:theos_pos_core/theos_pos_core.dart';

import '../contracts.dart';
import '../sales/sale_runtime_adapters.dart' show SaleOdooActions;
import '../storage/runtime_database_owner.dart';
import 'envases_operations.dart';

/// Modelo/método que dispatch() de `EnvasesOfflineOperationAdapter` reconoce.
/// Públicos para que el adaptador (fichero aparte) no duplique estas cadenas.
const envasesEnvioModel = 'l10n_ec.stock.envases.wizard.envio';
const envasesEnvioMethod = 'action_enviar';
const envasesRecepcionModel = 'l10n_ec.stock.envases.wizard.recepcion';
const envasesRecepcionMethod = 'action_recibir';
const envasesPerdidoModel = 'stock.picking';
const envasesPerdidoMethod = 'action_envases_dar_por_perdido';
const envasesOperacionModel = 'l10n_ec.envases.operacion';

const _tableName = 'orbi_envases_operations';

/// Crea la tabla local de operaciones de envases si no existe. Se llama una
/// vez por conexión — el mismo punto donde `RuntimeDatabaseOwner.open()` crea
/// `orbi_envases_dashboard_cache`/`orbi_stock_quant_cache`.
Future<void> ensureEnvasesOperationsSchema(AppDatabase database) async {
  await database.customStatement('''
    CREATE TABLE IF NOT EXISTS $_tableName (
      scope_key TEXT NOT NULL,
      company_id INTEGER NOT NULL CHECK (company_id > 0),
      operation_uuid TEXT NOT NULL,
      tipo TEXT NOT NULL CHECK (tipo IN ('envio', 'recepcion', 'perdido')),
      estado TEXT NOT NULL,
      creada_en TEXT NOT NULL,
      mensaje_odoo TEXT,
      picking_id INTEGER,
      PRIMARY KEY (scope_key, operation_uuid)
    )
  ''');
}

/// Acceso a `orbi_envases_operations`, compartido por el productor (este
/// fichero) y el adaptador de despacho (`envases_offline_adapter.dart`): el
/// adaptador necesita marcar `enviada`/`rechazada`/`revisarAMano` sobre la
/// misma fila que el productor creó en `pendienteDeEnviar`.
final class EnvasesOperationsStore {
  const EnvasesOperationsStore();

  Future<EnvasesOperacionLocal?> getByUuid(
    AppDatabase database, {
    required String scopeKey,
    required String operationUuid,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM $_tableName WHERE scope_key = ? AND operation_uuid = ?',
          variables: [
            Variable<String>(scopeKey),
            Variable<String>(operationUuid),
          ],
        )
        .get();
    if (rows.isEmpty) return null;
    return _toLocal(rows.first.data);
  }

  Future<void> insert(
    AppDatabase database, {
    required String scopeKey,
    required int companyId,
    required String operationUuid,
    required String tipo,
    required DateTime creadaEn,
    int? pickingId,
  }) async {
    await database.customInsert(
      'INSERT INTO $_tableName '
      '(scope_key, company_id, operation_uuid, tipo, estado, creada_en, '
      'mensaje_odoo, picking_id) VALUES (?, ?, ?, ?, ?, ?, NULL, ?)',
      variables: [
        Variable<String>(scopeKey),
        Variable<int>(companyId),
        Variable<String>(operationUuid),
        Variable<String>(tipo),
        Variable<String>(
          _estadoToStorage(EnvasesOperacionEstado.pendienteDeEnviar),
        ),
        Variable<String>(creadaEn.toUtc().toIso8601String()),
        Variable<int>(pickingId),
      ],
    );
    database.notifyUpdates({const TableUpdate(_tableName)});
  }

  /// Marca la operación como aplicada con éxito. `pickingId` es opcional a
  /// propósito: cuando el servidor todavía no tiene `envases_operacion_uuid`
  /// (política `manual_after_ambiguous`), el despachador no siempre puede
  /// identificar el picking resultante — se conserva `NULL` con COALESCE en
  /// vez de perder el que ya hubiera.
  Future<void> markEnviada(
    AppDatabase database, {
    required String scopeKey,
    required String operationUuid,
    int? pickingId,
  }) async {
    await database.customUpdate(
      'UPDATE $_tableName SET estado = ?, mensaje_odoo = NULL, '
      'picking_id = COALESCE(?, picking_id) '
      'WHERE scope_key = ? AND operation_uuid = ?',
      variables: [
        Variable<String>(_estadoToStorage(EnvasesOperacionEstado.enviada)),
        Variable<int>(pickingId),
        Variable<String>(scopeKey),
        Variable<String>(operationUuid),
      ],
    );
    database.notifyUpdates({const TableUpdate(_tableName)});
  }

  /// Un rechazo de Odoo (UserError/ValidationError) — terminal, sin
  /// reintentar. Ver `EnvasesOfflineOperationAdapter._runGuarded`.
  Future<void> markRechazada(
    AppDatabase database, {
    required String scopeKey,
    required String operationUuid,
    required String mensaje,
  }) async {
    await database.customUpdate(
      'UPDATE $_tableName SET estado = ?, mensaje_odoo = ? '
      'WHERE scope_key = ? AND operation_uuid = ?',
      variables: [
        Variable<String>(_estadoToStorage(EnvasesOperacionEstado.rechazada)),
        Variable<String>(mensaje),
        Variable<String>(scopeKey),
        Variable<String>(operationUuid),
      ],
    );
    database.notifyUpdates({const TableUpdate(_tableName)});
  }

  /// Un fallo ambiguo (red, timeout) contra un servidor sin
  /// `envases_operacion_uuid`: no hay evidencia durable con la que
  /// reconciliar, así que no se reintenta sola — queda para revisión manual.
  Future<void> markRevisarAMano(
    AppDatabase database, {
    required String scopeKey,
    required String operationUuid,
    String? mensaje,
  }) async {
    await database.customUpdate(
      'UPDATE $_tableName SET estado = ?, mensaje_odoo = ? '
      'WHERE scope_key = ? AND operation_uuid = ?',
      variables: [
        Variable<String>(
          _estadoToStorage(EnvasesOperacionEstado.revisarAMano),
        ),
        Variable<String>(mensaje),
        Variable<String>(scopeKey),
        Variable<String>(operationUuid),
      ],
    );
    database.notifyUpdates({const TableUpdate(_tableName)});
  }

  /// Mismo patrón `Stream.multi` + `tableUpdates` que `EnvasesDashboardCache`
  /// (`envases_dashboard_cache.dart`): re-lee de SQLite en cada notificación,
  /// que sigue siendo la fuente de verdad local.
  Stream<List<EnvasesOperacionLocal>> watch(
    RuntimeDatabaseOwner owner,
    SessionLease lease,
    CompanyContext company,
  ) {
    return Stream.multi((controller) {
      RuntimeDatabase? active() {
        final current = owner.active;
        if (current == null || !owner.accepts(lease)) return null;
        if (current.scope.scopeKey != company.scopeKey) return null;
        return current;
      }

      final initial = active();
      if (initial == null) {
        controller.close();
        return;
      }
      var closed = false;
      Future<void> emit() async {
        if (closed) return;
        final current = active();
        if (current == null) return;
        final rows = await _list(
          current.database,
          scopeKey: company.scopeKey,
          companyId: company.companyId,
        );
        if (!closed) controller.add(rows);
      }

      var pending = Future<void>.value();
      void scheduleEmit() {
        pending = pending.then((_) => emit()).catchError((
          Object error,
          StackTrace stack,
        ) {
          if (!closed) controller.addError(error, stack);
        });
      }

      final updates = initial.database
          .tableUpdates(const TableUpdateQuery.onTableName(_tableName))
          .listen(
            (_) => scheduleEmit(),
            onError: controller.addError,
            onDone: () {
              if (!closed) controller.close();
            },
          );
      controller.onCancel = () async {
        closed = true;
        await updates.cancel();
      };
      scheduleEmit();
    });
  }

  Future<List<EnvasesOperacionLocal>> _list(
    AppDatabase database, {
    required String scopeKey,
    required int companyId,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM $_tableName WHERE scope_key = ? AND company_id = ? '
          'ORDER BY creada_en DESC',
          variables: [Variable<String>(scopeKey), Variable<int>(companyId)],
        )
        .get();
    return rows.map((row) => _toLocal(row.data)).toList(growable: false);
  }

  EnvasesOperacionLocal _toLocal(Map<String, dynamic> data) {
    return EnvasesOperacionLocal(
      operacionUuid: data['operation_uuid'] as String,
      tipo: data['tipo'] as String,
      estado: _estadoFromStorage(data['estado'] as String),
      creadaEn: DateTime.parse(data['creada_en'] as String),
      mensajeOdoo: data['mensaje_odoo'] as String?,
      pickingId: data['picking_id'] as int?,
    );
  }
}

String _estadoToStorage(EnvasesOperacionEstado estado) => switch (estado) {
  EnvasesOperacionEstado.pendienteDeEnviar => 'pendiente_de_enviar',
  EnvasesOperacionEstado.enviada => 'enviada',
  EnvasesOperacionEstado.rechazada => 'rechazada',
  EnvasesOperacionEstado.revisarAMano => 'revisar_a_mano',
};

EnvasesOperacionEstado _estadoFromStorage(String value) => switch (value) {
  'enviada' => EnvasesOperacionEstado.enviada,
  'rechazada' => EnvasesOperacionEstado.rechazada,
  'revisar_a_mano' => EnvasesOperacionEstado.revisarAMano,
  _ => EnvasesOperacionEstado.pendienteDeEnviar,
};

/// Implementación durable del contrato `EnvasesOperations`
/// (`envases_operations.dart`): Drift + cola offline, atada a la sesión y
/// compañía activas igual que `EnvasesDashboardCache`.
final class DurableEnvasesOperations implements EnvasesOperations {
  DurableEnvasesOperations({
    required this.owner,
    required this.lease,
    required this.company,
    required this.actions,
    this.store = const EnvasesOperationsStore(),
  }) {
    if (company.scopeKey != lease.scope.scopeKey) {
      throw ArgumentError('Company context does not belong to the lease scope');
    }
  }

  final RuntimeDatabaseOwner owner;
  final SessionLease lease;
  final CompanyContext company;
  final SaleOdooActions actions;
  final EnvasesOperationsStore store;

  /// Se sondea una sola vez por instancia Y POR MODELO DE ASISTENTE (envío
  /// y recepción pueden estar en versiones distintas del módulo, así que no
  /// comparten política) y se memoriza — sólo si el sondeo respondió. Un
  /// fallo de red no se memoriza, para poder reintentarlo en una llamada
  /// posterior con conexión.
  final Map<String, OfflineReplayPolicy> _cachedWizardReplayPolicy = {};

  RuntimeDatabase _active() {
    final active = owner.active;
    if (active == null || !owner.accepts(lease)) {
      throw StateError('Session lease is no longer active');
    }
    if (active.scope.scopeKey != company.scopeKey) {
      throw StateError('Envases operations scope is no longer active');
    }
    return active;
  }

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async {
    final uuid = command.operacionUuid.trim();
    if (uuid.isEmpty) {
      throw ArgumentError.value(
        command.operacionUuid,
        'operacionUuid',
        'no puede estar vacío',
      );
    }
    if (command.lineas.isEmpty) {
      throw ArgumentError.value(
        command.lineas,
        'lineas',
        'un envío necesita al menos una línea',
      );
    }
    final replayPolicy = await _resolveWizardReplayPolicy(envasesEnvioModel);
    final active = _active();
    late EnvasesOperacionLocal result;
    await active.database.transaction(() async {
      final existing = await store.getByUuid(
        active.database,
        scopeKey: company.scopeKey,
        operationUuid: uuid,
      );
      if (existing != null) {
        result = existing;
        return;
      }
      final creadaEn = DateTime.now().toUtc();
      await store.insert(
        active.database,
        scopeKey: company.scopeKey,
        companyId: company.companyId,
        operationUuid: uuid,
        tipo: 'envio',
        creadaEn: creadaEn,
      );
      final queue = OfflineQueueDataSource(active.database);
      await queue.queueOperation(
        model: envasesEnvioModel,
        method: envasesEnvioMethod,
        values: {
          'operacion_uuid': uuid,
          'origen_id': command.origenId,
          'destino_id': command.destinoId,
          'fecha_salida': command.fechaSalida.toUtc().toIso8601String(),
          'responsable_id': lease.scope.userId,
          'lineas': [
            for (final linea in command.lineas)
              {'product_id': linea.productId, 'cantidad': linea.cantidad},
          ],
        },
        operationKey: 'envases.envio:$uuid',
        priority: OfflinePriority.high,
        replayPolicy: replayPolicy,
      );
      result = EnvasesOperacionLocal(
        operacionUuid: uuid,
        tipo: 'envio',
        estado: EnvasesOperacionEstado.pendienteDeEnviar,
        creadaEn: creadaEn,
      );
    });
    return result;
  }

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async {
    final uuid = command.operacionUuid.trim();
    if (uuid.isEmpty) {
      throw ArgumentError.value(
        command.operacionUuid,
        'operacionUuid',
        'no puede estar vacío',
      );
    }
    if (command.pickingId <= 0) {
      throw ArgumentError.value(command.pickingId, 'pickingId');
    }
    if (command.lineas.isEmpty) {
      throw ArgumentError.value(
        command.lineas,
        'lineas',
        'una recepción necesita al menos una línea',
      );
    }
    final replayPolicy = await _resolveWizardReplayPolicy(
      envasesRecepcionModel,
    );
    final active = _active();
    late EnvasesOperacionLocal result;
    await active.database.transaction(() async {
      final existing = await store.getByUuid(
        active.database,
        scopeKey: company.scopeKey,
        operationUuid: uuid,
      );
      if (existing != null) {
        result = existing;
        return;
      }
      final creadaEn = DateTime.now().toUtc();
      await store.insert(
        active.database,
        scopeKey: company.scopeKey,
        companyId: company.companyId,
        operationUuid: uuid,
        tipo: 'recepcion',
        creadaEn: creadaEn,
        pickingId: command.pickingId,
      );
      final queue = OfflineQueueDataSource(active.database);
      await queue.queueOperation(
        model: envasesRecepcionModel,
        method: envasesRecepcionMethod,
        recordId: command.pickingId,
        values: {
          'operacion_uuid': uuid,
          'picking_id': command.pickingId,
          'responsable_id': lease.scope.userId,
          'lineas': [
            for (final linea in command.lineas)
              {
                'product_id': linea.productId,
                'llegaron': linea.llegaron,
                'danadas': linea.danadas,
              },
          ],
        },
        operationKey: 'envases.recepcion:$uuid',
        priority: OfflinePriority.high,
        replayPolicy: replayPolicy,
      );
      result = EnvasesOperacionLocal(
        operacionUuid: uuid,
        tipo: 'recepcion',
        estado: EnvasesOperacionEstado.pendienteDeEnviar,
        creadaEn: creadaEn,
        pickingId: command.pickingId,
      );
    });
    return result;
  }

  @override
  Future<EnvasesOperacionLocal> darPorPerdido({
    required String operacionUuid,
    required int pickingId,
  }) async {
    final uuid = operacionUuid.trim();
    if (uuid.isEmpty) {
      throw ArgumentError.value(operacionUuid, 'operacionUuid', 'no puede estar vacío');
    }
    if (pickingId <= 0) {
      throw ArgumentError.value(pickingId, 'pickingId');
    }
    final active = _active();
    late EnvasesOperacionLocal result;
    await active.database.transaction(() async {
      final existing = await store.getByUuid(
        active.database,
        scopeKey: company.scopeKey,
        operationUuid: uuid,
      );
      if (existing != null) {
        result = existing;
        return;
      }
      final creadaEn = DateTime.now().toUtc();
      await store.insert(
        active.database,
        scopeKey: company.scopeKey,
        companyId: company.companyId,
        operationUuid: uuid,
        tipo: 'perdido',
        creadaEn: creadaEn,
        pickingId: pickingId,
      );
      final queue = OfflineQueueDataSource(active.database);
      // Siempre retry_safe: reconcile() se apoya en `stock.picking.state`
      // (campo nativo, nunca depende de `envases_operacion_uuid`) — ver
      // `EnvasesOfflineOperationAdapter._reconcilePerdido`.
      await queue.queueOperation(
        model: envasesPerdidoModel,
        method: envasesPerdidoMethod,
        recordId: pickingId,
        values: {'operacion_uuid': uuid, 'picking_id': pickingId},
        operationKey: 'envases.perdido:$uuid',
        priority: OfflinePriority.high,
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      result = EnvasesOperacionLocal(
        operacionUuid: uuid,
        tipo: 'perdido',
        estado: EnvasesOperacionEstado.pendienteDeEnviar,
        creadaEn: creadaEn,
        pickingId: pickingId,
      );
    });
    return result;
  }

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() =>
      store.watch(owner, lease, company);

  /// Ajuste del 14-sep-2026 sobre el D original: la sesión de Odoo confirmó
  /// el contrato final de `l10n_ec_stock_envases` 19.5.1.3.0 — la
  /// protección contra duplicados vive en `envases_operacion_uuid` DE CADA
  /// ASISTENTE (`l10n_ec.stock.envases.wizard.envio`/`.wizard.recepcion`/
  /// `.wizard.custodia`); escribirlo ahí es lo que activa la protección. La
  /// reconciliación, en cambio, va a apoyarse en el modelo nuevo
  /// `l10n_ec.envases.operacion` (campo `uuid`, UNIQUE): esa fila existe
  /// sólo si la operación se confirmó — `stock.picking` ya no es la fuente
  /// de verdad para reconciliar (eso lo cambia un encargo aparte, todavía
  /// sin diseñar; acá sólo cambia el SONDEO). Por eso `retry_safe` exige
  /// que las DOS sondas confirmen el campo: confiar sólo en el asistente
  /// dejaría de encontrar con qué reconciliar, y confiar sólo en
  /// `l10n_ec.envases.operacion` dejaría mandar un `create` que el
  /// asistente rechaza con `Invalid field`. Se memoriza por MODELO DE
  /// ASISTENTE (envío y recepción pueden estar en versiones distintas del
  /// módulo, comprobado: nada obliga a que las dos migraciones lleguen
  /// juntas). Sin red — o si `l10n_ec.envases.operacion` todavía no existe,
  /// que Odoo reporta lanzando en el `fields_get`—, no se memoriza el
  /// fallo: la próxima operación puede volver a sondear.
  Future<OfflineReplayPolicy> _resolveWizardReplayPolicy(
    String wizardModel,
  ) async {
    final cached = _cachedWizardReplayPolicy[wizardModel];
    if (cached != null) return cached;
    try {
      final wizardHasField = await _probeHasField(
        model: wizardModel,
        field: 'envases_operacion_uuid',
      );
      final operacionHasField = await _probeHasField(
        model: envasesOperacionModel,
        field: 'uuid',
      );
      final resolved = (wizardHasField && operacionHasField)
          ? OfflineReplayPolicy.retrySafe
          : OfflineReplayPolicy.manualAfterAmbiguous;
      _cachedWizardReplayPolicy[wizardModel] = resolved;
      return resolved;
    } catch (_) {
      return OfflineReplayPolicy.manualAfterAmbiguous;
    }
  }

  Future<bool> _probeHasField({
    required String model,
    required String field,
  }) async {
    final metadata = await actions.call(
      model: model,
      method: 'fields_get',
      kwargs: {
        'allfields': [field],
        'attributes': <String>[],
      },
    );
    return metadata is Map && metadata.containsKey(field);
  }
}
