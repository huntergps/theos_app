import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

import 'envases_por_recibir_reader.dart' show EnvasesMethodCallTransport;

/// Read-only binding for `stock.move.line.envases_movimientos(desde, hasta,
/// limite, desplazamiento)` (`l10n_ec_stock_envases/models/stock_move_line.py`).
///
/// Público y sin filtro por sede del usuario — el propio método Odoo no lo
/// aplica (a diferencia de `envases_por_recibir`), así que este lector
/// tampoco inventa uno.
final class EnvasesMovimientosReader {
  static const model = 'stock.move.line';
  static const method = 'envases_movimientos';

  final CompanyContext company;
  final EnvasesMethodCallTransport transport;
  final int maxPages;

  EnvasesMovimientosReader({
    required this.company,
    required this.transport,
    this.maxPages = 200,
  }) {
    if (maxPages < 1 || maxPages > 10000) {
      throw ArgumentError.value(maxPages, 'maxPages', 'must be between 1 and 10000');
    }
  }

  factory EnvasesMovimientosReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
    int maxPages = 200,
  }) => EnvasesMovimientosReader(
    company: company,
    maxPages: maxPages,
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

  /// Una página, del más reciente al más antiguo. `hasMore` es una
  /// estimación (el tamaño de página se llenó por completo), no una cuenta
  /// exacta del servidor: `envases_movimientos` no devuelve un total.
  Future<EnvasesMovimientosPage> readPage({
    DateTime? desde,
    DateTime? hasta,
    int limite = 200,
    int desplazamiento = 0,
  }) async {
    if (limite < 1 || limite > 500) {
      throw ArgumentError.value(limite, 'limite', 'must be between 1 and 500');
    }
    if (desplazamiento < 0) {
      throw ArgumentError.value(desplazamiento, 'desplazamiento');
    }
    final value = await transport(
      model: model,
      method: method,
      kwargs: {
        'desde': desde == null ? false : _odooDatetime(desde),
        'hasta': hasta == null ? false : _odooDatetime(hasta),
        'limite': limite,
        'desplazamiento': desplazamiento,
      },
      context: context,
    );
    if (value is! List) {
      throw const FormatException('Invalid envases_movimientos response');
    }
    final rows = value
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Invalid envases_movimientos row');
          }
          return EnvasesMovimientoRow.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
    return EnvasesMovimientosPage(rows: rows, hasMore: rows.length >= limite);
  }

  /// Acumula páginas sucesivas hasta agotar el rango o `maxPages`. Pensado
  /// para el refresco de caché (vista por omisión, sin `desde`/`hasta`); el
  /// filtro de fechas de la pantalla vuelve a pedir directo con `readPage`.
  Future<List<EnvasesMovimientoRow>> readAll({
    DateTime? desde,
    DateTime? hasta,
    int limite = 200,
  }) async {
    final result = <EnvasesMovimientoRow>[];
    var offset = 0;
    for (var pageNumber = 0; pageNumber < maxPages; pageNumber++) {
      final page = await readPage(
        desde: desde,
        hasta: hasta,
        limite: limite,
        desplazamiento: offset,
      );
      result.addAll(page.rows);
      if (!page.hasMore) return List.unmodifiable(result);
      offset += page.rows.length;
    }
    throw StateError('envases_movimientos exceeded maxPages without a stable end');
  }
}

final class EnvasesMovimientosPage {
  const EnvasesMovimientosPage({required this.rows, required this.hasMore});
  final List<EnvasesMovimientoRow> rows;
  final bool hasMore;
}

final class EnvasesMovimientoRow {
  const EnvasesMovimientoRow({
    required this.id,
    required this.date,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.desde,
    this.hacia,
    this.warehouseId,
    this.warehouseName,
    this.responsableId,
    this.responsableName,
    this.pickingId,
    this.pickingName,
    this.operacionUuid,
  });

  factory EnvasesMovimientoRow.fromJson(Map<String, dynamic> json) {
    final product = _many2one(json, 'product_id');
    final warehouse = _many2oneOrNull(json, 'envases_warehouse_id');
    final responsable = _many2oneOrNull(json, 'envases_responsable_id');
    final picking = _many2oneOrNull(json, 'picking_id');
    return EnvasesMovimientoRow(
      id: _positiveInt(json, 'id'),
      date: _datetime(json, 'date'),
      productId: product.$1,
      productName: product.$2,
      quantity: _number(json, 'quantity'),
      desde: _stringOrNull(json, 'envases_desde'),
      hacia: _stringOrNull(json, 'envases_hacia'),
      warehouseId: warehouse?.$1,
      warehouseName: warehouse?.$2,
      responsableId: responsable?.$1,
      responsableName: responsable?.$2,
      pickingId: picking?.$1,
      pickingName: picking?.$2,
      operacionUuid: _stringOrNull(json, 'envases_operacion_uuid'),
    );
  }

  final int id;
  final DateTime date;
  final int productId;
  final String productName;
  final double quantity;
  final String? desde;
  final String? hacia;
  final int? warehouseId;
  final String? warehouseName;
  final int? responsableId;
  final String? responsableName;
  final int? pickingId;
  final String? pickingName;

  /// `envases_operacion_uuid` — llega en 19.5.1.3.0. `null` contra un
  /// servidor que todavía no lo expone.
  final String? operacionUuid;
}

String _odooDatetime(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw FormatException('Invalid positive integer field: $key');
  }
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

DateTime _datetime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Invalid datetime field: $key');
  final parsed = DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z');
  if (parsed == null) throw FormatException('Invalid datetime field: $key');
  return parsed;
}
