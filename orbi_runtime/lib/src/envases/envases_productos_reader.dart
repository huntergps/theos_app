import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

import 'envases_dashboard_reader.dart' show EnvasesSearchReadTransport;

/// Un producto ofrecible como envase en una línea del asistente de envío.
final class EnvasesProductoRow {
  const EnvasesProductoRow({required this.id, required this.name, required this.uomId, required this.uomName});
  final int id;
  final String name;
  final int uomId;
  final String uomName;
}

/// Read-only binding for the products the "Enviar" form may offer.
///
/// 🔴 `l10n_ec.stock.envases.wizard.envio.line.product_id`
/// (`wizards/wizard_envio.py`) **no declara ningún dominio** — ni en el
/// campo Python ni en la vista (`views/wizard_envio_views.xml:20`, sólo
/// `<field name="product_id"/>`): cualquier `product.product` pasa por ahí
/// sin que Odoo lo rechace. Este lector filtra igual por
/// `product_tmpl_id.envases_es_retornable = True`
/// (`models/product_template.py:35-40`, "Marca que ESTE producto es el
/// envase que se controla y se custodia... no algo que se venda como
/// contenido") porque es el MISMO dominio que el propio módulo usa en sus
/// otros dos selectores de "qué cuenta como envase"
/// (`envases_contenedor_id` y `envases_intercambiable_ids`,
/// `models/product_template.py:45` y `:74`) — no una restricción que
/// Odoo aplique en el asistente de envío en sí.
final class EnvasesProductosReader {
  static const model = 'product.product';
  static const fields = <String>['id', 'name', 'uom_id'];
  static const order = 'name asc';

  final CompanyContext company;
  final EnvasesSearchReadTransport transport;

  const EnvasesProductosReader({required this.company, required this.transport});

  factory EnvasesProductosReader.fromClient({required OdooClient client, required CompanyContext company}) =>
      EnvasesProductosReader(
        company: company,
        transport:
            ({
              required String model,
              required List<dynamic> domain,
              required List<String> fields,
              required Map<String, dynamic> context,
              required int limit,
              required int offset,
              required String order,
            }) => client
                .call(
                  model: model,
                  method: 'search_read',
                  kwargs: {
                    'domain': domain,
                    'fields': fields,
                    'limit': limit,
                    'offset': offset,
                    'order': order,
                  },
                  context: context,
                )
                .then((value) {
                  if (value is! List) {
                    throw const FormatException('Invalid search_read response');
                  }
                  return value
                      .map<Map<String, dynamic>>((item) {
                        if (item is! Map) {
                          throw const FormatException('Invalid search_read row');
                        }
                        return Map<String, dynamic>.from(item);
                      })
                      .toList(growable: false);
                }),
      );

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<EnvasesProductoRow>> leer() async {
    final rows = await transport(
      model: model,
      domain: const [
        ['product_tmpl_id.envases_es_retornable', '=', true],
        ['active', '=', true],
      ],
      fields: fields,
      context: context,
      limit: 1000,
      offset: 0,
      order: order,
    );
    return rows.map(_productoFromJson).toList(growable: false);
  }

  static EnvasesProductoRow _productoFromJson(Map<String, dynamic> json) {
    final uom = _many2one(json, 'uom_id');
    return EnvasesProductoRow(id: _positiveInt(json, 'id'), name: _string(json, 'name'), uomId: uom.$1, uomName: uom.$2);
  }
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Invalid positive integer field: $key');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid string field: $key');
  return value;
}

(int, String) _many2one(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.length == 2 && value[0] is int && value[0] > 0) {
    return (value[0] as int, value[1] is String ? value[1] as String : '');
  }
  throw FormatException('Invalid many2one field: $key');
}
