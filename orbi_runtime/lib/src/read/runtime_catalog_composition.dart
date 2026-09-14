import '../session/session_runtime.dart';
import '../storage/runtime_database_owner.dart';
import '../sync/catalog_sync.dart';
import '../sync/operations_sync_job.dart';
import '../sync/sync_job.dart';
import 'json2_read_adapters.dart';
import 'local_catalog_adapters.dart';
import 'runtime_catalog_availability.dart';

/// Runtime-owned catalog synchronization graph. UI layers consume the stores
/// and jobs; they do not receive credentials or construct a second client.
final class RuntimeCatalogComposition {
  final SessionActivation activation;
  final RuntimeDatabaseOwner owner;
  final Map<String, SyncJob> jobs;
  final Map<String, DriftCatalogStore<Map<String, dynamic>>> stores;

  /// El lector que ya se construyó para los catálogos, expuesto para que el
  /// sondeo del servidor lo reutilice en vez de fabricarse otro cliente.
  final Json2ReadPort reader;

  /// Qué catálogos puede correr esta instancia de Odoo, según evidencia real
  /// (E02). Expuesto para que `/sync` pinte los `unsupported` aparte y para
  /// que "Forzar Sync Completo" pueda pedir un sondeo nuevo con
  /// [RuntimeCatalogAvailability.invalidate].
  final RuntimeCatalogAvailability availability;

  RuntimeCatalogComposition._({
    required this.activation,
    required this.owner,
    required this.jobs,
    required this.stores,
    required this.reader,
    required this.availability,
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
    // "Mis preferencias" (theos_panel/lib/features/account): usuario y
    // partner de la sesión activa. Una instancia por composición — nunca un
    // singleton global (ADR-03, docs/orbi_panel/ARCHITECTURE.md) — porque el
    // guard sólo tiene sentido atado al scope de ESTA activación.
    final accountLoader = RuntimeAccountLoader(effectiveReader);
    final partnerGuard = CurrentAccountPartnerGuard();
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
      'lang': RuntimeCatalogs.languages,
      'country': RuntimeCatalogs.countries,
      'countryState': RuntimeCatalogs.countryStates,
    };
    // Ver E02: qué de estos 17 corre de verdad lo decide el servidor, no
    // esta lista. `groups`/`currentUser`/`currentUserPartner` quedan fuera a
    // propósito — sus modelos (`res.groups`, `res.users`, `res.partner`)
    // siempre existen; sólo estos 17 catálogos "de más" son los que un
    // servidor recortado (Mepriga) puede no tener.
    final availability = RuntimeCatalogAvailability(effectiveReader, specs: specs);
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
      'lang': writeLanguageRecords,
      'country': writeCountryRecords,
      'countryState': writeCountryStateRecords,
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
      'lang': readLanguageRecords,
      'country': readCountryRecords,
      'countryState': readCountryStateRecords,
    };
    final stores = <String, DriftCatalogStore<Map<String, dynamic>>>{};
    final jobs = <String, SyncJob>{};
    // La cola de operaciones offline (ventas, cobros pendientes) va PRIMERO
    // en el grafo. `SyncCoordinatorImpl` ejecuta `_jobs` en el orden de
    // inserción de este mapa (sync_coordinator_impl.dart:120), así que
    // insertarla antes que los catálogos es lo que hace que drene antes de
    // sincronizar catálogos — el contrato documentado en CLAUDE.md. Medido
    // el 13-sep-2026: antes de este cambio, "operations" se insertaba al
    // final y corría DESPUÉS de los 14 catálogos.
    if (operationsJob != null) {
      jobs[operationsJob.id] = operationsJob;
    }
    for (final entry in specs.entries) {
      final store = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: entry.key,
        writeRows: writers[entry.key]!,
        readRows: readers[entry.key],
        // Sólo 'partner' (customers) puede alcanzar al partner de la sesión
        // activa por su barrido de salida de dominio (`customer_rank > 0`
        // negado) — ver CurrentAccountPartnerGuard en
        // local_catalog_adapters.dart y la prueba que reprodujo el borrado.
        neverDeleteIds: entry.key == 'partner'
            ? () => partnerGuard.protectedIds
            : null,
      );
      stores[entry.key] = store;
      jobs[entry.key] = CatalogSyncJob(
        id: 'catalog:${entry.key}',
        store: store,
        load: catalogAvailabilityLoader(
          availability: availability,
          key: entry.key,
          loader: loader,
        ),
      );
    }

    // 'groups' no tiene RuntimeCatalogDescriptor estático: sus campos se
    // resuelven con `fields_get` en tiempo de ejecución — `category_id` ya
    // no existe en Odoo 19/20 (reemplazado por `privilege_id`, ver la nota
    // en RuntimeCatalogLoader.selfDescribingLoader).
    final groupsStore = DriftCatalogStore<Map<String, dynamic>>(
      owner: owner,
      name: 'groups',
      writeRows: writeGroupRecords,
      readRows: readGroupRecords,
    );
    stores['groups'] = groupsStore;
    jobs['groups'] = CatalogSyncJob(
      id: 'catalog:groups',
      store: groupsStore,
      load: loader.selfDescribingLoader(
        key: 'groups',
        model: 'res.groups',
        candidateFields: const [
          'name',
          'full_name',
          'category_id',
          'write_date',
        ],
      ),
    );

    // Usuario y partner de la sesión activa. Un solo registro cada uno, sin
    // paginación (ver RuntimeAccountLoader) — por eso no pasan por `specs`.
    final currentUserStore = DriftCatalogStore<Map<String, dynamic>>(
      owner: owner,
      name: 'currentUser',
      writeRows: writeCurrentUserRecords,
    );
    stores['currentUser'] = currentUserStore;
    jobs['currentUser'] = CatalogSyncJob(
      id: 'catalog:currentUser',
      store: currentUserStore,
      load: accountLoader.userLoader,
    );

    final currentUserPartnerStore = DriftCatalogStore<Map<String, dynamic>>(
      owner: owner,
      name: 'currentUserPartner',
      writeRows: writeCurrentUserPartnerRecords(partnerGuard),
    );
    stores['currentUserPartner'] = currentUserPartnerStore;
    jobs['currentUserPartner'] = CatalogSyncJob(
      id: 'catalog:currentUserPartner',
      store: currentUserPartnerStore,
      load: accountLoader.partnerLoader,
    );

    return RuntimeCatalogComposition._(
      activation: activation,
      owner: owner,
      jobs: jobs,
      stores: stores,
      reader: effectiveReader,
      availability: availability,
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
