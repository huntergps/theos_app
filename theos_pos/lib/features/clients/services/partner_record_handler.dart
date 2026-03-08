import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../core/services/handlers/model_record_handler.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

/// Handler for res.partner records
class PartnerRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'res.partner';

  @override
  List<String> get defaultFields => [
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

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.resPartner)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.resPartner)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    // Get commercial partner name if different from current
    String? commercialPartnerName;
    final commercialPartnerId = odoo.extractMany2oneId(data['commercial_partner_id']);
    if (commercialPartnerId != null && commercialPartnerId != id) {
      commercialPartnerName = odoo.extractMany2oneName(data['commercial_partner_id']);
    }

    final companion = ResPartnerCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      displayName: Value(data['display_name'] as String?),
      ref: Value(data['ref'] is String ? data['ref'] : null),
      vat: Value(data['vat'] is String ? data['vat'] : null),
      email: Value(data['email'] is String ? data['email'] : null),
      phone: Value(data['phone'] is String ? data['phone'] : null),
      street: Value(data['street'] is String ? data['street'] : null),
      street2: Value(data['street2'] is String ? data['street2'] : null),
      city: Value(data['city'] is String ? data['city'] : null),
      zip: Value(data['zip'] is String ? data['zip'] : null),
      countryId: Value(odoo.extractMany2oneId(data['country_id'])),
      countryName: Value(odoo.extractMany2oneName(data['country_id'])),
      stateId: Value(odoo.extractMany2oneId(data['state_id'])),
      stateName: Value(odoo.extractMany2oneName(data['state_id'])),
      avatar128: Value(data['avatar_128'] is String ? data['avatar_128'] : null),
      isCompany: Value(data['is_company'] as bool? ?? false),
      active: Value(data['active'] as bool? ?? true),
      parentId: Value(odoo.extractMany2oneId(data['parent_id'])),
      parentName: Value(odoo.extractMany2oneName(data['parent_id'])),
      commercialPartnerName: Value(commercialPartnerName),
      propertyProductPricelistId: Value(
        odoo.extractMany2oneId(data['property_product_pricelist']),
      ),
      propertyProductPricelistName: Value(
        odoo.extractMany2oneName(data['property_product_pricelist']),
      ),
      propertyPaymentTermId: Value(
        odoo.extractMany2oneId(data['property_payment_term_id']),
      ),
      propertyPaymentTermName: Value(
        odoo.extractMany2oneName(data['property_payment_term_id']),
      ),
      lang: Value(data['lang'] is String ? data['lang'] : null),
      comment: Value(data['comment'] is String ? data['comment'] : null),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.resPartner)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.resPartner).insert(companion);
    }
  }
}
