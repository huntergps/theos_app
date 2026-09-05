import 'odoo_version.dart';

/// Stable feature areas that the app may enable after server discovery.
enum OdooCapabilityArea {
  banks,
  unitsOfMeasure,
  stock,
  cashRegister,
  paymentAndInvoice,
  reports,
  webSocket,
}

/// Result of checking a capability against an Odoo instance.
///
/// [unknown] is intentionally different from [unsupported]: it means the
/// relevant model, field, method, or route has not been checked. Callers must
/// not enable a feature while its state is unknown.
enum OdooCapabilityState { supported, unsupported, unknown }

/// Origin of the most specific information available for a capability.
enum OdooCapabilitySource { evidence, version, none }

/// A capability and the typed contract observed for it.
final class OdooCapability<T extends Object> {
  final OdooCapabilityState state;
  final OdooCapabilitySource source;
  final T? detail;

  const OdooCapability({
    required this.state,
    required this.source,
    this.detail,
  });

  bool get isSupported => state == OdooCapabilityState.supported;
  bool get isUnsupported => state == OdooCapabilityState.unsupported;
  bool get isUnknown => state == OdooCapabilityState.unknown;
}

/// Catalog used to select a bank for a payment.
enum OdooBankCatalog { resBank, l10nEcBank, unknown }

/// Observed banking contract.
final class OdooBankContract {
  final OdooBankCatalog catalog;
  final OdooCapabilityState partnerBank;

  const OdooBankContract({required this.catalog, required this.partnerBank});
}

enum OdooSaleOrderLineUomField { productUom, productUomId, unknown }

enum OdooStockMoveUomField { productUom, uomId, unknown }

/// Field naming observed on the sale and stock models.
final class OdooUomContract {
  final OdooSaleOrderLineUomField saleOrderLineField;
  final OdooStockMoveUomField stockMoveField;

  const OdooUomContract({
    required this.saleOrderLineField,
    required this.stockMoveField,
  });
}

enum OdooStockScrapStrategy { stockScrapModel, stockMoveFlag, unknown }

/// Observed stock contract, including optional warehouse lookup support.
final class OdooStockContract {
  final OdooStockScrapStrategy scrapStrategy;
  final OdooCapabilityState warehouseAvailability;

  const OdooStockContract({
    required this.scrapStrategy,
    required this.warehouseAvailability,
  });
}

enum OdooCashRegisterContract { collectionSession }

enum OdooPaymentInvoiceContract { collectionBoxWizard }

enum OdooReportContract { qweb }

/// Authentication path available for the Odoo bus WebSocket.
enum OdooWebSocketMode { standardSession, mobileSession }

/// Typed matrix of capabilities detected for one Odoo instance.
///
/// The matrix belongs to a specific server/database session. It must not be
/// reused after changing servers, databases, or users.
final class OdooCapabilities {
  final OdooVersion version;
  final OdooCapability<OdooBankContract> banks;
  final OdooCapability<OdooUomContract> unitsOfMeasure;
  final OdooCapability<OdooStockContract> stock;
  final OdooCapability<OdooCashRegisterContract> cashRegister;
  final OdooCapability<OdooPaymentInvoiceContract> paymentAndInvoice;
  final OdooCapability<OdooReportContract> reports;
  final OdooCapability<OdooWebSocketMode> webSocket;

  const OdooCapabilities({
    required this.version,
    required this.banks,
    required this.unitsOfMeasure,
    required this.stock,
    required this.cashRegister,
    required this.paymentAndInvoice,
    required this.reports,
    required this.webSocket,
  });

  /// A serializable-by-enum view useful for guards, diagnostics, and UI.
  Map<OdooCapabilityArea, OdooCapabilityState> get matrix => {
    OdooCapabilityArea.banks: banks.state,
    OdooCapabilityArea.unitsOfMeasure: unitsOfMeasure.state,
    OdooCapabilityArea.stock: stock.state,
    OdooCapabilityArea.cashRegister: cashRegister.state,
    OdooCapabilityArea.paymentAndInvoice: paymentAndInvoice.state,
    OdooCapabilityArea.reports: reports.state,
    OdooCapabilityArea.webSocket: webSocket.state,
  };

  OdooCapabilityState stateFor(OdooCapabilityArea area) => matrix[area]!;
}
