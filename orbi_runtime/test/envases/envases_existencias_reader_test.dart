import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_existencias_reader.dart';

/// Shaped exactly like `l10n_ec.envases.existencias.datos()`
/// (`l10n_ec_stock_envases/models/envases_existencias.py:133-143`): dynamic
/// columns (two sites, both transit directions, one damaged and one
/// custody-with-clients column), `celdas` carrying every column key, and the
/// per-column/general totals.
Map<String, dynamic> _realDatos() => {
  'columnas': [
    {'id': 'sede-1', 'nombre': 'Sede 1', 'location_id': 11, 'tipo': 'sede'},
    {
      'id': 'transito-1-2',
      'nombre': 'Sede 1 → Sede 2',
      'location_id': 13,
      'tipo': 'transito',
    },
    {
      'id': 'transito-2-1',
      'nombre': 'Sede 2 → Sede 1',
      'location_id': false,
      'tipo': 'transito',
    },
    {'id': 'sede-2', 'nombre': 'Sede 2', 'location_id': 12, 'tipo': 'sede'},
    {
      'id': 'danados-1',
      'nombre': 'Dañados Sede 1',
      'location_id': 14,
      'tipo': 'danados',
    },
    {
      'id': 'custodia_cliente-1',
      'nombre': 'Clientes Sede 1',
      'location_id': 15,
      'tipo': 'custodia_cliente',
    },
  ],
  'filas': [
    {
      'id': 501,
      'nombre': 'Botella retornable 600 ml',
      'uom': 'Unidades',
      'celdas': {
        'sede-1': 100.0,
        'transito-1-2': 24.0,
        'transito-2-1': 0.0,
        'sede-2': 200.0,
        'danados-1': 4.0,
        'custodia_cliente-1': 12.0,
      },
      'total': 340.0,
    },
  ],
  'totales_columna': {
    'sede-1': 100.0,
    'transito-1-2': 24.0,
    'transito-2-1': 0.0,
    'sede-2': 200.0,
    'danados-1': 4.0,
    'custodia_cliente-1': 12.0,
  },
  'total_general': 340.0,
  'pendientes': 3,
};

void main() {
  final scope = AppScope(
    appId: 'orbi',
    installationId: 'install-1',
    normalizedServerUrl: 'https://odoo.example',
    database: 'db',
    userId: 7,
  );

  CompanyContext company() => CompanyContext.forScope(
    scope: scope,
    companyId: 4,
    allowedCompanyIds: [4],
    capabilityRevision: 1,
  );

  test('requests the real api.model method with no ids/domain and decodes '
      'the exact datos() shape', () async {
    String? capturedModel;
    String? capturedMethod;
    Map<String, dynamic>? capturedKwargs;
    Map<String, dynamic>? capturedContext;
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required String model,
            required String method,
            required Map<String, dynamic> kwargs,
            required Map<String, dynamic> context,
          }) async {
            capturedModel = model;
            capturedMethod = method;
            capturedKwargs = kwargs;
            capturedContext = context;
            return _realDatos();
          },
    );

    final data = await reader.read();

    expect(capturedModel, 'l10n_ec.envases.existencias');
    expect(capturedMethod, 'datos');
    expect(capturedKwargs, isEmpty);
    expect(capturedContext, {
      'allowed_company_ids': [4],
      'company_id': 4,
    });

    expect(data.columnas.map((c) => c.id), [
      'sede-1',
      'transito-1-2',
      'transito-2-1',
      'sede-2',
      'danados-1',
      'custodia_cliente-1',
    ]);
    // A transit pair whose location does not exist yet still gets its
    // column, in zero, instead of vanishing from the grid.
    expect(
      data.columnas.firstWhere((c) => c.id == 'transito-2-1').locationId,
      isNull,
    );
    expect(data.filas.single.nombre, 'Botella retornable 600 ml');
    expect(data.filas.single.celdas['sede-2'], 200.0);
    expect(data.filas.single.celdas['transito-2-1'], 0.0);
    expect(data.filas.single.total, 340.0);
    expect(data.totalesColumna['sede-1'], 100.0);
    expect(data.totalGeneral, 340.0);
    expect(data.pendientes, 3);
  });

  test('rejects a response missing columnas instead of guessing a shape', () async {
    final broken = _realDatos()..remove('columnas');
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => broken,
    );
    expect(reader.read, throwsFormatException);
  });

  test('rejects a response missing filas', () async {
    final broken = _realDatos()..remove('filas');
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => broken,
    );
    expect(reader.read, throwsFormatException);
  });

  test('rejects a row whose celdas do not match the columnas', () async {
    final broken = _realDatos();
    (broken['filas'] as List<dynamic>).cast<Map<String, dynamic>>().first['celdas'] =
        {'sede-1': 1.0};
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => broken,
    );
    expect(reader.read, throwsFormatException);
  });

  test('rejects totales_columna that do not match the columnas', () async {
    final broken = _realDatos();
    broken['totales_columna'] = {'sede-1': 100.0};
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => broken,
    );
    expect(reader.read, throwsFormatException);
  });

  test('rejects a duplicate column id', () async {
    final broken = _realDatos();
    final columnas = (broken['columnas'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    broken['columnas'] = [...columnas, columnas.first];
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => broken,
    );
    expect(reader.read, throwsFormatException);
  });

  test('rejects a non-map response', () async {
    final reader = EnvasesExistenciasReader(
      company: company(),
      transport:
          ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => [1, 2, 3],
    );
    expect(reader.read, throwsFormatException);
  });

  group('readImages', () {
    test(
      'reads product.product.image_128 once fields_get confirms it exists',
      () async {
        final calls = <(String model, String method, Map<String, dynamic> kwargs)>[];
        final reader = EnvasesExistenciasReader(
          company: company(),
          transport:
              ({
                required String model,
                required String method,
                required Map<String, dynamic> kwargs,
                required Map<String, dynamic> context,
              }) async {
                calls.add((model, method, kwargs));
                if (method == 'fields_get') {
                  return {
                    'image_128': {'type': 'binary'},
                  };
                }
                expect(method, 'search_read');
                return [
                  {'id': 501, 'image_128': 'Zm90bw=='},
                  {'id': 502, 'image_128': false},
                ];
              },
        );

        final imagenes = await reader.readImages([501, 502, 503]);

        expect(calls.map((c) => c.$2), ['fields_get', 'search_read']);
        expect(calls.first.$1, 'product.product');
        expect(calls.last.$1, 'product.product');
        expect(imagenes[501], 'Zm90bw==');
        // `image_128: false` (sin foto) y un id que Odoo no devolvió se leen
        // igual: sin foto, no roto.
        expect(imagenes[502], isNull);
        expect(imagenes[503], isNull);
      },
    );

    test(
      'never calls search_read when fields_get does not confirm image_128',
      () async {
        final calls = <String>[];
        final reader = EnvasesExistenciasReader(
          company: company(),
          transport:
              ({
                required String model,
                required String method,
                required Map<String, dynamic> kwargs,
                required Map<String, dynamic> context,
              }) async {
                calls.add(method);
                // El servidor no confirma el campo: la respuesta de
                // fields_get no trae la clave `image_128`.
                return <String, dynamic>{};
              },
        );

        final imagenes = await reader.readImages([501]);

        expect(calls, ['fields_get']);
        expect(imagenes, isEmpty);
      },
    );

    test('returns empty without any call for an empty id set', () async {
      var callCount = 0;
      final reader = EnvasesExistenciasReader(
        company: company(),
        transport:
            ({
              required model,
              required method,
              required kwargs,
              required context,
            }) async {
              callCount++;
              return <String, dynamic>{};
            },
      );

      final imagenes = await reader.readImages(const []);

      expect(callCount, 0);
      expect(imagenes, isEmpty);
    });
  });
}
