import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:uuid/uuid.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, CreditIssue;

import '../../../../core/database/database_helper.dart';
import '../../../../core/services/handlers/related_record_resolver.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import '../../invoices/repositories/invoice_repository.dart';
import '../../products/repositories/product_repository.dart';
import 'sales_repository_models.dart';

// Re-export standalone models for backward compatibility
export 'sales_repository_models.dart';

// Part files
part 'sales_repository_invoice.dart';
part 'sales_repository_reads.dart';
part 'sales_repository_sync.dart';
part 'sales_repository_crud.dart';
part 'sales_repository_state.dart';
part 'sales_repository_credit.dart';
part 'sales_repository_lines.dart';
part 'sales_repository_withhold.dart';

/// Repository for Sales - Consolidated offline-first implementation
///
/// Handles sale orders, lines, state changes, and partner lookups.
///
/// Offline-first strategy for lines:
/// 1. All operations save to local DB first
/// 2. If online, attempt immediate sync
/// 3. If offline or sync fails, queue for later
/// 4. UUID tracks lines across local/remote IDs
///
/// Related record resolution is delegated to [RelatedRecordResolver]
/// which handles the offline-first pattern for fetching missing data.
class SalesRepository {
  final OdooClient? _odooClient;
  final OfflineQueueDataSource? _offlineQueue;
  final RelatedRecordResolver? _relatedResolver;
  final ProductRepository? _productRepository;

  final _uuid = const Uuid();

  final AppDatabase _db;

  /// Convenience accessor for the global SaleOrderManager
  SaleOrderManager get _orderManager => saleOrderManager;

  /// Convenience accessor for the global SaleOrderLineManager
  SaleOrderLineManager get _lineManager => saleOrderLineManager;

  SalesRepository({
    required DatabaseHelper db,
    required AppDatabase appDb,
    OdooClient? odooClient,
    OfflineQueueDataSource? offlineQueue,
    RelatedRecordResolver? relatedResolver,
    ProductRepository? productRepository,
  }) : _db = appDb,
       _odooClient = odooClient,
       _offlineQueue = offlineQueue,
       _relatedResolver = relatedResolver,
       _productRepository = productRepository;

  /// Find a sale order line by UUID using searchLocal domain filter
  Future<SaleOrderLine?> _findLineByUuid(String uuid) async {
    final results = await _lineManager.searchLocal(
      domain: [['line_uuid', '=', uuid]],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update local UUID-based line with its remote Odoo ID after sync
  ///
  /// Finds the line by UUID, deletes the old record, and re-inserts
  /// with the new remote ID and synced status.
  Future<void> _updateLineRemoteIdByUuid(String uuid, int remoteId) async {
    final existingLine = await _findLineByUuid(uuid);
    if (existingLine == null) {
      logger.w(
        '[SalesRepository] Cannot update remote ID: line UUID $uuid not found',
      );
      return;
    }

    await _lineManager.deleteLocal(existingLine.id);
    final updatedLine = existingLine.copyWith(
      id: remoteId,
      isSynced: true,
      lastSyncDate: DateTime.now().toUtc(),
    );
    await _lineManager.upsertLocal(updatedLine);
    logger.d('[SalesRepository] Updated line UUID $uuid with Odoo ID: $remoteId');
  }

  /// Check if we're online (have an active Odoo connection)
  bool get isOnline => _odooClient != null;
}
