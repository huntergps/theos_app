import 'package:odoo_sdk/odoo_sdk.dart';

import '../contracts.dart';
import 'envases_dashboard_reader.dart';

/// Read-only binding for the derived per-third-party Envases balance view.
final class EnvasesPartnerBalanceReader {
  static const model = 'l10n_ec.envases.saldo.tercero';
  static const fields = <String>[
    'id',
    'location_id',
    'warehouse_id',
    'envases_rol',
    'partner_id',
    'product_id',
    'company_id',
    'cantidad',
  ];
  static const order =
      'partner_id asc,product_id asc,location_id asc,company_id asc,id asc';
  static const roles = {'custodia_cliente', 'custodia_proveedor'};

  EnvasesPartnerBalanceReader({
    required this.company,
    required this.transport,
    this.limit = 100,
    this.partnerId,
    this.productId,
    this.locationId,
    this.role,
  }) {
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 500');
    }
    _positiveOptional(partnerId, 'partnerId');
    _positiveOptional(productId, 'productId');
    _positiveOptional(locationId, 'locationId');
    if (role != null && !roles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'must be a custody role');
    }
  }

  /// `search_read` direct, same pattern as `EnvasesPickingLineasReader`:
  /// `OdooClient.searchRead` never threads a `context`, and this reader
  /// needs `allowed_company_ids`/`company_id` on every request, so the
  /// transport calls `search_read` through `client.call` instead.
  factory EnvasesPartnerBalanceReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
    int limit = 100,
    int? partnerId,
    int? productId,
    int? locationId,
    String? role,
  }) => EnvasesPartnerBalanceReader(
    company: company,
    limit: limit,
    partnerId: partnerId,
    productId: productId,
    locationId: locationId,
    role: role,
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
              return List<Map<String, dynamic>>.from(
                value.map((item) => Map<String, dynamic>.from(item as Map)),
              );
            }),
  );

  final CompanyContext company;
  final EnvasesSearchReadTransport transport;
  final int limit;
  final int? partnerId;
  final int? productId;
  final int? locationId;
  final String? role;

  List<dynamic> get domain => [
    ['company_id', '=', company.companyId],
    if (partnerId != null) ['partner_id', '=', partnerId],
    if (productId != null) ['product_id', '=', productId],
    if (locationId != null) ['location_id', '=', locationId],
    if (role != null) ['envases_rol', '=', role],
  ];

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<EnvasesPartnerBalanceRow>> readPage() async {
    final raw = await transport(
      model: model,
      domain: domain,
      fields: fields,
      context: context,
      limit: limit,
      offset: 0,
      order: order,
    );
    final decoded = raw
        .map(EnvasesPartnerBalanceRow.fromJson)
        .toList(growable: false);
    for (final row in decoded) {
      if (row.companyId != company.companyId) {
        throw StateError('Envases balance row escaped selected company scope');
      }
    }
    return List.unmodifiable(decoded);
  }
}

final class EnvasesPartnerBalanceRow {
  EnvasesPartnerBalanceRow({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.warehouseId,
    required this.warehouseName,
    required this.role,
    required this.partnerId,
    required this.partnerName,
    required this.productId,
    required this.productName,
    required this.companyId,
    required this.quantity,
  });

  factory EnvasesPartnerBalanceRow.fromJson(Map<String, dynamic> json) {
    final location = _many2one(json, 'location_id');
    final warehouse = _many2one(json, 'warehouse_id');
    final partner = _many2one(json, 'partner_id');
    final product = _many2one(json, 'product_id');
    return EnvasesPartnerBalanceRow(
      id: _positive(json, 'id'),
      locationId: location.$1,
      locationName: location.$2,
      warehouseId: warehouse.$1,
      warehouseName: warehouse.$2,
      role: _role(json['envases_rol']),
      partnerId: partner.$1,
      partnerName: partner.$2,
      productId: product.$1,
      productName: product.$2,
      companyId: _many2oneId(json, 'company_id'),
      quantity: _number(json['cantidad']),
    );
  }

  final int id;
  final int locationId;
  final String locationName;
  final int warehouseId;
  final String warehouseName;
  final String role;
  final int partnerId;
  final String partnerName;
  final int productId;
  final String productName;
  final int companyId;
  final double quantity;
}

/// Odoo's JSON-2 wire format for a many2one is `[id, display_name]` — the
/// display name travels in the very same response as the id. Discarding it
/// (as this file used to, keeping only the id) would force the screen to
/// show a raw numeric id instead of the third party/product/warehouse name,
/// or make a second round trip for something Odoo already sent. Same shape
/// as `_many2one` in `envases_movimientos_reader.dart`.
(int, String) _many2one(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.length == 2 && value[0] is int && value[0] > 0) {
    return (value[0] as int, value[1] is String ? value[1] as String : '');
  }
  throw FormatException('Invalid many2one field: $key');
}

int _many2oneId(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.length == 2 && value[0] is int && value[0] > 0) {
    return value[0] as int;
  }
  throw FormatException('Invalid many2one field: $key');
}

int _positive(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Invalid positive integer field: $key');
  }
  return value;
}

void _positiveOptional(int? value, String name) {
  if (value != null && value <= 0) throw ArgumentError.value(value, name);
}

String _role(Object? value) {
  if (value is String && EnvasesPartnerBalanceReader.roles.contains(value)) {
    return value;
  }
  throw const FormatException('Invalid Envases custody role');
}

double _number(Object? value) {
  if (value is num && value.toDouble().isFinite) return value.toDouble();
  throw const FormatException('Invalid Envases balance quantity');
}
