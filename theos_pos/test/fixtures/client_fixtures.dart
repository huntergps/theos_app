/// Client Fixtures
///
/// Predefined client data for consistent testing across test files.
/// These fixtures represent common scenarios and edge cases.
library;

/// Odoo API response format for clients.
class ClientOdooFixtures {
  /// Standard customer response.
  static Map<String, dynamic> standard({
    int id = 1,
    String name = 'Cliente Estándar',
    String? vat = '1712345678',
    String? email = 'cliente@example.com',
    String? phone = '0991234567',
    double creditLimit = 0.0,
    double credit = 0.0,
    bool active = true,
  }) =>
      {
        'id': id,
        'name': name,
        'vat': vat ?? false,
        'email': email ?? false,
        'phone': phone ?? false,
        'credit_limit': creditLimit,
        'credit': credit,
        'active': active,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Final consumer (Consumidor Final).
  static Map<String, dynamic> finalConsumer({int id = 9999}) => {
        'id': id,
        'name': 'CONSUMIDOR FINAL',
        'vat': '9999999999999',
        'email': false,
        'phone': false,
        'credit_limit': 0.0,
        'credit': 0.0,
        'active': true,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Company with RUC.
  static Map<String, dynamic> company({
    int id = 2,
    String name = 'Empresa Test S.A.',
    String ruc = '1791234567001',
  }) =>
      {
        'id': id,
        'name': name,
        'vat': ruc,
        'email': 'empresa@example.com',
        'phone': '022345678',
        'credit_limit': 5000.0,
        'credit': 0.0,
        'active': true,
        'is_company': true,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Customer with credit.
  static Map<String, dynamic> withCredit({
    int id = 3,
    double creditLimit = 1000.0,
    double credit = 500.0,
  }) =>
      {
        'id': id,
        'name': 'Cliente Con Crédito',
        'vat': '1798765432',
        'email': 'credito@example.com',
        'phone': false,
        'credit_limit': creditLimit,
        'credit': credit,
        'active': true,
        'write_date': DateTime.now().toIso8601String(),
      };

  /// Customer exceeding credit limit.
  static Map<String, dynamic> overCreditLimit({
    int id = 4,
    double creditLimit = 1000.0,
    double credit = 1500.0,
  }) =>
      withCredit(id: id, creditLimit: creditLimit, credit: credit);

  /// Inactive/archived customer.
  static Map<String, dynamic> inactive({int id = 5}) => standard(
        id: id,
        name: 'Cliente Inactivo',
        active: false,
      );

  /// List of multiple clients for batch testing.
  static List<Map<String, dynamic>> batch({int count = 5}) => List.generate(
        count,
        (i) => standard(id: i + 1, name: 'Cliente ${i + 1}'),
      );
}

/// Local database format for clients (Drift companion).
class ClientDriftFixtures {
  /// Create a Drift-compatible map.
  static Map<String, dynamic> standard({
    int id = 1,
    String name = 'Cliente Estándar',
    String? vat = '1712345678',
  }) =>
      {
        'id': id,
        'name': name,
        'vat': vat,
        'email': null,
        'phone': null,
        'credit_limit': 0.0,
        'credit': 0.0,
        'active': true,
        'is_synced': true,
        'uuid': null,
      };
}

/// Invalid data fixtures for error testing.
class ClientInvalidFixtures {
  /// Missing required name field.
  static Map<String, dynamic> missingName() => {
        'id': 100,
        'vat': '1712345678',
        'email': false,
        'credit_limit': 0.0,
      };

  /// Invalid VAT format.
  static Map<String, dynamic> invalidVat() => {
        'id': 101,
        'name': 'Cliente VAT Inválido',
        'vat': '123', // Too short
        'email': false,
      };

  /// Negative credit (impossible state).
  static Map<String, dynamic> negativeCredit() => {
        'id': 102,
        'name': 'Cliente Crédito Negativo',
        'credit': -100.0,
        'credit_limit': 1000.0,
      };
}
