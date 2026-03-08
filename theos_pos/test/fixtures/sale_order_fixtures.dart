/// Sale Order Fixtures
///
/// Predefined sale order data for consistent testing.
/// Includes orders in various states and configurations.
library;

/// Odoo API response format for sale orders.
class SaleOrderOdooFixtures {
  /// Draft order without lines.
  static Map<String, dynamic> draft({
    int id = 1,
    String name = 'SO00001',
    int? partnerId = 1,
    int? userId = 1,
    DateTime? dateOrder,
  }) =>
      {
        'id': id,
        'name': name,
        'state': 'draft',
        'partner_id': partnerId != null ? [partnerId, 'Test Partner'] : false,
        'user_id': userId != null ? [userId, 'Test User'] : false,
        'date_order': (dateOrder ?? DateTime.now()).toIso8601String(),
        'amount_untaxed': 0.0,
        'amount_tax': 0.0,
        'amount_total': 0.0,
        'order_line': [],
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Order with lines (full).
  static Map<String, dynamic> withLines({
    int id = 2,
    String name = 'SO00002',
    int? partnerId = 1,
    double amountUntaxed = 100.0,
    double amountTax = 15.0,
    double amountTotal = 115.0,
    List<int>? lineIds,
  }) =>
      {
        'id': id,
        'name': name,
        'state': 'draft',
        'partner_id': partnerId != null ? [partnerId, 'Test Partner'] : false,
        'user_id': [1, 'Test User'],
        'date_order': DateTime.now().toIso8601String(),
        'amount_untaxed': amountUntaxed,
        'amount_tax': amountTax,
        'amount_total': amountTotal,
        'order_line': lineIds ?? [1, 2, 3],
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Confirmed/sale order.
  static Map<String, dynamic> confirmed({
    int id = 3,
    String name = 'SO00003',
    int? partnerId = 1,
    double amountTotal = 250.0,
  }) =>
      {
        'id': id,
        'name': name,
        'state': 'sale',
        'partner_id': partnerId != null ? [partnerId, 'Test Partner'] : false,
        'user_id': [1, 'Test User'],
        'date_order': DateTime.now().toIso8601String(),
        'amount_untaxed': amountTotal / 1.15,
        'amount_tax': amountTotal - (amountTotal / 1.15),
        'amount_total': amountTotal,
        'order_line': [1, 2],
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Cancelled order.
  static Map<String, dynamic> cancelled({int id = 4, String name = 'SO00004'}) => {
        'id': id,
        'name': name,
        'state': 'cancel',
        'partner_id': [1, 'Test Partner'],
        'user_id': [1, 'Test User'],
        'date_order': DateTime.now().toIso8601String(),
        'amount_untaxed': 0.0,
        'amount_tax': 0.0,
        'amount_total': 0.0,
        'order_line': [],
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Done (locked) order.
  static Map<String, dynamic> done({int id = 5, String name = 'SO00005'}) => {
        'id': id,
        'name': name,
        'state': 'done',
        'partner_id': [1, 'Test Partner'],
        'user_id': [1, 'Test User'],
        'date_order': DateTime.now().toIso8601String(),
        'amount_untaxed': 500.0,
        'amount_tax': 75.0,
        'amount_total': 575.0,
        'order_line': [1, 2, 3],
        'invoice_status': 'invoiced',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Batch of orders for list testing.
  static List<Map<String, dynamic>> batch({int count = 5}) => List.generate(
        count,
        (i) => draft(id: i + 1, name: 'SO${(i + 1).toString().padLeft(5, '0')}'),
      );
}

/// Sale order line fixtures.
class SaleOrderLineOdooFixtures {
  /// Standard product line.
  static Map<String, dynamic> productLine({
    int id = 1,
    int orderId = 1,
    int productId = 1,
    String name = 'Test Product',
    double qty = 1.0,
    double priceUnit = 100.0,
    double discount = 0.0,
    double priceSubtotal = 100.0,
    double priceTax = 15.0,
    double priceTotal = 115.0,
  }) =>
      {
        'id': id,
        'order_id': [orderId, 'SO00001'],
        'product_id': [productId, name],
        'name': name,
        'product_uom_qty': qty,
        'price_unit': priceUnit,
        'discount': discount,
        'price_subtotal': priceSubtotal,
        'price_tax': priceTax,
        'price_total': priceTotal,
        'display_type': false,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Line with discount.
  static Map<String, dynamic> withDiscount({
    int id = 2,
    int orderId = 1,
    double priceUnit = 100.0,
    double discount = 10.0,
  }) {
    final subtotal = priceUnit * (1 - discount / 100);
    final tax = subtotal * 0.15;
    return productLine(
      id: id,
      orderId: orderId,
      priceUnit: priceUnit,
      discount: discount,
      priceSubtotal: subtotal,
      priceTax: tax,
      priceTotal: subtotal + tax,
    );
  }

  /// Section line.
  static Map<String, dynamic> section({
    int id = 10,
    int orderId = 1,
    String name = 'Products Section',
  }) =>
      {
        'id': id,
        'order_id': [orderId, 'SO00001'],
        'product_id': false,
        'name': name,
        'product_uom_qty': 0.0,
        'price_unit': 0.0,
        'discount': 0.0,
        'price_subtotal': 0.0,
        'price_tax': 0.0,
        'price_total': 0.0,
        'display_type': 'line_section',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Note line.
  static Map<String, dynamic> note({
    int id = 11,
    int orderId = 1,
    String name = 'Note: Special instructions',
  }) =>
      {
        'id': id,
        'order_id': [orderId, 'SO00001'],
        'product_id': false,
        'name': name,
        'product_uom_qty': 0.0,
        'price_unit': 0.0,
        'discount': 0.0,
        'price_subtotal': 0.0,
        'price_tax': 0.0,
        'price_total': 0.0,
        'display_type': 'line_note',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Batch of product lines.
  static List<Map<String, dynamic>> batch({
    int count = 3,
    int orderId = 1,
    double basePrice = 50.0,
  }) =>
      List.generate(
        count,
        (i) => productLine(
          id: i + 1,
          orderId: orderId,
          productId: i + 1,
          name: 'Product ${i + 1}',
          priceUnit: basePrice * (i + 1),
          priceSubtotal: basePrice * (i + 1),
          priceTax: basePrice * (i + 1) * 0.15,
          priceTotal: basePrice * (i + 1) * 1.15,
        ),
      );
}

/// Invalid order fixtures for error testing.
class SaleOrderInvalidFixtures {
  /// Order missing partner.
  static Map<String, dynamic> missingPartner() => {
        'id': 100,
        'name': 'SO_INVALID_1',
        'state': 'draft',
        'partner_id': false,
        'user_id': [1, 'Test User'],
        'date_order': DateTime.now().toIso8601String(),
        'amount_total': 0.0,
      };

  /// Order with negative total.
  static Map<String, dynamic> negativeTotal() => {
        'id': 101,
        'name': 'SO_INVALID_2',
        'state': 'draft',
        'partner_id': [1, 'Test Partner'],
        'amount_total': -100.0,
      };
}
