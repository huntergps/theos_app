/// Tier 3 - Simple Managers Metadata Tests
///
/// Verifies odooModel, tableName, and odooFields for many simpler managers.
/// Each manager follows the same pattern: verify metadata is correct and non-empty.
///
/// Managers that extend OdooModelManager with GenericDriftOperations have tableName.
/// Lightweight managers (plain classes) only have odooModel and odooFields.
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/src/database/database.dart';

// Taxes
import 'package:theos_pos_core/src/models/taxes/tax.model.dart';
import 'package:theos_pos_core/src/managers/taxes/fiscal_position_manager.dart';
import 'package:theos_pos_core/src/models/taxes/fiscal_position.model.dart';

// Config
import 'package:theos_pos_core/src/managers/config/locale_manager.dart';
import 'package:theos_pos_core/src/models/config/currency.model.dart';
import 'package:theos_pos_core/src/models/warehouses/warehouse.model.dart';
import 'package:theos_pos_core/src/models/payment_terms/payment_term.model.dart';

// Banks
import 'package:theos_pos_core/src/models/banks/bank.model.dart';
import 'package:theos_pos_core/src/models/prices/pricelist.model.dart';

// Sales
import 'package:theos_pos_core/src/models/sales/sales_team.model.dart';

// Warehouses

// Prices
import 'package:theos_pos_core/src/managers/prices/pricelist_manager.dart';

// Products (generated managers from model files)
import 'package:theos_pos_core/src/models/products/product_category.model.dart';
import 'package:theos_pos_core/src/models/products/product_uom.model.dart';
import 'package:theos_pos_core/src/models/products/uom.model.dart';

// Company
import 'package:theos_pos_core/src/models/company/company.model.dart';

// Users
import 'package:theos_pos_core/src/models/users/user.model.dart';
import 'package:theos_pos_core/src/managers/users/groups_manager.dart';

// Payment Terms

// Activities (generated manager from model file)
import 'package:theos_pos_core/src/models/activities/mail_activity.model.dart';

// Collection (generated managers from model files)
import 'package:theos_pos_core/src/models/collection/collection_config.model.dart';
import 'package:theos_pos_core/src/models/collection/collection_session.model.dart';
import 'package:theos_pos_core/src/models/collection/account_payment.model.dart';
import 'package:theos_pos_core/src/managers/collection/journal_manager.dart';

// Advances (generated manager from model file)
import 'package:theos_pos_core/src/models/advances/advance.model.dart';

// Invoices
import 'package:theos_pos_core/src/managers/invoices/credit_note_manager.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late MockAppDatabase db;

  setUp(() {
    db = MockAppDatabase();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Taxes
  // ═══════════════════════════════════════════════════════════════════════════

  group('TaxManager', () {
    test('odooModel is account.tax', () {
      expect(taxManager.odooModel, equals('account.tax'));
    });
    test('tableName is account_tax', () {
      expect(taxManager.tableName, equals('account_tax'));
    });
    test('odooFields is non-empty', () {
      expect(taxManager.odooFields, isNotEmpty);
    });
  });

  group('FiscalPositionManager', () {
    test('odooModel is account.fiscal.position', () {
      expect(fiscalPositionManager.odooModel, equals('account.fiscal.position'));
    });
    test('tableName is account_fiscal_positions', () {
      expect(fiscalPositionManager.tableName, equals('account_fiscal_positions'));
    });
    test('odooFields is non-empty', () {
      expect(fiscalPositionManager.odooFields, isNotEmpty);
    });
  });

  group('FiscalPositionTaxManager', () {
    late FiscalPositionTaxManager manager;
    setUp(() => manager = FiscalPositionTaxManager(db));

    test('odooModel is account.fiscal.position.tax', () {
      expect(manager.odooModel, equals('account.fiscal.position.tax'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Config
  // ═══════════════════════════════════════════════════════════════════════════

  group('CurrencyManager', () {
    test('odooModel is res.currency', () {
      expect(currencyManager.odooModel, equals('res.currency'));
    });
    test('tableName is res_currency', () {
      expect(currencyManager.tableName, equals('res_currency'));
    });
    test('odooFields is non-empty', () {
      expect(currencyManager.odooFields, isNotEmpty);
    });
  });

  group('DecimalPrecisionManager', () {
    test('odooModel is decimal.precision', () {
      expect(decimalPrecisionManager.odooModel, equals('decimal.precision'));
    });
    test('tableName is decimal_precision', () {
      expect(decimalPrecisionManager.tableName, equals('decimal_precision'));
    });
    test('odooFields is non-empty', () {
      expect(decimalPrecisionManager.odooFields, isNotEmpty);
    });
  });

  group('CountryManager', () {
    late CountryManager manager;
    setUp(() => manager = CountryManager(db));

    test('odooModel is res.country', () {
      expect(manager.odooModel, equals('res.country'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('CountryStateManager', () {
    late CountryStateManager manager;
    setUp(() => manager = CountryStateManager(db));

    test('odooModel is res.country.state', () {
      expect(manager.odooModel, equals('res.country.state'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('LanguageManager', () {
    late LanguageManager manager;
    setUp(() => manager = LanguageManager(db));

    test('odooModel is res.lang', () {
      expect(manager.odooModel, equals('res.lang'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Banks
  // ═══════════════════════════════════════════════════════════════════════════

  group('BankManager', () {
    test('odooModel is res.bank', () {
      expect(bankManager.odooModel, equals('res.bank'));
    });
    test('tableName is res_bank', () {
      expect(bankManager.tableName, equals('res_bank'));
    });
    test('odooFields is non-empty', () {
      expect(bankManager.odooFields, isNotEmpty);
    });
  });

  group('PartnerBankManager', () {
    test('odooModel is res.partner.bank', () {
      expect(partnerBankManager.odooModel, equals('res.partner.bank'));
    });
    test('tableName is res_partner_bank', () {
      expect(partnerBankManager.tableName, equals('res_partner_bank'));
    });
    test('odooFields is non-empty', () {
      expect(partnerBankManager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Sales
  // ═══════════════════════════════════════════════════════════════════════════

  group('SalesTeamManager', () {
    test('odooModel is crm.team', () {
      expect(salesTeamManager.odooModel, equals('crm.team'));
    });
    test('tableName is crm_teams', () {
      expect(salesTeamManager.tableName, equals('crm_teams'));
    });
    test('odooFields is non-empty', () {
      expect(salesTeamManager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Warehouses
  // ═══════════════════════════════════════════════════════════════════════════

  group('WarehouseManager', () {
    test('odooModel is stock.warehouse', () {
      expect(warehouseManager.odooModel, equals('stock.warehouse'));
    });
    test('tableName is stock_warehouses', () {
      expect(warehouseManager.tableName, equals('stock_warehouses'));
    });
    test('odooFields is non-empty', () {
      expect(warehouseManager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Prices
  // ═══════════════════════════════════════════════════════════════════════════

  group('PricelistManager', () {
    test('odooModel is product.pricelist', () {
      expect(pricelistManager.odooModel, equals('product.pricelist'));
    });
    test('tableName is product_pricelists', () {
      expect(pricelistManager.tableName, equals('product_pricelists'));
    });
    test('odooFields is non-empty', () {
      expect(pricelistManager.odooFields, isNotEmpty);
    });
  });

  group('PricelistItemManager', () {
    late PricelistItemManager manager;
    setUp(() => manager = PricelistItemManager(db));

    test('odooModel is product.pricelist.item', () {
      expect(manager.odooModel, equals('product.pricelist.item'));
    });
    test('tableName is product_pricelist_item', () {
      expect(manager.tableName, equals('product_pricelist_item'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Products
  // ═══════════════════════════════════════════════════════════════════════════

  group('ProductCategoryManager', () {
    final manager = productCategoryManager;

    test('odooModel is product.category', () {
      expect(manager.odooModel, equals('product.category'));
    });
    test('tableName is product_categories', () {
      expect(manager.tableName, equals('product_categories'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('ProductUomManager', () {
    late ProductUomManager manager;
    setUp(() => manager = productUomManager);

    test('odooModel is product.uom', () {
      expect(manager.odooModel, equals('product.uom'));
    });
    test('tableName is product_uom', () {
      expect(manager.tableName, equals('product_uom'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('UomManager', () {
    final manager = uomManager;

    test('odooModel is uom.uom', () {
      expect(manager.odooModel, equals('uom.uom'));
    });
    test('tableName is uom_uom', () {
      expect(manager.tableName, equals('uom_uom'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Company
  // ═══════════════════════════════════════════════════════════════════════════

  group('CompanyManager', () {
    test('odooModel is res.company', () {
      expect(companyManager.odooModel, equals('res.company'));
    });
    test('tableName is res_company_table', () {
      expect(companyManager.tableName, equals('res_company_table'));
    });
    test('odooFields is non-empty', () {
      expect(companyManager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Users
  // ═══════════════════════════════════════════════════════════════════════════

  group('UserManager', () {
    test('odooModel is res.users', () {
      expect(userManager.odooModel, equals('res.users'));
    });
    test('tableName is res_users', () {
      expect(userManager.tableName, equals('res_users'));
    });
    test('odooFields is non-empty', () {
      expect(userManager.odooFields, isNotEmpty);
    });
  });

  group('GroupsManager', () {
    late GroupsManager manager;
    setUp(() => manager = GroupsManager(db));

    test('odooModel is res.groups', () {
      expect(manager.odooModel, equals('res.groups'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Payment Terms
  // ═══════════════════════════════════════════════════════════════════════════

  group('PaymentTermManager', () {
    test('odooModel is account.payment.term', () {
      expect(paymentTermManager.odooModel, equals('account.payment.term'));
    });
    test('tableName is account_payment_terms', () {
      expect(paymentTermManager.tableName, equals('account_payment_terms'));
    });
    test('odooFields is non-empty', () {
      expect(paymentTermManager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Activities
  // ═══════════════════════════════════════════════════════════════════════════

  group('MailActivityManager', () {
    final manager = mailActivityManager;

    test('odooModel is mail.activity', () {
      expect(manager.odooModel, equals('mail.activity'));
    });
    test('tableName is mail_activities', () {
      expect(manager.tableName, equals('mail_activities'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Collection
  // ═══════════════════════════════════════════════════════════════════════════

  group('CollectionConfigManager', () {
    final manager = collectionConfigManager;

    test('odooModel is collection.config', () {
      expect(manager.odooModel, equals('collection.config'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('CollectionSessionManager', () {
    final manager = collectionSessionManager;

    test('odooModel is collection.session', () {
      expect(manager.odooModel, equals('collection.session'));
    });
    test('tableName is collection_sessions', () {
      expect(manager.tableName, equals('collection_sessions'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('AccountPaymentManager', () {
    final manager = accountPaymentManager;

    test('odooModel is account.payment', () {
      expect(manager.odooModel, equals('account.payment'));
    });
    test('tableName is account_payments', () {
      expect(manager.tableName, equals('account_payments'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('JournalManager', () {
    late JournalManager manager;
    setUp(() => manager = JournalManager(db));

    test('odooModel is account.journal', () {
      expect(manager.odooModel, equals('account.journal'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  group('PaymentMethodLineManager', () {
    late PaymentMethodLineManager manager;
    setUp(() => manager = PaymentMethodLineManager(db));

    test('odooModel is account.payment.method.line', () {
      expect(manager.odooModel, equals('account.payment.method.line'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Advances
  // ═══════════════════════════════════════════════════════════════════════════

  group('AdvanceManager', () {
    final manager = advanceManager;

    test('odooModel is account.advance', () {
      expect(manager.odooModel, equals('account.advance'));
    });
    test('tableName is advances', () {
      expect(manager.tableName, equals('advances'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Invoices
  // ═══════════════════════════════════════════════════════════════════════════

  group('CreditNoteManager', () {
    late CreditNoteManager manager;
    setUp(() => manager = CreditNoteManager(db));

    test('odooModel is account.move', () {
      expect(manager.odooModel, equals('account.move'));
    });
    test('odooFields is non-empty', () {
      expect(manager.odooFields, isNotEmpty);
    });
  });
}
