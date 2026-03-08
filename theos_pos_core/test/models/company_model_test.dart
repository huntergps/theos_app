import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/company/company.model.dart';

void main() {
  group('Company - fromOdoo', () {
    test('parses full company data', () {
      final json = {
        'id': 1,
        'name': 'Tech Solutions S.A.',
        'vat': '0990123456001',
        'street': 'Av. 9 de Octubre 123',
        'street2': 'Piso 5',
        'city': 'Guayaquil',
        'zip': '090101',
        'country_id': [63, 'Ecuador'],
        'state_id': [5, 'Guayas'],
        'phone': '042000000',
        'email': 'info@tech.com',
        'website': 'https://tech.com',
        'currency_id': [1, 'USD'],
        'parent_id': [2, 'Holding Corp'],
        'l10n_ec_comercial_name': 'TechSol',
        'l10n_ec_legal_name': 'Tech Solutions S.A.',
        'l10n_ec_production_env': true,
        'logo': 'base64data',
        'report_header_image': 'headerdata',
        'report_footer': 'Autorizado por SRI',
        'primary_color': '#3498db',
        'secondary_color': '#2ecc71',
        'font': 'Roboto',
        'layout_background': 'Geometric',
        'external_report_layout_id': [3, 'Standard Layout'],
        'tax_calculation_rounding_method': 'round_globally',
        'pedir_end_customer_data': true,
        'pedir_sale_referrer': false,
        'pedir_tipo_canal_cliente': true,
        'sale_customer_invoice_limit_sri': 200.0,
        'max_discount_percentage': 50.0,
        'write_date': '2024-06-15 10:30:00',
      };

      final company = companyManager.fromOdoo(json);

      expect(company.id, equals(1));
      expect(company.name, equals('Tech Solutions S.A.'));
      expect(company.vat, equals('0990123456001'));
      expect(company.street, equals('Av. 9 de Octubre 123'));
      expect(company.street2, equals('Piso 5'));
      expect(company.city, equals('Guayaquil'));
      expect(company.zip, equals('090101'));
      expect(company.countryId, equals(63));
      expect(company.countryName, equals('Ecuador'));
      expect(company.stateId, equals(5));
      expect(company.stateName, equals('Guayas'));
      expect(company.phone, equals('042000000'));
      expect(company.email, equals('info@tech.com'));
      expect(company.website, equals('https://tech.com'));
      expect(company.currencyId, equals(1));
      expect(company.currencyName, equals('USD'));
      expect(company.parentId, equals(2));
      expect(company.parentName, equals('Holding Corp'));
      expect(company.l10nEcComercialName, equals('TechSol'));
      expect(company.l10nEcLegalName, equals('Tech Solutions S.A.'));
      expect(company.l10nEcProductionEnv, isTrue);
      expect(company.logo, equals('base64data'));
      expect(company.primaryColor, equals('#3498db'));
      expect(company.taxCalculationRoundingMethod, equals('round_globally'));
      expect(company.pedirEndCustomerData, isTrue);
      expect(company.pedirSaleReferrer, isFalse);
      expect(company.pedirTipoCanalCliente, isTrue);
      expect(company.saleCustomerInvoiceLimitSri, equals(200.0));
      expect(company.maxDiscountPercentage, equals(50.0));
      expect(company.writeDate, isNotNull);
    });

    test('handles false/null Odoo values', () {
      final json = {
        'id': 1,
        'name': 'Simple Co',
        'vat': false,
        'street': false,
        'city': false,
        'country_id': false,
        'state_id': false,
        'phone': false,
        'email': false,
        'website': false,
        'currency_id': false,
        'parent_id': false,
        'l10n_ec_comercial_name': false,
        'l10n_ec_legal_name': false,
        'logo': false,
        'report_header_image': false,
        'primary_color': false,
      };

      final company = companyManager.fromOdoo(json);

      expect(company.name, equals('Simple Co'));
      expect(company.vat, isNull);
      expect(company.street, isNull);
      expect(company.countryId, isNull);
      expect(company.stateId, isNull);
      expect(company.phone, isNull);
      expect(company.email, isNull);
      expect(company.currencyId, isNull);
      expect(company.parentId, isNull);
      expect(company.l10nEcComercialName, isNull);
      expect(company.logo, isNull);
    });

    test('defaults for missing numeric fields', () {
      final json = {
        'id': 1,
        'name': 'Minimal Co',
      };

      final company = companyManager.fromOdoo(json);

      // Generated fromOdoo defaults to 0.0 and '' for missing fields
      expect(company.maxDiscountPercentage, equals(0.0));
      expect(company.taxCalculationRoundingMethod, equals(''));
      expect(company.l10nEcProductionEnv, isFalse);
    });
  });

  group('Company - Validation', () {
    test('isValid with valid data', () {
      const company = Company(id: 1, name: 'Valid Co', currencyId: 1);
      expect(company.isValid, isTrue);
    });

    test('isValid fails without name', () {
      const company = Company(id: 1, name: '', currencyId: 1);
      expect(company.isValid, isFalse);
    });

    test('isValid fails with only spaces name', () {
      const company = Company(id: 1, name: '   ', currencyId: 1);
      expect(company.isValid, isFalse);
    });

    test('isValid fails without currency', () {
      const company = Company(id: 1, name: 'Test');
      expect(company.isValid, isFalse);
    });
  });

  group('Company - Convenience Getters', () {
    test('hasAddress checks street or city', () {
      expect(const Company(id: 1, name: 'T', street: 'Main St').hasAddress, isTrue);
      expect(const Company(id: 1, name: 'T', city: 'Quito').hasAddress, isTrue);
      expect(const Company(id: 1, name: 'T').hasAddress, isFalse);
      expect(const Company(id: 1, name: 'T', street: '').hasAddress, isFalse);
    });

    test('hasContactInfo checks phone or email', () {
      expect(const Company(id: 1, name: 'T', phone: '042000000').hasContactInfo, isTrue);
      expect(const Company(id: 1, name: 'T', email: 'a@b.c').hasContactInfo, isTrue);
      expect(const Company(id: 1, name: 'T').hasContactInfo, isFalse);
    });

    test('hasLogo checks logo field', () {
      expect(const Company(id: 1, name: 'T', logo: 'data').hasLogo, isTrue);
      expect(const Company(id: 1, name: 'T').hasLogo, isFalse);
    });

    test('fullAddress joins non-empty parts', () {
      const company = Company(
        id: 1,
        name: 'T',
        street: 'Av. Principal',
        city: 'Guayaquil',
        stateName: 'Guayas',
        countryName: 'Ecuador',
      );
      expect(company.fullAddress, contains('Av. Principal'));
      expect(company.fullAddress, contains('Guayaquil'));
      expect(company.fullAddress, contains('Guayas'));
      expect(company.fullAddress, contains('Ecuador'));
    });

    test('displayName uses comercial name when available', () {
      const company = Company(
        id: 1,
        name: 'Legal Corp S.A.',
        l10nEcComercialName: 'LegalCorp',
      );
      expect(company.displayName, equals('LegalCorp'));
    });

    test('displayName falls back to name', () {
      const company = Company(id: 1, name: 'My Company');
      expect(company.displayName, equals('My Company'));
    });

    test('legalName uses legal name when available', () {
      const company = Company(
        id: 1,
        name: 'Short Name',
        l10nEcLegalName: 'Full Legal Name S.A.',
      );
      expect(company.legalName, equals('Full Legal Name S.A.'));
    });

    test('legalName falls back to name', () {
      const company = Company(id: 1, name: 'My Company');
      expect(company.legalName, equals('My Company'));
    });

    test('id > 0 indicates synced', () {
      expect(const Company(id: 1, name: 'T').id > 0, isTrue);
      expect(const Company(id: 0, name: 'T').id > 0, isFalse);
    });
  });
}
