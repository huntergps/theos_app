// Revisión del dueño (15-sep-2026): `SessionRuntime._verifyDatabaseIdentity`
// publica `OdooDatabaseReplaced` DURANTE `activate()` — al entrar o al
// restaurar, casi siempre ANTES de que exista el armazón que debería
// avisarlo. Un `StreamController.broadcast()` sin oyentes en ese momento
// pierde el evento para siempre: `databaseReplacedNoticeProvider` sólo se
// suscribía hacia adelante, así que el dueño nunca vería «se borraron N
// operaciones». El arreglo real vive en `SessionRuntime.pendingDatabaseReplacement`
// (`orbi_runtime`); esta prueba fija el contrato del lado de `theos_panel`:
// activar (y con eso, emitir el reemplazo) ANTES de construir el
// `ProviderContainer` — el orden real en el que pasa en producción — y
// comprobar que el aviso sigue disponible cuando el contenedor por fin se
// suscribe.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/app/router.dart';

AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'notice-provider-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'orbi_demo',
  userId: 7,
);

Future<SessionRuntime> _activateWithReplacedDatabase(AppScope scope) async {
  final owner = RuntimeDatabaseOwner(
    factory: (_) => AppDatabase(NativeDatabase.memory()),
  );
  final runtime = SessionRuntime(
    databaseOwner: owner,
    clientFactory: (scope, apiKey) => OdooClient(
      config: OdooClientConfig(
        baseUrl: scope.normalizedServerUrl,
        apiKey: apiKey,
        database: scope.database,
      ),
    ),
    identityReader: (client, scope) async => 'new-identity',
  );

  final opened = await owner.open(scope);
  final database = opened.database;
  await database.customStatement(
    "INSERT INTO sync_metadata (key, value) VALUES "
    "('odoo_database_identity', 'old-identity')",
  );
  await database.customStatement('''
    INSERT INTO offline_queue
      (operation, model, method, "values", created_at, status)
    VALUES (
      'create', 'sale.order', 'create', '{}',
      '2026-09-14T00:00:00.000Z', 'pending'
    )
  ''');

  // El reemplazo se emite AQUÍ, dentro de `activate()` — antes de que
  // exista ningún `ProviderContainer` ni armazón que lo escuche.
  await runtime.activate(scope, apiKey: 'key');
  return runtime;
}

void main() {
  test(
    'replacement notice survives until the shell subscribes',
    () async {
      final scope = _scope();
      final runtime = await _activateWithReplacedDatabase(scope);

      // Recién ahora se construye lo que en producción sería el armazón —
      // exactamente el orden que perdía el evento con el `broadcast()` a
      // secas.
      final container = ProviderContainer(
        overrides: [runtimeSessionProvider.overrideWithValue(runtime)],
      );
      addTearDown(container.dispose);

      final notice = container.read(databaseReplacedNoticeProvider);
      expect(
        notice,
        isNotNull,
        reason:
            'el aviso se emitió antes de que este contenedor existiera; '
            'debe seguir disponible vía SessionRuntime.pendingDatabaseReplacement',
      );
      expect(notice!.scope, scope);
      expect(notice.discardedOperations, 1);

      container.read(databaseReplacedNoticeProvider.notifier).dismiss();
      expect(container.read(databaseReplacedNoticeProvider), isNull);

      // Un contenedor NUEVO (equivalente a reconstruir el armazón) no debe
      // volver a ver el mismo aviso: `dismiss()` lo reconoció de verdad en
      // `SessionRuntime`, no sólo en el `state` de este contenedor.
      final rebuilt = ProviderContainer(
        overrides: [runtimeSessionProvider.overrideWithValue(runtime)],
      );
      addTearDown(rebuilt.dispose);
      expect(rebuilt.read(databaseReplacedNoticeProvider), isNull);

      await runtime.close();
    },
  );
}
