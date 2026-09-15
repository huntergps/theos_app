// Huella de la base de Odoo (14-sep-2026): si la base detrás de un `AppScope`
// se reinstala o se reemplaza por otra con el mismo nombre de
// servidor/base/usuario, los ids de Odoo pueden coincidir (admin 2,
// usuarios 5..8) y Orbi reabriría la MISMA base local mezclando ids viejos
// con la base nueva. `SessionRuntime.activate()` compara `create_date` del
// propio usuario del scope contra lo guardado en `sync_metadata`
// (`odooDatabaseIdentityMetadataKey`) y, si difiere, borra TODAS las tablas
// de esa base local en una transacción — ANTES de dejar la activación
// vigente — y publica `OdooDatabaseReplaced`.
import 'dart:async';

// El test deliberadamente usa el executor real de Drift en memoria.
// ignore: depend_on_referenced_packages
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show parseOdooDateTime;
import 'package:orbi_runtime/orbi_runtime.dart';

AppScope _scope(int userId) => AppScope(
  appId: 'orbi-panel',
  installationId: 'installation-a',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: userId,
);

RuntimeClientFactory _harmlessClientFactory({void Function()? onCall}) =>
    (scope, apiKey) {
      onCall?.call();
      return OdooClient(
        config: OdooClientConfig(
          baseUrl: scope.normalizedServerUrl,
          apiKey: apiKey,
          database: scope.database,
        ),
      );
    };

Future<void> _seedIdentity(dynamic database, String value) => database
    .customStatement(
      'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
      [odooDatabaseIdentityMetadataKey, value],
    );

Future<String?> _readIdentity(dynamic database) async {
  final rows = await database
      .customSelect(
        'SELECT value FROM sync_metadata WHERE key = ?',
        variables: [Variable<String>(odooDatabaseIdentityMetadataKey)],
      )
      .get();
  return rows.isEmpty ? null : rows.first.read<String>('value');
}

/// Fila real de `offline_queue` con un `created_at` controlado — vía la API
/// tipada de Drift (`OfflineQueueCompanion.insert`), NUNCA con SQL crudo:
/// `created_at` es un `DateTimeColumn` de verdad (guardado como epoch, no
/// texto), y `_earliestLocalWriteTimestamp` lo lee de vuelta con
/// `readNullable<DateTime>`. Un `INSERT` a mano con un literal ISO-8601 se
/// guardaría como TEXTO y esa lectura tipada fallaría.
Future<void> _seedOfflineQueueRow(AppDatabase database, DateTime createdAt) =>
    database
        .into(database.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'sale.order',
            method: const Value('create'),
            values: '{}',
            createdAt: createdAt,
          ),
        );

/// `create_date` tal como lo manda Odoo de verdad: "YYYY-MM-DD HH:MM:SS" en
/// UTC, SIN 'Z' ni offset — nunca `.toIso8601String()` (que sí lleva 'Z').
String _odooRawUtc(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-'
      '${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
}

void main() {
  // Revisión del dueño (15-sep-2026): `create_date` de Odoo llega SIN
  // indicador de zona aunque ya está en UTC. `DateTime.tryParse(raw)?.toUtc()`
  // (el código de `_looksLikeDataFromAReplacedDatabase` hasta el commit
  // 9dd7b86) interpreta ese texto como hora LOCAL del proceso — en Guayaquil
  // (UTC−5) el resultado queda 5 horas DESPUÉS del instante real. El arreglo
  // usa `parseOdooDateTime` (`odoo_sdk/lib/src/utils/odoo_parsing_utils.dart`,
  // ya usado por el resto de `orbi_runtime` para `write_date`), que normaliza
  // el espacio a 'T' y añade 'Z' antes de parsear — nunca se creó un
  // `parseOdooUtcDateTime` nuevo porque éste ya cumple el contrato pedido.
  test('odoo create_date without zone is parsed as UTC', () {
    const raw = '2026-09-14 20:10:00';
    final parsed = parseOdooDateTime(raw);

    expect(parsed, isNotNull);
    expect(parsed!.isUtc, isTrue);
    expect(parsed, DateTime.utc(2026, 9, 14, 20, 10));

    // Hace explícita la diferencia con el código viejo: sólo se puede
    // comprobar de verdad cuando el proceso NO corre en UTC (por eso esta
    // suite se corre también con `TZ=America/Guayaquil` — ver el cierre de
    // esta tarea). En un proceso que ya estuviera en UTC, `legacyBuggyParse`
    // coincidiría con `parsed` por pura casualidad de la zona, no porque el
    // código viejo estuviera bien — de ahí el `if`.
    final legacyBuggyParse = DateTime.tryParse(raw)!.toUtc();
    if (DateTime.now().timeZoneOffset != Duration.zero) {
      expect(
        legacyBuggyParse,
        isNot(parsed),
        reason:
            'con la zona del proceso distinta de UTC, `DateTime.tryParse` '
            'sin "Z" interpreta el texto como hora LOCAL y `.toUtc()` corre '
            'el instante por el desfase — justo lo que corrige '
            'parseOdooDateTime',
      );
    }
  });

  test(
    'recent user with fresh local data is not wiped regardless of device zone',
    () async {
      // Sin huella guardada todavía. El usuario existe desde hace 2 horas
      // (en UTC real); el dato local es de hace 30 minutos — perfectamente
      // compatible con ese usuario, sin importar en qué zona horaria corra
      // el proceso que evalúa la comparación.
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final nowUtc = DateTime.now().toUtc();
      final userCreatedAtUtc = nowUtc.subtract(const Duration(hours: 2));
      final runtime = SessionRuntime(
        databaseOwner: owner,
        clientFactory: _harmlessClientFactory(),
        identityReader: (client, scope) async =>
            _odooRawUtc(userCreatedAtUtc),
      );
      final scope = _scope(1);

      final opened = await owner.open(scope);
      final database = opened.database;
      await _seedOfflineQueueRow(
        database,
        nowUtc.subtract(const Duration(minutes: 30)),
      );

      final events = <OdooDatabaseReplaced>[];
      runtime.databaseReplacements.listen(events.add);

      await runtime.activate(scope, apiKey: 'key');
      await Future<void>.delayed(Duration.zero);

      expect(
        await database.customSelect('SELECT * FROM offline_queue').get(),
        hasLength(1),
        reason:
            'un dato de hace 30 minutos es compatible con un usuario que '
            'existe desde hace 2 horas (en UTC real) — con el parseo viejo '
            'y TZ=America/Guayaquil el usuario "nacía" 5 horas después, así '
            'que este dato parecía anterior a él y se borraba sin motivo',
      );
      expect(events, isEmpty);

      await runtime.close();
    },
  );
  test(
    'replaced odoo database wipes local data before activation',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final runtime = SessionRuntime(
        databaseOwner: owner,
        clientFactory: _harmlessClientFactory(),
        identityReader: (client, scope) async => '2026-09-15 09:00:00',
      );
      final scope = _scope(1);

      final opened = await owner.open(scope);
      final database = opened.database;
      await _seedIdentity(database, '2026-09-12 10:00:00');
      // Fila de control en la MISMA tabla que guarda la huella — prueba que
      // el borrado alcanza a "TODAS las tablas", no sólo las dos que
      // menciona el diseño.
      await database.customStatement(
        "INSERT INTO sync_metadata (key, value) VALUES ('unrelated_key', 'unrelated_value')",
      );
      await database.customStatement('''
        INSERT INTO offline_queue
          (operation, model, method, "values", created_at, status)
        VALUES (
          'create', 'sale.order', 'create', '{}',
          '2026-09-14T00:00:00.000Z', 'pending'
        )
      ''');
      await database.customStatement('''
        INSERT INTO orbi_editable_draft
          (scope_key, company_id, draft_id, payload, revision)
        VALUES ('scope-1', 1, 'draft-1', '{"lines":[]}', 1)
      ''');

      final events = <OdooDatabaseReplaced>[];
      runtime.databaseReplacements.listen(events.add);

      final activation = await runtime.activate(scope, apiKey: 'key');
      // Deja correr los microtasks que entregan el evento del stream
      // broadcast antes de comprobarlo.
      await Future<void>.delayed(Duration.zero);

      expect(activation.client, isNotNull);
      expect(
        await database.customSelect('SELECT * FROM offline_queue').get(),
        isEmpty,
      );
      expect(
        await database.customSelect('SELECT * FROM orbi_editable_draft').get(),
        isEmpty,
      );
      final unrelated = await database
          .customSelect(
            "SELECT * FROM sync_metadata WHERE key = 'unrelated_key'",
          )
          .get();
      expect(unrelated, isEmpty);
      expect(await _readIdentity(database), '2026-09-15 09:00:00');

      expect(events, hasLength(1));
      expect(events.single.scope, scope);
      expect(events.single.discardedOperations, 1);
      expect(events.single.operationsSummary, ['sale.order.create']);

      await runtime.close();
    },
  );

  test('same database keeps local data', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: _harmlessClientFactory(),
      identityReader: (client, scope) async => '2026-09-12 10:00:00',
    );
    final scope = _scope(1);

    final opened = await owner.open(scope);
    final database = opened.database;
    await _seedIdentity(database, '2026-09-12 10:00:00');
    await database.customStatement('''
      INSERT INTO offline_queue
        (operation, model, method, "values", created_at, status)
      VALUES (
        'create', 'sale.order', 'create', '{}',
        '2026-09-14T00:00:00.000Z', 'pending'
      )
    ''');
    await database.customStatement('''
      INSERT INTO orbi_editable_draft
        (scope_key, company_id, draft_id, payload, revision)
      VALUES ('scope-1', 1, 'draft-1', '{"lines":[]}', 1)
    ''');

    final events = <OdooDatabaseReplaced>[];
    runtime.databaseReplacements.listen(events.add);

    await runtime.activate(scope, apiKey: 'key');
    await Future<void>.delayed(Duration.zero);

    expect(
      await database.customSelect('SELECT * FROM offline_queue').get(),
      hasLength(1),
    );
    expect(
      await database.customSelect('SELECT * FROM orbi_editable_draft').get(),
      hasLength(1),
    );
    expect(await _readIdentity(database), '2026-09-12 10:00:00');
    expect(events, isEmpty);

    await runtime.close();
  });

  test('first activation stores the identity without wiping', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: _harmlessClientFactory(),
      identityReader: (client, scope) async => 'first-identity',
    );
    final scope = _scope(1);

    final events = <OdooDatabaseReplaced>[];
    runtime.databaseReplacements.listen(events.add);

    final activation = await runtime.activate(scope, apiKey: 'key');
    await Future<void>.delayed(Duration.zero);

    expect(activation.client, isNotNull);
    expect(
      await _readIdentity(activation.database.database),
      'first-identity',
    );
    expect(events, isEmpty);

    await runtime.close();
  });

  test('legacy local data older than the user is wiped', () async {
    // El caso real (15-sep-2026, Mepriga): el equipo ya tiene datos locales
    // de ANTES de que existiera esta huella — nunca se guardó una fila en
    // `sync_metadata`, pero `offline_queue` sí tiene una fila de hace dos
    // días. Si esta base se reinstaló anoche, el usuario del scope existe
    // desde hace sólo una hora: ese dato de hace dos días NO PUDO
    // escribirse contra el usuario actual, así que es de la base vieja.
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final now = DateTime.now().toUtc();
    final userCreatedAt = now.subtract(const Duration(hours: 1));
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: _harmlessClientFactory(),
      identityReader: (client, scope) async =>
          userCreatedAt.toIso8601String(),
    );
    final scope = _scope(1);

    final opened = await owner.open(scope);
    final database = opened.database;
    await _seedOfflineQueueRow(database, now.subtract(const Duration(days: 2)));

    final events = <OdooDatabaseReplaced>[];
    runtime.databaseReplacements.listen(events.add);

    await runtime.activate(scope, apiKey: 'key');
    await Future<void>.delayed(Duration.zero);

    expect(
      await database.customSelect('SELECT * FROM offline_queue').get(),
      isEmpty,
      reason:
          'un dato de hace 2 días no pudo escribirlo un usuario que existe '
          'desde hace 1 hora — es de la base vieja y debe borrarse',
    );
    expect(await _readIdentity(database), userCreatedAt.toIso8601String());
    expect(events, hasLength(1));
    expect(events.single.discardedOperations, 1);
    expect(events.single.operationsSummary, ['sale.order.create']);

    await runtime.close();
  });

  test('legacy local data newer than the user is kept', () async {
    // Lo contrario: la fila local es de hace 10 minutos y el usuario existe
    // desde hace 2 días — perfectamente compatible con la misma base de
    // siempre (el usuario ya existía cuando se escribió). Sin huella
    // guardada todavía, se guarda y se sigue, sin borrar nada.
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final now = DateTime.now().toUtc();
    final userCreatedAt = now.subtract(const Duration(days: 2));
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: _harmlessClientFactory(),
      identityReader: (client, scope) async =>
          userCreatedAt.toIso8601String(),
    );
    final scope = _scope(1);

    final opened = await owner.open(scope);
    final database = opened.database;
    await _seedOfflineQueueRow(
      database,
      now.subtract(const Duration(minutes: 10)),
    );

    final events = <OdooDatabaseReplaced>[];
    runtime.databaseReplacements.listen(events.add);

    await runtime.activate(scope, apiKey: 'key');
    await Future<void>.delayed(Duration.zero);

    expect(
      await database.customSelect('SELECT * FROM offline_queue').get(),
      hasLength(1),
      reason:
          'una fila de hace 10 minutos es compatible con un usuario que '
          'existe desde hace 2 días — no hay motivo para borrarla',
    );
    expect(await _readIdentity(database), userCreatedAt.toIso8601String());
    expect(events, isEmpty);

    await runtime.close();
  });

  test('offline activation never reads identity nor wipes', () async {
    var identityCalls = 0;
    var clientFactoryCalls = 0;
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: _harmlessClientFactory(
        onCall: () => clientFactoryCalls++,
      ),
      identityReader: (client, scope) async {
        identityCalls++;
        return 'never-used';
      },
    );
    final scope = _scope(1);

    // Sin apiKey: `activate()` no debe construir cliente ni tocar la huella.
    final activation = await runtime.activate(scope);

    expect(activation.client, isNull);
    expect(clientFactoryCalls, 0);
    expect(identityCalls, 0);
    expect(await _readIdentity(activation.database.database), isNull);

    await runtime.close();
  });

  test(
    'identity read failure fails activation without wiping',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final runtime = SessionRuntime(
        databaseOwner: owner,
        clientFactory: _harmlessClientFactory(),
        identityReader: (client, scope) async =>
            throw const OdooConnectionException('sin red'),
      );
      final scope = _scope(1);

      final opened = await owner.open(scope);
      final database = opened.database;
      await database.customStatement('''
        INSERT INTO offline_queue
          (operation, model, method, "values", created_at, status)
        VALUES (
          'create', 'sale.order', 'create', '{}',
          '2026-09-14T00:00:00.000Z', 'pending'
        )
      ''');

      await expectLater(
        runtime.activate(scope, apiKey: 'key'),
        throwsA(isA<OdooConnectionException>()),
      );

      expect(runtime.active, isNull);
      expect(
        await database.customSelect('SELECT * FROM offline_queue').get(),
        hasLength(1),
        reason: 'un fallo de red al leer la huella no debe borrar nada',
      );
      expect(await _readIdentity(database), isNull);

      await runtime.close();
    },
  );

  test('activation is not visible before the check', () async {
    final completer = Completer<String>();
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: _harmlessClientFactory(),
      identityReader: (client, scope) => completer.future,
    );
    final scope = _scope(1);

    expect(runtime.active, isNull);
    final pending = runtime.activate(scope, apiKey: 'key');
    await Future<void>.delayed(Duration.zero);
    expect(
      runtime.active,
      isNull,
      reason:
          'mientras la huella no se confirmó, la activación nunca es '
          'visible para nadie más',
    );

    completer.complete('confirmed-identity');
    final activation = await pending;
    expect(runtime.active, same(activation));

    await runtime.close();
  });
}
