// The optional private factory is intentionally selected in the initializer.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase;

typedef RuntimeClientFactory = OdooClient Function(
  AppScope scope,
  String apiKey,
);

/// Lee la huella de la base de Odoo detrás de un cliente ya autenticado —
/// por omisión, `create_date` del propio `res.users` del scope (ver
/// [defaultOdooDatabaseIdentityReader]). Inyectable para pruebas: nada aquí
/// hace un RPC real fuera del lector por omisión.
typedef OdooDatabaseIdentityReader = Future<String> Function(
  OdooClient client,
  AppScope scope,
);

/// Clave en `sync_metadata` (la misma tabla que ya usa `RuntimeMetadataStore`)
/// donde se guarda la huella de la base de Odoo activa para este scope.
const odooDatabaseIdentityMetadataKey = 'odoo_database_identity';

/// El lector real: `create_date` del usuario del propio scope. Al
/// reinstalar la base de Odoo, el usuario se recrea y esta fecha cambia; al
/// restaurar la MISMA base, la fecha es idéntica. Mismo patrón de lectura
/// que `OdooActiveIdentityReader` (`auth/capability_runtime.dart`): `read`
/// con kwargs reales, nunca `OdooClient.call(args: ...)`, que está
/// deprecado.
Future<String> defaultOdooDatabaseIdentityReader(
  OdooClient client,
  AppScope scope,
) async {
  final rows = await client.read(
    model: 'res.users',
    ids: [scope.userId],
    fields: ['id', 'create_date'],
  );
  if (rows.length != 1 || rows.single['id'] != scope.userId) {
    throw StateError('Odoo database identity mismatch');
  }
  final createDate = rows.single['create_date'];
  if (createDate is! String || createDate.trim().isEmpty) {
    throw const FormatException('Invalid res.users create_date');
  }
  return createDate;
}

/// Coordinates activation and teardown without owning credentials or UI state.
final class SessionRuntime {
  SessionRuntime({
    RuntimeDatabaseOwner? databaseOwner,
    RuntimeClientFactory? clientFactory,
    OdooDatabaseIdentityReader? identityReader,
  }) : _databaseOwner = databaseOwner ?? RuntimeDatabaseOwner(),
       _clientFactory = clientFactory,
       _identityReader = identityReader ?? defaultOdooDatabaseIdentityReader;

  final RuntimeDatabaseOwner _databaseOwner;
  final RuntimeClientFactory? _clientFactory;
  final OdooDatabaseIdentityReader _identityReader;
  SessionActivation? _active;
  int _activationEpoch = 0;

  final StreamController<OdooDatabaseReplaced> _databaseReplacements =
      StreamController<OdooDatabaseReplaced>.broadcast();
  OdooDatabaseReplaced? _pendingDatabaseReplacement;

  /// Se publica cuando `activate()` detecta que la base de Odoo de este
  /// scope se reinstaló o se reemplazó, DESPUÉS de haber borrado los datos
  /// locales que le correspondían. Sin UI aquí (ADR-01) — quien la escuche
  /// decide cómo avisarlo.
  ///
  /// 🔴 En la vida real esto pasa DURANTE `activate()`, casi siempre antes
  /// de que exista ningún oyente (el armazón todavía no se construyó) — un
  /// `StreamController.broadcast()` sin suscriptores en ese momento pierde
  /// el evento para siempre. [pendingDatabaseReplacement] es el respaldo:
  /// guarda el ÚLTIMO reemplazo sin reconocer para que quien se suscriba
  /// después (`_DatabaseReplacedNoticeNotifier`, `theos_panel/app/router.dart`)
  /// lo pueda leer en su primer `build()`, no sólo escuchando hacia
  /// adelante.
  Stream<OdooDatabaseReplaced> get databaseReplacements =>
      _databaseReplacements.stream;

  /// El último reemplazo de base sin reconocer, o `null` si no hay ninguno
  /// pendiente. Quien lo muestre debe compararlo contra el scope activo
  /// (`active?.scope`) antes de pintarlo: un reemplazo de OTRO scope (otro
  /// usuario, otro servidor) no es de esta sesión.
  OdooDatabaseReplaced? get pendingDatabaseReplacement =>
      _pendingDatabaseReplacement;

  /// Marca el reemplazo pendiente como visto — se llama al cerrar a mano el
  /// aviso. Sin esto, [pendingDatabaseReplacement] seguiría devolviendo el
  /// mismo evento para siempre.
  void acknowledgeDatabaseReplacement() {
    _pendingDatabaseReplacement = null;
  }

  SessionActivation? get active => _active;

  /// Exposes the already-owned database boundary to composition adapters.
  /// Callers must not construct another owner from this value.
  RuntimeDatabaseOwner get databaseOwner => _databaseOwner;

  Future<SessionActivation> activate(
    AppScope scope, {
    String? apiKey,
    bool webSession = false,
    String? csrfToken,
  }) async {
    final requestEpoch = ++_activationEpoch;
    final database = await _databaseOwner.open(scope);
    if (requestEpoch != _activationEpoch) {
      throw StateError('Session activation superseded by a newer request');
    }
    final client = apiKey == null && !webSession
        ? null
        : webSession
            ? _webSessionClient(scope, csrfToken)
            : (_clientFactory ?? _defaultClient)(scope, apiKey!);

    // Huella de la base de Odoo (14-sep-2026): SÓLO en línea, y SIEMPRE
    // antes de dejar la activación vigente — si la lectura falla (red, 401,
    // lo que sea), la activación entera falla con ese error y nunca se deja
    // ver ni usar la base local sin haberla verificado. `client == null`
    // (restore sin conexión) no lee ni compara nada: se respeta el
    // contrato de "sin cliente, sin RPC".
    if (client != null) {
      await _verifyDatabaseIdentity(
        scope: scope,
        client: client,
        database: database.database,
      );
      if (requestEpoch != _activationEpoch) {
        throw StateError('Session activation superseded by a newer request');
      }
    }

    final activation = SessionActivation(database: database, client: client);
    _active = activation;
    return activation;
  }

  Future<void> close() async {
    ++_activationEpoch;
    _active = null;
    await _databaseOwner.close();
  }

  bool accepts(SessionLease lease) => _active?.database.lease == lease;

  /// Applies the authenticated user's own `lang`/`tz` to the active
  /// session's client (see `OdooClient.updateLocale`). A no-op when there
  /// is no active client — nothing activated yet, or the current activation
  /// has none (offline with no bearer credential passed to [activate]).
  void applyUserLocale({String? language, String? timezone}) {
    _active?.client?.updateLocale(language: language, timezone: timezone);
  }

  static OdooClient _defaultClient(AppScope scope, String apiKey) => OdooClient(
    config: OdooClientConfig(
      baseUrl: scope.normalizedServerUrl,
      apiKey: apiKey,
      database: scope.database,
    ),
  );

  static OdooClient _webSessionClient(AppScope scope, String? csrfToken) =>
      OdooClient(
        config: OdooClientConfig(
          baseUrl: scope.normalizedServerUrl,
          apiKey: '',
          database: scope.database,
          csrfToken: csrfToken,
          transportMode: OdooTransportMode.webSession,
        ),
      );

  /// Compara la huella guardada de esta base local contra la que responde
  /// el servidor ahora mismo. Si difiere, borra. Si NO hay huella guardada
  /// (primera activación de esta función, o una instalación de antes de que
  /// existiera), no se asume inocencia a ciegas — huella nula (15-sep-2026,
  /// caso real: el equipo ya tenía cachés de una base que se reinstaló ANTES
  /// de que esta función existiera): un dato local sólo puede existir
  /// DESPUÉS de que su usuario existiera en Odoo, porque para escribirlo
  /// tuvo que entrar. Si la marca de escritura local MÁS ANTIGUA que ya hay
  /// en la base es anterior al alta de este usuario (con un margen de una
  /// hora por desfase de reloj), esos datos son de una base que ya no
  /// existe — se tratan exactamente igual que una huella distinta. Sin
  /// datos locales previos, o todos posteriores al alta: se guarda la
  /// huella y se sigue, sin borrar nada. Cualquier error de la lectura del
  /// servidor (red, 401, lo que sea) se propaga tal cual — quien llama deja
  /// fallar la activación entera con él.
  Future<void> _verifyDatabaseIdentity({
    required AppScope scope,
    required OdooClient client,
    required AppDatabase database,
  }) async {
    final serverIdentity = await _identityReader(client, scope);
    final storedRows = await database
        .customSelect(
          'SELECT value FROM sync_metadata WHERE key = ?',
          variables: [Variable<String>(odooDatabaseIdentityMetadataKey)],
        )
        .get();
    final storedIdentity = storedRows.isEmpty
        ? null
        : storedRows.first.read<String>('value');

    if (storedIdentity != null && storedIdentity == serverIdentity) return;

    if (storedIdentity == null) {
      final replaced = await _looksLikeDataFromAReplacedDatabase(
        database: database,
        userCreatedAt: serverIdentity,
      );
      if (!replaced) {
        await database.customStatement(
          'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
          [odooDatabaseIdentityMetadataKey, serverIdentity],
        );
        return;
      }
    }

    await _wipeAndPublishReplacement(
      scope: scope,
      database: database,
      newIdentity: serverIdentity,
    );
  }

  /// `true` cuando ya hay datos locales de ESCRITURA LOCAL (nunca `write_date`
  /// de Odoo) más viejos que el alta del usuario de este scope menos una
  /// hora de margen — es decir, datos que sólo pudieron escribirse contra
  /// una base de Odoo distinta de la actual, porque este usuario todavía no
  /// existía cuando se guardaron. `userCreatedAt` inválido, o sin ninguna
  /// marca local todavía, cuenta como "no": nunca se borra por una
  /// comparación que no se pudo hacer.
  Future<bool> _looksLikeDataFromAReplacedDatabase({
    required AppDatabase database,
    required String userCreatedAt,
  }) async {
    final createdAt = DateTime.tryParse(userCreatedAt)?.toUtc();
    if (createdAt == null) return false;
    final earliestLocal = await _earliestLocalWriteTimestamp(database);
    if (earliestLocal == null) return false;
    return earliestLocal.isBefore(
      createdAt.subtract(const Duration(hours: 1)),
    );
  }

  /// Tablas Drift reales cuya columna de fecha es una de ESCRITURA LOCAL
  /// (el equipo la puso, nunca Odoo) y que Drift guarda como `DateTime`
  /// nativo (por omisión, epoch — nunca texto):
  /// - `offline_queue.created_at`: `DateTime.now().toUtc()` al encolar
  ///   (`sale_runtime_adapters.dart`), no `write_date` ni nada del servidor.
  /// - `sync_audit_log.created_offline_at`: doc de la propia tabla
  ///   (`sync_tables.dart`), "When the operation was created locally".
  /// - `related_record_cache.cached_at`: cuándo ESTE equipo cacheó el
  ///   registro — distinto de su `write_date` (nullable, ese sí de Odoo).
  static const _localDateTimeColumns = <(String, String)>[
    ('offline_queue', 'created_at'),
    ('sync_audit_log', 'created_offline_at'),
    ('related_record_cache', 'cached_at'),
  ];

  /// Tablas propias de Orbi (creadas a mano por `RuntimeDatabaseOwner.open()`
  /// / `ensureEnvasesOperationsSchema`, fuera del esquema Drift) cuya columna
  /// de fecha es TEXTO ISO-8601 en UTC, siempre puesto por el propio equipo
  /// (`DateTime.now().toUtc().toIso8601String()`) al leer o crear algo — cada
  /// `orbi_envases_*_cache`/`orbi_stock_quant_cache.cached_at` lo dice en su
  /// propio comentario ("local retrieval time, never presented as server
  /// time"), y `orbi_envases_operations.creada_en` se pone al persistir la
  /// intención offline (`envases_operations_durable.dart`).
  ///
  /// `orbi_editable_draft` y `sync_metadata` quedan FUERA: ninguna de las dos
  /// tiene columna de fecha en su esquema, así que no hay nada que leer ahí.
  static const _localTextTimestampColumns = <(String, String)>[
    ('orbi_envases_dashboard_cache', 'cached_at'),
    ('orbi_stock_quant_cache', 'cached_at'),
    ('orbi_envases_por_recibir_cache', 'cached_at'),
    ('orbi_envases_movimientos_cache', 'cached_at'),
    ('orbi_envases_existencias_cache', 'cached_at'),
    ('orbi_envases_sedes_cache', 'cached_at'),
    ('orbi_envases_productos_cache', 'cached_at'),
    ('orbi_envases_saldo_terceros_cache', 'cached_at'),
    ('orbi_envases_operations', 'creada_en'),
  ];

  /// La marca de tiempo de escritura LOCAL más antigua que ya existe en esta
  /// base, mirando sólo las columnas de [_localDateTimeColumns] (Drift,
  /// epoch nativo) y [_localTextTimestampColumns] (texto ISO-8601 propio de
  /// Orbi) — nunca una columna que venga de Odoo (`write_date`). `null` si
  /// ninguna tabla tiene todavía una fila.
  Future<DateTime?> _earliestLocalWriteTimestamp(AppDatabase database) async {
    DateTime? earliest;
    void consider(DateTime? candidate) {
      if (candidate == null) return;
      if (earliest == null || candidate.isBefore(earliest!)) {
        earliest = candidate;
      }
    }

    for (final (table, column) in _localDateTimeColumns) {
      final row = await database
          .customSelect('SELECT MIN($column) AS m FROM $table')
          .getSingle();
      consider(row.readNullable<DateTime>('m'));
    }
    for (final (table, column) in _localTextTimestampColumns) {
      final row = await database
          .customSelect('SELECT MIN($column) AS m FROM $table')
          .getSingle();
      final raw = row.readNullable<String>('m');
      if (raw != null) consider(DateTime.tryParse(raw)?.toUtc());
    }
    return earliest;
  }

  /// Cuenta y describe lo que se va a perder ANTES de borrarlo, borra TODAS
  /// las tablas de esta base local en una sola transacción, guarda la huella
  /// nueva y publica [OdooDatabaseReplaced] — tanto por el stream (quien ya
  /// esté escuchando) como en [pendingDatabaseReplacement] (quien se
  /// suscriba después, ver esa doc).
  Future<void> _wipeAndPublishReplacement({
    required AppScope scope,
    required AppDatabase database,
    required String newIdentity,
  }) async {
    final queueRows = await database
        .customSelect(
          "SELECT model, method FROM offline_queue "
          "WHERE status != 'completed' LIMIT 20",
        )
        .get();
    final countRow = await database
        .customSelect(
          "SELECT COUNT(*) AS cnt FROM offline_queue "
          "WHERE status != 'completed'",
        )
        .getSingle();
    final discardedOperations = countRow.read<int>('cnt');
    final operationsSummary = [
      for (final row in queueRows)
        _queueEntryLabel(row.read<String>('model'), row.readNullable<String>('method')),
    ];

    await database.transaction(() async {
      final tableRows = await database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      for (final row in tableRows) {
        final name = row.read<String>('name');
        await database.customStatement('DELETE FROM "$name"');
      }
      await database.customStatement(
        'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
        [odooDatabaseIdentityMetadataKey, newIdentity],
      );
    });

    final event = OdooDatabaseReplaced(
      scope: scope,
      discardedOperations: discardedOperations,
      operationsSummary: operationsSummary,
    );
    _pendingDatabaseReplacement = event;
    if (!_databaseReplacements.isClosed) {
      _databaseReplacements.add(event);
    }
  }

  static String _queueEntryLabel(String model, String? method) =>
      method == null || method.isEmpty ? model : '$model.$method';
}

final class SessionActivation {
  const SessionActivation({required this.database, this.client});

  final RuntimeDatabase database;
  final OdooClient? client;

  AppScope get scope => database.scope;
  SessionLease get lease => database.lease;
}
