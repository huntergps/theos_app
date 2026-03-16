import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    hide
        // Drift code generation requires local table definitions (can't resolve
        // cross-package Table classes). These 5 tables are mirrored in
        // sync_tables.dart with identical schemas. See P0 note in sync_tables.dart.
        SyncAuditLog,
        SyncMetadata,
        FieldSelections,
        RelatedRecordCache,
        OfflineQueue,
        // SyncConflict from odoo_sdk conflicts with the local Drift table class
        SyncConflict;

// Import table definitions directly for Drift code generation
import 'tables/res_partner_table.dart';
import 'tables/res_users_table.dart';
import 'tables/res_currency_table.dart';
import 'tables/geographic_tables.dart';
import 'tables/banking_tables.dart';
import 'tables/accounting_tables.dart';
import 'tables/product_tables.dart';
import 'tables/pricing_tables.dart';
import 'tables/inventory_tables.dart';
import 'tables/sales_lines_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/pos_system_tables.dart';
import 'tables/payment_config_tables.dart';
import 'tables/collection_tables.dart';
import 'tables/reporting_tables.dart';
import 'tables/account_journal_table.dart';
import 'tables/product_product_table.dart';
import 'tables/sale_order_table.dart';

import 'migrations.dart';

part 'database.g.dart';

// ============ Database Definition ============

/// Theos POS Core Database
///
/// Pure Dart database definition using Drift ORM.
/// This database can be used with any QueryExecutor:
/// - Flutter apps: Use DriftFlutterDatabase from drift_flutter
/// - CLI tools: Use NativeDatabase from drift/native
/// - Web: Use WebDatabase from drift/web
/// - Testing: Use NativeDatabase.memory()
///
/// Example usage in Flutter app:
/// ```dart
/// import 'package:drift_flutter/drift_flutter.dart';
///
/// final db = AppDatabase(driftDatabase(name: 'theos_pos'));
/// ```
///
/// Example usage in CLI:
/// ```dart
/// import 'package:drift/native.dart';
///
/// final db = AppDatabase(NativeDatabase.memory());
/// ```
@DriftDatabase(tables: [
  // Core system tables
  DecimalPrecision,
  ResCurrency,
  // User and partner tables
  ResUsers,
  ResGroups,
  ResPartner,
  // Geographic tables
  ResCountry,
  ResCountryState,
  ResLang,
  // Banking tables
  ResBank,
  ResPartnerBank,
  ResCompanyTable,
  // Inventory tables
  StockWarehouse,
  ResourceCalendar,
  // Sync tables
  OfflineQueue,
  SyncAuditLog,
  SyncMetadata,
  FieldSelections,
  RelatedRecordCache,
  // Activity and mail tables
  MailActivityTable,
  // Collection system tables
  CollectionConfig,
  CollectionSession,
  CollectionSessionCash,
  CollectionSessionDeposit,
  CashOut,
  // Accounting tables
  AccountPayment,
  AccountMove,
  AccountMoveLine,
  // Sales tables
  SaleOrder,
  SaleOrderLine,
  SaleOrderWithholdLine,
  SaleOrderPaymentLine,
  // Product tables
  ProductProduct,
  ProductCategory,
  // Tax and pricing tables
  AccountTax,
  UomUom,
  UomCategory,
  ProductUom,
  ProductPricelist,
  ProductPricelistItem,
  // Payment and fiscal tables
  AccountPaymentTerm,
  CrmTeam,
  AccountFiscalPosition,
  AccountFiscalPositionTax,
  AccountJournal,
  AccountCreditCardBrand,
  AccountCreditCardDeadline,
  AccountCardLote,
  AccountPaymentMethodLine,
  AccountAdvance,
  AdvanceLinesTable,
  AccountCreditNote,
  OfflineInvoice,
  // Cash out types
  CashOutType,
  // Stock and inventory tables
  StockByWarehouse,
  ProductPriceChange,
  StockQuantityChange,
  // Sync and conflict tables
  DirtyFields,
  SyncConflict,
  // Report templates
  QwebReportTemplate,
  QwebPaperFormat,
])
class AppDatabase extends _$AppDatabase {
  /// Default database name (used when no server-specific name is provided)
  static const String defaultDatabaseName = 'theos_pos_db';

  /// Current database name being used
  static String? _currentDatabaseName;

  /// Get the current database name
  static String get currentDatabaseName =>
      _currentDatabaseName ?? defaultDatabaseName;

  /// Constructor with QueryExecutor
  ///
  /// The executor determines how the database is opened:
  /// - Flutter: DriftFlutterDatabase from drift_flutter
  /// - Native: NativeDatabase from drift/native
  /// - Web: WebDatabase from drift/web
  /// - Testing: NativeDatabase.memory()
  ///
  /// Example:
  /// ```dart
  /// // In Flutter app
  /// final db = AppDatabase(driftDatabase(name: 'theos_pos'));
  ///
  /// // In CLI tool
  /// final db = AppDatabase(NativeDatabase.memory());
  /// ```
  AppDatabase(QueryExecutor executor, {String? databaseName}) : super(executor) {
    _currentDatabaseName = databaseName ?? defaultDatabaseName;
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        logger.i('[Database]', 'Creating all tables (schema v$schemaVersion)...');
        await m.createAll();
        logger.i('[Database]', 'All tables created successfully');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Delega a DatabaseMigrations para lógica de migración incremental.
        //
        // Estrategia:
        //   - from <= 3 (alfa): drop + recreate. Sin datos de producción.
        //   - from >= 4 (prod): migraciones incrementales que preservan datos.
        //     Las migraciones se ejecutan paso a paso: from→from+1→...→to.
        //
        // Ver: theos_pos_core/lib/src/database/migrations.dart
        logger.i('[Database]', 'Iniciando upgrade v$from → v$to...');
        await DatabaseMigrations.migrate(m, from, to, this);
        logger.i('[Database]', 'Upgrade v$from → v$to completado.');
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA journal_mode=WAL');
        await customStatement('PRAGMA busy_timeout=10000');

        // ----------------------------------------------------------------
        // Índices de búsqueda en ProductProduct
        //
        // Se crean con IF NOT EXISTS → idempotentes en cada apertura.
        // Sobreviven al onUpgrade (drop+recreate) porque beforeOpen corre
        // después del recreate.
        //
        // Beneficio: queries de catálogo con filtro por name/barcode/
        // defaultCode/availableInPos pasan de full table scan a index scan,
        // crítico con 5,000+ productos.
        // ----------------------------------------------------------------
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_product_name '
          'ON product_product (name)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_product_barcode '
          'ON product_product (barcode)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_product_default_code '
          'ON product_product (default_code)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_product_available_pos '
          'ON product_product (available_in_pos)',
        );

        // ----------------------------------------------------------------
        // Recovery de operaciones 'processing' al startup
        //
        // Si la app crashea mientras procesaba operaciones offline, éstas
        // quedan en estado 'processing' indefinidamente. Al abrir la DB,
        // se resetean a 'pending' para que el sync las reintente.
        //
        // Seguro: una operación genuinamente en curso no existirá en la DB
        // en el momento de apertura, ya que el proceso previo fue terminado.
        // ----------------------------------------------------------------
        await customStatement(
          "UPDATE offline_queue SET status = 'pending' WHERE status = 'processing'",
        );
        final recovered = await customSelect(
          "SELECT COUNT(*) AS cnt FROM offline_queue WHERE status = 'pending'",
        ).getSingle();
        final pendingCount = recovered.read<int>('cnt');
        logger.i(
          '[Database]',
          'Startup recovery: offline_queue processing→pending reset. '
          'Total pending now: $pendingCount',
        );
      },
    );
  }
}
