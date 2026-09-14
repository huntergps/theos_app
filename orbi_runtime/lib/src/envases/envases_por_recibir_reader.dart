import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

import 'envases_dashboard_reader.dart' show EnvasesSearchReadTransport;

/// `@api.model` method-call transport shared by the two envases RPC methods
/// bound in this file (`stock.picking.envases_por_recibir()` and the picking
/// line lookup below). Unlike [EnvasesSearchReadTransport], these calls take
/// no `domain`/`fields`/`limit`/`offset` — the server already decides what to
/// return.
typedef EnvasesMethodCallTransport =
    Future<dynamic> Function({
      required String model,
      required String method,
      required Map<String, dynamic> kwargs,
      required Map<String, dynamic> context,
    });

/// Read-only binding for `stock.picking.envases_por_recibir()`
/// (`l10n_ec_stock_envases/models/stock_picking.py`).
///
/// The server already filters by the calling user's
/// `res.users.envases_warehouse_ids` and orders by declared departure date —
/// this reader does not repeat that filter, only decodes the response.
final class EnvasesPorRecibirReader {
  static const model = 'stock.picking';
  static const method = 'envases_por_recibir';

  final CompanyContext company;
  final EnvasesMethodCallTransport transport;

  const EnvasesPorRecibirReader({required this.company, required this.transport});

  factory EnvasesPorRecibirReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
  }) => EnvasesPorRecibirReader(
    company: company,
    transport:
        ({
          required String model,
          required String method,
          required Map<String, dynamic> kwargs,
          required Map<String, dynamic> context,
        }) => client.call(model: model, method: method, kwargs: kwargs, context: context),
  );

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<List<EnvasesPorRecibirRow>> readAll() async {
    final value = await transport(model: model, method: method, kwargs: const {}, context: context);
    if (value is! List) {
      throw const FormatException('Invalid envases_por_recibir response');
    }
    final rows = value
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid envases_por_recibir row');
          }
          return EnvasesPorRecibirRow.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    final ids = <int>{};
    for (final row in rows) {
      if (!ids.add(row.id)) {
        throw StateError('Repeated envases_por_recibir picking id: ${row.id}');
      }
    }
    return List<EnvasesPorRecibirRow>.unmodifiable(rows);
  }
}

final class EnvasesPorRecibirRow {
  const EnvasesPorRecibirRow({
    required this.id,
    required this.name,
    this.envioId,
    this.envioName,
    this.fechaSalida,
    this.origenId,
    this.origenName,
    this.destinoId,
    this.destinoName,
    required this.unidadesPendientes,
    this.operacionUuid,
  });

  factory EnvasesPorRecibirRow.fromJson(Map<String, dynamic> json) {
    final envio = _many2oneOrNull(json, 'envases_envio_id');
    final origen = _many2oneOrNull(json, 'envases_origen_id');
    final destino = _many2oneOrNull(json, 'envases_destino_id');
    return EnvasesPorRecibirRow(
      id: _positiveInt(json, 'id'),
      name: _string(json, 'name'),
      envioId: envio?.$1,
      envioName: envio?.$2,
      fechaSalida: _datetimeOrNull(json, 'envases_fecha_salida'),
      origenId: origen?.$1,
      origenName: origen?.$2,
      destinoId: destino?.$1,
      destinoName: destino?.$2,
      unidadesPendientes: _number(json, 'envases_unidades_pendientes'),
      operacionUuid: _stringOrNull(json, 'envases_envio_operacion_uuid'),
    );
  }

  final int id;
  final String name;
  final int? envioId;
  final String? envioName;
  final DateTime? fechaSalida;
  final int? origenId;
  final String? origenName;
  final int? destinoId;
  final String? destinoName;
  final double unidadesPendientes;

  /// `envases_envio_operacion_uuid` — llega en 19.5.1.3.0 junto con este
  /// método. Contra un servidor que aún no lo expone, `null`.
  final String? operacionUuid;

  /// Lo que las láminas leen como "sentido" del traslado: "Origen → Destino".
  /// Cuando el servidor no resolvió alguno de los dos (ubicación de tránsito
  /// mal configurada), se marca en vez de fingir un nombre.
  String get sentido =>
      '${origenName ?? 'Origen desconocido'} → ${destinoName ?? 'Destino desconocido'}';
}

/// Lectura de las líneas abiertas de un picking de "por recibir": lo que
/// `wizard_recepcion.py._envases_lineas_desde_picking` arma al abrir el
/// asistente nativo, leído aquí por `search_read` directo porque no hay un
/// método `@api.model` dedicado en el contrato — mismo patrón que
/// `EnvasesLocationReader` (lectura directa de un modelo nativo).
final class EnvasesPickingLineasReader {
  static const model = 'stock.move';
  static const fields = <String>['id', 'product_id', 'product_uom_qty', 'uom_id'];
  static const order = 'id asc';

  final CompanyContext company;
  final EnvasesSearchReadTransport transport;

  const EnvasesPickingLineasReader({required this.company, required this.transport});

  factory EnvasesPickingLineasReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
  }) => EnvasesPickingLineasReader(
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

  /// Domain matches `wizard_recepcion.py._envases_lineas_desde_picking`:
  /// open moves (`state not in ('done', 'cancel')`) that are chained from a
  /// real dispatch (`move_orig_ids` set) — never a move created directly on
  /// the recepción picking.
  Future<List<EnvasesPickingLineaRow>> leer(int pickingId) async {
    if (pickingId <= 0) {
      throw ArgumentError.value(pickingId, 'pickingId', 'must be positive');
    }
    final rows = await transport(
      model: model,
      domain: [
        ['picking_id', '=', pickingId],
        ['state', 'not in', ['done', 'cancel']],
        ['move_orig_ids', '!=', false],
      ],
      fields: fields,
      context: context,
      limit: 500,
      offset: 0,
      order: order,
    );
    return rows.map(EnvasesPickingLineaRow.fromJson).toList(growable: false);
  }
}

final class EnvasesPickingLineaRow {
  const EnvasesPickingLineaRow({
    required this.moveId,
    required this.productId,
    required this.productName,
    required this.uomId,
    required this.uomName,
    required this.pendientes,
  });

  factory EnvasesPickingLineaRow.fromJson(Map<String, dynamic> json) {
    final product = _many2one(json, 'product_id');
    final uom = _many2one(json, 'uom_id');
    return EnvasesPickingLineaRow(
      moveId: _positiveInt(json, 'id'),
      productId: product.$1,
      productName: product.$2,
      uomId: uom.$1,
      uomName: uom.$2,
      pendientes: _number(json, 'product_uom_qty'),
    );
  }

  final int moveId;
  final int productId;
  final String productName;
  final int uomId;
  final String uomName;

  /// Fotografía de lo pendiente al abrir el formulario — no se recalcula,
  /// igual que `wizard_recepcion.line.pendientes` en Odoo.
  final double pendientes;
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

String? _stringOrNull(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) return null;
  final value = json[key];
  if (value == null || value == false) return null;
  if (value is! String) throw FormatException('Invalid optional string field: $key');
  return value;
}

double _number(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value.toDouble();
  if (value is double && value.isFinite) return value;
  if (value is num && value.toDouble().isFinite) return value.toDouble();
  throw FormatException('Invalid numeric field: $key');
}

(int, String) _many2one(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.length == 2 && value[0] is int && value[0] > 0) {
    return (value[0] as int, value[1] is String ? value[1] as String : '');
  }
  throw FormatException('Invalid many2one field: $key');
}

(int, String)? _many2oneOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value == false) return null;
  return _many2one(json, key);
}

DateTime? _datetimeOrNull(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value == false) return null;
  if (value is! String) throw FormatException('Invalid datetime field: $key');
  final parsed = DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z');
  if (parsed == null) throw FormatException('Invalid datetime field: $key');
  return parsed;
}
