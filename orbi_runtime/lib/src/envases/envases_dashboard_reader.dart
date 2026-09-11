import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

typedef EnvasesSearchReadTransport =
    Future<List<Map<String, dynamic>>> Function({
      required String model,
      required List<dynamic> domain,
      required List<String> fields,
      required Map<String, dynamic> context,
      required int limit,
      required int offset,
      required String order,
    });

/// Read-only binding for the Odoo envases panel model.
///
/// The transport is deliberately injectable so an online OdooClient adapter can
/// be supplied by the composition layer without adding an endpoint or a second
/// remote protocol here.
final class EnvasesDashboardReader {
  static const model = 'l10n_ec.envases.panel';
  static const fields = <String>[
    'id',
    'product_id',
    'uom_id',
    'company_id',
    'total_propio',
    'en_sede',
    'danados',
    'en_custodia_cliente',
    'en_custodia_proveedor',
    'en_transito',
  ];
  static const order = 'product_id asc,company_id asc,id asc';

  final CompanyContext company;
  final EnvasesSearchReadTransport transport;
  final int pageSize;
  final int maxPages;

  EnvasesDashboardReader({
    required this.company,
    required this.transport,
    this.pageSize = 100,
    this.maxPages = 1000,
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
  }

  factory EnvasesDashboardReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
    int pageSize = 100,
    int maxPages = 1000,
  }) => EnvasesDashboardReader(
    company: company,
    pageSize: pageSize,
    maxPages: maxPages,
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

  List<dynamic> get domain => [
    ['company_id', '=', company.companyId],
  ];

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<EnvasesDashboardRow>> readPage({int offset = 0}) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final rows = await transport(
      model: model,
      domain: domain,
      fields: fields,
      context: context,
      limit: pageSize,
      offset: offset,
      order: order,
    );
    final decoded = rows
        .map(EnvasesDashboardRow.fromJson)
        .toList(growable: false);
    for (final row in decoded) {
      if (row.companyId != company.companyId) {
        throw StateError('Envases row escaped selected company scope');
      }
    }
    return List<EnvasesDashboardRow>.unmodifiable(decoded);
  }

  Future<List<EnvasesDashboardRow>> readAll() async {
    // search_read pages are not a server snapshot; callers must treat the
    // result as a bounded, best-effort read and reconcile if source changes.
    final result = <EnvasesDashboardRow>[];
    final seen = <String>{};
    var offset = 0;
    for (var pageNumber = 0; pageNumber < maxPages; pageNumber++) {
      final page = await readPage(offset: offset);
      for (final row in page) {
        final key = '${row.companyId}:${row.productId}';
        if (!seen.add(key)) {
          throw StateError('Repeated envases product/company row: $key');
        }
        result.add(row);
      }
      if (page.length < pageSize) return List.unmodifiable(result);
      offset += page.length;
    }
    throw StateError(
      'Envases dashboard exceeded maxPages without a stable end',
    );
  }
}

final class EnvasesDashboardRow {
  EnvasesDashboardRow({
    required this.id,
    required this.productId,
    required this.productName,
    required this.uomId,
    required this.uomName,
    required this.companyId,
    required this.companyName,
    required this.totalPropio,
    required this.enSede,
    required this.danados,
    required this.enCustodiaCliente,
    required this.enCustodiaProveedor,
    required this.enTransito,
  });

  factory EnvasesDashboardRow.fromJson(Map<String, dynamic> json) {
    return EnvasesDashboardRow(
      id: _positiveInt(json, 'id'),
      productId: _many2oneId(json, 'product_id'),
      productName: _many2oneName(json, 'product_id'),
      uomId: _many2oneId(json, 'uom_id'),
      uomName: _many2oneName(json, 'uom_id'),
      companyId: _many2oneId(json, 'company_id'),
      companyName: _many2oneName(json, 'company_id'),
      totalPropio: _number(json, 'total_propio'),
      enSede: _number(json, 'en_sede'),
      danados: _number(json, 'danados'),
      enCustodiaCliente: _number(json, 'en_custodia_cliente'),
      enCustodiaProveedor: _number(json, 'en_custodia_proveedor'),
      enTransito: _number(json, 'en_transito'),
    );
  }

  final int id;
  final int productId;
  final String productName;
  final int uomId;
  final String uomName;
  final int companyId;
  final String companyName;
  final double totalPropio;
  final double enSede;
  final double danados;
  final double enCustodiaCliente;
  final double enCustodiaProveedor;
  final double enTransito;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Invalid positive integer field: $key');
  }
  return value;
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value.toDouble();
  if (value is double && value.isFinite) return value;
  if (value is num && value.toDouble().isFinite) return value.toDouble();
  throw FormatException('Invalid numeric field: $key');
}

int _many2oneId(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.length == 2 && value[0] is int && value[0] > 0) {
    return value[0] as int;
  }
  throw FormatException('Invalid many2one field: $key');
}

String _many2oneName(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.length == 2 && value[1] is String) {
    return value[1] as String;
  }
  throw FormatException('Invalid many2one field: $key');
}
