import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late AppDatabase firstDatabase;
  AppDatabase? secondDatabase;
  var firstDatabaseClosed = false;

  setUp(() {
    firstDatabase = AppDatabase(NativeDatabase.memory());
    firstDatabaseClosed = false;
  });

  tearDown(() async {
    resetModelManagersSession();
    if (!firstDatabaseClosed) await firstDatabase.close();
    await secondDatabase?.close();
  });

  test(
    'all managers bind, detach and rebind without retaining a client',
    () async {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://example.test',
          apiKey: 'test-key',
          database: 'test_db',
        ),
      );

      await initializeModelManagers(
        client: client,
        db: firstDatabase,
        queueStore: OfflineQueueDataSource(firstDatabase),
      );

      expect(productManager.isOnline, isTrue);
      expect(withholdLineManager.isOnline, isTrue);
      expect(paymentLineManager.isOnline, isTrue);
      expect(cardLoteManager.isOnline, isTrue);
      expect(advanceLineManager.isOnline, isTrue);
      expect(
        ModelRegistry().registeredModels,
        containsAll(<String>[
          productManager.odooModel,
          withholdLineManager.odooModel,
          paymentLineManager.odooModel,
          cardLoteManager.odooModel,
          advanceLineManager.odooModel,
        ]),
      );

      resetModelManagersSession();

      expect(productManager.isOnline, isFalse);
      expect(withholdLineManager.isOnline, isFalse);
      expect(ModelRegistry().registeredModels, isEmpty);
      expect(() => productManager.client, throwsStateError);

      await firstDatabase.close();
      firstDatabaseClosed = true;
      secondDatabase = AppDatabase(NativeDatabase.memory());
      await initializeModelManagers(
        db: secondDatabase!,
        queueStore: OfflineQueueDataSource(secondDatabase!),
      );

      expect(productManager.isOnline, isFalse);
      expect(withholdLineManager.isOnline, isFalse);
      expect(ModelRegistry().registeredModels, isNotEmpty);
      expect(() => productManager.client, throwsStateError);
    },
  );
}
