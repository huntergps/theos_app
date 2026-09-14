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
    return EnvasesExistenciasRow(
      id: id,
      nombre: nombre,
      uom: uom,
      celdas: celdas,
      total: _number(json['total']),
    );
  }

  final int id;
  final String nombre;
  final String uom;
  final Map<String, double> celdas;
  final double total;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'uom': uom,
    'celdas': celdas,
    'total': total,
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
