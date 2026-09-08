import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RuntimeDatabaseOwner persists and isolates browser scopes', (
    tester,
  ) async {
    final scope = AppScope(
      appId: 'theos-panel-web-harness',
      installationId: 'integration-test-installation',
      normalizedServerUrl: 'https://erp2.tecnosmart.com.ec',
      database: 'erp2',
      userId: 7101,
    );
    final otherScope = scope.copyWith(userId: 7102);

    final firstOwner = RuntimeDatabaseOwner();
    final first = await firstOwner.open(scope);
    await first.database.customStatement(
      'INSERT OR REPLACE INTO sync_metadata ("key", "value") VALUES (?, ?)',
      ['web-harness-key', 'persisted-value'],
    );
    await firstOwner.close();

    final reopenedOwner = RuntimeDatabaseOwner();
    final reopened = await reopenedOwner.open(scope);
    final persisted = await reopened.database
        .customSelect(
          'SELECT "value" FROM sync_metadata WHERE "key" = ?',
          variables: [Variable.withString('web-harness-key')],
        )
        .getSingleOrNull();
    expect(persisted?.data['value'], 'persisted-value');
    await reopenedOwner.close();

    final isolatedOwner = RuntimeDatabaseOwner();
    final isolated = await isolatedOwner.open(otherScope);
    final crossScope = await isolated.database
        .customSelect(
          'SELECT "value" FROM sync_metadata WHERE "key" = ?',
          variables: [Variable.withString('web-harness-key')],
        )
        .getSingleOrNull();
    expect(crossScope, isNull);
    await isolatedOwner.close();

    await tester.pump();
  });
}
