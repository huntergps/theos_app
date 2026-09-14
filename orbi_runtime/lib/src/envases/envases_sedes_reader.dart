import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

import 'envases_dashboard_reader.dart' show EnvasesSearchReadTransport;

/// Una sede (`stock.warehouse`) ofrecible en el formulario de envío.
final class EnvasesSedeRow {
  const EnvasesSedeRow({required this.id, required this.name});
  final int id;
  final String name;
}

final class EnvasesSedesResult {
  EnvasesSedesResult({required Iterable<EnvasesSedeRow> propias, required Iterable<EnvasesSedeRow> posibles})
    : propias = List.unmodifiable(propias),
      posibles = List.unmodifiable(posibles);

  /// `res.users.envases_warehouse_ids` del usuario que llama — vacío es
  /// "ninguna sede", nunca "todas" (`res_users.py` en
  /// `l10n_ec_stock_envases`, orden del dueño transcrita ahí mismo).
  final List<EnvasesSedeRow> propias;

  /// Todas las sedes con `controla_envases = True` de la compañía activa —
  /// el dominio de destino del asistente de envío.
  final List<EnvasesSedeRow> posibles;
}

/// Read-only binding for the two sede lists the "Enviar" form needs:
/// `res.users.envases_warehouse_ids` (origen posible) y `stock.warehouse`
/// con `controla_envases = True` (destino posible) —
/// `l10n_ec_stock_envases/models/res_users.py` y `models/stock_warehouse.py`.
///
/// No hay `ir.rule` detrás de ninguno de los dos campos: sólo deciden qué
/// se OFRECE. La comprobación real vuelve a vivir en
/// `wizards/wizard_envio.py:action_enviar()`, del lado de Odoo — este
/// lector no repite esa validación, sólo la lista.
final class EnvasesSedesReader {
  static const warehouseModel = 'stock.warehouse';
  static const warehouseFields = <String>['id', 'name'];
  static const warehouseOrder = 'name asc';
  static const userModel = 'res.users';
  static const userFields = <String>['id', 'envases_warehouse_ids'];

  final CompanyContext company;

  /// El `uid` de la sesión activa (`AppScope.userId`) — `envases_warehouse_ids`
  /// es un campo de `res.users`, no hay forma de pedir "el mío" sin decir
  /// de quién. Mismo patrón que `RuntimeAccountLoader._runUser`
  /// (`json2_read_adapters.dart`): `search_read` con
  /// `[('id', '=', userId)]`, nunca `read(ids: [...])`.
  final int userId;

  final EnvasesSearchReadTransport transport;

  const EnvasesSedesReader({required this.company, required this.userId, required this.transport});

  factory EnvasesSedesReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
    required int userId,
  }) => EnvasesSedesReader(
    company: company,
    userId: userId,
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

  Future<EnvasesSedesResult> leer() async {
    final posiblesRows = await transport(
      model: warehouseModel,
      domain: [
        ['controla_envases', '=', true],
        ['company_id', '=', company.companyId],
      ],
      fields: warehouseFields,
      context: context,
      limit: 500,
      offset: 0,
      order: warehouseOrder,
    );
    final posibles = posiblesRows.map(_sedeFromJson).toList(growable: false);
    final ids = <int>{};
    for (final sede in posibles) {
      if (!ids.add(sede.id)) {
        throw StateError('Repeated stock.warehouse id: ${sede.id}');
      }
    }

    final userRows = await transport(
      model: userModel,
      domain: [
        ['id', '=', userId],
      ],
      fields: userFields,
      context: context,
      limit: 1,
      offset: 0,
      order: 'id asc',
    );
    if (userRows.isEmpty) {
      throw StateError('res.users row not found for uid $userId');
    }
    final propiaIds = _many2manyIds(userRows.single, 'envases_warehouse_ids').toSet();
    // Filtered from `posibles`, not built from `propiaIds` directly: this
    // keeps the same `name asc` order the destino ComboBox already uses,
    // instead of whatever order Odoo happened to store the many2many in.
    final propias = posibles.where((sede) => propiaIds.contains(sede.id)).toList(growable: false);
    return EnvasesSedesResult(propias: propias, posibles: posibles);
  }

  static EnvasesSedeRow _sedeFromJson(Map<String, dynamic> json) => EnvasesSedeRow(
    id: _positiveInt(json, 'id'),
    name: _string(json, 'name'),
  );
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

List<int> _many2manyIds(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value == false) return const [];
  if (value is! List) throw FormatException('Invalid many2many field: $key');
  return value.map((item) {
    if (item is! int) throw FormatException('Invalid many2many id in field: $key');
    return item;
  }).toList(growable: false);
}
