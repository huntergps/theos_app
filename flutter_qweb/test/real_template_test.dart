import 'dart:io';

import 'package:test/test.dart';
import 'package:flutter_qweb/src/qweb_report_engine.dart';
import 'package:flutter_qweb/src/models/template_context.dart';

void main() {
  group('Real Odoo template rendering', () {
    late QWebReportEngine engine;
    late Map<String, dynamic> saleOrder;

    setUp(() {
      engine = QWebReportEngine();

      saleOrder = {
        'id': 29,
        'name': 'S00029',
        'state': 'sale',
        'date_order': '2024-12-14',
        'validity_date': '2024-12-24',
        'amount_untaxed': 2580.97,
        'amount_tax': 387.15,
        'amount_total': 2968.12,
        'is_final_consumer': false,
        'currency_id': {'id': 1, 'name': 'USD', 'symbol': r'$'},
        'partner_id': {
          'id': 1,
          'name': 'ABAD BURI JUAN ALEJANDRO',
          'vat': '0301707816',
          'phone': '+593 99 578 0372 - +593 99 578 0372',
          'email': 'jabad_b@hotmail.com',
          'street': 'AZOGUES',
          'city': 'Ecuador',
          'lang': 'es_EC',
        },
        'partner_shipping_id': {'id': 1},
        'partner_invoice_id': {'id': 1},
        'user_id': {'id': 2, 'name': 'Administrator'},
        'fiscal_position_id': null,
        'payment_term_id': {'id': 1, 'name': 'pago inmediato'},
        'order_line': [
          {
            'id': 1,
            'name': '[MBO0630] MAINBOARD ASUS PRIME B760M-A AX6 II',
            'product_id': {
              'id': 1,
              'name': 'MAINBOARD ASUS PRIME B760M-A AX6 II',
              'barcode': 'MBO0630',
              'default_code': 'MBO0630'
            },
            'product_uom_qty': 2.0,
            'price_unit': 159.65,
            'discount': 0.0,
            'price_subtotal': 319.30,
            'price_total': 367.20,
            'tax_amount': 47.90,
            'tax_ids': [
              {'id': 1, 'tax_label': 'IVA 15%'}
            ],
            'display_type': false,
            'is_downpayment': false,
            'product_type': 'product',
          },
          {
            'id': 2,
            'name': '[CPU0216] PROCESADOR INTEL CORE i5-12400',
            'product_id': {
              'id': 2,
              'name': 'PROCESADOR INTEL CORE i5-12400',
              'barcode': 'CPU0216',
              'default_code': 'CPU0216'
            },
            'product_uom_qty': 3.0,
            'price_unit': 190.27,
            'discount': 0.0,
            'price_subtotal': 570.81,
            'price_total': 656.43,
            'tax_amount': 85.62,
            'tax_ids': [
              {'id': 1, 'tax_label': 'IVA 15%'}
            ],
            'display_type': false,
            'is_downpayment': false,
            'product_type': 'product',
          },
        ],
      };
    });

    test('renders real sale order template to PDF', () async {
      // Load the real template
      final templateFile =
          File('test/templates/sale_report_saleorder_document.xml');
      if (!templateFile.existsSync()) {
        // Skip if template file not available (CI environment)
        return;
      }
      final templateXml = await templateFile.readAsString();

      // Register external_layout as empty wrapper
      engine.registerTemplate('web.external_layout', '''
        <div class="external_layout">
          <t t-out="0"/>
        </div>
      ''');

      // Register main template
      engine.registerTemplate(
          'sale.report_saleorder_document', templateXml);

      // Pre-process the order
      final rawOrderLines =
          (saleOrder['order_line'] as List).map((line) {
        final l = Map<String, dynamic>.from(line as Map);
        l['_has_taxes'] = () {
          final taxIds = l['tax_ids'];
          return taxIds is List && taxIds.isNotEmpty;
        };
        l['discount'] ??= 0.0;
        l['tax_amount'] ??= 0.0;
        return l;
      }).toList();

      saleOrder['order_line'] = rawOrderLines;
      saleOrder['_get_order_lines_to_report'] = () => rawOrderLines;
      saleOrder['with_context'] =
          ([Map<String, dynamic>? ctx]) => saleOrder;

      // Generate PDF
      final pdfBytes = await engine.renderToPdf(
        xml: templateXml,
        data: {
          'docs': [saleOrder],
          'doc': saleOrder,
          'env': {'context': {}},
          'is_pro_forma': false,
          'report_type': 'pdf',
        },
        company: CompanyInfo(
          name: 'ALDAS ROMERO ERIK ANDRES',
          vat: '2000074001001',
          street: 'Av. Carlos Luis Plaza Danin 820 y Miguel H. Alcivar',
          phone: '0998323437',
          email: 'ventas@tecnosmart.com.ec',
        ),
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000)); // Reasonable PDF size
    });
  });
}
