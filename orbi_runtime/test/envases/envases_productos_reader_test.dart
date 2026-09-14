import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_productos_reader.dart';

/// El dominio que este lector aplica —
/// `[('product_tmpl_id.envases_es_retornable', '=', true), ('active', '=', true)]`—
/// no lo impone `l10n_ec.stock.envases.wizard.envio.line.product_id`: ese
/// campo (dev_odoo20/addons/l10n_ec_stock_envases/wizards/wizard_envio.py,
/// clase `WizardEnvioLine`, `product_id = fields.Many2one('product.product',
/// string='Envase', required=True)`) NO declara `domain=`, y la vista
/// (`views/wizard_envio_views.xml:20`, sólo `<field name="product_id"/>`)
/// tampoco. `envases_es_retornable` es el booleano que el propio módulo usa
/// para decidir "esto es un envase" en sus otros dos selectores del mismo
/// concepto — `product_template.py:45`
/// (`envases_contenedor_id`, `domain="[('envases_es_retornable', '=',
/// True)]"`) y `product_template.py:74` (`envases_intercambiable_ids`,
/// mismo dominio) — así que este lector reusa ESE criterio en vez de
/// ofrecer cualquier producto de la compañía.
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

  Map<String, dynamic> row({int id = 50, String name = 'Jaba 12'}) => {
    'id': id,
    'name': name,
    'uom_id': [1, 'Unidades'],
  };

  test('requests product.product filtered by envases_es_retornable, matching '
      'product_template.py:45 and :74\'s own domain for "what counts as an envase"', () async {
    String? capturedModel;
    List<dynamic>? capturedDomain;
    final reader = EnvasesProductosReader(
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
            capturedModel = model;
            capturedDomain = domain;
            return [row()];
          },
    );

    final rows = await reader.leer();

    expect(capturedModel, 'product.product');
    expect(capturedDomain, [
      ['product_tmpl_id.envases_es_retornable', '=', true],
      ['active', '=', true],
    ]);
    expect(rows.single.name, 'Jaba 12');
    expect(rows.single.uomName, 'Unidades');
  });

  test('rejects a malformed product row', () async {
    final reader = EnvasesProductosReader(
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
        {'id': 50, 'name': 'Jaba 12', 'uom_id': false},
      ],
    );

    expect(reader.leer, throwsFormatException);
  });
}
