import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_por_recibir_reader.dart';

void main() {
  final scope = AppScope(
    appId: 'orbi',
    installationId: 'install-1',
    normalizedServerUrl: 'https://odoo.example',
    database: 'db',
    userId: 7,
  );

  CompanyContext company() =>
      CompanyContext.forScope(scope: scope, companyId: 4, allowedCompanyIds: [4], capabilityRevision: 1);

  Map<String, dynamic> pickingRow({int id = 11, Object? origen = const [1, 'Guayaquil']}) => {
    'id': id,
    'name': 'WH2/IN/00001',
    'envases_envio_id': [id + 100, 'WH1/OUT/00001'],
    'envases_fecha_salida': '2026-09-01 08:00:00',
    'envases_origen_id': origen,
    'envases_destino_id': [2, 'Manta'],
    'envases_unidades_pendientes': 5.0,
  };

  group('EnvasesPorRecibirReader', () {
    test('requests the real method with no domain/fields and decodes rows', () async {
      String? capturedModel;
      String? capturedMethod;
      Map<String, dynamic>? capturedKwargs;
      Map<String, dynamic>? capturedContext;
      final reader = EnvasesPorRecibirReader(
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
              return [pickingRow()];
            },
      );

      final rows = await reader.readAll();

      expect(capturedModel, 'stock.picking');
      expect(capturedMethod, 'envases_por_recibir');
      expect(capturedKwargs, isEmpty);
      expect(capturedContext, {
        'allowed_company_ids': [4],
        'company_id': 4,
      });
      expect(rows.single.name, 'WH2/IN/00001');
      expect(rows.single.origenName, 'Guayaquil');
      expect(rows.single.destinoName, 'Manta');
      expect(rows.single.unidadesPendientes, 5.0);
      expect(rows.single.sentido, 'Guayaquil → Manta');
    });

    test('accepts false many2one fields as null', () async {
      final reader = EnvasesPorRecibirReader(
        company: company(),
        transport: ({required model, required method, required kwargs, required context}) async => [
          {...pickingRow(), 'envases_envio_id': false, 'envases_origen_id': false, 'envases_destino_id': false},
        ],
      );
      final rows = await reader.readAll();
      expect(rows.single.envioId, isNull);
      expect(rows.single.origenId, isNull);
      expect(rows.single.sentido, 'Origen desconocido → Destino desconocido');
    });

    test('rejects a malformed response shape', () async {
      final reader = EnvasesPorRecibirReader(
        company: company(),
        transport: ({required model, required method, required kwargs, required context}) async => {
          'not': 'a list',
        },
      );
      expect(reader.readAll, throwsFormatException);
    });

    test('rejects a row missing required fields', () async {
      final reader = EnvasesPorRecibirReader(
        company: company(),
        transport: ({required model, required method, required kwargs, required context}) async => [
          {'id': 11, 'name': 'WH2/IN/00001'},
        ],
      );
      expect(reader.readAll, throwsFormatException);
    });

    test('rejects duplicate picking ids', () async {
      final reader = EnvasesPorRecibirReader(
        company: company(),
        transport: ({required model, required method, required kwargs, required context}) async => [
          pickingRow(id: 11),
          pickingRow(id: 11),
        ],
      );
      expect(reader.readAll, throwsStateError);
    });
  });

  group('EnvasesPickingLineasReader', () {
    Map<String, dynamic> lineRow({int id = 1, double pendientes = 8}) => {
      'id': id,
      'product_id': [50, 'Jaba 12'],
      'uom_id': [1, 'Unidades'],
      'product_uom_qty': pendientes,
    };

    test('requests open, chained moves for the picking and decodes them', () async {
      List<dynamic>? capturedDomain;
      final reader = EnvasesPickingLineasReader(
        company: company(),
        transport:
            ({
              required String model,
              required List<dynamic> domain,
              required List<String> fields,
              required Map<String, dynamic> context,
              required int limit,
              required int offset,
              required String order,
            }) async {
              capturedDomain = domain;
              expect(model, 'stock.move');
              return [lineRow()];
            },
      );

      final lines = await reader.leer(11);

      expect(capturedDomain, [
        ['picking_id', '=', 11],
        ['state', 'not in', ['done', 'cancel']],
        ['move_orig_ids', '!=', false],
      ]);
      expect(lines.single.productName, 'Jaba 12');
      expect(lines.single.pendientes, 8.0);
    });

    test('rejects an invalid picking id', () async {
      final reader = EnvasesPickingLineasReader(
        company: company(),
        transport: ({
          required model,
          required domain,
          required fields,
          required context,
          required limit,
          required offset,
          required order,
        }) async => [],
      );
      expect(() => reader.leer(0), throwsArgumentError);
    });

    test('rejects a malformed line', () async {
      final reader = EnvasesPickingLineasReader(
        company: company(),
        transport: ({
          required model,
          required domain,
          required fields,
          required context,
          required limit,
          required offset,
          required order,
        }) async => [
          {'id': 1, 'product_id': false, 'uom_id': false, 'product_uom_qty': 1.0},
        ],
      );
      expect(() => reader.leer(11), throwsFormatException);
    });
  });
}
