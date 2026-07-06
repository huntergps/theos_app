/// Tests del mecanismo real de `upsertLocal`/`upsertLocalBatch` en
/// `GenericDriftOperations` (odoo_sdk/lib/src/model/generic_drift_operations
/// .dart), usando una tabla Drift REAL (compilada, no un mock) para poder
/// ejecutar SQL de verdad — igual que en producción.
///
/// ## ⚠️ Pendiente de regenerar (build_runner en odoo_sdk)
///
/// Este archivo tiene `part 'generic_drift_operations_upsert_test.g.dart';`
/// — necesita que alguien corra
/// `cd odoo_sdk && dart run build_runner build --delete-conflicting-outputs`
/// (con `drift_dev`, que ya es dev_dependency de odoo_sdk) antes de poder
/// ejecutarse. No lo corrí yo mismo porque la instrucción de esta fase fue
/// "NO build_runner sin avisar" — avisando acá.
///
/// ## Qué cubre
///
/// 1. Caso positivo: un companion bien formado (todas sus claves matchean
///    columnas reales) se inserta y actualiza correctamente vía
///    `upsertLocal`/`upsertLocalBatch`, preservando la resolución de
///    conflicto actual (odoo_id -> line_uuid -> uuid).
/// 2. Caso NEGATIVO (el que pidió explícitamente la Fase F1): un companion
///    con una clave que NO matchea ninguna columna real (ej. el bug
///    `country_id_name` en vez de `country_name` encontrado en julio 2026)
///    ahora debe LANZAR una excepción en vez de descartar el dato en
///    silencio. Este es el cambio de comportamiento deliberado documentado
///    en `_throwIfDroppedKeys()`.
///
/// ## Por qué NO se migró a la API tipada de Drift (insertOnConflictUpdate/
/// DoUpdate)
///
/// Se investigó y probó empíricamente (ver reporte de la Fase F1) que
/// `DoUpdate<T extends Table, D>` y el `where((t) => ...)` de
/// `select`/`update` EXIGEN conocer el tipo Drift concreto de la tabla
/// generada (ej. `$FakeThingsTable` acá abajo) — algo que
/// `GenericDriftOperations<T>` no puede conocer en tiempo de compilación
/// (solo tiene `TableInfo` erasado). Ni siquiera `(x as dynamic)` lo
/// resuelve: Dart sigue validando en runtime el tipo real del argumento
/// contra la firma real del método resuelto. Por eso el mecanismo sigue
/// siendo SQL crudo — pero con la validación de claves fantasma ahora
/// SIEMPRE activa (no solo en debug), que es la parte del objetivo que sí
/// se pudo recuperar sin la migración completa.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:odoo_sdk/src/model/generic_drift_operations.dart';
import 'package:odoo_sdk/src/model/odoo_model_manager.dart';

part 'generic_drift_operations_upsert_test.g.dart';

// ============================================================================
// Fixture: tabla Drift real + modelo + manager mínimos
// ============================================================================

// DataClassName evita la colisión: sin esto, Drift genera su data class como
// `FakeThing` (singular de FakeThings), el mismo nombre del modelo manual de
// abajo, y el .g.dart no compila.
@DataClassName('FakeThingRow')
class FakeThings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get odooId => integer().unique().nullable()();
  TextColumn get lineUuid => text().unique().nullable()();
  TextColumn get name => text()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
}

@DriftDatabase(tables: [FakeThings])
class FakeThingsDb extends _$FakeThingsDb {
  FakeThingsDb(super.e);

  @override
  int get schemaVersion => 1;
}

/// Modelo plano (no Freezed — no hace falta para este test de mecanismo).
class FakeThing {
  final int id;
  final String? lineUuid;
  final String name;
  final double price;

  const FakeThing({
    required this.id,
    this.lineUuid,
    required this.name,
    required this.price,
  });

  @override
  bool operator ==(Object other) =>
      other is FakeThing &&
      id == other.id &&
      lineUuid == other.lineUuid &&
      name == other.name &&
      price == other.price;

  @override
  int get hashCode => Object.hash(id, lineUuid, name, price);

  @override
  String toString() =>
      'FakeThing(id: $id, lineUuid: $lineUuid, name: $name, price: $price)';
}

/// Manager que SÍ usa GenericDriftOperations — el mecanismo bajo prueba.
///
/// `wrongCompanionKey` simula el bug real encontrado: cuando es `true`,
/// `createDriftCompanion()` escribe a una clave que no existe como columna
/// (`name_wrong` en vez de `name`) — exactamente la forma del bug de
/// `@OdooMany2OneName` (`country_id_name` en vez de `country_name`).
class FakeThingManager extends OdooModelManager<FakeThing>
    with GenericDriftOperations<FakeThing> {
  FakeThingManager(this._db, {this.wrongCompanionKey = false}) {
    // resolveTable() usa el campo `db` interno del base (no el getter
    // `database` de este fake) — sin initDb() retorna null.
    initDb(_db);
  }

  final GeneratedDatabase _db;
  final bool wrongCompanionKey;

  @override
  String get odooModel => 'fake.thing';

  @override
  String get tableName => 'fake_things';

  @override
  List<String> get odooFields => ['id', 'name', 'price'];

  @override
  GeneratedDatabase get database => _db;

  @override
  TableInfo get table => resolveTable()!;

  @override
  FakeThing fromOdoo(Map<String, dynamic> data) => FakeThing(
        id: data['id'] as int,
        name: data['name'] as String,
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  Map<String, dynamic> toOdoo(FakeThing record) => {
        'name': record.name,
        'price': record.price,
      };

  @override
  FakeThing fromDrift(dynamic row) => FakeThing(
        id: row.odooId as int,
        lineUuid: row.lineUuid as String?,
        name: row.name as String,
        price: row.price as double,
      );

  @override
  int getId(FakeThing record) => record.id;

  @override
  String? getUuid(FakeThing record) => record.lineUuid;

  @override
  FakeThing withIdAndUuid(FakeThing record, int id, String uuid) => FakeThing(
        id: id,
        lineUuid: uuid,
        name: record.name,
        price: record.price,
      );

  @override
  FakeThing withSyncStatus(FakeThing record, bool isSynced) => record;

  @override
  dynamic createDriftCompanion(FakeThing record) {
    return RawValuesInsertable({
      'odoo_id': driftVar<int>(record.id),
      'line_uuid': driftVar<String>(record.lineUuid),
      if (wrongCompanionKey)
        // Clave fantasma deliberada — no existe como columna ("name" sí
        // existe, "name_wrong" no). Simula el bug real de naming.
        'name_wrong': Variable<String>(record.name)
      else
        'name': Variable<String>(record.name),
      'price': Variable<double>(record.price),
    });
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeThingsDb db;

  setUp(() {
    db = FakeThingsDb(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('upsertLocal — caso positivo (companion bien formado)', () {
    test('inserta un registro nuevo y lo puede releer', () async {
      final manager = FakeThingManager(db);
      const record = FakeThing(id: 100, name: 'Tornillo', price: 1.5);

      await manager.upsertLocal(record);
      final readBack = await manager.readLocal(100);

      expect(readBack, isNotNull);
      expect(readBack!.name, equals('Tornillo'));
      expect(readBack.price, equals(1.5));
    });

    test('actualiza un registro existente vía ON CONFLICT (odoo_id)',
        () async {
      final manager = FakeThingManager(db);
      await manager.upsertLocal(
        const FakeThing(id: 101, name: 'Original', price: 1.0),
      );
      await manager.upsertLocal(
        const FakeThing(id: 101, name: 'Actualizado', price: 2.0),
      );

      final readBack = await manager.readLocal(101);
      expect(readBack!.name, equals('Actualizado'));
      expect(readBack.price, equals(2.0));

      final all = await manager.searchLocal();
      expect(all, hasLength(1), reason: 'no debe duplicar la fila');
    });

    test('upsertLocalBatch inserta varios registros en una sola transacción',
        () async {
      final manager = FakeThingManager(db);
      await manager.upsertLocalBatch([
        const FakeThing(id: 201, name: 'Uno', price: 1.0),
        const FakeThing(id: 202, name: 'Dos', price: 2.0),
        const FakeThing(id: 203, name: 'Tres', price: 3.0),
      ]);

      final all = await manager.searchLocal();
      expect(all, hasLength(3));
    });
  });

  group('upsertLocal — caso NEGATIVO (companion con clave fantasma)', () {
    test(
      'lanza StateError en vez de descartar el dato en silencio',
      () async {
        final manager = FakeThingManager(db, wrongCompanionKey: true);
        const record = FakeThing(id: 300, name: 'Nunca se guarda', price: 9.0);

        // ANTES (mecanismo debug-only-warn): esto insertaba la fila SIN el
        // campo "name" (perdido en silencio) y el test hubiera pasado en
        // verde con datos incompletos. AHORA: debe tronar.
        expect(
          () => manager.upsertLocal(record),
          throwsA(isA<StateError>()),
        );

        // La fila NO debe haber quedado a medio insertar.
        final readBack = await manager.readLocal(300);
        expect(readBack, isNull);
      },
    );

    test(
      'upsertLocalBatch también lanza StateError antes de escribir nada',
      () async {
        final manager = FakeThingManager(db, wrongCompanionKey: true);

        await expectLater(
          manager.upsertLocalBatch([
            const FakeThing(id: 301, name: 'A', price: 1.0),
            const FakeThing(id: 302, name: 'B', price: 2.0),
          ]),
          throwsA(isA<StateError>()),
        );

        final all = await manager.searchLocal();
        expect(
          all,
          isEmpty,
          reason:
              'el lote completo debe abortar, no dejar registros parciales',
        );
      },
    );
  });
}
