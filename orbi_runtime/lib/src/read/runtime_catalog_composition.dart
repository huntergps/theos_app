import '../session/session_runtime.dart';
import '../storage/runtime_database_owner.dart';
import '../sync/catalog_sync.dart';
import '../sync/operations_sync_job.dart';
import '../sync/sync_job.dart';
import 'json2_read_adapters.dart';
import 'local_catalog_adapters.dart';

/// Runtime-owned catalog synchronization graph. UI layers consume the stores
/// and jobs; they do not receive credentials or construct a second client.
final class RuntimeCatalogComposition {
  final SessionActivation activation;
  final RuntimeDatabaseOwner owner;
  final Map<String, SyncJob> jobs;
  final Map<String, DriftCatalogStore<Map<String, dynamic>>> stores;

  RuntimeCatalogComposition._({
    required this.activation,
    required this.owner,
    required this.jobs,
    required this.stores,
  });

  factory RuntimeCatalogComposition({
    required SessionActivation activation,
    required RuntimeDatabaseOwner owner,
    Json2ReadPort? reader,
    OperationsSyncJob? operationsJob,
  }) {
    final client = activation.client;
    if (client == null && reader == null) {
      throw StateError('Catalog sync requires an online client');
    }
    final effectiveReader = reader ?? OdooJson2ReadPort(client!);
    final loader = RuntimeCatalogLoader(effectiveReader);
    final specs = <String, RuntimeCatalogDescriptor>{
      'partner': RuntimeCatalogs.customers,
      'product': RuntimeCatalogs.products,
      'paymentTerm': RuntimeCatalogs.paymentTerms,
      'uom': RuntimeCatalogs.uoms,
      'collectionConfig': RuntimeCatalogs.collectionConfigs,
      'collectionSession': RuntimeCatalogs.collectionSessions,
      'tax': RuntimeCatalogs.taxes,
      'pricelist': RuntimeCatalogs.pricelists,
      'warehouse': RuntimeCatalogs.warehouses,
      'journal': RuntimeCatalogs.journals,
      'cardBrand': RuntimeCatalogs.cardBrands,
      'cardDeadline': RuntimeCatalogs.cardDeadlines,
      'cardLote': RuntimeCatalogs.cardLotes,
      'paymentMethodLine': RuntimeCatalogs.paymentMethodLines,
    };
    final writers = <String, CatalogRowsWriter<Map<String, dynamic>>>{
      'partner': writePartnerRecords,
      'product': writeProductRecords,
      'paymentTerm': writePaymentTermRecords,
      'uom': writeUomRecords,
      'collectionConfig': writeCollectionConfigRecords,
      'collectionSession': writeCollectionSessionRecords,
      'tax': writeTaxRecords,
      'pricelist': writePricelistRecords,
      'warehouse': writeWarehouseRecords,
      'journal': writeJournalRecords,
      'cardBrand': writeCardBrandRecords,
      'cardDeadline': writeCardDeadlineRecords,
      'cardLote': writeCardLoteRecords,
      'paymentMethodLine': writePaymentMethodLineRecords,
    };
    final readers = <String, CatalogRowsReader<Map<String, dynamic>>>{
      'partner': readPartnerRecords,
      'product': readProductRecords,
      'paymentTerm': readPaymentTermRecords,
      'uom': readUomRecords,
      'collectionConfig': readCollectionConfigRecords,
      'collectionSession': readCollectionSessionRecords,
      'tax': readTaxRecords,
      'pricelist': readPricelistRecords,
      'warehouse': readWarehouseRecords,
      'journal': readJournalRecords,
      'cardBrand': readCardBrandRecords,
      'cardDeadline': readCardDeadlineRecords,
      'cardLote': readCardLoteRecords,
      'paymentMethodLine': readPaymentMethodLineRecords,
    };
    final stores = <String, DriftCatalogStore<Map<String, dynamic>>>{};
    final jobs = <String, SyncJob>{};
    for (final entry in specs.entries) {
      final store = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        writeRows: writers[entry.key]!,
        readRows: readers[entry.key],
      );
      stores[entry.key] = store;
      jobs[entry.key] = CatalogSyncJob(
        id: 'catalog:${entry.key}',
        store: store,
        load: loader.loader(entry.value),
      );
    }
    if (operationsJob != null) {
      jobs[operationsJob.id] = operationsJob;
    }
    return RuntimeCatalogComposition._(
      activation: activation,
      owner: owner,
      jobs: jobs,
      stores: stores,
    );
  }

  Future<SyncJobResult> sync(String key) {
    final job = jobs[key];
    if (job == null) throw ArgumentError.value(key, 'key', 'Unknown catalog');
    if (activation.scope != owner.active?.scope ||
        !owner.accepts(activation.lease)) {
      throw StateError('Catalog activation is stale');
    }
    return job.run(activation.scope);
  }

  /// Adds a scope-owned non-catalog job to the same coordinator graph.
  void registerJob(SyncJob job) {
    if (jobs.containsKey(job.id)) {
      throw ArgumentError.value(job.id, 'job', 'Duplicate sync job');
    }
    jobs[job.id] = job;
  }

  SyncJob job(String key) =>
      jobs[key] ?? (throw ArgumentError.value(key, 'key', 'Unknown catalog'));

  DriftCatalogStore<Map<String, dynamic>> store(String key) =>
      stores[key] ?? (throw ArgumentError.value(key, 'key', 'Unknown catalog'));
}
