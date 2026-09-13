import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('OdooVersion', () {
    test('recognizes supported Odoo 19 and Odoo 20 version strings', () {
      final odoo19 = OdooVersion.parse('saas-19.2+e');
      final odoo20 = OdooVersion.parse('Odoo Server 20.0+e');

      expect(odoo19.isOdoo19, isTrue);
      expect(odoo19.isSupported, isTrue);
      expect(odoo20.isOdoo20, isTrue);
      expect(odoo20.isSupported, isTrue);
      expect(OdooVersion.parse('21.0').isSupported, isFalse);
      expect(OdooVersion.parse('not-a-version').isUnknown, isTrue);
    });
  });

  group('OdooCapabilitiesDetector', () {
    const detector = OdooCapabilitiesDetector();

    test('Odoo 19.5 uses observed custom contracts', () {
      final capabilities = detector.detect(
        version: OdooVersion.parse('saas-19.5+e'),
        evidence: _odoo20Fixture,
      );
      expect(capabilities.version.minor, 5);
      expect(capabilities.banks.detail?.catalog, OdooBankCatalog.l10nEcBank);
      expect(capabilities.paymentAndInvoice.isSupported, isTrue);
      expect(
        capabilities.unitsOfMeasure.detail?.saleOrderLineField,
        OdooSaleOrderLineUomField.productUomId,
      );
    });

    test('absent fields and catalogs never regain version hints', () {
      for (final version in ['19.1', '19.5', '20.0']) {
        final capabilities = detector.detect(
          version: OdooVersion.parse(version),
          evidence: const OdooCapabilityEvidence(
            models: {'uom.uom', 'sale.order.line', 'stock.move'},
            fieldsByModel: {'sale.order.line': {}, 'stock.move': {}},
          ),
        );
        expect(capabilities.banks.isUnsupported, isTrue);
        expect(capabilities.banks.detail?.catalog, OdooBankCatalog.unknown);
        expect(capabilities.unitsOfMeasure.isUnsupported, isTrue);
        expect(
          capabilities.unitsOfMeasure.detail?.saleOrderLineField,
          OdooSaleOrderLineUomField.unknown,
        );
        expect(
          capabilities.unitsOfMeasure.detail?.stockMoveField,
          OdooStockMoveUomField.unknown,
        );
      }
    });

    test('builds the typed Odoo 19 legacy matrix from a local fixture', () {
      final capabilities = detector.detect(
        version: OdooVersion.parse('19.1+e'),
        evidence: _odoo19Fixture,
      );

      expect(capabilities.banks.state, OdooCapabilityState.supported);
      expect(capabilities.banks.detail?.catalog, OdooBankCatalog.resBank);
      expect(
        capabilities.unitsOfMeasure.detail?.saleOrderLineField,
        OdooSaleOrderLineUomField.productUom,
      );
      expect(
        capabilities.unitsOfMeasure.detail?.stockMoveField,
        OdooStockMoveUomField.productUom,
      );
      expect(capabilities.stock.state, OdooCapabilityState.supported);
      expect(
        capabilities.stock.detail?.scrapStrategy,
        OdooStockScrapStrategy.stockScrapModel,
      );
      expect(
        capabilities.stock.detail?.warehouseAvailability,
        OdooCapabilityState.unsupported,
      );
      expect(capabilities.cashRegister.state, OdooCapabilityState.unsupported);
      expect(
        capabilities.paymentAndInvoice.state,
        OdooCapabilityState.unsupported,
      );
      expect(capabilities.reports.state, OdooCapabilityState.supported);
      expect(capabilities.webSocket.state, OdooCapabilityState.supported);
      expect(capabilities.webSocket.detail, OdooWebSocketMode.standardSession);
    });

    test('builds the observed Odoo 20 custom matrix from a local fixture', () {
      final capabilities = detector.detect(
        version: OdooVersion.parse('20.0+e'),
        evidence: _odoo20Fixture,
      );

      expect(capabilities.banks.state, OdooCapabilityState.supported);
      expect(capabilities.banks.detail?.catalog, OdooBankCatalog.l10nEcBank);
      expect(
        capabilities.banks.detail?.partnerBank,
        OdooCapabilityState.supported,
      );
      expect(
        capabilities.unitsOfMeasure.detail?.saleOrderLineField,
        OdooSaleOrderLineUomField.productUomId,
      );
      expect(
        capabilities.unitsOfMeasure.detail?.stockMoveField,
        OdooStockMoveUomField.uomId,
      );
      expect(
        capabilities.stock.detail?.scrapStrategy,
        OdooStockScrapStrategy.stockMoveFlag,
      );
      expect(
        capabilities.stock.detail?.warehouseAvailability,
        OdooCapabilityState.supported,
      );
      expect(capabilities.cashRegister.state, OdooCapabilityState.supported);
      expect(
        capabilities.paymentAndInvoice.state,
        OdooCapabilityState.supported,
      );
      expect(capabilities.reports.state, OdooCapabilityState.supported);
      expect(capabilities.webSocket.state, OdooCapabilityState.supported);
      expect(capabilities.webSocket.detail, OdooWebSocketMode.standardSession);
      expect(
        capabilities.matrix,
        everyCapabilityArea(OdooCapabilityState.supported),
      );
    });

    test('keeps unchecked features unknown instead of enabling by version', () {
      final capabilities = detector.detect(
        version: OdooVersion.parse('20.0'),
        evidence: const OdooCapabilityEvidence(),
      );

      expect(
        capabilities.matrix,
        everyCapabilityArea(OdooCapabilityState.unknown),
      );
      expect(
        capabilities.unitsOfMeasure.detail?.saleOrderLineField,
        OdooSaleOrderLineUomField.productUomId,
      );
      expect(
        capabilities.unitsOfMeasure.detail?.stockMoveField,
        OdooStockMoveUomField.uomId,
      );
    });

    test('does not reuse Odoo 20 field hints for a future major version', () {
      final capabilities = detector.detect(
        version: OdooVersion.parse('21.0'),
        evidence: const OdooCapabilityEvidence(),
      );

      expect(capabilities.unitsOfMeasure.state, OdooCapabilityState.unknown);
      expect(
        capabilities.unitsOfMeasure.detail?.saleOrderLineField,
        OdooSaleOrderLineUomField.unknown,
      );
      expect(
        capabilities.unitsOfMeasure.detail?.stockMoveField,
        OdooStockMoveUomField.unknown,
      );
    });

    test('observed fields override version hints', () {
      final capabilities = detector.detect(
        version: OdooVersion.parse('20.0'),
        evidence: const OdooCapabilityEvidence(
          models: {'uom.uom', 'sale.order.line', 'stock.move'},
          fieldsByModel: {
            'sale.order.line': {'product_uom'},
            'stock.move': {'product_uom'},
          },
        ),
      );

      expect(capabilities.unitsOfMeasure.state, OdooCapabilityState.supported);
      expect(
        capabilities.unitsOfMeasure.detail?.saleOrderLineField,
        OdooSaleOrderLineUomField.productUom,
      );
      expect(
        capabilities.unitsOfMeasure.detail?.stockMoveField,
        OdooStockMoveUomField.productUom,
      );
    });
  });
}

Matcher everyCapabilityArea(OdooCapabilityState expected) => predicate(
  (Object? value) =>
      value is Map<OdooCapabilityArea, OdooCapabilityState> &&
      value.length == OdooCapabilityArea.values.length &&
      value.values.every((state) => state == expected),
  'contains every typed capability area with state $expected',
);

const _odoo19Fixture = OdooCapabilityEvidence(
  models: {
    'res.bank',
    'res.partner.bank',
    'uom.uom',
    'sale.order.line',
    'stock.move',
    'stock.quant',
    'stock.scrap',
    'ir.actions.report',
  },
  fieldsByModel: {
    'sale.order.line': {'product_uom'},
    'stock.move': {'product_uom'},
    'ir.actions.report': {'report_name', 'report_type'},
  },
  endpoints: {'/websocket'},
);

const _odoo20Fixture = OdooCapabilityEvidence(
  models: {
    'l10n.ec.bank',
    'res.partner.bank',
    'uom.uom',
    'sale.order.line',
    'stock.move',
    'stock.quant',
    'product.template',
    'collection.session',
    'l10n_ec_collection_box.sale.order.payment.wizard',
    'account.move',
    'ir.actions.report',
    'res.users',
  },
  fieldsByModel: {
    'sale.order.line': {'product_uom_id'},
    'stock.move': {'uom_id', 'is_scrap'},
    'ir.actions.report': {'report_name', 'report_type'},
  },
  methodsByModel: {
    'product.template': {'get_stock_by_warehouse'},
    'collection.session': {
      'action_session_open',
      'action_session_pause',
      'action_session_resume',
      'action_session_close',
    },
    'l10n_ec_collection_box.sale.order.payment.wizard': {
      'action_apply_and_create_invoice',
    },
  },
  endpoints: {'/json/2/product.template/get_stock_by_warehouse', '/websocket'},
);
