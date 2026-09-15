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

  /// Se publica cuando `activate()` detecta que la base de Odoo de este
  /// scope se reinstaló o se reemplazó, DESPUÉS de haber borrado los datos
  /// locales que le correspondían. Sin UI aquí (ADR-01) — quien la escuche
  /// decide cómo avisarlo.
  Stream<OdooDatabaseReplaced> get databaseReplacements =>
      _databaseReplacements.stream;

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
  /// el servidor ahora mismo. Sin fila guardada (primera activación, o una
  /// instalación de antes de que existiera esta huella): la guarda y sigue,
  /// sin borrar nada — nunca se trata "no sé" como "cambió". Si difiere, la
  /// base de Odoo se reinstaló o se reemplazó: borra TODAS las tablas de
  /// usuario de esta base local en una sola transacción y publica
  /// [OdooDatabaseReplaced]. Cualquier error de la lectura (red, 401, lo
  /// que sea) se propaga tal cual — quien llama deja fallar la activación
  /// entera con él.
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

    if (storedIdentity == null) {
      await database.customStatement(
        'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
        [odooDatabaseIdentityMetadataKey, serverIdentity],
      );
      return;
    }
    if (storedIdentity == serverIdentity) return;

    // Difiere: cuenta y describe lo que se va a perder ANTES de borrarlo —
    // la cola ya no vale nada contra la base nueva (mismos ids de usuario,
    // otra base detrás), pero quien avise necesita poder decir qué era.
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
        [odooDatabaseIdentityMetadataKey, serverIdentity],
      );
    });

    if (!_databaseReplacements.isClosed) {
      _databaseReplacements.add(
        OdooDatabaseReplaced(
          scope: scope,
          discardedOperations: discardedOperations,
          operationsSummary: operationsSummary,
        ),
      );
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
