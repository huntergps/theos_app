/// Roundtrip exhaustivo `upsertLocal` → `readLocal` para TODOS los managers
/// generados (los que usan `GenericDriftOperations`) registrados en
/// theos_pos_core.
///
/// ## Por qué existe este test
///
/// Es el prerequisito obligatorio antes de migrar `upsertLocal`/
/// `upsertLocalBatch` (en `odoo_sdk/lib/src/model/generic_drift_operations
/// .dart`) del mecanismo actual (SQL crudo manual vía `customStatement`) a
/// la API tipada de Drift (`insertOnConflictUpdate`). Ver
/// `d-data.md` ítem 2: el mecanismo actual descarta EN SILENCIO cualquier
/// clave de `createDriftCompanion()` que no matchee una columna real — eso
/// ya causó bugs reales (columnas fantasma `country_id_name` en vez de
/// `country_name`, corregidas en julio 2026). Antes de cambiar el mecanismo
/// de escritura hace falta una red de pruebas que detecte cualquier mismatch
/// de columna EN CUALQUIER modelo, no solo en los que ya se auditaron a mano.
///
/// ## Estrategia (100% genérica, sin código por-modelo)
///
/// Para cada manager:
/// 1. Se resuelve la tabla Drift real (`manager.table`) — fuente de verdad.
/// 2. Se construye una fila Drift FALSA ([FakeDriftRow]) que responde a
///    CUALQUIER getter que pida `fromDrift()`, generando un valor centinela
///    determinístico y ÚNICO por columna, tipado exactamente según el tipo
///    Dart real de esa columna (`GeneratedColumn<int|String|double|bool|
///    DateTime>`) — nunca hay riesgo de `TypeError` por cast incorrecto.
/// 3. `record = manager.fromDrift(fakeRow)` — construye una instancia real
///    del modelo con TODOS los campos que Drift conoce poblados con valores
///    no-default y distinguibles entre sí.
/// 4. `manager.upsertLocal(record)` — el mecanismo bajo prueba.
/// 5. `manager.readLocal(manager.getId(record))` — relee de la DB real
///    (SQLite en memoria).
/// 6. Se compara `record` vs `readBack` con `==` (Freezed genera igualdad
///    profunda por TODOS los campos del constructor, incluyendo los que
///    `toOdoo()` excluye a propósito — ej. `@OdooMany2OneName`, campos
///    local-only — que es justo la clase de bug que este test debe cazar).
///
/// No se compara contra `toOdoo()` porque ESE método excluye a propósito
/// los campos no-escribibles (Many2OneName, localOnly, computed, id) — que
/// son exactamente los campos donde ya se encontró un bug de naming real.
///
/// ## Limitación conocida y documentada
///
/// Los campos `@OdooSelection` con enum (`isEnumType`) hacen
/// `EnumType.values.firstWhere(code == valorLeido, orElse: () => .first)`.
/// El centinela genérico (un string JSON arbitrario) nunca matchea un
/// código de enum real, así que estos campos colapsan a `.values.first`
/// tanto en el registro original como en el releído — el test sigue
/// pasando, pero no distingue una columna de enum mal nombreada de una bien
/// nombreada. Es una limitación aceptada del enfoque genérico (no hay forma
/// de conocer en runtime, sin metadata de compilación, qué string es un
/// código de enum válido para una columna arbitraria). El resto de tipos
/// (string, int, double, bool, datetime, selection no-enum, json-map,
/// many2one id, many2oneName, reference, storedComputed/related) SÍ quedan
/// completamente cubiertos.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:theos_pos_core/src/database/database.dart';

import 'package:theos_pos_core/src/models/activities/mail_activity.model.dart';
import 'package:theos_pos_core/src/models/advances/advance.model.dart';
import 'package:theos_pos_core/src/models/banks/bank.model.dart';
import 'package:theos_pos_core/src/models/clients/client.model.dart';
import 'package:theos_pos_core/src/models/collection/account_payment.model.dart';
import 'package:theos_pos_core/src/models/collection/cash_out.model.dart';
import 'package:theos_pos_core/src/models/collection/collection_config.model.dart';
import 'package:theos_pos_core/src/models/collection/collection_session.model.dart';
import 'package:theos_pos_core/src/models/collection/collection_session_cash.model.dart';
import 'package:theos_pos_core/src/models/collection/collection_session_deposit.model.dart';
import 'package:theos_pos_core/src/models/company/company.model.dart';
import 'package:theos_pos_core/src/models/config/currency.model.dart';
import 'package:theos_pos_core/src/models/invoices/account_move.model.dart';
import 'package:theos_pos_core/src/models/payment_terms/payment_term.model.dart';
import 'package:theos_pos_core/src/models/prices/pricelist.model.dart';
import 'package:theos_pos_core/src/models/products/product.model.dart';
import 'package:theos_pos_core/src/models/products/product_category.model.dart';
import 'package:theos_pos_core/src/models/products/product_uom.model.dart';
import 'package:theos_pos_core/src/models/products/uom.model.dart';
import 'package:theos_pos_core/src/models/sales/payment_line.model.dart';
import 'package:theos_pos_core/src/models/sales/sale_order.model.dart';
import 'package:theos_pos_core/src/models/sales/sale_order_line.model.dart';
import 'package:theos_pos_core/src/models/sales/sales_team.model.dart';
import 'package:theos_pos_core/src/models/sales/withhold_line.model.dart';
import 'package:theos_pos_core/src/models/shared/res_country.model.dart';
import 'package:theos_pos_core/src/models/shared/res_country_state.model.dart';
import 'package:theos_pos_core/src/models/shared/res_lang.model.dart';
import 'package:theos_pos_core/src/models/shared/resource_calendar.model.dart';
import 'package:theos_pos_core/src/models/taxes/fiscal_position.model.dart';
import 'package:theos_pos_core/src/models/taxes/tax.model.dart';
import 'package:theos_pos_core/src/models/users/user.model.dart';
import 'package:theos_pos_core/src/models/warehouses/warehouse.model.dart';

// ============================================================================
// FakeDriftRow — fila Drift genérica y determinística para CUALQUIER tabla
// ============================================================================

/// Fila falsa usable con cualquier `fromDrift(dynamic row)` generado.
///
/// Resuelve dinámicamente (`noSuchMethod`) cualquier getter que se le pida,
/// buscando la columna REAL con ese nombre en [table] (aplicando el mismo
/// algoritmo de snake_case que usa Drift internamente — ver
/// `odoo_model_generator.dart:_toSnakeCase`) y generando un valor centinela
/// tipado exactamente según el tipo Dart real de esa columna. Cada columna
/// recibe un valor DISTINTO (contador incremental) para poder detectar
/// también bugs de "campo A escribe en la columna de B" (ambos del mismo
/// tipo), no solo "campo perdido".
class FakeDriftRow {
  FakeDriftRow(this.table);

  final TableInfo table;
  final Map<String, Object> _cache = {};
  int _counter = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (!invocation.isGetter) return super.noSuchMethod(invocation);

    final name = _symbolName(invocation.memberName);
    final cached = _cache[name];
    if (cached != null) return cached;

    final column = _findColumn(name);
    if (column == null) {
      throw StateError(
        'FakeDriftRow: fromDrift() pidió el getter "$name" pero la tabla '
        '"${table.actualTableName}" no tiene ninguna columna real con ese '
        'nombre (buscado como "${_toDriftSnakeCase(name)}"). Esto indica un '
        'mismatch de naming entre el modelo (@Odoo* annotations) y la tabla '
        'Drift — revisar driftAccessorName / la columna en la tabla manual.',
      );
    }

    _counter++;
    final value = _sentinelForColumn(column, _counter);
    _cache[name] = value;
    return value;
  }

  GeneratedColumn? _findColumn(String getterName) {
    final snake = _toDriftSnakeCase(getterName);
    for (final col in table.$columns) {
      if (col.$name == snake) return col;
    }
    return null;
  }

  Object _sentinelForColumn(GeneratedColumn column, int n) {
    if (column is GeneratedColumn<int>) return 1000000 + n;
    if (column is GeneratedColumn<double>) return 1000.0 + (n / 100);
    if (column is GeneratedColumn<bool>) return n.isEven;
    if (column is GeneratedColumn<DateTime>) {
      // DOS cuidados para no generar falsos positivos (no son bugs reales):
      // 1. Precisión de segundo completo — Drift almacena DateTime como
      //    unix timestamp en SEGUNDOS, no milisegundos.
      // 2. DateTime LOCAL, no UTC — Drift/sqlite3 reconstruye DateTime al
      //    releer con isUtc=false por defecto (no hay config de zona horaria
      //    en este proyecto). DateTime.== en Dart compara también el flag
      //    isUtc, no solo el instante — un centinela `.utc(...)` fallaría
      //    contra el releído (`isUtc=false`) aunque sea el MISMO instante.
      return DateTime(2026, 1, 1).add(Duration(minutes: n));
    }
    // String — incluye campos JSON-map (reciben un JSON válido, así
    // parseOdooJson() en fromDrift también los puede decodificar de vuelta)
    // y selection no-enum (roundtrip exacto, sin fallback).
    return '{"v":"sentinel_${column.$name}_$n"}';
  }
}

String _symbolName(Symbol symbol) {
  // No hay forma pública de leer un Symbol sin dart:mirrors (no disponible/
  // no deseable aquí) — pero el toString() de Symbol es estable y contiene
  // el nombre literal: Symbol("countryName") -> countryName.
  final s = symbol.toString();
  return s.substring('Symbol("'.length, s.length - 2);
}

/// Mismo algoritmo que `_toSnakeCase` en `odoo_model_generator.dart` y que
/// Drift usa internamente (paquete `recase`, `ReCase.snakeCase`): inserta
/// '_' antes de cada mayúscula (salvo la primera letra) y pasa a minúsculas.
String _toDriftSnakeCase(String input) {
  final result = input.replaceAllMapped(
    RegExp('([A-Z])'),
    (match) => '_${match.group(1)!.toLowerCase()}',
  );
  return result.startsWith('_') ? result.substring(1) : result;
}

// ============================================================================
// Registro de managers a probar
// ============================================================================

/// Todos los managers generados con `GenericDriftOperations` registrados en
/// theos_pos_core (confirmado por grep: `with GenericDriftOperations` en
/// `theos_pos_core/lib/src/models/**/*.model.g.dart`, julio 2026).
///
/// Si se agrega un modelo `@OdooModel` nuevo, agregar UNA línea acá — el
/// resto del test es 100% genérico.
final Map<String, dynamic Function()> _managerFactories = {
  'MailActivityManager': () => MailActivityManager(),
  'AdvanceManager': () => AdvanceManager(),
  'AdvanceLineManager': () => AdvanceLineManager(),
  'BankManager': () => BankManager(),
  'PartnerBankManager': () => PartnerBankManager(),
  'ClientManager': () => ClientManager(),
  'AccountPaymentManager': () => AccountPaymentManager(),
  'CashOutManager': () => CashOutManager(),
  'CollectionConfigManager': () => CollectionConfigManager(),
  'CollectionSessionManager': () => CollectionSessionManager(),
  'CollectionSessionCashManager': () => CollectionSessionCashManager(),
  'CollectionSessionDepositManager': () => CollectionSessionDepositManager(),
  'CompanyManager': () => CompanyManager(),
  'CurrencyManager': () => CurrencyManager(),
  'DecimalPrecisionManager': () => DecimalPrecisionManager(),
  'AccountMoveManager': () => AccountMoveManager(),
  'AccountMoveLineManager': () => AccountMoveLineManager(),
  'PaymentTermManager': () => PaymentTermManager(),
  'PricelistManager': () => PricelistManager(),
  'ProductManager': () => ProductManager(),
  'ProductCategoryManager': () => ProductCategoryManager(),
  'ProductUomManager': () => ProductUomManager(),
  'UomManager': () => UomManager(),
  'PaymentLineManager': () => PaymentLineManager(),
  'CardLoteManager': () => CardLoteManager(),
  'SaleOrderManager': () => SaleOrderManager(),
  'SaleOrderLineManager': () => SaleOrderLineManager(),
  'SalesTeamManager': () => SalesTeamManager(),
  'WithholdLineManager': () => WithholdLineManager(),
  'ResCountryManager': () => ResCountryManager(),
  'ResCountryStateManager': () => ResCountryStateManager(),
  'ResLangManager': () => ResLangManager(),
  'ResourceCalendarManager': () => ResourceCalendarManager(),
  'FiscalPositionManager': () => FiscalPositionManager(),
  'TaxManager': () => TaxManager(),
  'UserManager': () => UserManager(),
  'WarehouseManager': () => WarehouseManager(),
};

void main() {
  // Se crean varias AppDatabase in-memory en el mismo proceso de test.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'sanity: se están probando los 37 managers generados conocidos',
    () {
      // Si este número cambia porque se agregó/quitó un @OdooModel, hay que
      // actualizar _managerFactories arriba (agregar o quitar una línea).
      expect(_managerFactories, hasLength(37));
    },
  );

  group('upsertLocal -> readLocal roundtrip (mecanismo actual)', () {
    for (final entry in _managerFactories.entries) {
      final name = entry.key;
      final factory = entry.value;

      test(name, () async {
        final manager = factory();
        (manager as dynamic).initDb(db);

        final fakeRow = FakeDriftRow(manager.table as TableInfo);
        final dynamic original = manager.fromDrift(fakeRow);

        await manager.upsertLocal(original);

        final id = manager.getId(original) as int;
        final dynamic readBack = await manager.readLocal(id);

        expect(
          readBack,
          isNotNull,
          reason:
              '$name: readLocal($id) no encontró el registro recién '
              'insertado — posible mismatch en la columna usada para el ID '
              '(odoo_id) o en la resolución de la clave de conflicto.',
        );

        expect(
          readBack,
          equals(original),
          reason:
              '$name: el registro releído difiere del original.\n'
              'Original: $original\n'
              'Releído:  $readBack',
        );
      });
    }
  });
}
