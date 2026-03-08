/// Tests for OdooFieldRegistry consistency.
///
/// Verifies that:
/// 1. Registry covers all expected models
/// 2. Registry field column names match actual Drift table columns
/// 3. WebSocket fields are a subset of all registered fields
/// 4. No duplicate field definitions exist
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:theos_pos_core/src/database/database.dart';
import 'package:theos_pos_core/src/odoo_field_registry.dart';

void main() {
  // Suppress warning about multiple database instances (expected in tests)
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // Helper: Get Drift table for a model name
  // =========================================================================

  TableInfo<Table, dynamic> getTable(String model) {
    switch (model) {
      case 'sale.order':
        return db.saleOrder;
      case 'res.partner':
        return db.resPartner;
      case 'product.product':
        return db.productProduct;
      case 'account.move':
        return db.accountMove;
      case 'res.company':
        return db.resCompanyTable;
      case 'res.users':
        return db.resUsers;
      default:
        throw ArgumentError('Unknown model: $model');
    }
  }

  // =========================================================================
  // Test 1: Registry covers all expected models
  // =========================================================================

  test('Registry covers all synced models', () {
    expect(
      OdooFieldRegistry.models.keys,
      containsAll([
        'sale.order',
        'res.partner',
        'product.product',
        'res.company',
        'res.users',
        'account.move',
      ]),
    );
  });

  // =========================================================================
  // Test 2: Registry field column names match Drift table columns
  // =========================================================================

  for (final entry in OdooFieldRegistry.models.entries) {
    final model = entry.key;
    final fields = entry.value;

    test('$model: registry field columns exist in Drift table', () {
      final table = getTable(model);
      final driftColumnNames =
          table.$columns.map((c) => c.name).toSet();

      final missingColumns = <String>[];
      for (final field in fields) {
        if (!driftColumnNames.contains(field.columnName)) {
          missingColumns.add(
            '${field.odooName} -> ${field.columnName}',
          );
        }
      }

      expect(
        missingColumns,
        isEmpty,
        reason:
            '$model: these registry fields map to columns that do NOT exist '
            'in the Drift table:\n  ${missingColumns.join('\n  ')}',
      );
    });
  }

  // =========================================================================
  // Test 3: WebSocket fields are subset of all registered fields
  // =========================================================================

  for (final model in OdooFieldRegistry.models.keys) {
    test('$model: WebSocket fields are subset of all fields', () {
      final wsFields = OdooFieldRegistry.getWebSocketFields(model);
      final allOdooNames = OdooFieldRegistry.models[model]!
          .map((f) => f.odooName)
          .toSet();

      final extraWsFields =
          wsFields.where((f) => !allOdooNames.contains(f)).toList();

      expect(
        extraWsFields,
        isEmpty,
        reason:
            '$model: WebSocket fields not in registry: $extraWsFields',
      );
    });
  }

  // =========================================================================
  // Test 4: API fields are subset of all registered fields
  // =========================================================================

  for (final model in OdooFieldRegistry.models.keys) {
    test('$model: API fields are subset of all fields', () {
      final apiFields = OdooFieldRegistry.getOdooFields(model);
      final allOdooNames = OdooFieldRegistry.models[model]!
          .map((f) => f.odooName)
          .toSet();

      final extraApiFields =
          apiFields.where((f) => !allOdooNames.contains(f)).toList();

      expect(
        extraApiFields,
        isEmpty,
        reason: '$model: API fields not in registry: $extraApiFields',
      );
    });
  }

  // =========================================================================
  // Test 5: No duplicate odooName within a model
  // =========================================================================

  for (final entry in OdooFieldRegistry.models.entries) {
    final model = entry.key;
    final fields = entry.value;

    test('$model: no duplicate odooName entries', () {
      final seen = <String>{};
      final duplicates = <String>[];

      for (final field in fields) {
        if (!seen.add(field.odooName)) {
          duplicates.add(field.odooName);
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: '$model: duplicate odooName entries: $duplicates',
      );
    });
  }

  // =========================================================================
  // Test 6: No duplicate dartName within a model
  // =========================================================================

  for (final entry in OdooFieldRegistry.models.entries) {
    final model = entry.key;
    final fields = entry.value;

    test('$model: no duplicate dartName entries', () {
      final seen = <String>{};
      final duplicates = <String>[];

      for (final field in fields) {
        if (!seen.add(field.dartName)) {
          duplicates.add(field.dartName);
        }
      }

      expect(
        duplicates,
        isEmpty,
        reason: '$model: duplicate dartName entries: $duplicates',
      );
    });
  }

  // =========================================================================
  // Test 7: getFieldMapping returns only WebSocket fields
  // =========================================================================

  for (final model in OdooFieldRegistry.models.keys) {
    test('$model: getFieldMapping returns only syncViaWebSocket fields', () {
      final mapping = OdooFieldRegistry.getFieldMapping(model);
      final fields = OdooFieldRegistry.models[model]!;

      for (final field in fields) {
        if (field.syncViaWebSocket) {
          expect(
            mapping.containsKey(field.odooName),
            isTrue,
            reason:
                '${field.odooName} has syncViaWebSocket=true but is missing '
                'from getFieldMapping()',
          );
        } else {
          expect(
            mapping.containsKey(field.odooName),
            isFalse,
            reason:
                '${field.odooName} has syncViaWebSocket=false but appears '
                'in getFieldMapping()',
          );
        }
      }
    });
  }

  // =========================================================================
  // Test 8: getOdooFields returns only API fields
  // =========================================================================

  for (final model in OdooFieldRegistry.models.keys) {
    test('$model: getOdooFields returns only syncViaApi fields', () {
      final apiFields = OdooFieldRegistry.getOdooFields(model).toSet();
      final fields = OdooFieldRegistry.models[model]!;

      for (final field in fields) {
        if (field.syncViaApi) {
          expect(
            apiFields.contains(field.odooName),
            isTrue,
            reason:
                '${field.odooName} has syncViaApi=true but is missing '
                'from getOdooFields()',
          );
        } else {
          expect(
            apiFields.contains(field.odooName),
            isFalse,
            reason:
                '${field.odooName} has syncViaApi=false but appears '
                'in getOdooFields()',
          );
        }
      }
    });
  }
}
