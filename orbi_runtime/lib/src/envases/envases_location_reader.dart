import '../contracts.dart';
import 'envases_dashboard_reader.dart';

/// Read-only stock.quant binding used by the native Envases detail actions.
/// The domain mirrors `stock.location._envases_dominio_existencias()` and the
/// dashboard's product/company narrowing; grouping is intentionally left to
/// the caller so transit directions cannot be merged accidentally.
final class EnvasesLocationReader {
  static const model = 'stock.quant';
  static const fields = <String>[
    'id',
    'product_id',
    'uom_id',
    'location_id',
    'warehouse_id',
    'company_id',
    'envases_rol',
    'envases_origen_id',
    'envases_destino_id',
    'quantity',
  ];
  static const order = 'product_id asc,location_id asc,id asc';
  static const roles = {
    'sede',
    'danados',
    'custodia_cliente',
    'custodia_proveedor',
    'transito',
  };

  EnvasesLocationReader({
    required this.company,
    required this.transport,
    this.pageSize = 100,
    this.maxPages = 1000,
    this.productId,
    this.locationId,
    this.warehouseId,
    this.originWarehouseId,
    this.destinationWarehouseId,
    this.role,
  }) {
    if (pageSize < 1 || pageSize > 500) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'must be between 1 and 500',
      );
    }
    if (maxPages < 1 || maxPages > 10000) {
      throw ArgumentError.value(
        maxPages,
        'maxPages',
        'must be between 1 and 10000',
      );
    }
    _positiveOptional(productId, 'productId');
    _positiveOptional(locationId, 'locationId');
    _positiveOptional(warehouseId, 'warehouseId');
    _positiveOptional(originWarehouseId, 'originWarehouseId');
    _positiveOptional(destinationWarehouseId, 'destinationWarehouseId');
    if (role != null && !roles.contains(role)) {
      throw ArgumentError.value(
        role,
        'role',
        'must be an Envases location role',
      );
    }
  }

  final CompanyContext company;
  final EnvasesSearchReadTransport transport;
  final int pageSize;
  final int maxPages;
  final int? productId;
  final int? locationId;
  final int? warehouseId;
  final int? originWarehouseId;
  final int? destinationWarehouseId;
  final String? role;

  List<dynamic> get domain => [
    [
      'location_id.usage',
      'in',
      ['internal', 'transit'],
    ],
    ['location_id.envases_rol', '!=', false],
    ['company_id', '=', company.companyId],
    if (productId != null) ['product_id', '=', productId],
    if (locationId != null) ['location_id', '=', locationId],
    if (warehouseId != null) ['warehouse_id', '=', warehouseId],
    if (originWarehouseId != null)
      ['envases_origen_id', '=', originWarehouseId],
    if (destinationWarehouseId != null)
      ['envases_destino_id', '=', destinationWarehouseId],
    if (role != null) ['envases_rol', '=', role],
  ];

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<EnvasesLocationRow>> readPage({int offset = 0}) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final raw = await transport(
      model: model,
      domain: domain,
      fields: fields,
      context: context,
      limit: pageSize,
      offset: offset,
      order: order,
    );
    final rows = raw.map(EnvasesLocationRow.fromJson).toList(growable: false);
    for (final row in rows) {
      if (row.companyId != company.companyId) {
        throw StateError('Envases location row escaped selected company scope');
      }
    }
    return List.unmodifiable(rows);
  }

  Future<List<EnvasesLocationRow>> readAll() async {
    final result = <EnvasesLocationRow>[];
    final seen = <int>{};
    var offset = 0;
    for (var page = 0; page < maxPages; page++) {
      final rows = await readPage(offset: offset);
      for (final row in rows) {
        if (!seen.add(row.id)) {
          throw StateError('Repeated stock.quant row: ${row.id}');
        }
        result.add(row);
      }
      if (rows.length < pageSize) return List.unmodifiable(result);
      offset += rows.length;
    }
    throw StateError(
      'Envases locations exceeded maxPages without a stable end',
    );
  }
}

final class EnvasesLocationRow {
  EnvasesLocationRow({
    required this.id,
    required this.productId,
    required this.productName,
    required this.uomId,
    required this.uomName,
    required this.locationId,
    required this.locationName,
    required this.warehouseId,
    required this.warehouseName,
    required this.companyId,
    required this.companyName,
    required this.role,
    required this.originWarehouseId,
    required this.originWarehouseName,
    required this.destinationWarehouseId,
    required this.destinationWarehouseName,
    required this.quantity,
  });

  factory EnvasesLocationRow.fromJson(Map<String, dynamic> json) {
    final origin = _optionalMany2one(json, 'envases_origen_id');
    final destination = _optionalMany2one(json, 'envases_destino_id');
    return EnvasesLocationRow(
      id: _positive(json, 'id'),
      productId: _many2one(json, 'product_id').id,
      productName: _many2one(json, 'product_id').name,
      uomId: _many2one(json, 'uom_id').id,
      uomName: _many2one(json, 'uom_id').name,
      locationId: _many2one(json, 'location_id').id,
      locationName: _many2one(json, 'location_id').name,
      warehouseId: _optionalMany2one(json, 'warehouse_id')?.id,
      warehouseName: _optionalMany2one(json, 'warehouse_id')?.name,
      companyId: _many2one(json, 'company_id').id,
      companyName: _many2one(json, 'company_id').name,
      role: _role(json['envases_rol']),
      originWarehouseId: origin?.id,
      originWarehouseName: origin?.name,
      destinationWarehouseId: destination?.id,
      destinationWarehouseName: destination?.name,
      quantity: _number(json, 'quantity'),
    );
  }

  final int id;
  final int productId;
  final String productName;
  final int uomId;
  final String uomName;
  final int locationId;
  final String locationName;
  final int? warehouseId;
  final String? warehouseName;
  final int companyId;
  final String companyName;
  final String role;
  final int? originWarehouseId;
  final String? originWarehouseName;
  final int? destinationWarehouseId;
  final String? destinationWarehouseName;
  final double quantity;
}

final class _Many2one {
  const _Many2one(this.id, this.name);
  final int id;
  final String name;
}

_Many2one _many2one(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List &&
      value.length == 2 &&
      value[0] is int &&
      (value[0] as int) > 0 &&
      value[1] is String &&
      (value[1] as String).trim().isNotEmpty) {
    return _Many2one(value[0] as int, value[1] as String);
  }
  throw FormatException('Invalid many2one field: $key');
}

_Many2one? _optionalMany2one(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == false || value == null) return null;
  return _many2one(json, key);
}

int _positive(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Invalid positive integer field: $key');
  }
  return value;
}

void _positiveOptional(int? value, String name) {
  if (value != null && value <= 0) {
    throw ArgumentError.value(value, name);
  }
}

String _role(Object? value) {
  if (value is String && EnvasesLocationReader.roles.contains(value)) {
    return value;
  }
  throw const FormatException('Invalid Envases location role');
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.toDouble().isFinite) return value.toDouble();
  throw FormatException('Invalid numeric field: $key');
}
