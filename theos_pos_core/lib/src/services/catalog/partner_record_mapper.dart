import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class PartnerRecordMapper {
  static const fields = <String>[
    'id',
    'name',
    'display_name',
    'ref',
    'vat',
    'email',
    'phone',
    'street',
    'street2',
    'city',
    'zip',
    'country_id',
    'state_id',
    'avatar_128',
    'is_company',
    'active',
    'parent_id',
    'commercial_partner_id',
    'property_product_pricelist',
    'property_payment_term_id',
    'lang',
    'comment',
    'write_date',
  ];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.resPartner,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('res.partner id');
    final commercialId = odoo.extractMany2oneId(d['commercial_partner_id']);
    final c = ResPartnerCompanion(
      odooId: Value(id),
      // 🔴 Odoo manda `false`, no `null` ni `''`, en cualquier campo de texto
      // vacío (Char/Text/Selection). `d['name'] as String?` no lo filtra:
      // `false as String?` lanza TypeError porque `bool` no es subtipo de
      // `String?` — sólo `null` lo es. Medido contra ERP2 el 12-sep-2026:
      // `TypeError: false: type 'bool' is not a subtype of type 'String'`
      // tumbaba la lectura entera de Clientes. `toStringOrNull` sí filtra
      // `false` (y preserva `''` tal cual, sin convertirla en null).
      name: Value(odoo.toStringOrNull(d['name']) ?? ''),
      displayName: Value(odoo.toStringOrNull(d['display_name'])),
      ref: Value(odoo.toStringOrNull(d['ref'])),
      vat: Value(odoo.toStringOrNull(d['vat'])),
      email: Value(odoo.toStringOrNull(d['email'])),
      phone: Value(odoo.toStringOrNull(d['phone'])),
      street: Value(odoo.toStringOrNull(d['street'])),
      street2: Value(odoo.toStringOrNull(d['street2'])),
      city: Value(odoo.toStringOrNull(d['city'])),
      zip: Value(odoo.toStringOrNull(d['zip'])),
      countryId: Value(odoo.extractMany2oneId(d['country_id'])),
      countryName: Value(odoo.extractMany2oneName(d['country_id'])),
      stateId: Value(odoo.extractMany2oneId(d['state_id'])),
      stateName: Value(odoo.extractMany2oneName(d['state_id'])),
      avatar128: Value(odoo.toStringOrNull(d['avatar_128'])),
      isCompany: Value(d['is_company'] as bool? ?? false),
      active: Value(d['active'] as bool? ?? true),
      parentId: Value(odoo.extractMany2oneId(d['parent_id'])),
      parentName: Value(odoo.extractMany2oneName(d['parent_id'])),
      commercialPartnerId: Value(commercialId),
      commercialPartnerName: Value(
        commercialId == id
            ? null
            : odoo.extractMany2oneName(d['commercial_partner_id']),
      ),
      propertyProductPricelist: Value(
        odoo.extractMany2oneId(d['property_product_pricelist']),
      ),
      propertyProductPricelistName: Value(
        odoo.extractMany2oneName(d['property_product_pricelist']),
      ),
      propertyPaymentTermId: Value(
        odoo.extractMany2oneId(d['property_payment_term_id']),
      ),
      propertyPaymentTermName: Value(
        odoo.extractMany2oneName(d['property_payment_term_id']),
      ),
      lang: Value(odoo.toStringOrNull(d['lang'])),
      comment: Value(odoo.toStringOrNull(d['comment'])),
      customerRank: Value((d['customer_rank'] as num?)?.toInt() ?? 0),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.resPartner,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.resPartner).insert(c);
    }
  }

  static Future<List<Map<String, dynamic>>> read(AppDatabase db) async =>
      (await db.select(db.resPartner).get())
          .map(
            (r) => {
              'id': r.odooId,
              'name': r.name,
              'vat': r.vat,
              'email': r.email,
              'phone': r.phone,
            },
          )
          .toList(growable: false);
}
