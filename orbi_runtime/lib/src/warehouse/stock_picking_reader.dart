import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

typedef StockPickingSearchReadTransport =
    Future<List<Map<String, dynamic>>> Function({
      required String model,
      required List<dynamic> domain,
      required List<String> fields,
      required Map<String, dynamic> context,
      required int limit,
      required int offset,
      required String order,
    });

/// Read-only binding for `stock.picking`, backing the BOD-02 menu
/// (recepción / preparación / entrega / transferencia). Every field below
/// was verified directly against the Odoo 20 source at
/// `/Users/elmers/Documents/dev_odoo20`:
///
/// - `stock.picking`, `name`, `origin`, `state`
///   (draft/waiting/confirmed/assigned/done/cancel), `scheduled_date`,
///   `location_id`, `location_dest_id`, `picking_type_id`, `partner_id` —
///   `odoo/addons/stock/models/stock_picking.py:19,35-38,55-61,75-79,89-100,111-113`.
/// - `picking_type_code` (related to `picking_type_id.code`, readonly) —
///   same file, `:105-107`.
/// - `company_id` (related to `picking_type_id.company_id`, `store=True`) —
///   same file, `:114-116`.
/// - `stock.picking.type.code` selection is exactly `incoming` (Receipt),
///   `outgoing` (Delivery), `internal` (Internal Transfer) —
///   `odoo/addons/stock/models/stock_picking_type.py:40-43`. This is the
///   mapping BOD-02's four menu items rely on: recepción → `incoming`,
///   entrega → `outgoing`, transferencia → `internal`. "Preparación" is a
///   step inside the `outgoing` flow (picking/packing before delivery), not
///   a fourth `picking_type_code` — there is no such code to filter on, and
///   this reader does not invent one.
/// - ACL: `access_stock_picking_user` grants `stock.group_stock_user`
///   `crud` — `odoo/addons/stock/security/ir.access.csv:8`.
///
/// This reader only lists pickings; validating one (and reading the
/// resulting server state rather than trusting the RPC's return value) is
/// `WarehouseOperationPort.validatePicking` in this same directory, which
/// already applies to every `picking_type_code` — `button_validate` is a
/// core `stock.picking` method with no type-specific override besides the
/// `outgoing`-only guard documented in the CAJA/BODEGA study. Recepción and
/// transferencia therefore need no separate validation transport here.
final class StockPickingReader {
  static const model = 'stock.picking';
  static const fields = <String>[
    'id',
    'name',
    'origin',
    'state',
    'scheduled_date',
    'location_id',
    'location_dest_id',
    'picking_type_id',
    'picking_type_code',
    'partner_id',
    'company_id',
  ];
  static const order = 'scheduled_date asc,id desc';
  static const codes = {'incoming', 'outgoing', 'internal'};

  StockPickingReader({
    required this.company,
    required this.transport,
    this.pageSize = 100,
    this.maxPages = 1000,
    this.pickingTypeCode,
    this.states = const [],
    this.partnerId,
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
    if (pickingTypeCode != null && !codes.contains(pickingTypeCode)) {
      throw ArgumentError.value(
        pickingTypeCode,
        'pickingTypeCode',
        'must be a stock.picking.type code',
      );
    }
    if (partnerId != null && partnerId! <= 0) {
      throw ArgumentError.value(partnerId, 'partnerId');
    }
  }

  factory StockPickingReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
    int pageSize = 100,
    int maxPages = 1000,
    String? pickingTypeCode,
    List<String> states = const [],
    int? partnerId,
  }) => StockPickingReader(
    company: company,
    pageSize: pageSize,
    maxPages: maxPages,
    pickingTypeCode: pickingTypeCode,
    states: states,
    partnerId: partnerId,
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
  final StockPickingSearchReadTransport transport;
  final int pageSize;
  final int maxPages;
  final String? pickingTypeCode;
  final List<String> states;
  final int? partnerId;

  List<dynamic> get domain => [
    ['company_id', '=', company.companyId],
    if (pickingTypeCode != null) ['picking_type_code', '=', pickingTypeCode],
    if (states.isNotEmpty) ['state', 'in', states],
    if (partnerId != null) ['partner_id', '=', partnerId],
  ];

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<StockPickingRow>> readPage({int offset = 0}) async {
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
    final rows = raw.map(StockPickingRow.fromJson).toList(growable: false);
    for (final row in rows) {
      if (row.companyId != company.companyId) {
        throw StateError('stock.picking row escaped selected company scope');
      }
    }
    return List.unmodifiable(rows);
  }

  Future<List<StockPickingRow>> readAll() async {
    final result = <StockPickingRow>[];
    final seen = <int>{};
    var offset = 0;
    for (var page = 0; page < maxPages; page++) {
      final rows = await readPage(offset: offset);
      for (final row in rows) {
        if (!seen.add(row.id)) {
          throw StateError('Repeated stock.picking row: ${row.id}');
        }
        result.add(row);
      }
      if (rows.length < pageSize) return List.unmodifiable(result);
      offset += rows.length;
    }
    throw StateError(
      'stock.picking read exceeded maxPages without a stable end',
    );
  }
}

final class StockPickingRow {
  StockPickingRow({
    required this.id,
    required this.name,
    required this.origin,
    required this.state,
    required this.scheduledDate,
    required this.sourceLocationId,
    required this.sourceLocationName,
    required this.destinationLocationId,
    required this.destinationLocationName,
    required this.pickingTypeId,
    required this.pickingTypeName,
    required this.pickingTypeCode,
    required this.partnerId,
    required this.partnerName,
    required this.companyId,
    required this.companyName,
  });

  factory StockPickingRow.fromJson(Map<String, dynamic> json) {
    final partner = _optionalMany2one(json, 'partner_id');
    return StockPickingRow(
      id: _positive(json, 'id'),
      name: _requiredString(json, 'name'),
      origin: _optionalString(json['origin']),
      state: _state(json['state']),
      scheduledDate: _requiredDateTime(json, 'scheduled_date'),
      sourceLocationId: _many2one(json, 'location_id').id,
      sourceLocationName: _many2one(json, 'location_id').name,
      destinationLocationId: _many2one(json, 'location_dest_id').id,
      destinationLocationName: _many2one(json, 'location_dest_id').name,
      pickingTypeId: _many2one(json, 'picking_type_id').id,
      pickingTypeName: _many2one(json, 'picking_type_id').name,
      pickingTypeCode: _code(json['picking_type_code']),
      partnerId: partner?.id,
      partnerName: partner?.name,
      companyId: _many2one(json, 'company_id').id,
      companyName: _many2one(json, 'company_id').name,
    );
  }

  final int id;
  final String name;
  final String? origin;
  final String state;
  final DateTime scheduledDate;
  final int sourceLocationId;
  final String sourceLocationName;
  final int destinationLocationId;
  final String destinationLocationName;
  final int pickingTypeId;
  final String pickingTypeName;
  final String pickingTypeCode;
  final int? partnerId;
  final String? partnerName;
  final int companyId;
  final String companyName;
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Invalid required string field: $key');
}

String? _optionalString(Object? value) {
  if (value == false || value == null) return null;
  if (value is String) return value;
  throw const FormatException('Invalid optional string field');
}

const _states = {
  'draft',
  'waiting',
  'confirmed',
  'assigned',
  'done',
  'cancel',
};

String _state(Object? value) {
  if (value is String && _states.contains(value)) return value;
  throw const FormatException('Invalid stock.picking state');
}

String _code(Object? value) {
  if (value is String && StockPickingReader.codes.contains(value)) {
    return value;
  }
  throw const FormatException('Invalid stock.picking.type code');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  // Odoo returns naive "YYYY-MM-DD HH:MM:SS" UTC strings with no 'Z' suffix;
  // a bare DateTime.parse would misread that as local time. Reuse the
  // already-fixed odoo_sdk helper instead of re-deriving that conversion.
  final parsed = parseOdooDateTime(json[key]);
  if (parsed != null) return parsed;
  throw FormatException('Invalid datetime field: $key');
}
