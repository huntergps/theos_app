import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/services/handlers/model_record_handler.dart';
import 'package:theos_pos/core/services/handlers/related_record_resolver.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show AppDatabase, ProductProductCompanion;

import '../../../mocks/mock_odoo_client.dart';

void main() {
  late AppDatabase db;
  late MockOdooClient client;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
  });
  tearDown(() => db.close());

  test('registered handler fetches and upserts missing product', () async {
    final registry = ModelRecordHandlerRegistry()..register(_ProductHandler());
    when(
      () => client.searchRead(
        model: 'product.product',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (_) async => [
        {'id': 7, 'name': 'Test'},
      ],
    );
    final resolver = RelatedRecordResolver(
      odooClient: client,
      db: db,
      handlerRegistry: registry,
    );
    await resolver.resolveForLineIds(
      productIds: [7],
      taxIdsStrings: [],
      uomIds: [],
    );
    expect(
      await (db.select(
        db.productProduct,
      )..where((t) => t.odooId.equals(7))).getSingleOrNull(),
      isNotNull,
    );
  });

  test('missing handler propagates StateError', () async {
    final resolver = RelatedRecordResolver(
      odooClient: client,
      db: db,
      handlerRegistry: ModelRecordHandlerRegistry(),
    );
    expect(
      () => resolver.resolveForLineIds(
        productIds: [7],
        taxIdsStrings: [],
        uomIds: [],
      ),
      throwsStateError,
    );
  });

  test('offline resolver performs no work', () async {
    final resolver = RelatedRecordResolver(
      db: db,
      handlerRegistry: ModelRecordHandlerRegistry(),
    );
    await resolver.resolveForLineIds(
      productIds: [7],
      taxIdsStrings: [],
      uomIds: [],
    );
    verifyNever(
      () => client.searchRead(
        model: any(named: 'model'),
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    );
  });
}

class _ProductHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'product.product';
  @override
  List<String> get defaultFields => ['id', 'name'];
  @override
  Future<bool> exists(AppDatabase db, int id) async => false;
  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    await db
        .into(db.productProduct)
        .insert(
          ProductProductCompanion.insert(
            odooId: data['id'] as int,
            name: data['name'] as String,
          ),
        );
  }
}
