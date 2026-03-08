import 'package:test/test.dart';
import 'package:flutter_qweb/src/qweb_report_engine.dart';
import 'package:flutter_qweb/src/models/template_context.dart';

void main() {
  group('PDF report generation', () {
    late QWebReportEngine engine;
    late Map<String, dynamic> saleOrder;
    late List<Map<String, dynamic>> orderLines;

    const template = '''
<t t-name="test.sale_order_report">
  <t t-foreach="docs" t-as="doc">
    <div class="page">
      <h1>Orden de Venta: <t t-out="doc.name"/></h1>

      <div class="row">
        <div class="col">
          <strong>Cliente:</strong> <t t-out="doc.partner_id.name"/>
        </div>
        <div class="col">
          <strong>RUC:</strong> <t t-out="doc.partner_id.vat"/>
        </div>
      </div>

      <div class="row">
        <div class="col">
          <strong>Telefono:</strong> <t t-out="doc.partner_id.phone"/>
        </div>
        <div class="col">
          <strong>Email:</strong> <t t-out="doc.partner_id.email"/>
        </div>
      </div>

      <t t-set="lines_to_report" t-value="doc._get_order_lines_to_report()"/>
      <t t-set="display_discount" t-value="any([l.discount for l in lines_to_report])"/>

      <table class="o_main_table table">
        <thead>
          <tr>
            <th>Codigo</th>
            <th>Descripcion</th>
            <th class="text-end">Cantidad</th>
            <th class="text-end">P. Unitario</th>
            <t t-if="display_discount">
              <th class="text-end">Descuento</th>
            </t>
            <th class="text-end">IVA</th>
            <th class="text-end">SubTotal</th>
          </tr>
        </thead>
        <tbody>
          <t t-foreach="lines_to_report" t-as="line">
            <tr>
              <td><t t-out="line.product_id.barcode or line.product_id.default_code or ''"/></td>
              <td>
                <t t-out="line.product_id.name"/>
              </td>
              <td class="text-end"><t t-out="line.product_uom_qty"/></td>
              <td class="text-end">\$ <t t-out="line.price_unit"/></td>
              <t t-if="display_discount">
                <td class="text-end"><t t-out="line.discount"/>%</td>
              </t>
              <td class="text-end">\$ <t t-out="line.tax_amount"/></td>
              <td class="text-end">\$ <t t-out="line.price_subtotal"/></td>
            </tr>
          </t>
        </tbody>
      </table>

      <div class="text-end">
        <p><strong>Subtotal:</strong> \$ <t t-out="doc.amount_untaxed"/></p>
        <p><strong>IVA:</strong> \$ <t t-out="doc.amount_tax"/></p>
        <p><strong>Total:</strong> \$ <t t-out="doc.amount_total"/></p>
      </div>
    </div>
  </t>
</t>
''';

    setUp(() {
      engine = QWebReportEngine();

      saleOrder = {
        'id': 29,
        'name': 'S00029',
        'state': 'sale',
        'date_order': '2024-12-14',
        'amount_untaxed': 1500.00,
        'amount_tax': 180.00,
        'amount_total': 1680.00,
        'currency_symbol': r'$',
        'partner_id': {
          'id': 1,
          'name': 'Cliente de Prueba',
          'vat': '0123456789001',
          'phone': '0991234567',
          'email': 'cliente@test.com',
          'street': 'Av. Principal 123',
          'city': 'Quito',
        },
        'user_id': {
          'id': 2,
          'name': 'Vendedor Test',
        },
        'order_line': [
          {
            'id': 1,
            'name': '[PROD001] Producto de Prueba\nDescripcion detallada',
            'product_id': {
              'id': 1,
              'name': 'Producto de Prueba',
              'barcode': 'PROD001',
              'default_code': 'PROD001'
            },
            'product_uom_qty': 5.0,
            'price_unit': 100.00,
            'discount': 10.0,
            'price_subtotal': 450.00,
            'price_total': 540.00,
            'tax_ids': [
              {'id': 1, 'tax_label': 'IVA 12%'}
            ],
            'display_type': false,
            'is_downpayment': false,
            'product_type': 'product',
          },
          {
            'id': 2,
            'name': '[PROD002] Segundo Producto',
            'product_id': {
              'id': 2,
              'name': 'Segundo Producto',
              'barcode': 'PROD002',
              'default_code': 'PROD002'
            },
            'product_uom_qty': 10.0,
            'price_unit': 105.00,
            'discount': 0.0,
            'price_subtotal': 1050.00,
            'price_total': 1140.00,
            'tax_ids': [
              {'id': 1, 'tax_label': 'IVA 12%'}
            ],
            'display_type': false,
            'is_downpayment': false,
            'product_type': 'product',
          },
        ],
      };

      // Pre-process the order lines
      orderLines = (saleOrder['order_line'] as List).map((line) {
        final l = Map<String, dynamic>.from(line as Map);
        l['_has_taxes'] = () {
          final taxIds = l['tax_ids'];
          return taxIds is List && taxIds.isNotEmpty;
        };
        l['discount'] ??= 0.0;
        l['price_unit'] ??= 0.0;
        l['price_subtotal'] ??= 0.0;
        l['price_total'] ??= 0.0;
        l['display_type'] ??= false;
        l['is_downpayment'] ??= false;
        if (l['discount_amount'] == null) {
          final priceUnit = (l['price_unit'] as num?)?.toDouble() ?? 0.0;
          final qty =
              (l['product_uom_qty'] as num?)?.toDouble() ?? 0.0;
          final discount = (l['discount'] as num?)?.toDouble() ?? 0.0;
          l['discount_amount'] = priceUnit * qty * discount / 100.0;
        }
        return l;
      }).toList();

      saleOrder['_get_order_lines_to_report'] = () => orderLines;
      saleOrder['order_line'] = orderLines;
    });

    test('generates non-empty PDF bytes', () async {
      engine.registerTemplate('test.sale_order_report', template);

      final pdfBytes = await engine.renderToPdf(
        xml: template,
        data: {
          'docs': [saleOrder],
        },
        company: CompanyInfo(
          name: 'Empresa de Prueba S.A.',
          vat: '1790012345001',
          street: 'Calle Principal 456',
          city: 'Quito',
          phone: '022345678',
          email: 'info@empresa.com',
        ),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('preprocessed lines have correct discount_amount', () {
      // First line has 10% discount on 5 units at 100.00
      expect(orderLines[0]['discount_amount'], equals(50.0));
      // Second line has 0% discount
      expect(orderLines[1]['discount_amount'], equals(0.0));
    });

    test('has discount detection works', () {
      final hasDiscounts =
          orderLines.any((l) => (l['discount'] as num) > 0);
      expect(hasDiscounts, isTrue);
    });

    test('_get_order_lines_to_report returns all lines', () {
      final getFunc =
          saleOrder['_get_order_lines_to_report'] as Function;
      final linesToReport = getFunc() as List;
      expect(linesToReport.length, equals(2));
    });
  });
}
