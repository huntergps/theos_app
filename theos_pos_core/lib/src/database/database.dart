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
  int get schemaVersion => 53;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        print('[Database] 🆕 onCreate: Creando todas las tablas (schema v$schemaVersion)...');
        logger.i('[Database]', '🆕 onCreate: Creando todas las tablas (schema v$schemaVersion)...');
        await m.createAll();
        print('[Database] ✅ Todas las tablas creadas correctamente');
        logger.i('[Database]', '✅ Todas las tablas creadas correctamente');
      },
      onUpgrade: (Migrator m, int from, int to) async {
        print('[Database] ⬆️ onUpgrade: Migrando de v$from a v$to...');
        logger.i('[Database]', '⬆️ onUpgrade: Migrando de v$from a v$to...');
        print('[Database] Total de migraciones a ejecutar: ${to - from}');
        logger.d('[Database] Total de migraciones a ejecutar: ${to - from}');

        // Migration v48 -> v49: Add HR fields to res_users
        if (from < 49) {
          logger.d('[Database] 📦 Adding HR fields to res_users (v49)...');
          await customStatement('ALTER TABLE res_users ADD COLUMN out_of_office_from INTEGER;');
          await customStatement('ALTER TABLE res_users ADD COLUMN out_of_office_to INTEGER;');
          await customStatement('ALTER TABLE res_users ADD COLUMN out_of_office_message TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN calendar_default_privacy TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN work_location_id INTEGER;');
          await customStatement('ALTER TABLE res_users ADD COLUMN work_location_name TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN resource_calendar_id INTEGER;');
          await customStatement('ALTER TABLE res_users ADD COLUMN resource_calendar_name TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN pin TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_street TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_street2 TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_city TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_zip TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_state_id INTEGER;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_state_name TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_country_id INTEGER;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_country_name TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_email TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN private_phone TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN emergency_contact TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN emergency_phone TEXT;');
          logger.d('[Database] ✅ HR fields added to res_users');
        }

        // Migration v49 -> v50: Add sales default columns to res_company_table
        if (from < 50) {
          logger.d('[Database] 📦 Adding sales default columns to res_company_table (v50)...');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_partner_id INTEGER;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_partner_name TEXT;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_warehouse_id INTEGER;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_warehouse_name TEXT;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_pricelist_id INTEGER;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_pricelist_name TEXT;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_payment_term_id INTEGER;');
          await customStatement('ALTER TABLE res_company_table ADD COLUMN default_payment_term_name TEXT;');
          logger.d('[Database] ✅ Sales default columns added to res_company_table');
        }

        // Migration v50 -> v51: Add unique index on stock_by_warehouse (product_id, warehouse_id)
        if (from < 51) {
          logger.i('[Database]', '📦 v51: Adding unique index on stock_by_warehouse...');

          // Count rows before deletion
          logger.d('[Database] Contando filas en stock_by_warehouse...');
          final countResult = await customSelect('SELECT COUNT(*) as total FROM stock_by_warehouse').get();
          final totalRows = countResult.first.data['total'] as int;
          logger.d('[Database] Total de filas en stock_by_warehouse: $totalRows');

          // First delete duplicates if any exist (keep the latest one)
          logger.d('[Database] Eliminando duplicados (puede tardar si hay muchos)...');
          await customStatement('''
            DELETE FROM stock_by_warehouse
            WHERE id NOT IN (
              SELECT MAX(id)
              FROM stock_by_warehouse
              GROUP BY product_id, warehouse_id
            )
          ''');
          logger.d('[Database] ✅ Duplicados eliminados');

          // Count rows after deletion
          final afterCountResult = await customSelect('SELECT COUNT(*) as total FROM stock_by_warehouse').get();
          final rowsAfter = afterCountResult.first.data['total'] as int;
          logger.d('[Database] Filas después de eliminar duplicados: $rowsAfter (eliminados: ${totalRows - rowsAfter})');

          // Create unique index
          logger.d('[Database] Creando índice único (puede tardar si hay muchas filas)...');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_stock_by_warehouse_unique
            ON stock_by_warehouse(product_id, warehouse_id)
          ''');
          logger.i('[Database]', '✅ v51: Índice único creado en stock_by_warehouse');
        }

        // Migration v51 -> v52: Unify sync tables with odoo_offline_core
        if (from < 52) {
          logger.i('[Database]', '📦 v52: Unifying sync tables with odoo_offline_core...');

          // 1. OfflineQueue: Add missing columns from core
          await customStatement(
              "ALTER TABLE offline_queue ADD COLUMN status TEXT DEFAULT 'pending'");
          await customStatement(
              'ALTER TABLE offline_queue ADD COLUMN max_retries INTEGER DEFAULT 3');
          await customStatement(
              'ALTER TABLE offline_queue ADD COLUMN requires_network INTEGER DEFAULT 1');

          // 2. SyncAuditLog: Fill nulls in columns that core expects NOT NULL
          await customStatement(
              "UPDATE sync_audit_log SET method = operation WHERE method IS NULL");
          await customStatement(
              "UPDATE sync_audit_log SET result = COALESCE(result, status, 'success') WHERE result IS NULL");
          await customStatement(
              'UPDATE sync_audit_log SET synced_at = COALESCE(synced_at, timestamp) WHERE synced_at IS NULL');
          await customStatement(
              'UPDATE sync_audit_log SET created_offline_at = COALESCE(created_offline_at, synced_at, timestamp) WHERE created_offline_at IS NULL');
          await customStatement(
              'UPDATE sync_audit_log SET gap_seconds = COALESCE(gap_seconds, 0) WHERE gap_seconds IS NULL');

          // 3. RelatedRecordCache: Fix nulls and add unique index
          await customStatement(
              "UPDATE related_record_cache SET name = '' WHERE name IS NULL");
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS idx_related_record_cache_model_odoo_id
            ON related_record_cache(model, odoo_id)
          ''');

          logger.i('[Database]', '✅ v52: Sync tables unified');
        }

        // Migration v52 -> v53: Add work contact fields to res_users
        if (from < 53) {
          logger.i('[Database]', '📦 v53: Adding work contact fields to res_users...');
          await customStatement('ALTER TABLE res_users ADD COLUMN work_email TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN work_phone TEXT;');
          await customStatement('ALTER TABLE res_users ADD COLUMN mobile_phone TEXT;');
          logger.i('[Database]', '✅ v53: Work contact fields added to res_users');
        }

        logger.i('[Database]', '✅ Migración de v$from a v$to COMPLETADA');
      },
      beforeOpen: (details) async {
        // Enable WAL mode for better concurrent read/write performance
        await customStatement('PRAGMA journal_mode=WAL');
        // Wait up to 10 seconds for a lock to release instead of failing immediately
        await customStatement('PRAGMA busy_timeout=10000');
      },
    );
  }
}
