import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/features/collection/repositories/collection_repository.dart';
import 'package:theos_pos/features/users/repositories/user_repository.dart';
import 'package:theos_pos/features/sync/repositories/user_sync_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../mocks/mock_odoo_client.dart';

class _Database extends Mock implements DatabaseHelper {}

class _Users extends Mock implements UserRepository {}

void main() {
  late Directory directory;
  late AppDatabase db;
  late MockOdooClient client;
  late _Users users;

  final policies = {
    for (final name in PosAppCapabilities.booleanPolicyNames) name: false,
    'panel_dias_pendientes': 30,
  };
  Map<String, dynamic> snapshot() => {
    'version': 1,
    'config_id': 4,
    'company_id': 2,
    'counter_policies': policies,
  };

  CollectionRepository repository({bool offline = false}) =>
      CollectionRepository(
        odooClient: offline ? null : client,
        db: _Database(),
        userRepository: users,
        sessionManager: CollectionSessionManager()..initDb(db),
        paymentManager: AccountPaymentManager()..initDb(db),
        cashOutManager: CashOutManager()..initDb(db),
        sessionCashManager: CollectionSessionCashManager()..initDb(db),
        sessionDepositManager: CollectionSessionDepositManager()..initDb(db),
      );

  void respond(Object? payload) {
    when(
      () => client.call(
        model: 'collection.config',
        method: 'pos_app_capabilities',
        ids: [4],
      ),
    ).thenAnswer((_) async => payload);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pos-capabilities-');
    db = AppDatabase(NativeDatabase(File('${directory.path}/cache.sqlite')));
    client = MockOdooClient.online();
    users = _Users();
    when(
      users.getCurrentUser,
    ).thenAnswer((_) async => const User(id: 7, name: 'Caja', login: 'test'));
    when(
      () => client.searchRead(
        model: 'collection.config',
        fields: any(named: 'fields'),
        domain: any(named: 'domain'),
      ),
    ).thenAnswer(
      (_) async => [
        {
          'id': 4,
          'name': 'Actualizado',
          'code': 'CAJA',
          'company_id': [2, 'Empresa'],
        },
      ],
    );
    when(
      () => client.searchRead(
        model: 'collection.session',
        fields: any(named: 'fields'),
        domain: any(named: 'domain'),
        limit: 20,
      ),
    ).thenAnswer((_) async => []);
    when(() => client.hasField('collection.config', 'pos_app_contract_version'))
        .thenAnswer((_) async => true);
  });

  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'point capability stream updates from local SQLite without RPC',
    () async {
      respond([snapshot()]);
      final config = (await repository().syncCollectionConfigs()).single;
      final stream = StreamIterator(
        repository(offline: true).watchPosCapabilities(4),
      );
      addTearDown(stream.cancel);
      expect(await stream.moveNext(), isTrue);
      expect(
        stream.current!.counterPolicies!['panel_accion_visible_pago'],
        isFalse,
      );
      final changed = snapshot();
      changed['counter_policies'] = {
        ...policies,
        'panel_accion_visible_pago': true,
      };
      await (CollectionConfigManager()..initDb(db)).upsertLocal(
        config.copyWith(posAppCapabilitiesJson: jsonEncode(changed)),
      );
      expect(await stream.moveNext(), isTrue);
      expect(
        stream.current!.counterPolicies!['panel_accion_visible_pago'],
        isTrue,
      );
      await stream.cancel();
    },
  );

  test('point capability stream rejects mismatched company in cache', () async {
    respond([snapshot()]);
    final config = (await repository().syncCollectionConfigs()).single;
    await (CollectionConfigManager()..initDb(db)).upsertLocal(
      config.copyWith(
        posAppCapabilitiesJson: jsonEncode({...snapshot(), 'company_id': 99}),
      ),
    );
    await expectLater(
      repository(offline: true).watchPosCapabilities(4).first,
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'POS bridge snapshot survives reopening the cache without network',
    () async {
      respond([snapshot()]);
      final online = (await repository().syncCollectionConfigs()).single;
      final parsed = PosAppCapabilities.fromJson(
        jsonDecode(online.posAppCapabilitiesJson!),
      );
      expect(parsed.counterPolicies!['panel_editar_precio'], isFalse);
      expect(parsed.pendingDays, 30);
      await db.close();
      db = AppDatabase(NativeDatabase(File('${directory.path}/cache.sqlite')));
      final offline = (await repository(
        offline: true,
      ).syncCollectionConfigs()).single;
      expect(offline.posAppCapabilitiesJson, online.posAppCapabilitiesJson);
    },
  );

  test('base POS contract works without installing the panel', () async {
    respond([
      {...snapshot(), 'counter_policies': null},
    ]);
    final config = (await repository().syncCollectionConfigs()).single;
    expect(
      PosAppCapabilities.fromJson(jsonDecode(config.posAppCapabilitiesJson!))
          .counterPolicies,
      isNull,
    );
  });

  test(
    'main incremental sync also refreshes effective company policies',
    () async {
      respond([snapshot()]);
      when(
        () => client.searchCount(
          model: 'collection.config',
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        () => client.searchRead(
          model: 'collection.config',
          fields: any(named: 'fields'),
          domain: any(named: 'domain'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'id': 4,
            'name': 'Actualizado',
            'code': 'CAJA',
            'company_id': [2, 'Empresa'],
          },
        ],
      );
      final sync = UserSyncRepository(
        db: _Database(),
        appDatabase: db,
        odooClient: client,
      );
      expect(
        await sync.syncCollectionConfigs(sinceDate: DateTime.utc(2026, 9, 5)),
        1,
      );
      final manager = CollectionConfigManager()..initDb(db);
      expect((await manager.readLocal(4))?.posAppCapabilitiesJson, isNotNull);
      final domain = verify(
        () => client.searchCount(
          model: 'collection.config',
          domain: captureAny(named: 'domain'),
        ),
      ).captured.single.toString();
      expect(domain, isNot(contains('write_date')));
    },
  );

  test(
    'older bridge without marker never invokes a panel or capability RPC',
    () async {
      when(
        () => client.hasField('collection.config', 'pos_app_contract_version'),
      ).thenAnswer((_) async => false);
      final config = (await repository().syncCollectionConfigs()).single;
      expect(config.posAppCapabilitiesJson, isNull);
      verifyNever(
        () => client.call(
          model: 'collection.config',
          method: 'pos_app_capabilities',
          ids: [4],
        ),
      );
    },
  );

  for (final bad in <Object?>[
    null,
    [],
    [
      {'version': 2, 'config_id': 4, 'company_id': 2, 'counter_policies': null},
    ],
    [
      {
        'version': 1,
        'config_id': 4,
        'company_id': 99,
        'counter_policies': null,
      },
    ],
    [
      {
        'version': 1,
        'config_id': 4,
        'company_id': 2,
        'counter_policies': {'panel_editar_precio': 'company'},
      },
    ],
  ]) {
    test(
      'invalid response preserves the complete prior config: $bad',
      () async {
        final manager = CollectionConfigManager()..initDb(db);
        final priorJson = jsonEncode(snapshot());
        await manager.upsertLocal(
          CollectionConfig(
            id: 4,
            name: 'Anterior',
            code: 'CAJA',
            companyId: 2,
            posAppCapabilitiesJson: priorJson,
          ),
        );
        respond(bad);
        final config = (await repository().syncCollectionConfigs()).single;
        expect(config.name, 'Anterior');
        expect(config.posAppCapabilitiesJson, priorJson);
      },
    );
  }
}
