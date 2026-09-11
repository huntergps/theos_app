import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localWorkflowCatalogCompositionProvider =
    NotifierProvider<LocalWorkflowCatalogNotifier, RuntimeCatalogComposition?>(
      LocalWorkflowCatalogNotifier.new,
    );

final class LocalWorkflowCatalogNotifier
    extends Notifier<RuntimeCatalogComposition?> {
  @override
  RuntimeCatalogComposition? build() => null;

  void setComposition(RuntimeCatalogComposition? value) => state = value;
}

/// Seeds the real product, partner, and payment-term projections used by the
/// sale editor's reactive catalog controllers. The reader is local and
/// deterministic; no transport, Odoo client, or ERP record is involved.
Future<RuntimeCatalogComposition> seedLocalSaleCatalogs({
  required SessionRuntime runtime,
  required AppScope scope,
}) async {
  final active = runtime.active;
  if (active == null || active.scope != scope) {
    throw StateError('Local workflow runtime is not activated');
  }
  final composition = RuntimeCatalogComposition(
    activation: active,
    owner: runtime.databaseOwner,
    reader: const _LocalCatalogReader(),
  );
  await composition.stores['product']!.commit(
    scope,
    CatalogBatch(
      records: [
        CatalogRecord(
          uuid: '101',
          value: {
            'id': 101,
            'name': 'Taladro inalámbrico demo',
            'display_name': 'Taladro inalámbrico demo',
            'uom_id': [1, 'Unidad'],
            'taxes_id': <dynamic>[],
            'list_price': 49.90,
            'active': true,
            'sale_ok': true,
          },
        ),
        CatalogRecord(
          uuid: '102',
          value: {
            'id': 102,
            'name': 'Cinta métrica 5 m demo',
            'display_name': 'Cinta métrica 5 m demo',
            'uom_id': [1, 'Unidad'],
            'taxes_id': <dynamic>[],
            'list_price': 6.75,
            'active': true,
            'sale_ok': true,
          },
        ),
        CatalogRecord(
          uuid: '501',
          value: {
            'id': 501,
            'name': 'Botella retornable 600 ml demo',
            'display_name': 'Botella retornable 600 ml demo',
            'uom_id': [1, 'Unidad'],
            'taxes_id': <dynamic>[],
            'list_price': 1.25,
            'active': true,
            'sale_ok': true,
          },
        ),
        CatalogRecord(
          uuid: '502',
          value: {
            'id': 502,
            'name': 'Botella retornable 330 ml demo',
            'display_name': 'Botella retornable 330 ml demo',
            'uom_id': [1, 'Unidad'],
            'taxes_id': <dynamic>[],
            'list_price': 1.10,
            'active': true,
            'sale_ok': true,
          },
        ),
      ],
      cursor: null,
    ),
  );
  await composition.stores['partner']!.commit(
    scope,
    CatalogBatch(
      records: [
        CatalogRecord(
          uuid: '201',
          value: {
            'id': 201,
            'name': 'Comercial Andina (demo)',
            'display_name': 'Comercial Andina (demo)',
            'email': 'compras@demo.invalid',
            'active': true,
          },
        ),
        CatalogRecord(
          uuid: '202',
          value: {
            'id': 202,
            'name': 'Tienda Centro (demo)',
            'display_name': 'Tienda Centro (demo)',
            'email': 'ventas@demo.invalid',
            'active': true,
          },
        ),
      ],
      cursor: null,
    ),
  );
  await composition.stores['paymentTerm']!.commit(
    scope,
    CatalogBatch(
      records: [
        CatalogRecord(
          uuid: '301',
          value: {
            'id': 301,
            'name': 'Contado demo',
            'active': true,
            'sequence': 1,
            'company_id': [1, 'Empresa local'],
          },
        ),
        CatalogRecord(
          uuid: '302',
          value: {
            'id': 302,
            'name': 'Crédito 30 días demo',
            'active': true,
            'sequence': 2,
            'company_id': [1, 'Empresa local'],
          },
        ),
      ],
      cursor: null,
    ),
  );
  return composition;
}

final class _LocalCatalogReader implements Json2ReadPort {
  const _LocalCatalogReader();

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async => const [];
}

/// Seeds the real Envases cache with deterministic, clearly fictitious data.
/// The reader still exercises the runtime's DTO validation and atomic cache
/// write path; its transport is completed locally and never contacts Odoo.
Future<void> seedLocalEnvasesDashboard({
  required SessionRuntime runtime,
  required AppScope scope,
}) async {
  final active = runtime.active;
  if (active == null || active.scope != scope) {
    throw StateError('Local workflow runtime is not activated');
  }
  final company = CompanyContext.forScope(
    scope: scope,
    companyId: 1,
    allowedCompanyIds: const [1],
    capabilityRevision: 1,
  );
  final reader = EnvasesDashboardReader(
    company: company,
    pageSize: 100,
    transport:
        ({
          required String model,
          required List<dynamic> domain,
          required List<String> fields,
          required Map<String, dynamic> context,
          required int limit,
          required int offset,
          required String order,
        }) async => [
          {
            'id': 1001,
            'product_id': [501, 'Botella retornable 600 ml demo'],
            'uom_id': [1, 'Unidad'],
            'company_id': [1, 'Empresa local'],
            'total_propio': 480.0,
            // The panel renders danados as a separate role; total_propio
            // already includes it and must not be recomputed by the UI.
            'en_sede': 320.0,
            'danados': 4.0,
            'en_custodia_cliente': 120.0,
            'en_custodia_proveedor': 12.0,
            'en_transito': 24.0,
          },
          {
            'id': 1002,
            'product_id': [502, 'Botella retornable 330 ml demo'],
            'uom_id': [2, 'Unidad'],
            'company_id': [1, 'Empresa local'],
            'total_propio': 240.0,
            'en_sede': 178.0,
            'danados': 2.0,
            'en_custodia_cliente': 36.0,
            'en_custodia_proveedor': 12.0,
            'en_transito': 12.0,
          },
        ],
  );
  final cache = EnvasesDashboardCache(
    owner: runtime.databaseOwner,
    lease: active.lease,
    company: company,
  );
  await cache.refresh(reader);
}
