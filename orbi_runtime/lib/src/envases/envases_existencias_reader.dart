import '../contracts.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

import 'envases_por_recibir_reader.dart' show EnvasesMethodCallTransport;

/// Read-only binding for `l10n_ec.envases.existencias.datos()` — the single
/// source of the Existencias grid (see
/// `dev_odoo20/docs/especificaciones/envases/CONTRATO_PARA_ORBI.md` and
/// `l10n_ec_stock_envases/models/envases_existencias.py`). Columns are
/// decided by the server's own warehouse configuration, never by this app:
/// there is no fixed set of column keys anywhere in this file.
final class EnvasesExistenciasReader {
  static const model = 'l10n_ec.envases.existencias';
  static const method = 'datos';

  const EnvasesExistenciasReader({
    required this.company,
    required this.transport,
  });

  factory EnvasesExistenciasReader.fromClient({
    required OdooClient client,
    required CompanyContext company,
  }) => EnvasesExistenciasReader(
    company: company,
    transport:
        ({
          required String model,
          required String method,
          required Map<String, dynamic> kwargs,
          required Map<String, dynamic> context,
        }) => client.call(
          model: model,
          method: method,
          kwargs: kwargs,
          context: context,
        ),
  );

  final CompanyContext company;
  final EnvasesMethodCallTransport transport;

  Map<String, dynamic> get context => {
    'allowed_company_ids': [company.companyId],
    'company_id': company.companyId,
  };

  Future<EnvasesExistenciasData> read() async {
    final value = await transport(
      model: model,
      method: method,
      kwargs: const {},
      context: context,
    );
    if (value is! Map) {
      throw const FormatException('Invalid envases existencias response');
    }
    return EnvasesExistenciasData.fromJson(Map<String, dynamic>.from(value));
  }

  /// Foto de producto, en un segundo viaje SEPARADO de [read] a propósito —
  /// orden del dueño: «primero se publican las existencias y después se
  /// completan las fotos», así una foto lenta nunca retrasa las cifras.
  ///
  /// `datos()` nunca trae imagen (no hay `image_128` en
  /// `l10n_ec_stock_envases/models/envases_existencias.py:100-115`): el `id`
  /// de cada fila es el de `product.product` (confirmado — `celdas`/`id`
  /// salen de agrupar `stock.quant` por `product_id`, que en
  /// `dev_odoo20/odoo/addons/stock/models/stock_quant.py:47-50` es
  /// `Many2one('product.product', ...)`; ver también
  /// `envases_existencias.py:79-90,101,110`). Por eso esto pide
  /// `product.product`, con una lectura JSON-2 estándar — nunca se toca el
  /// método `datos()`.
  ///
  /// Igual que el resto del proyecto (`ServerFeatureStore`,
  /// `RuntimeCatalogLoader._resolvePresentFields`): primero `fields_get`
  /// para confirmar que `image_128` existe en ESTE servidor. Si no lo trae,
  /// devuelve `{}` (vacío de verdad, sin ninguna clave) sin llamar nunca a
  /// `search_read` — la regla del proyecto de nunca mandar a Odoo un campo
  /// que no se comprobó (caso `envases_operacion_uuid`). Un mapa NO vacío
  /// con valores `null` es un resultado válido: "se comprobó y no hay foto".
  Future<Map<int, String?>> readImages(Iterable<int> productIds) async {
    final ids = productIds.toSet();
    if (ids.isEmpty) return const {};
    final metadata = await transport(
      model: _imagenModel,
      method: 'fields_get',
      kwargs: const {
        'allfields': [_imagenCampo],
        'attributes': ['type'],
      },
      context: context,
    );
    if (metadata is! Map || !metadata.containsKey(_imagenCampo)) {
      return const {};
    }
    final response = await transport(
      model: _imagenModel,
      method: 'search_read',
      kwargs: {
        'domain': [
          ['id', 'in', ids.toList()..sort()],
        ],
        'fields': const ['id', _imagenCampo],
      },
      context: context,
    );
    if (response is! List) {
      throw const FormatException('Invalid product.product image response');
    }
    final result = <int, String?>{};
    for (final item in response) {
      if (item is! Map) continue;
      final rawId = item['id'];
      if (rawId is! int) continue;
      final rawImage = item[_imagenCampo];
      result[rawId] = (rawImage is String && rawImage.isNotEmpty)
          ? rawImage
          : null;
    }
    // Un id pedido que Odoo no devolvió (producto borrado/archivado entre la
    // lectura de existencias y ésta) se queda sin foto, no roto.
    for (final id in ids) {
      result.putIfAbsent(id, () => null);
    }
    return result;
  }

  static const _imagenModel = 'product.product';
  static const _imagenCampo = 'image_128';
}

/// One column of the grid: a site, a transit direction, damaged goods or a
/// custody bucket — `location_id` is `false`/`null` only for a transit pair
/// whose location has never been used yet.
final class EnvasesExistenciasColumn {
  const EnvasesExistenciasColumn({
    required this.id,
    required this.nombre,
    required this.locationId,
    required this.tipo,
  });

  factory EnvasesExistenciasColumn.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nombre = json['nombre'];
    final tipo = json['tipo'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid envases existencias column id');
    }
    if (nombre is! String || nombre.isEmpty) {
      throw const FormatException(
        'Invalid envases existencias column nombre',
      );
    }
    if (tipo is! String || tipo.isEmpty) {
      throw const FormatException('Invalid envases existencias column tipo');
    }
    final rawLocation = json['location_id'];
    final int? locationId;
    if (rawLocation == false || rawLocation == null) {
      locationId = null;
    } else if (rawLocation is int && rawLocation > 0) {
      locationId = rawLocation;
    } else {
      throw const FormatException(
        'Invalid envases existencias column location_id',
      );
    }
    return EnvasesExistenciasColumn(
      id: id,
      nombre: nombre,
      locationId: locationId,
      tipo: tipo,
    );
  }

  final String id;
  final String nombre;
  final int? locationId;
  final String tipo;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'location_id': locationId ?? false,
    'tipo': tipo,
  };
}

/// One product row. `celdas` always carries exactly the same keys as the
/// grid's columns — a cell with no stock is `0.0`, never a missing key.
final class EnvasesExistenciasRow {
  EnvasesExistenciasRow({
    required this.id,
    required this.nombre,
    required this.uom,
    required Map<String, double> celdas,
    required this.total,
    this.imagenBase64,
  }) : celdas = Map.unmodifiable(celdas);

  factory EnvasesExistenciasRow.fromJson(
    Map<String, dynamic> json, {
    required Set<String> columnIds,
  }) {
    final id = json['id'];
    final nombre = json['nombre'];
    final uom = json['uom'];
    final rawCeldas = json['celdas'];
    if (id is! int || id <= 0) {
      throw const FormatException('Invalid envases existencias row id');
    }
    if (nombre is! String || nombre.isEmpty) {
      throw const FormatException('Invalid envases existencias row nombre');
    }
    if (uom is! String || uom.isEmpty) {
      throw const FormatException('Invalid envases existencias row uom');
    }
    if (rawCeldas is! Map) {
      throw const FormatException('Invalid envases existencias row celdas');
    }
    final celdasMap = Map<String, dynamic>.from(rawCeldas);
    if (celdasMap.keys.toSet().length != columnIds.length ||
        !celdasMap.keys.toSet().containsAll(columnIds)) {
      throw const FormatException(
        'Envases existencias row celdas do not match columnas',
      );
    }
    final celdas = <String, double>{
      for (final entry in celdasMap.entries) entry.key: _number(entry.value),
    };
    final rawImagen = json['imagen_128'];
    return EnvasesExistenciasRow(
      id: id,
      nombre: nombre,
      uom: uom,
      celdas: celdas,
      total: _number(json['total']),
      imagenBase64: (rawImagen is String && rawImagen.isNotEmpty)
          ? rawImagen
          : null,
    );
  }

  final int id;
  final String nombre;
  final String uom;
  final Map<String, double> celdas;
  final double total;

  /// `product.product.image_128`, en base64, sólo cuando
  /// [EnvasesExistenciasReader.readImages] la trajo y
  /// `EnvasesExistenciasCache.mergeImages` ya la fusionó en la copia local.
  /// `null` es "todavía sin foto" (o "el servidor confirmó que no hay
  /// ninguna"), nunca un error — la pantalla cae al ícono de Fluent.
  final String? imagenBase64;

  /// Copia esta fila con una foto nueva (o su ausencia), sin tocar el resto
  /// — lo único que cambia entre `datos()` y la fusión posterior de fotos.
  EnvasesExistenciasRow withImagen(String? imagenBase64) =>
      EnvasesExistenciasRow(
        id: id,
        nombre: nombre,
        uom: uom,
        celdas: celdas,
        total: total,
        imagenBase64: imagenBase64,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'uom': uom,
    'celdas': celdas,
    'total': total,
    if (imagenBase64 != null) 'imagen_128': imagenBase64,
  };
}

/// The exact envelope of `datos()`: dynamic columns, one row per product,
/// per-column totals and the general total, plus how many transfers this
/// user still has pending to receive.
final class EnvasesExistenciasData {
  EnvasesExistenciasData({
    required Iterable<EnvasesExistenciasColumn> columnas,
    required Iterable<EnvasesExistenciasRow> filas,
    required Map<String, double> totalesColumna,
    required this.totalGeneral,
    required this.pendientes,
  }) : columnas = List.unmodifiable(columnas),
       filas = List.unmodifiable(filas),
       totalesColumna = Map.unmodifiable(totalesColumna);

  static const _requiredKeys = [
    'columnas',
    'filas',
    'totales_columna',
    'total_general',
    'pendientes',
  ];

  factory EnvasesExistenciasData.fromJson(Map<String, dynamic> json) {
    for (final key in _requiredKeys) {
      if (!json.containsKey(key)) {
        throw FormatException('Missing envases existencias key: $key');
      }
    }
    final rawColumnas = json['columnas'];
    if (rawColumnas is! List) {
      throw const FormatException('Invalid envases existencias columnas');
    }
    final columnas = rawColumnas.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid envases existencias column');
      }
      return EnvasesExistenciasColumn.fromJson(Map<String, dynamic>.from(item));
    }).toList(growable: false);
    final columnIds = columnas.map((c) => c.id).toSet();
    if (columnIds.length != columnas.length) {
      throw const FormatException(
        'Duplicate envases existencias column id',
      );
    }

    final rawFilas = json['filas'];
    if (rawFilas is! List) {
      throw const FormatException('Invalid envases existencias filas');
    }
    final filas = rawFilas.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid envases existencias row');
      }
      return EnvasesExistenciasRow.fromJson(
        Map<String, dynamic>.from(item),
        columnIds: columnIds,
      );
    }).toList(growable: false);
    final rowIds = <int>{};
    for (final fila in filas) {
      if (!rowIds.add(fila.id)) {
        throw const FormatException(
          'Duplicate envases existencias product row',
        );
      }
    }

    final rawTotales = json['totales_columna'];
    if (rawTotales is! Map) {
      throw const FormatException(
        'Invalid envases existencias totales_columna',
      );
    }
    final totalesMap = Map<String, dynamic>.from(rawTotales);
    if (totalesMap.keys.toSet().length != columnIds.length ||
        !totalesMap.keys.toSet().containsAll(columnIds)) {
      throw const FormatException(
        'Envases existencias totales_columna do not match columnas',
      );
    }
    final totalesColumna = <String, double>{
      for (final entry in totalesMap.entries) entry.key: _number(entry.value),
    };

    final rawPendientes = json['pendientes'];
    if (rawPendientes is! int || rawPendientes < 0) {
      throw const FormatException('Invalid envases existencias pendientes');
    }

    return EnvasesExistenciasData(
      columnas: columnas,
      filas: filas,
      totalesColumna: totalesColumna,
      totalGeneral: _number(json['total_general']),
      pendientes: rawPendientes,
    );
  }

  final List<EnvasesExistenciasColumn> columnas;
  final List<EnvasesExistenciasRow> filas;
  final Map<String, double> totalesColumna;
  final double totalGeneral;
  final int pendientes;

  Map<String, dynamic> toJson() => {
    'columnas': columnas.map((c) => c.toJson()).toList(growable: false),
    'filas': filas.map((f) => f.toJson()).toList(growable: false),
    'totales_columna': totalesColumna,
    'total_general': totalGeneral,
    'pendientes': pendientes,
  };
}

double _number(Object? value) {
  if (value is int) return value.toDouble();
  if (value is double && value.isFinite) return value;
  if (value is num && value.toDouble().isFinite) return value.toDouble();
  throw const FormatException('Invalid envases existencias numeric field');
}
