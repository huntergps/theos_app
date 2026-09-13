import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooValidationException, OfflineQueueWrapper;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class _MockSaleOdooActions extends Mock implements SaleOdooActions {}

Future<void> _seedUser(
  AppDatabase db, {
  required int odooId,
  String name = 'Erik Salazar',
  String login = 'erik',
  int? partnerId,
  String? lang,
  String? tz,
  String? signature,
  String? notificationType,
  int? propertyWarehouseId,
  String? mobilePhone,
  String? groupIds,
}) async {
  await db
      .into(db.resUsers)
      .insert(
        ResUsersCompanion.insert(
          odooId: odooId,
          name: name,
          login: login,
          partnerId: drift.Value(partnerId),
          lang: drift.Value(lang),
          tz: drift.Value(tz),
          signature: drift.Value(signature),
          notificationType: drift.Value(notificationType),
          propertyWarehouseId: drift.Value(propertyWarehouseId),
          mobilePhone: drift.Value(mobilePhone),
          groupIds: drift.Value(groupIds),
        ),
      );
}

Future<void> _seedPartner(
  AppDatabase db, {
  required int odooId,
  String name = 'Erik Salazar',
  String? email,
  String? phone,
  String? street,
  int? countryId,
  int? stateId,
}) async {
  await db
      .into(db.resPartner)
      .insert(
        ResPartnerCompanion.insert(
          odooId: odooId,
          name: name,
          email: drift.Value(email),
          phone: drift.Value(phone),
          street: drift.Value(street),
          countryId: drift.Value(countryId),
          stateId: drift.Value(stateId),
        ),
      );
}

Future<void> _markFieldAvailable(AppDatabase db, String field) {
  return FieldAvailabilityCache(db).markAvailable(field);
}

void main() {
  late AppDatabase db;
  late OfflineQueueDataSource queue;
  late LocalUserPreferencesPort port;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(db);
    port = LocalUserPreferencesPort(database: db, queue: queue);
  });

  tearDown(() => db.close());

  group('LocalUserPreferencesPort.watch — sin red, nunca llama a Odoo', () {
    test('un usuario no sincronizado todavía devuelve null', () async {
      expect(await port.watch(999).first, isNull);
    });

    test('trae los campos base y el partner cuando existen', () async {
      await _seedUser(
        db,
        odooId: 7,
        partnerId: 42,
        lang: 'es_EC',
        tz: 'America/Guayaquil',
        signature: '<p>Erik</p>',
      );
      await _seedPartner(
        db,
        odooId: 42,
        email: 'erik@example.com',
        phone: '022222222',
        countryId: 63,
      );

      final prefs = await port.watch(7).first;

      expect(prefs, isNotNull);
      expect(prefs!.userId, 7);
      expect(prefs.partnerId, 42);
      expect(prefs.lang, 'es_EC');
      expect(prefs.email, 'erik@example.com');
      expect(prefs.countryId, 63);
    });

    group('Mepriga — sin hr ni sale_stock', () {
      test(
        'mobile_phone y property_warehouse_id salen null y ausentes de availableUserFields',
        () async {
          await _seedUser(
            db,
            odooId: 7,
            mobilePhone: '0999999999',
            propertyWarehouseId: 3,
          );

          final prefs = await port.watch(7).first;

          expect(prefs!.mobilePhone, isNull);
          expect(prefs.warehouseId, isNull);
          expect(
            prefs.availableUserFields.contains('mobile_phone'),
            isFalse,
          );
          expect(
            prefs.availableUserFields.contains('property_warehouse_id'),
            isFalse,
          );
        },
      );

      test(
        'con la disponibilidad marcada, los mismos campos sí se muestran',
        () async {
          await _seedUser(
            db,
            odooId: 7,
            mobilePhone: '0999999999',
            propertyWarehouseId: 3,
          );
          await _markFieldAvailable(db, 'mobile_phone');
          await _markFieldAvailable(db, 'property_warehouse_id');

          final prefs = await port.watch(7).first;

          expect(prefs!.mobilePhone, '0999999999');
          expect(prefs.warehouseId, 3);
        },
      );
    });
  });

  group('LocalUserPreferencesPort.catalogs', () {
    test('idiomas, países y almacenes salen de Drift local', () async {
      await db
          .into(db.resLang)
          .insert(
            ResLangCompanion.insert(odooId: 1, name: 'Español (EC)', code: 'es_EC'),
          );
      await db
          .into(db.resCountry)
          .insert(ResCountryCompanion.insert(odooId: 63, name: 'Ecuador'));
      await db
          .into(db.stockWarehouse)
          .insert(
            StockWarehouseCompanion.insert(
              odooId: 3,
              name: 'Almacén Principal',
              code: 'AP',
            ),
          );

      final catalogs = await port.catalogs();

      expect(catalogs.languages.single.code, 'es_EC');
      expect(catalogs.countries.single.id, 63);
      expect(catalogs.warehouses.single.id, 3);
      expect(catalogs.states, isEmpty);
    });

    test('countryId filtra las provincias', () async {
      await db
          .into(db.resCountryState)
          .insert(
            ResCountryStateCompanion.insert(
              odooId: 536,
              name: 'Pichincha',
              countryId: const drift.Value(63),
            ),
          );
      await db
          .into(db.resCountryState)
          .insert(
            ResCountryStateCompanion.insert(
              odooId: 900,
              name: 'Otro país',
              countryId: const drift.Value(99),
            ),
          );

      final catalogs = await port.catalogs(countryId: 63);

      expect(catalogs.states.single.id, 536);
    });

    test('zonas horarias y tipos de notificación vienen de field_selections', () async {
      await FieldSelectionDatasource(db).upsertFieldSelection('res.users', 'tz', [
        ['America/Guayaquil', 'America/Guayaquil'],
      ]);
      await FieldSelectionDatasource(
        db,
      ).upsertFieldSelection('res.users', 'notification_type', [
        ['email', 'Correo electrónico'],
      ]);

      final catalogs = await port.catalogs();

      expect(catalogs.timezones.single.code, 'America/Guayaquil');
      expect(catalogs.notificationTypes.single.code, 'email');
    });
  });

  group('LocalUserPreferencesPort.watchGroups', () {
    test('resuelve group_ids contra res_groups, ordenado por nombre', () async {
      await _seedUser(db, odooId: 7, groupIds: '10,20');
      await db
          .into(db.resGroups)
          .insert(
            ResGroupsCompanion.insert(
              odooId: 20,
              name: 'Ventas',
              xmlId: const drift.Value('sales_team.group_sale_salesman'),
            ),
          );
      await db
          .into(db.resGroups)
          .insert(
            ResGroupsCompanion.insert(
              odooId: 10,
              name: 'Administración',
              xmlId: const drift.Value('base.group_system'),
            ),
          );

      final groups = await port.watchGroups(7).first;

      expect(groups.map((g) => g.name), ['Administración', 'Ventas']);
    });

    test('sin group_ids devuelve una lista vacía', () async {
      await _seedUser(db, odooId: 7);
      expect(await port.watchGroups(7).first, isEmpty);
    });
  });

  group('LocalUserPreferencesPort.save — local primero, cola durable', () {
    test('sin cambios no toca la fila local ni la cola', () async {
      await _seedUser(db, odooId: 7, lang: 'es_EC');

      final saved = await port.save(7, const UserPreferencesChange());

      expect(saved, isTrue);
      expect(await queue.getPendingCount(), 0);
    });

    test(
      'cambiar sólo el idioma actualiza res_users local y encola SÓLO ese diff',
      () async {
        await _seedUser(db, odooId: 7, lang: 'es_EC', partnerId: 42);
        await _seedPartner(db, odooId: 42);

        final saved = await port.save(
          7,
          const UserPreferencesChange(
            partnerId: 42,
            userValues: {'lang': 'en_US'},
          ),
        );

        expect(saved, isTrue);
        final row = await (db.select(
          db.resUsers,
        )..where((t) => t.odooId.equals(7))).getSingle();
        expect(row.lang, 'en_US');

        final ops = await queue.getPendingOperations();
        expect(ops, hasLength(1));
        expect(ops.single.model, 'res.users');
        expect(ops.single.method, 'write');
        expect(ops.single.recordId, 7);
        expect(ops.single.values, {'lang': 'en_US'});
      },
    );

    test(
      'cambiar sólo el teléfono actualiza res_partner local y encola SÓLO ese diff',
      () async {
        await _seedUser(db, odooId: 7, partnerId: 42);
        await _seedPartner(db, odooId: 42, phone: '022222222');

        final saved = await port.save(
          7,
          const UserPreferencesChange(
            partnerId: 42,
            partnerValues: {'phone': '0987654321'},
          ),
        );

        expect(saved, isTrue);
        final row = await (db.select(
          db.resPartner,
        )..where((t) => t.odooId.equals(42))).getSingle();
        expect(row.phone, '0987654321');

        final ops = await queue.getPendingOperations();
        expect(ops, hasLength(1));
        expect(ops.single.model, 'res.partner');
        expect(ops.single.recordId, 42);
      },
    );

    test('partnerValues sin partnerId truena, no se guarda a medias', () async {
      await _seedUser(db, odooId: 7);
      await expectLater(
        port.save(
          7,
          const UserPreferencesChange(partnerValues: {'phone': '099'}),
        ),
        throwsStateError,
      );
      expect(await queue.getPendingCount(), 0);
    });

    test(
      'dos guardados seguidos del mismo usuario quedan comprimibles en uno',
      () async {
        await _seedUser(db, odooId: 7, lang: 'es_EC', tz: 'America/Guayaquil');

        await port.save(
          7,
          const UserPreferencesChange(userValues: {'lang': 'en_US'}),
        );
        await port.save(
          7,
          const UserPreferencesChange(userValues: {'tz': 'Europe/Madrid'}),
        );

        final before = await queue.getOperationsForModel('res.users');
        expect(before, hasLength(2));

        final removed = await OfflineQueueWrapper(queue).compressQueue();

        expect(removed, 1);
        final after = await queue.getOperationsForModel('res.users');
        expect(after, hasLength(1));
        expect(after.single.values, {'lang': 'en_US', 'tz': 'Europe/Madrid'});
      },
    );
  });

  group('OdooUserSecurityActionsPort — sólo en línea', () {
    late _MockSaleOdooActions actions;

    setUp(() {
      actions = _MockSaleOdooActions();
    });

    test('changePassword sin red devuelve offline y no llama al servidor', () async {
      final security = OdooUserSecurityActionsPort(
        actions: actions,
        isOnline: false,
      );
      final result = await security.changePassword(
        oldPassword: 'old',
        newPassword: 'newpassword',
      );
      expect(result.outcome, UserSecurityActionOutcome.offline);
      verifyNever(
        () => actions.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      );
    });

    test('changePassword en línea llama change_password con los nombres reales', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'change_password',
          kwargs: {'old_passwd': 'old', 'new_passwd': 'newpassword'},
        ),
      ).thenAnswer((_) async => true);

      final security = OdooUserSecurityActionsPort(
        actions: actions,
        isOnline: true,
      );
      final result = await security.changePassword(
        oldPassword: 'old',
        newPassword: 'newpassword',
      );

      expect(result.isApplied, isTrue);
    });

    test('un rechazo de Odoo llega íntegro en serverMessage', () async {
      when(
        () => actions.call(
          model: 'res.users',
          method: 'change_password',
          kwargs: {'old_passwd': 'old', 'new_passwd': 'bad'},
        ),
      ).thenThrow(OdooValidationException('La contraseña actual no es correcta.'));

      final security = OdooUserSecurityActionsPort(
        actions: actions,
        isOnline: true,
      );
      final result = await security.changePassword(
        oldPassword: 'old',
        newPassword: 'bad',
      );

      expect(result.outcome, UserSecurityActionOutcome.rejected);
      expect(result.serverMessage, 'La contraseña actual no es correcta.');
    });

    test('listDevices sin red devuelve una lista vacía sin llamar al servidor', () async {
      final security = OdooUserSecurityActionsPort(
        actions: actions,
        isOnline: false,
      );
      expect(await security.listDevices(), isEmpty);
      verifyNever(
        () => actions.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          kwargs: any(named: 'kwargs'),
        ),
      );
    });

    test('revokeDevice sin red devuelve offline', () async {
      final security = OdooUserSecurityActionsPort(
        actions: actions,
        isOnline: false,
      );
      final result = await security.revokeDevice(5, 'password');
      expect(result.outcome, UserSecurityActionOutcome.offline);
    });

    test('revokeAllDevices sin red devuelve offline', () async {
      final security = OdooUserSecurityActionsPort(
        actions: actions,
        isOnline: false,
      );
      final result = await security.revokeAllDevices('password');
      expect(result.outcome, UserSecurityActionOutcome.offline);
    });
  });
}
