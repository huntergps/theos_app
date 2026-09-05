import 'odoo_capabilities.dart';
import 'odoo_version.dart';

/// Read-only discovery results collected from one Odoo server/database.
///
/// A nullable collection means "not checked". A non-null collection is a
/// complete result for that kind of probe, so a missing member means
/// "checked and absent". The detector never performs network requests itself;
/// login/integration code can populate this value using controlled, read-only
/// model, field, method, and route probes.
final class OdooCapabilityEvidence {
  final Set<String>? models;
  final Map<String, Set<String>> fieldsByModel;
  final Map<String, Set<String>> methodsByModel;
  final Set<String>? endpoints;

  const OdooCapabilityEvidence({
    this.models,
    this.fieldsByModel = const {},
    this.methodsByModel = const {},
    this.endpoints,
  });

  bool? hasModel(String model) => models?.contains(model);

  bool? hasField(String model, String field) {
    if (hasModel(model) == false) return false;
    final fields = fieldsByModel[model];
    return fields?.contains(field);
  }

  bool? hasMethod(String model, String method) {
    if (hasModel(model) == false) return false;
    final methods = methodsByModel[model];
    return methods?.contains(method);
  }

  bool? hasEndpoint(String path) => endpoints?.contains(path);
}

/// Builds the capability matrix from server version plus observed evidence.
///
/// Evidence always wins over version hints. Version hints select field naming
/// details for supported 19.x/20.x series, but never turn an unchecked feature
/// into a supported one.
final class OdooCapabilitiesDetector {
  const OdooCapabilitiesDetector();

  static const stockByWarehouseEndpoint =
      '/json/2/product.template/get_stock_by_warehouse';
  static const webSocketEndpoint = '/websocket';

  OdooCapabilities detect({
    required OdooVersion version,
    required OdooCapabilityEvidence evidence,
  }) {
    return OdooCapabilities(
      version: version,
      banks: _detectBanks(version, evidence),
      unitsOfMeasure: _detectUom(version, evidence),
      stock: _detectStock(evidence),
      cashRegister: _detectCashRegister(evidence),
      paymentAndInvoice: _detectPaymentAndInvoice(evidence),
      reports: _detectReports(evidence),
      webSocket: _detectWebSocket(evidence),
    );
  }

  OdooCapability<OdooBankContract> _detectBanks(
    OdooVersion version,
    OdooCapabilityEvidence evidence,
  ) {
    final hasLocalCatalog = evidence.hasModel('l10n.ec.bank');
    final hasLegacyCatalog = evidence.hasModel('res.bank');
    final hasPartnerBank = evidence.hasModel('res.partner.bank');
    final state = _stateOfAny([hasLocalCatalog, hasLegacyCatalog]);

    final observedCatalog = switch ((hasLocalCatalog, hasLegacyCatalog)) {
      (true, _) => OdooBankCatalog.l10nEcBank,
      (_, true) => OdooBankCatalog.resBank,
      _ => null,
    };
    final versionCatalog =
        hasLocalCatalog == null &&
            hasLegacyCatalog == null &&
            version.isOdoo19 &&
            version.minor <= 1
        ? OdooBankCatalog.resBank
        : OdooBankCatalog.unknown;

    return OdooCapability(
      state: state,
      source: _source(
        [hasLocalCatalog, hasLegacyCatalog, hasPartnerBank],
        hasVersionHint:
            observedCatalog == null &&
            versionCatalog != OdooBankCatalog.unknown,
      ),
      detail: OdooBankContract(
        catalog: observedCatalog ?? versionCatalog,
        partnerBank: _stateOf(hasPartnerBank),
      ),
    );
  }

  OdooCapability<OdooUomContract> _detectUom(
    OdooVersion version,
    OdooCapabilityEvidence evidence,
  ) {
    final hasUomModel = evidence.hasModel('uom.uom');
    final hasLegacySaleField = evidence.hasField(
      'sale.order.line',
      'product_uom',
    );
    final hasModernSaleField = evidence.hasField(
      'sale.order.line',
      'product_uom_id',
    );
    final hasLegacyStockField = evidence.hasField('stock.move', 'product_uom');
    final hasModernStockField = evidence.hasField('stock.move', 'uom_id');

    final saleField = switch ((hasLegacySaleField, hasModernSaleField)) {
      (true, _) => OdooSaleOrderLineUomField.productUom,
      (_, true) => OdooSaleOrderLineUomField.productUomId,
      (false, false) => OdooSaleOrderLineUomField.unknown,
      _ => _saleUomHint(version),
    };
    final stockField = switch ((hasLegacyStockField, hasModernStockField)) {
      (true, _) => OdooStockMoveUomField.productUom,
      (_, true) => OdooStockMoveUomField.uomId,
      (false, false) => OdooStockMoveUomField.unknown,
      _ => _stockUomHint(version),
    };
    final evidenceValues = [
      hasUomModel,
      hasLegacySaleField,
      hasModernSaleField,
      hasLegacyStockField,
      hasModernStockField,
    ];

    return OdooCapability(
      state: _stateOfAll([
        hasUomModel,
        _any([hasLegacySaleField, hasModernSaleField]),
        _any([hasLegacyStockField, hasModernStockField]),
      ]),
      source: _source(
        evidenceValues,
        hasVersionHint:
            saleField != OdooSaleOrderLineUomField.unknown ||
            stockField != OdooStockMoveUomField.unknown,
      ),
      detail: OdooUomContract(
        saleOrderLineField: saleField,
        stockMoveField: stockField,
      ),
    );
  }

  OdooCapability<OdooStockContract> _detectStock(
    OdooCapabilityEvidence evidence,
  ) {
    final hasStockQuant = evidence.hasModel('stock.quant');
    final hasStockScrap = evidence.hasModel('stock.scrap');
    final hasScrapFlag = evidence.hasField('stock.move', 'is_scrap');
    final hasWarehouseMethod = evidence.hasMethod(
      'product.template',
      'get_stock_by_warehouse',
    );
    final hasWarehouseEndpoint = evidence.hasEndpoint(stockByWarehouseEndpoint);
    final warehouseAvailability = _stateOfAny([
      hasWarehouseMethod,
      hasWarehouseEndpoint,
    ]);
    final scrapStrategy = switch ((hasStockScrap, hasScrapFlag)) {
      (true, _) => OdooStockScrapStrategy.stockScrapModel,
      (_, true) => OdooStockScrapStrategy.stockMoveFlag,
      _ => OdooStockScrapStrategy.unknown,
    };

    return OdooCapability(
      state: _stateOf(hasStockQuant),
      source: _source([
        hasStockQuant,
        hasStockScrap,
        hasScrapFlag,
        hasWarehouseMethod,
        hasWarehouseEndpoint,
      ]),
      detail: OdooStockContract(
        scrapStrategy: scrapStrategy,
        warehouseAvailability: warehouseAvailability,
      ),
    );
  }

  OdooCapability<OdooCashRegisterContract> _detectCashRegister(
    OdooCapabilityEvidence evidence,
  ) {
    final checks = [
      evidence.hasModel('collection.session'),
      evidence.hasMethod('collection.session', 'action_session_open'),
      evidence.hasMethod('collection.session', 'action_session_pause'),
      evidence.hasMethod('collection.session', 'action_session_resume'),
      evidence.hasMethod('collection.session', 'action_session_close'),
    ];
    final state = _stateOfAll(checks);
    return OdooCapability(
      state: state,
      source: _source(checks),
      detail: state == OdooCapabilityState.supported
          ? OdooCashRegisterContract.collectionSession
          : null,
    );
  }

  OdooCapability<OdooPaymentInvoiceContract> _detectPaymentAndInvoice(
    OdooCapabilityEvidence evidence,
  ) {
    const wizard = 'l10n_ec_collection_box.sale.order.payment.wizard';
    final checks = [
      evidence.hasModel(wizard),
      evidence.hasMethod(wizard, 'action_apply_and_create_invoice'),
      evidence.hasModel('account.move'),
    ];
    final state = _stateOfAll(checks);
    return OdooCapability(
      state: state,
      source: _source(checks),
      detail: state == OdooCapabilityState.supported
          ? OdooPaymentInvoiceContract.collectionBoxWizard
          : null,
    );
  }

  OdooCapability<OdooReportContract> _detectReports(
    OdooCapabilityEvidence evidence,
  ) {
    final checks = [
      evidence.hasModel('ir.actions.report'),
      evidence.hasField('ir.actions.report', 'report_name'),
      evidence.hasField('ir.actions.report', 'report_type'),
    ];
    final state = _stateOfAll(checks);
    return OdooCapability(
      state: state,
      source: _source(checks),
      detail: state == OdooCapabilityState.supported
          ? OdooReportContract.qweb
          : null,
    );
  }

  OdooCapability<OdooWebSocketMode> _detectWebSocket(
    OdooCapabilityEvidence evidence,
  ) {
    final hasEndpoint = evidence.hasEndpoint(webSocketEndpoint);
    final hasMobileSession = evidence.hasMethod(
      'res.users',
      'mobile_get_websocket_session',
    );
    final state = _stateOf(hasEndpoint);
    return OdooCapability(
      state: state,
      source: _source([hasEndpoint, hasMobileSession]),
      detail: state == OdooCapabilityState.supported
          ? hasMobileSession == true
                ? OdooWebSocketMode.mobileSession
                : OdooWebSocketMode.standardSession
          : null,
    );
  }

  OdooSaleOrderLineUomField _saleUomHint(OdooVersion version) {
    if (version.isOdoo20 || (version.isOdoo19 && version.minor >= 2)) {
      return OdooSaleOrderLineUomField.productUomId;
    }
    if (version.isOdoo19) return OdooSaleOrderLineUomField.productUom;
    return OdooSaleOrderLineUomField.unknown;
  }

  OdooStockMoveUomField _stockUomHint(OdooVersion version) {
    if (version.isOdoo20 || (version.isOdoo19 && version.minor >= 2)) {
      return OdooStockMoveUomField.uomId;
    }
    if (version.isOdoo19) return OdooStockMoveUomField.productUom;
    return OdooStockMoveUomField.unknown;
  }
}

OdooCapabilityState _stateOf(bool? value) => switch (value) {
  true => OdooCapabilityState.supported,
  false => OdooCapabilityState.unsupported,
  null => OdooCapabilityState.unknown,
};

OdooCapabilityState _stateOfAll(Iterable<bool?> values) {
  final list = values.toList(growable: false);
  if (list.any((value) => value == false)) {
    return OdooCapabilityState.unsupported;
  }
  if (list.isNotEmpty && list.every((value) => value == true)) {
    return OdooCapabilityState.supported;
  }
  return OdooCapabilityState.unknown;
}

OdooCapabilityState _stateOfAny(Iterable<bool?> values) =>
    _stateOf(_any(values));

bool? _any(Iterable<bool?> values) {
  final list = values.toList(growable: false);
  if (list.any((value) => value == true)) return true;
  if (list.isNotEmpty && list.every((value) => value == false)) return false;
  return null;
}

OdooCapabilitySource _source(
  Iterable<bool?> evidence, {
  bool hasVersionHint = false,
}) {
  if (evidence.any((value) => value != null)) {
    return OdooCapabilitySource.evidence;
  }
  return hasVersionHint
      ? OdooCapabilitySource.version
      : OdooCapabilitySource.none;
}
