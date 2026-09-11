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
    required this.warehouseId,
    required this.role,
    required this.partnerId,
    required this.productId,
    required this.companyId,
    required this.quantity,
  });

  factory EnvasesPartnerBalanceRow.fromJson(Map<String, dynamic> json) {
    return EnvasesPartnerBalanceRow(
      id: _positive(json, 'id'),
      locationId: _many2oneId(json, 'location_id'),
      warehouseId: _many2oneId(json, 'warehouse_id'),
      role: _role(json['envases_rol']),
      partnerId: _many2oneId(json, 'partner_id'),
      productId: _many2oneId(json, 'product_id'),
      companyId: _many2oneId(json, 'company_id'),
      quantity: _number(json['cantidad']),
    );
  }

  final int id;
  final int locationId;
  final int warehouseId;
  final String role;
  final int partnerId;
  final int productId;
  final int companyId;
  final double quantity;
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
