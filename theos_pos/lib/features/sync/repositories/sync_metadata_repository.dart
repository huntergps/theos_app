/// SyncMetadataRepository - Metadata de sincronización y limpieza de tablas
///
/// Extraído de CatalogSyncRepository (Fase E2): guarda/lee el estado de sync
/// por modelo y limpia tablas de catálogo.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'qweb_template_sync_repository.dart';

/// Repository for sync metadata (last-sync timestamps, per-model sync info)
/// and catalog table clearing.
class SyncMetadataRepository {
  final AppDatabase _appDb;
  final QwebTemplateSyncRepository _qwebTemplateSync;

  SyncMetadataRepository({
    required this._appDb,
    required this._qwebTemplateSync,
  });

  /// Get sync info for a specific model
  Future<SyncModelInfo> getModelSyncInfo(String modelName) async {
    try {
      final metadata = await (_appDb.select(
        _appDb.syncMetadata,
      )..where((t) => t.key.equals('model_$modelName'))).getSingleOrNull();
      if (metadata != null) {
        final json = jsonDecode(metadata.value) as Map<String, dynamic>;
        return SyncModelInfo.fromJson(json);
      }
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error getting model sync info for $modelName',
        e,
      );
    }
    return SyncModelInfo(modelName: modelName);
  }

  /// Save sync info for a specific model
  Future<void> saveModelSyncInfo(SyncModelInfo info) async {
    try {
      await _appDb
          .into(_appDb.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: Value('model_${info.modelName}'),
              value: Value(jsonEncode(info.toJson())),
            ),
          );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error saving model sync info', e);
    }
  }

  /// Clear error message for a specific model, allowing it to sync again
  Future<void> clearModelSyncError(String modelName) async {
    try {
      final info = await getModelSyncInfo(modelName);
      if (info.errorMessage != null) {
        await saveModelSyncInfo(info.copyWith(errorMessage: null));
        logger.d('[CatalogSync]', 'Cleared error for model: $modelName');
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing model sync error', e);
    }
  }

  /// Get sync info for all models
  Future<Map<String, SyncModelInfo>> getAllModelSyncInfo() async {
    final results = <String, SyncModelInfo>{};
    try {
      final rows = await (_appDb.select(
        _appDb.syncMetadata,
      )..where((t) => t.key.like('model_%'))).get();
      for (final row in rows) {
        final modelName = row.key.replaceFirst('model_', '');
        final json = jsonDecode(row.value) as Map<String, dynamic>;
        results[modelName] = SyncModelInfo.fromJson(json);
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error getting all model sync info', e);
    }
    return results;
  }

  /// Clear sync info for a specific model
  Future<void> clearModelSyncInfo(String modelName) async {
    try {
      await (_appDb.delete(
        _appDb.syncMetadata,
      )..where((t) => t.key.equals('model_$modelName'))).go();
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing model sync info', e);
    }
  }

  /// Clear all model sync info
  Future<void> clearAllModelSyncInfo() async {
    try {
      await (_appDb.delete(
        _appDb.syncMetadata,
      )..where((t) => t.key.like('model_%'))).go();
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing all model sync info', e);
    }
  }

  /// Clear all catalog tables
  Future<Map<String, int>> clearAllCatalogTables() async {
    final results = <String, int>{};

    try {
      results['products'] = await clearCatalogTable('product.product');
      results['categories'] = await clearCatalogTable('product.category');
      results['taxes'] = await clearCatalogTable('account.tax');
      results['uom'] = await clearCatalogTable('uom.uom');
      results['productUom'] = await clearCatalogTable('product.uom');
      results['pricelists'] = await clearCatalogTable('product.pricelist');
      results['pricelistItems'] = await clearCatalogTable(
        'product.pricelist.item',
      );
      results['paymentTerms'] = await clearCatalogTable('account.payment.term');
      results['partners'] = await clearCatalogTable('res.partner');
      results['saleOrders'] = await clearCatalogTable('sale.order');
      results['saleOrderLines'] = await clearCatalogTable('sale.order.line');
      results['users'] = await clearCatalogTable('res.users');
      results['warehouses'] = await clearCatalogTable('stock.warehouse');
      results['teams'] = await clearCatalogTable('crm.team');
      results['fiscalPositions'] = await clearCatalogTable(
        'account.fiscal.position',
      );
      results['fiscalPositionTaxes'] = await clearCatalogTable(
        'account.fiscal.position.tax',
      );
      results['journals'] = await clearCatalogTable('account.journal');
      results['collectionConfigs'] = await clearCatalogTable(
        'collection.config',
      );

      // Clear sync metadata
      await clearAllModelSyncInfo();

      logger.i('[CatalogSync] All catalog tables cleared: $results');
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing catalog tables', e);
    }

    return results;
  }

  /// Clear a specific catalog table
  Future<int> clearCatalogTable(String modelName) async {
    try {
      switch (modelName) {
        case 'product.product':
          return await _appDb.delete(_appDb.productProduct).go();
        case 'product.category':
          return await _appDb.delete(_appDb.productCategory).go();
        case 'account.tax':
          return await _appDb.delete(_appDb.accountTax).go();
        case 'uom.uom':
          return await _appDb.delete(_appDb.uomUom).go();
        case 'product.uom':
          return await _appDb.delete(_appDb.productUom).go();
        case 'product.pricelist':
          return await _appDb.delete(_appDb.productPricelist).go();
        case 'product.pricelist.item':
          return await _appDb.delete(_appDb.productPricelistItem).go();
        case 'account.payment.term':
          return await _appDb.delete(_appDb.accountPaymentTerm).go();
        case 'res.partner':
          return await _appDb.delete(_appDb.resPartner).go();
        case 'sale.order':
          return await _appDb.delete(_appDb.saleOrder).go();
        case 'sale.order.line':
          return await _appDb.delete(_appDb.saleOrderLine).go();
        case 'res.users':
          return await _appDb.delete(_appDb.resUsers).go();
        case 'stock.warehouse':
          return await _appDb.delete(_appDb.stockWarehouse).go();
        case 'crm.team':
          return await _appDb.delete(_appDb.crmTeam).go();
        case 'account.fiscal.position':
          return await _appDb.delete(_appDb.accountFiscalPosition).go();
        case 'account.fiscal.position.tax':
          return await _appDb.delete(_appDb.accountFiscalPositionTax).go();
        case 'res.currency':
          return await _appDb.delete(_appDb.resCurrency).go();
        case 'decimal.precision':
          return await _appDb.delete(_appDb.decimalPrecision).go();
        case 'account.journal':
          return await _appDb.delete(_appDb.accountJournal).go();
        case 'collection.config':
          return await _appDb.delete(_appDb.collectionConfig).go();
        case 'ir.ui.view':
          await _qwebTemplateSync.clearAllTemplates();
          return 0; // clearAll doesn't return count
        default:
          logger.w('[CatalogSync] Unknown model for clearing: $modelName');
          return 0;
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing table $modelName', e);
      return 0;
    }
  }
}
