/// Product Fixtures
///
/// Predefined product data for consistent testing.
/// Includes various product types and configurations.
library;

/// Odoo API response format for products.
class ProductOdooFixtures {
  /// Standard product.
  static Map<String, dynamic> standard({
    int id = 1,
    String name = 'Producto Estándar',
    String? defaultCode = 'PROD001',
    String? barcode = '7501234567890',
    double listPrice = 10.0,
    int categId = 1,
    int uomId = 1,
    bool active = true,
  }) =>
      {
        'id': id,
        'name': name,
        'default_code': defaultCode ?? false,
        'barcode': barcode ?? false,
        'list_price': listPrice,
        'categ_id': [categId, 'All / Saleable'],
        'uom_id': [uomId, 'Units'],
        'active': active,
        'sale_ok': true,
        'type': 'consu',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Service product.
  static Map<String, dynamic> service({
    int id = 2,
    String name = 'Servicio',
    double listPrice = 50.0,
  }) =>
      {
        'id': id,
        'name': name,
        'default_code': 'SERV001',
        'barcode': false,
        'list_price': listPrice,
        'categ_id': [2, 'Services'],
        'uom_id': [1, 'Units'],
        'active': true,
        'sale_ok': true,
        'type': 'service',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Product with stock (storable).
  static Map<String, dynamic> storable({
    int id = 3,
    String name = 'Producto Almacenable',
    double listPrice = 25.0,
    double qtyAvailable = 100.0,
  }) =>
      {
        'id': id,
        'name': name,
        'default_code': 'STOR001',
        'barcode': '7501234567891',
        'list_price': listPrice,
        'categ_id': [1, 'All / Saleable'],
        'uom_id': [1, 'Units'],
        'active': true,
        'sale_ok': true,
        'type': 'product',
        'qty_available': qtyAvailable,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Temporary product (to be replaced).
  static Map<String, dynamic> temporary({
    int id = 4,
    String name = '[TEMP] Producto Temporal',
    double listPrice = 0.01,
  }) =>
      {
        'id': id,
        'name': name,
        'default_code': 'TEMP001',
        'barcode': false,
        'list_price': listPrice,
        'categ_id': [1, 'All / Saleable'],
        'uom_id': [1, 'Units'],
        'active': true,
        'sale_ok': true,
        'type': 'consu',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// High-value product.
  static Map<String, dynamic> expensive({
    int id = 5,
    String name = 'Producto Premium',
    double listPrice = 999.99,
  }) =>
      standard(
        id: id,
        name: name,
        defaultCode: 'PREM001',
        listPrice: listPrice,
      );

  /// Inactive/archived product.
  static Map<String, dynamic> inactive({int id = 6}) => standard(
        id: id,
        name: 'Producto Inactivo',
        active: false,
      );

  /// Product with tax included in price.
  static Map<String, dynamic> taxIncluded({
    int id = 7,
    String name = 'Producto IVA Incluido',
    double listPrice = 115.0,
  }) =>
      {
        'id': id,
        'name': name,
        'default_code': 'TAXINC001',
        'barcode': false,
        'list_price': listPrice,
        'categ_id': [1, 'All / Saleable'],
        'uom_id': [1, 'Units'],
        'active': true,
        'sale_ok': true,
        'type': 'consu',
        'taxes_id': [1],
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Batch of products.
  static List<Map<String, dynamic>> batch({int count = 5}) => List.generate(
        count,
        (i) => standard(
          id: i + 1,
          name: 'Producto ${i + 1}',
          defaultCode: 'PROD${(i + 1).toString().padLeft(3, '0')}',
          listPrice: 10.0 * (i + 1),
        ),
      );
}

/// Product category fixtures.
class ProductCategoryOdooFixtures {
  /// Root category.
  static Map<String, dynamic> root({int id = 1}) => {
        'id': id,
        'name': 'All',
        'parent_id': false,
        'complete_name': 'All',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Saleable category.
  static Map<String, dynamic> saleable({int id = 2}) => {
        'id': id,
        'name': 'Saleable',
        'parent_id': [1, 'All'],
        'complete_name': 'All / Saleable',
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Services category.
  static Map<String, dynamic> services({int id = 3}) => {
        'id': id,
        'name': 'Services',
        'parent_id': [1, 'All'],
        'complete_name': 'All / Services',
        'write_date': DateTime.now().toIso8601String(),
      };
}

/// UOM (Unit of Measure) fixtures.
class UomOdooFixtures {
  /// Units (base UOM).
  static Map<String, dynamic> units({int id = 1}) => {
        'id': id,
        'name': 'Units',
        'category_id': [1, 'Unit'],
        'uom_type': 'reference',
        'factor': 1.0,
        'rounding': 0.01,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Dozen.
  static Map<String, dynamic> dozen({int id = 2}) => {
        'id': id,
        'name': 'Dozen',
        'category_id': [1, 'Unit'],
        'uom_type': 'bigger',
        'factor': 12.0,
        'rounding': 0.01,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Kilogram.
  static Map<String, dynamic> kilogram({int id = 3}) => {
        'id': id,
        'name': 'kg',
        'category_id': [2, 'Weight'],
        'uom_type': 'reference',
        'factor': 1.0,
        'rounding': 0.001,
        'write_date': DateTime.now().toIso8601String(),
      };
}

/// Invalid product fixtures for error testing.
class ProductInvalidFixtures {
  /// Missing required name.
  static Map<String, dynamic> missingName() => {
        'id': 100,
        'default_code': 'INVALID001',
        'list_price': 10.0,
      };

  /// Negative price.
  static Map<String, dynamic> negativePrice() => {
        'id': 101,
        'name': 'Precio Negativo',
        'list_price': -10.0,
      };
}
