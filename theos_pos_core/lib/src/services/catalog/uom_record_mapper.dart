import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class UomRecordMapper {
  static const fields = <String>[
    'id',
    'name',
    'factor',
    'rounding',
    'active',
    'write_date',
  ];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.uomUom,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('uom.uom id');
    final c = UomUomCompanion(
      odooId: Value(id),
      name: Value(d['name'] as String? ?? ''),
      factor: Value((d['factor'] as num?)?.toDouble() ?? 1),
      rounding: Value((d['rounding'] as num?)?.toDouble() ?? .01),
      active: Value(d['active'] as bool? ?? true),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(db.uomUom)..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.uomUom).insert(c);
    }
  }

  static Future<List<Map<String, dynamic>>> read(AppDatabase db) async =>
      (await db.select(db.uomUom).get())
          .map((r) => {'id': r.odooId, 'name': r.name, 'factor': r.factor})
          .toList(growable: false);
}
