import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/sales/durable_sale_draft_store.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'provider-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: 1,
);

CapabilitySnapshot _capability(AppScope scope, int companyId) =>
    CapabilitySnapshot(
      scopeKey: scope.scopeKey,
      companyId: companyId,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 1, 1),
    );

RuntimeDatabaseOwner _owner(File file) =>
    RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));

SaleDraftSnapshot _draft(String scope, String command, String note) =>
    SaleDraftSnapshot(
      scopeKey: scope,
      clientName: 'Cliente',
      commandId: command,
      note: note,
      orderLocalId: 'local-1',
    );

Future<SessionRuntime> _runtime(
  RuntimeDatabaseOwner owner,
  AppScope scope,
) async {
  final runtime = SessionRuntime(databaseOwner: owner);
  await runtime.activate(scope);
  return runtime;
}

ProviderContainer _container({
  required SessionRuntime runtime,
  required CapabilitySnapshot? capabilities,
}) => ProviderContainer(
  overrides: [
    runtimeSessionProvider.overrideWithValue(runtime),
    capabilitySnapshotProvider.overrideWithValue(capabilities),
  ],
);

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-provider-draft-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'provider uses durable store and recovers after container recreation',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      final runtime = await _runtime(owner, scope);
      final capabilities = _capability(scope, 1);
      final first = _container(runtime: runtime, capabilities: capabilities);
      final firstStore = first.read(saleDraftStoreProvider);
      expect(firstStore, isA<DurableSaleDraftStore>());
      final firstController = first.read(saleDraftControllerProvider);
      await firstController.restore();
      firstController.update(note: 'persistido');
      await firstController.flush();
      first.dispose();

      final second = _container(runtime: runtime, capabilities: capabilities);
      final secondController = second.read(saleDraftControllerProvider);
      await secondController.restore();
      expect(secondController.draft.note, 'persistido');
      second.dispose();
      await runtime.close();
    },
  );

  test('changing company through capability does not leak the draft', () async {
    final scope = _scope();
    final owner = _owner(file);
    final runtime = await _runtime(owner, scope);
    final first = _container(
      runtime: runtime,
      capabilities: _capability(scope, 1),
    );
    final controller = first.read(saleDraftControllerProvider);
    await controller.restore();
    controller.update(note: 'solo empresa 1');
    await controller.flush();
    first.dispose();

    final second = _container(
      runtime: runtime,
      capabilities: _capability(scope, 2),
    );
    final secondStore = second.read(saleDraftStoreProvider);
    expect(secondStore, isA<DurableSaleDraftStore>());
    final secondController = second.read(saleDraftControllerProvider);
    await secondController.restore();
    expect(secondController.draft.note, isNot('solo empresa 1'));
    expect(secondController.draft.note, isEmpty);
    second.dispose();
    await runtime.close();
  });

  test(
    'missing capabilities returns unavailable store without fallback',
    () async {
      final scope = _scope();
      final owner = _owner(file);
      final runtime = await _runtime(owner, scope);
      final container = _container(runtime: runtime, capabilities: null);
      final store = container.read(saleDraftStoreProvider);
      expect(store, isA<UnavailableSaleDraftStore>());
      expect(await store.load(scope.scopeKey), isNull);
      expect(
        store.save(_draft(scope.scopeKey, 'missing', 'must not persist')),
        throwsA(isA<StateError>()),
      );
      container.dispose();
      await runtime.close();
    },
  );

  test('unmatched capability scope returns unavailable store', () async {
    final scope = _scope();
    final otherScope = scope.copyWith(database: 'other-db');
    final owner = _owner(file);
    final runtime = await _runtime(owner, scope);
    final container = _container(
      runtime: runtime,
      capabilities: _capability(otherScope, 1),
    );
    expect(
      container.read(saleDraftStoreProvider),
      isA<UnavailableSaleDraftStore>(),
    );
    container.dispose();
    await runtime.close();
  });
}
