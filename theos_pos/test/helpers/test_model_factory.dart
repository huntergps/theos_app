/// Test Model Factory
///
/// Provides factory methods for creating test model instances with
/// reasonable defaults. Use these to quickly create test data.
library;

import 'package:theos_pos_core/theos_pos_core.dart';

/// Counter for generating unique IDs.
int _idCounter = 1;

/// Reset the ID counter (call in setUp if needed).
void resetIdCounter() => _idCounter = 1;

/// Get the next unique ID.
int nextId() => _idCounter++;

/// Factory for creating test Client instances.
class ClientFactory {
  /// Create a minimal valid client.
  static Client create({
    int? id,
    String name = 'Test Client',
    String? vat,
    String? email,
    String? phone,
    double creditLimit = 0.0,
    double credit = 0.0,
    bool active = true,
  }) {
    return Client(
      id: id ?? nextId(),
      name: name,
      vat: vat,
      email: email,
      phone: phone,
      creditLimit: creditLimit,
      credit: credit,
      active: active,
    );
  }

  /// Create a client with credit limit.
  static Client withCreditLimit({
    int? id,
    String name = 'Credit Client',
    double creditLimit = 1000.0,
    double credit = 0.0,
  }) {
    return create(
      id: id,
      name: name,
      creditLimit: creditLimit,
      credit: credit,
    );
  }

  /// Create a final consumer (9999999999999).
  static Client finalConsumer({int? id}) {
    return create(
      id: id,
      name: 'CONSUMIDOR FINAL',
      vat: '9999999999999',
    );
  }

  /// Create a company client with RUC.
  static Client company({
    int? id,
    String name = 'Test Company S.A.',
    String ruc = '1791234567001',
  }) {
    return create(
      id: id,
      name: name,
      vat: ruc,
    );
  }
}

/// Factory for creating test Product instances.
class ProductFactory {
  /// Create a minimal valid product.
  static Product create({
    int? id,
    String name = 'Test Product',
    String? defaultCode,
    String? barcode,
    double listPrice = 10.0,
    int? categId,
    int? uomId,
    bool active = true,
  }) {
    final productId = id ?? nextId();
    return Product(
      id: productId,
      name: name,
      defaultCode: defaultCode,
      barcode: barcode,
      listPrice: listPrice,
      categId: categId ?? 1,
      uomId: uomId ?? 1,
      active: active,
    );
  }

  /// Create a product with stock tracking.
  static Product withStock({
    int? id,
    String name = 'Stock Product',
    double listPrice = 50.0,
    double qtyAvailable = 100.0,
  }) {
    return create(
      id: id,
      name: name,
      listPrice: listPrice,
    );
  }

  /// Create a service product.
  static Product service({
    int? id,
    String name = 'Test Service',
    double listPrice = 100.0,
  }) {
    return create(
      id: id,
      name: name,
      listPrice: listPrice,
    );
  }
}

/// Factory for creating test SaleOrder instances.
class SaleOrderFactory {
  /// Create a minimal draft order.
  static SaleOrder draft({
    int? id,
    String? name,
    int? partnerId,
    int? userId,
  }) {
    final orderId = id ?? nextId();
    return SaleOrder(
      id: orderId,
      name: name ?? 'SO${orderId.toString().padLeft(5, '0')}',
      state: SaleOrderState.draft,
      partnerId: partnerId,
      userId: userId ?? 1,
      dateOrder: DateTime.now(),
    );
  }

  /// Create an order with amounts.
  static SaleOrder withAmounts({
    int? id,
    int? partnerId,
    double amountUntaxed = 100.0,
    double amountTax = 15.0,
  }) {
    final orderId = id ?? nextId();
    return SaleOrder(
      id: orderId,
      name: 'SO${orderId.toString().padLeft(5, '0')}',
      state: SaleOrderState.draft,
      partnerId: partnerId ?? nextId(),
      userId: 1,
      dateOrder: DateTime.now(),
      amountUntaxed: amountUntaxed,
      amountTax: amountTax,
      amountTotal: amountUntaxed + amountTax,
    );
  }

  /// Create a confirmed order.
  static SaleOrder confirmed({
    int? id,
    int? partnerId,
  }) {
    final order = withAmounts(id: id, partnerId: partnerId);
    return order.copyWith(state: SaleOrderState.sale);
  }

  /// Create a cancelled order.
  static SaleOrder cancelled({int? id, int? partnerId}) {
    final order = draft(id: id, partnerId: partnerId);
    return order.copyWith(state: SaleOrderState.cancel);
  }
}

/// Factory for creating test SaleOrderLine instances.
class SaleOrderLineFactory {
  /// Create a minimal valid line.
  static SaleOrderLine create({
    int? id,
    required int orderId,
    String name = 'Test Line',
    int? productId,
    double productUomQty = 1.0,
    double priceUnit = 10.0,
    double discount = 0.0,
    LineDisplayType displayType = LineDisplayType.product,
  }) {
    return SaleOrderLine(
      id: id ?? nextId(),
      orderId: orderId,
      name: name,
      productId: productId,
      productUomQty: productUomQty,
      priceUnit: priceUnit,
      discount: discount,
      displayType: displayType,
    );
  }

  /// Create a line with discount.
  static SaleOrderLine withDiscount({
    int? id,
    required int orderId,
    double priceUnit = 100.0,
    double discount = 10.0,
  }) {
    return create(
      id: id,
      orderId: orderId,
      priceUnit: priceUnit,
      discount: discount,
    );
  }

  /// Create a section line.
  static SaleOrderLine section({
    int? id,
    required int orderId,
    String name = 'Section',
  }) {
    return SaleOrderLine(
      id: id ?? nextId(),
      orderId: orderId,
      name: name,
      displayType: LineDisplayType.lineSection,
    );
  }

  /// Create a note line.
  static SaleOrderLine note({
    int? id,
    required int orderId,
    String name = 'Note text',
  }) {
    return SaleOrderLine(
      id: id ?? nextId(),
      orderId: orderId,
      name: name,
      displayType: LineDisplayType.lineNote,
    );
  }
}

/// Factory for creating test Tax instances.
class TaxFactory {
  /// Create a minimal valid tax.
  static Tax create({
    int? id,
    String name = 'IVA 15%',
    double amount = 15.0,
    TaxAmountType amountType = TaxAmountType.percent,
    TaxTypeUse typeTaxUse = TaxTypeUse.sale,
    bool priceInclude = false,
    bool active = true,
  }) {
    return Tax(
      id: id ?? nextId(),
      name: name,
      amount: amount,
      amountType: amountType,
      typeTaxUse: typeTaxUse,
      priceInclude: priceInclude,
      active: active,
    );
  }

  /// Create a zero-rated tax.
  static Tax zeroRated({int? id, String name = 'IVA 0%'}) {
    return create(id: id, name: name, amount: 0.0);
  }

  /// Create a fixed-amount tax.
  static Tax fixed({
    int? id,
    String name = 'Fixed Tax',
    double amount = 5.0,
  }) {
    return create(
      id: id,
      name: name,
      amount: amount,
      amountType: TaxAmountType.fixed,
    );
  }
}

/// Factory for creating test Uom instances.
class UomFactory {
  /// Create a minimal valid UoM.
  static Uom create({
    int? id,
    String name = 'Units',
    UomType uomType = UomType.reference,
    double factor = 1.0,
    double factorInv = 1.0,
    double rounding = 0.01,
    int? categoryId,
    bool active = true,
  }) {
    return Uom(
      id: id ?? nextId(),
      name: name,
      uomType: uomType,
      factor: factor,
      factorInv: factorInv,
      rounding: rounding,
      categoryId: categoryId,
      active: active,
    );
  }
}

/// Factory for creating test ProductCategory instances.
class ProductCategoryFactory {
  /// Create a minimal valid category.
  static ProductCategory create({
    int? id,
    String name = 'General',
    String? completeName,
    int? parentId,
  }) {
    return ProductCategory(
      id: id ?? nextId(),
      name: name,
      completeName: completeName,
      parentId: parentId,
    );
  }
}

/// Batch creation helpers.
class TestDataBatch {
  /// Create multiple clients.
  static List<Client> clients(int count, {String prefix = 'Client'}) {
    return List.generate(
      count,
      (i) => ClientFactory.create(name: '$prefix ${i + 1}'),
    );
  }

  /// Create multiple products.
  static List<Product> products(int count, {String prefix = 'Product'}) {
    return List.generate(
      count,
      (i) => ProductFactory.create(
        name: '$prefix ${i + 1}',
        listPrice: 10.0 * (i + 1),
      ),
    );
  }

  /// Create multiple draft orders.
  static List<SaleOrder> orders(int count, {int? partnerId}) {
    return List.generate(
      count,
      (i) => SaleOrderFactory.draft(partnerId: partnerId),
    );
  }

  /// Create multiple order lines.
  static List<SaleOrderLine> orderLines(
    int count, {
    required int orderId,
    double basePrice = 50.0,
  }) {
    return List.generate(
      count,
      (i) => SaleOrderLineFactory.create(
        orderId: orderId,
        name: 'Product ${i + 1}',
        priceUnit: basePrice * (i + 1),
      ),
    );
  }
}
