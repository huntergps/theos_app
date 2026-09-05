import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/managers/manager_providers.dart'
    show appDatabaseProvider;
import 'package:theos_pos/features/collection/screens/collection_session/tabs/documentos_tab.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test(
    'lists only the orders, invoices and withholdings of the session',
    () async {
      await database
          .into(database.saleOrder)
          .insert(
            SaleOrderCompanion.insert(
              odooId: 101,
              name: 'SO101',
              collectionSessionId: const drift.Value(7),
              partnerName: const drift.Value('Cliente Uno'),
              amountTotal: const drift.Value(125.50),
              dateOrder: drift.Value(DateTime(2026, 8, 26)),
            ),
          );
      await database
          .into(database.saleOrder)
          .insert(
            SaleOrderCompanion.insert(
              odooId: 202,
              name: 'SO202',
              collectionSessionId: const drift.Value(8),
            ),
          );
      await database
          .into(database.accountMove)
          .insert(
            AccountMoveCompanion.insert(
              odooId: 301,
              moveType: 'out_invoice',
              name: const drift.Value('INV301'),
              saleOrderId: const drift.Value(101),
              amountTotal: const drift.Value(125.50),
              state: const drift.Value('posted'),
              paymentState: const drift.Value('paid'),
            ),
          );
      await database
          .into(database.saleOrderWithholdLine)
          .insert(
            SaleOrderWithholdLineCompanion.insert(
              odooId: const drift.Value(401),
              orderId: 101,
              taxId: 17,
              taxName: 'Retención IVA 30%',
              withholdType: 'withhold_vat_sale',
              amount: const drift.Value(3.75),
              isSynced: const drift.Value(true),
            ),
          );

      final provider = collectionDocumentsProvider(7);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final documents = await container.read(provider.future);

      expect(documents, hasLength(3));
      expect(
        documents.map((document) => document.type),
        containsAll(<CollectionDocumentType>{
          CollectionDocumentType.saleOrder,
          CollectionDocumentType.invoice,
          CollectionDocumentType.withholding,
        }),
      );
      expect(documents.any((document) => document.name == 'SO202'), isFalse);
      expect(
        documents
            .singleWhere(
              (document) => document.type == CollectionDocumentType.invoice,
            )
            .secondaryState,
        'paid',
      );
    },
  );
}
