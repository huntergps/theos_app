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
import 'tables/notification_tables.dart';

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
@DriftDatabase(
  tables: [
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
    AccountPaymentTable,
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
    SyncConflict,
    // Report templates
    QwebReportTemplate,
    QwebPaperFormat,
    // Notifications (append-only to preserve generated table ordering)
    NotificationEntries,
    NotificationDeliveries,
    NotificationCursors,
    NotificationSystemIds,
  ],
)
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
  AppDatabase(QueryExecutor executor, {String? databaseName})
    : super(executor) {
    _currentDatabaseName = databaseName ?? defaultDatabaseName;
  }

  @override
  int get schemaVersion => 15;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        logger.i(
          '[Database]',
          'Creating all tables (schema v$schemaVersion)...',
        );
        await m.createAll();
        logger.i('[Database]', 'All tables created successfully');
      },
      // Los pasos son ACUMULATIVOS y se aplican en orden, no por destino
      // exacto. Antes cada rama miraba a qué versión se subía (`to == 14`) y
      // devolvía; al subir el esquema a 15, una base en 13 dejó de encontrar
      // su rama y se caía al camino destructivo del final, que **borra y
      // recrea todas las tablas**. Escrito así, subir el esquema otra vez sólo
      // pide añadir un paso al final.
      onUpgrade: (Migrator m, int from, int to) async {
        if (from >= 10 && from <= schemaVersion) {
          if (from < 11) {
            await m.addColumn(advanceLinesTable, advanceLinesTable.advanceId);
          }
          if (from < 12) {
            await m.addColumn(
              collectionConfig,
              collectionConfig.posAppCapabilitiesJson,
            );
          }
          if (from < 13) {
            await m.addColumn(accountJournal, accountJournal.numberedByClient);
          }
          if (from < 14) {
            await m.createTable(notificationEntries);
            await m.createTable(notificationDeliveries);
            await m.createTable(notificationCursors);
            await m.createTable(notificationSystemIds);
          }
          if (from < 15) {
            // Los plazos de tarjeta cambian de columnas porque las que tenían
            // —días y porcentaje— no existen en Odoo y esta tabla nunca llegó
            // a llenarse. Es un catálogo: se recrea vacía y se vuelve a traer
            // del servidor. **Sólo esa tabla**, para no rozar la cola sin
            // conexión ni ningún documento financiero.
            await m.deleteTable(accountCreditCardDeadline.actualTableName);
            await m.createTable(accountCreditCardDeadline);
          }
          return;
        }
        logger.i(
          '[Database]',
          'Development schema changed v$from → v$to; recreating local cache',
        );
        for (final table in allTables.toList().reversed) {
          await m.deleteTable(table.actualTableName);
        }
        await m.createAll();
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
        // Índices de búsqueda en SaleOrder
        //
        // sale_order_line(order_id): las queries de líneas filtran siempre
        //   por order_id (FK a SaleOrder). Sin índice → full table scan en
        //   tablas con miles de líneas acumuladas.
        // sale_order(state): getEditableOrdersForPOS filtra por state.isIn(...)
        //   en cada render del POS screen.
        // sale_order(partner_id): getSaleOrders() con filtro partnerId y
        //   queries del panel de clientes.
        // offline_queue(status, priority): el procesador de cola filtra por
        //   status='pending' ORDER BY priority desc; este índice compuesto
        //   cubre ambas condiciones en una sola operación.
        // sale_order(write_date): syncFromOdoo() filtra por write_date >= last
        //   sync para incremental sync; sin índice → full scan en cada ciclo.
        // ----------------------------------------------------------------
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sol_order_id '
          'ON sale_order_line (order_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_so_state '
          'ON sale_order (state)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_so_date_order_state '
          'ON sale_order (date_order, state)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_so_is_synced '
          'ON sale_order (is_synced)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_so_partner_id '
          'ON sale_order (partner_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_oq_status_priority '
          'ON offline_queue (status, priority)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_so_write_date '
          'ON sale_order (write_date)',
        );

        // ----------------------------------------------------------------
        // Índices en líneas hijas de SaleOrder y sesiones de cobranza
        //
        // sale_order_payment_line(order_id) / sale_order_withhold_line(order_id):
        //   mismo patrón de filtro que sale_order_line(order_id) — payment_service,
        //   payment_line_local_service y withhold_line_local_service siempre
        //   consultan por order_id. Sin índice → full table scan, igual que
        //   sale_order_line antes de indexarla.
        // collection_session_cash/deposit(collection_session_id) y
        //   cash_out(collection_session_id): se consultan en cada apertura de
        //   la pantalla de sesión de cobranza (arqueo, depósitos, retiros).
        // ----------------------------------------------------------------
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sopl_order_id '
          'ON sale_order_payment_line (order_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sowl_order_id '
          'ON sale_order_withhold_line (order_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_csc_collection_session_id '
          'ON collection_session_cash (collection_session_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_csd_collection_session_id '
          'ON collection_session_deposit (collection_session_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_co_collection_session_id '
          'ON cash_out (collection_session_id)',
        );

        // ----------------------------------------------------------------
        // Recovery de operaciones 'processing' al startup
        //
        // Si la app crashea mientras procesaba operaciones offline, éstas
        // quedan en estado 'processing' indefinidamente. Al abrir la DB,
        // se mueven a 'recovery_pending'. El procesador solo reintentará
        // automáticamente las que tengan un contrato de reconciliación
        // remoto; una creación ambigua sin ese contrato irá a dead-letter.
        //
        // Seguro: una operación genuinamente en curso no existirá en la DB
        // en el momento de apertura, ya que el proceso previo fue terminado.
        // ----------------------------------------------------------------
        await customStatement(
          "UPDATE offline_queue SET status = 'recovery_pending' "
          "WHERE status = 'processing'",
        );
        final recovered = await customSelect(
          "SELECT COUNT(*) AS cnt FROM offline_queue "
          "WHERE status IN ('pending', 'recovery_pending')",
        ).getSingle();
        final pendingCount = recovered.read<int>('cnt');
        logger.i(
          '[Database]',
          'Startup recovery: offline_queue processing→recovery_pending. '
              'Total pending now: $pendingCount',
        );
      },
    );
  }
}
