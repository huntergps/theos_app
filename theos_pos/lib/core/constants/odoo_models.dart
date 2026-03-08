/// Constantes para nombres de modelos Odoo
///
/// Usar estas constantes en lugar de strings para evitar errores de tipeo
/// y permitir refactoring automático.
///
/// Uso:
/// ```dart
/// RelatedFieldText(
///   model: OdooModels.resPartner,
///   id: order.partnerId,
///   fallbackName: order.partnerName,
/// )
/// ```
abstract class OdooModels {
  OdooModels._();

  // ============================================================================
  // BASE / SISTEMA
  // ============================================================================

  /// res.users - Usuarios del sistema
  static const resUsers = 'res.users';

  /// res.partner - Contactos (clientes, proveedores, direcciones)
  static const resPartner = 'res.partner';

  /// res.company - Compañías
  static const resCompany = 'res.company';

  /// res.country - Países
  static const resCountry = 'res.country';

  /// res.country.state - Estados/Provincias
  static const resCountryState = 'res.country.state';

  /// res.currency - Monedas
  static const resCurrency = 'res.currency';

  /// res.lang - Idiomas
  static const resLang = 'res.lang';

  // ============================================================================
  // RECURSOS HUMANOS
  // ============================================================================

  /// hr.employee - Empleados
  static const hrEmployee = 'hr.employee';

  /// hr.department - Departamentos
  static const hrDepartment = 'hr.department';

  /// resource.calendar - Calendarios de trabajo
  static const resourceCalendar = 'resource.calendar';

  // ============================================================================
  // VENTAS
  // ============================================================================

  /// sale.order - Órdenes de venta
  static const saleOrder = 'sale.order';

  /// sale.order.line - Líneas de orden de venta
  static const saleOrderLine = 'sale.order.line';

  /// crm.team - Equipos de venta
  static const crmTeam = 'crm.team';

  // ============================================================================
  // PRODUCTOS
  // ============================================================================

  /// product.product - Productos (variantes)
  static const productProduct = 'product.product';

  /// product.template - Plantillas de producto
  static const productTemplate = 'product.template';

  /// product.category - Categorías de producto
  static const productCategory = 'product.category';

  /// product.pricelist - Listas de precios
  static const productPricelist = 'product.pricelist';

  /// product.pricelist.item - Items de lista de precios
  static const productPricelistItem = 'product.pricelist.item';

  // ============================================================================
  // UNIDADES DE MEDIDA
  // ============================================================================

  /// uom.uom - Unidades de medida
  static const uomUom = 'uom.uom';

  /// uom.category - Categorías de unidades
  static const uomCategory = 'uom.category';

  // ============================================================================
  // CONTABILIDAD
  // ============================================================================

  /// account.account - Cuentas contables
  static const accountAccount = 'account.account';

  /// account.tax - Impuestos
  static const accountTax = 'account.tax';

  /// account.journal - Diarios contables
  static const accountJournal = 'account.journal';

  /// account.move - Asientos contables / Facturas
  static const accountMove = 'account.move';

  /// account.move.line - Líneas de asiento
  static const accountMoveLine = 'account.move.line';

  /// account.payment - Pagos
  static const accountPayment = 'account.payment';

  /// account.payment.term - Términos de pago
  static const accountPaymentTerm = 'account.payment.term';

  /// account.payment.method - Métodos de pago
  static const accountPaymentMethod = 'account.payment.method';

  /// account.payment.method.line - Líneas de método de pago
  static const accountPaymentMethodLine = 'account.payment.method.line';

  /// account.fiscal.position - Posiciones fiscales
  static const accountFiscalPosition = 'account.fiscal.position';

  // ============================================================================
  // INVENTARIO
  // ============================================================================

  /// stock.warehouse - Almacenes
  static const stockWarehouse = 'stock.warehouse';

  /// stock.location - Ubicaciones
  static const stockLocation = 'stock.location';

  /// stock.picking - Transferencias
  static const stockPicking = 'stock.picking';

  /// stock.picking.type - Tipos de operación
  static const stockPickingType = 'stock.picking.type';

  /// stock.move - Movimientos de stock
  static const stockMove = 'stock.move';

  /// stock.quant - Cantidades en stock
  static const stockQuant = 'stock.quant';

  // ============================================================================
  // CAJA DE COBROS (COLLECTION)
  // ============================================================================

  /// collection.config - Configuración de caja
  static const collectionConfig = 'l10n_ec.collection.config';

  /// collection.session - Sesiones de caja
  static const collectionSession = 'l10n_ec.collection.session';

  /// collection.session.cash - Movimientos de efectivo
  static const collectionSessionCash = 'l10n_ec.collection.session.cash';

  /// collection.session.deposit - Depósitos bancarios
  static const collectionSessionDeposit = 'l10n_ec.collection.session.deposit';

  /// collection.cash_out - Salidas de efectivo
  static const collectionCashOut = 'l10n_ec.collection.cash_out';

  // ============================================================================
  // ACTIVIDADES
  // ============================================================================

  /// mail.activity - Actividades
  static const mailActivity = 'mail.activity';

  /// mail.activity.type - Tipos de actividad
  static const mailActivityType = 'mail.activity.type';

  // ============================================================================
  // OTROS
  // ============================================================================

  /// ir.sequence - Secuencias
  static const irSequence = 'ir.sequence';

  /// ir.attachment - Adjuntos
  static const irAttachment = 'ir.attachment';
}
