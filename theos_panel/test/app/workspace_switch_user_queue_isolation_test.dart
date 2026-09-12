import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// Two identities on the same server/database, differing only by
/// `userId` — exactly what "cambiar de usuario" produces in
/// `OperationalShell`/`router.dart` (`confirmSwitchWorkspaceUser` closes the
/// current [SessionRuntime] before any other identity can activate one).
AppScope _scope(int userId) => AppScope(
  appId: 'orbi-panel',
  installationId: 'switch-user-isolation-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'orbi_demo',
  userId: userId,
);

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-switch-user-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('switching the active user opens a physically different database: the '
      'previous user pending queue is never reachable — let alone '
      'replayable — under the new identity, and is exactly where it was '
      'left when that user comes back', () async {
    // Same naming rule production uses (RuntimeDatabaseOwner._defaultFactory
    // via databaseNameFor), just backed by a real file instead of
    // sqlite3_flutter_libs, so this proves the actual isolation contract
    // instead of a test shortcut.
    final owner = RuntimeDatabaseOwner(
      factory: (name) =>
          AppDatabase(NativeDatabase(File('${directory.path}/$name.sqlite'))),
    );
    final runtime = SessionRuntime(databaseOwner: owner);

    final userA = _scope(11);
    final userB = _scope(22);
    expect(
      userA.scopeKey,
      isNot(userB.scopeKey),
      reason:
          'AppScope.scopeKey includes userId; two users must never '
          'collapse onto the same scope key',
    );

    // Cashier A confirms a sale offline; it lands in the queue under A.
    final activationA = await runtime.activate(userA);
    final queueA = OfflineQueueDataSource(activationA.database.database);
    await queueA.queueOperation(
      model: 'sale.order',
      method: 'action_confirm',
      values: {'x_uuid': 'orderA-uuid'},
    );
    expect(await queueA.getPendingCount(), 1);

    // "Cambiar de usuario": the shell always closes the runtime before a
    // different identity can authenticate (see confirmSwitchWorkspaceUser
    // in router.dart). Reproduced directly against the real runtime here,
    // not a fake, so the guarantee is checked at the layer that actually
    // owns the database connection.
    await runtime.close();

    final activationB = await runtime.activate(userB);
    expect(
      activationB.database.databaseName,
      isNot(activationA.database.databaseName),
      reason: 'a different user must open a different physical database',
    );
    final queueB = OfflineQueueDataSource(activationB.database.database);
    expect(
      await queueB.getPendingCount(),
      0,
      reason:
          "B must never see A's pending queue, let alone have it replay "
          'under B\'s identity',
    );

    // A's operation was not lost and was not resent under B: it is
    // exactly where A left it, still tagged under A's own scope.
    await runtime.close();
    final reopenedA = await runtime.activate(userA);
    final queueAAgain = OfflineQueueDataSource(reopenedA.database.database);
    expect(await queueAAgain.getPendingCount(), 1);

    await runtime.close();
  });
}
