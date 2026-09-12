import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

/// search_read transport shape shared by the read-only Odoo bindings in this
/// package. Kept local to `warehouse/` (rather than reusing the `envases`
/// typedef of the same shape) so this boundary does not couple to an
/// unrelated feature module.
typedef StockQuantSearchReadTransport =
    Future<List<Map<String, dynamic>>> Function({
      required String model,
      required List<dynamic> domain,
      required List<String> fields,
      required Map<String, dynamic> context,
      required int limit,
      required int offset,
      required String order,
    });

/// Read-only binding for `stock.quant`, the on-hand existence backing BOD-01
/// (inventory / existences), BOD-02 (operations) and BOD-03 (partial
/// delivery). Every field below was verified directly against the Odoo 20
/// source at `/Users/elmers/Documents/dev_odoo20`, not copied from the
/// planning doc:
///
/// - `stock.quant`, `product_id`, `location_id`, `company_id` (related,
///   `store=True`), `quantity`, `reserved_quantity`, `available_quantity`
///   (compute) — `odoo/addons/stock/models/stock_quant.py:21,47-63,80-92`.
/// - `warehouse_id` (related to `location_id.warehouse_id`, not required —
///   can be `false` for a location outside any warehouse) — same file, `:63`.
/// - `location_id.usage` selection includes `'internal'` —
///   `odoo/addons/stock/models/stock_location.py:33-40`.
/// - `reservado_por` (compute, `Char`, no restricted `groups=`) —
///   `addons/l10n_ec_stock_base/models/stock_quant.py` (`_compute_reservado_por`).
/// - ACL: `stock.group_stock_user` has `cru`, `base.group_user` has `r` —
///   `odoo/addons/stock/security/ir.access.csv:31-32`.
///
/// Deliberately NOT read here: `costo_promedio`, also in
/// `l10n_ec_stock_base/models/stock_quant.py`, is gated behind
/// `groups='stock.group_stock_manager'`. A plain existences read must not
/// assume every caller holds that group; a cost column belongs in a reader
/// that is itself gated on that capability, not bundled into the base read.
///
/// The transport is injectable so an online `OdooClient` adapter can be
/// supplied by the composition layer without adding a second remote
/// protocol here — same shape as `EnvasesLocationReader`.
final class StockQuantReader {
  static const model = 'stock.quant';
  static const fields = <String>[
    'id',
    'product_id',
    'uom_id',
    'location_id',
    'warehouse_id',
    'company_id',
    'quantity',
    'reserved_quantity',
    'available_quantity',
    'reservado_por',
  ];
  static const order = 'product_id asc,location_id asc,id asc';

  StockQuantReader({
    required this.company,
    required this.transport,
    this.pageSize = 100,
    this.maxPages = 1000,
    this.productId,
    this.locationId,
    this.warehouseId,
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
  }

  factory StockQuantReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
    int pageSize = 100,
    int maxPages = 1000,
    int? productId,
    int? locationId,
    int? warehouseId,
  }) => StockQuantReader(
    company: company,
    pageSize: pageSize,
    maxPages: maxPages,
    productId: productId,
    locationId: locationId,
    warehouseId: warehouseId,
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
                throw FormatException('Invalid search_read response');
              }
              return value
                  .map<Map<String, dynamic>>((item) {
                    if (item is! Map) {
                      throw FormatException('Invalid search_read row');
                    }
                    return Map<String, dynamic>.from(item);
                  })
                  .toList(growable: false);
            }),
  );

  final CompanyContext company;
  final StockQuantSearchReadTransport transport;
  final int pageSize;
  final int maxPages;
  final int? productId;
  final int? locationId;
  final int? warehouseId;

  /// Restricted to `internal` locations: this is the existences screen, not
  /// an inventory-adjustment or transit-tracking view. This narrowing is my
  /// own read-model choice (not sourced from any Odoo file or the planning
  /// doc) — `location_id.usage` itself is verified above, the filter value
  /// is a product decision for BOD-01.
  List<dynamic> get domain => [
    ['company_id', '=', company.companyId],
    ['location_id.usage', '=', 'internal'],
    if (productId != null) ['product_id', '=', productId],
    if (locationId != null) ['location_id', '=', locationId],
    if (warehouseId != null) ['warehouse_id', '=', warehouseId],
  ];

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<StockQuantRow>> readPage({int offset = 0}) async {
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
    final rows = raw.map(StockQuantRow.fromJson).toList(growable: false);
    for (final row in rows) {
      if (row.companyId != company.companyId) {
        throw StateError('stock.quant row escaped selected company scope');
      }
    }
    return List.unmodifiable(rows);
  }

  Future<List<StockQuantRow>> readAll() async {
    // search_read pages are not a server snapshot; callers must treat the
    // result as a bounded, best-effort read and reconcile if source changes.
    final result = <StockQuantRow>[];
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
    throw StateError('stock.quant read exceeded maxPages without a stable end');
  }
}

final class StockQuantRow {
  StockQuantRow({
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
    required this.quantity,
    required this.reservedQuantity,
    required this.availableQuantity,
    required this.reservedBy,
  });

  factory StockQuantRow.fromJson(Map<String, dynamic> json) {
    final warehouse = _optionalMany2one(json, 'warehouse_id');
    return StockQuantRow(
      id: _positive(json, 'id'),
      productId: _many2one(json, 'product_id').id,
      productName: _many2one(json, 'product_id').name,
      uomId: _many2one(json, 'uom_id').id,
      uomName: _many2one(json, 'uom_id').name,
      locationId: _many2one(json, 'location_id').id,
      locationName: _many2one(json, 'location_id').name,
      warehouseId: warehouse?.id,
      warehouseName: warehouse?.name,
      companyId: _many2one(json, 'company_id').id,
      companyName: _many2one(json, 'company_id').name,
      quantity: _number(json, 'quantity'),
      reservedQuantity: _number(json, 'reserved_quantity'),
      availableQuantity: _number(json, 'available_quantity'),
      reservedBy: _optionalString(json['reservado_por']),
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

  /// Total on-hand quantity in this quant (`quantity`).
  final double quantity;

  /// Quantity already claimed by another document (`reserved_quantity`).
  final double reservedQuantity;

  /// On-hand quantity not yet reserved (`available_quantity`, computed by
  /// Odoo as `quantity - reserved_quantity`, but always taken from the
  /// server field rather than recomputed here).
  final double availableQuantity;

  /// `null` when nothing has claimed this existence yet; otherwise the
  /// human-readable document(s) that did, from `reservado_por`.
  final String? reservedBy;
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

String? _optionalString(Object? value) {
  if (value == false || value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value;
  throw const FormatException('Invalid reservado_por field');
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

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num && value.toDouble().isFinite) return value.toDouble();
  throw FormatException('Invalid numeric field: $key');
}
