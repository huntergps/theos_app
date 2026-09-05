import 'package:dio/dio.dart' show CancelToken;

import 'client/odoo_http_client.dart';
import 'client/odoo_crud_api.dart';
import 'client/json2_transport.dart';
import 'client/odoo_transport.dart';
import 'odoo_exception.dart';
import 'odoo_version.dart';

/// Unified Odoo client for JSON-2 API (Odoo 19.0+).
///
/// This is the **main entry point** for all Odoo operations, providing:
/// - **CRUD operations** via [crud] or convenience methods
/// - **HTTP client access** via [http] (for advanced use cases)
///
/// ## Basic Usage
///
/// ```dart
/// final client = OdooClient(
///   config: OdooClientConfig(
///     baseUrl: 'https://odoo.example.com',
///     apiKey: 'your-api-key',
///     database: 'your-db',
///   ),
/// );
///
/// // Search and read records
/// final partners = await client.searchRead(
///   model: 'res.partner',
///   fields: ['name', 'email', 'phone'],
///   domain: [['customer_rank', '>', 0]],
///   limit: 50,
///   order: 'name asc',
/// );
///
/// // Create a new record
/// final newId = await client.create(
///   model: 'res.partner',
///   values: {'name': 'New Customer', 'email': 'new@example.com'},
/// );
///
/// // Update existing records
/// await client.write(
///   model: 'res.partner',
///   ids: [newId!],
///   values: {'phone': '+1234567890'},
/// );
///
/// // Delete records
/// await client.unlink(model: 'res.partner', ids: [newId]);
/// ```
///
/// ## Batch Operations
///
/// For better performance when handling multiple records:
///
/// ```dart
/// // Create multiple records in one call
/// final ids = await client.crud.createBatch(
///   model: 'product.product',
///   valuesList: [
///     {'name': 'Product A', 'list_price': 10.0},
///     {'name': 'Product B', 'list_price': 20.0},
///     {'name': 'Product C', 'list_price': 30.0},
///   ],
/// );
///
/// // Execute mixed operations
/// final result = await client.crud.executeBatch(
///   model: 'res.partner',
///   creates: [{'name': 'New Partner'}],
///   updates: [BatchUpdate(ids: [1, 2], values: {'active': true})],
///   deletes: [99, 100],
/// );
/// print('Created: ${result.createdIds}, Success: ${result.success}');
/// ```
///
/// ## Custom Method Calls
///
/// For calling custom Odoo methods:
///
/// ```dart
/// // Call a model method
/// final result = await client.call(
///   model: 'sale.order',
///   method: 'action_confirm',
///   ids: [orderId],
/// );
///
/// // Call with keyword arguments
/// final report = await client.call(
///   model: 'ir.actions.report',
///   method: 'render_qweb_pdf',
///   kwargs: {'report_name': 'sale.report_saleorder', 'res_ids': [orderId]},
/// );
/// ```
///
/// ## Configuration Options
///
/// ```dart
/// final client = OdooClient(
///   config: OdooClientConfig(
///     baseUrl: 'https://odoo.example.com',
///     apiKey: 'your-api-key',
///     database: 'production',
///     timeout: Duration(seconds: 30),
///     enableRetry: true,
///     retryConfig: RetryConfig(
///       maxRetries: 3,
///       initialDelay: Duration(seconds: 1),
///       onRetry: (attempt, delay, error) {
///         print('Retry $attempt after $delay');
///       },
///     ),
///   ),
/// );
/// ```
///
/// ## Error Handling
///
/// ```dart
/// try {
///   await client.searchRead(model: 'invalid.model', fields: ['id']);
/// } on OdooAuthenticationException {
///   print('Invalid API key');
/// } on OdooAccessDeniedException {
///   print('No permission for this model');
/// } on OdooNotFoundException {
///   print('Model not found');
/// } on OdooConnectionException {
///   print('Network error - consider offline mode');
/// } on OdooException catch (e) {
///   print('Odoo error: ${e.message}');
/// }
/// ```
class OdooClient {
  final OdooHttpClient _httpClient;
  final OdooCrudApi _crudApi;
  late final OdooTransport _transport = Json2Transport(crudApi: _crudApi);
  OdooVersion _version = OdooVersion.unknown;
  int _credentialsGeneration = 0;

  /// Field metadata discovered from the current server/database.
  ///
  /// Values are futures so concurrent callers for one model share a single
  /// read-only request. Failed requests are removed by [getModelFields] and
  /// are therefore never cached.
  final Map<String, Future<Map<String, dynamic>>> _modelFieldsCache = {};

  OdooClient._({
    required OdooHttpClient httpClient,
    required OdooCrudApi crudApi,
  }) : _httpClient = httpClient,
       _crudApi = crudApi;

  /// Create a new OdooClient with the given configuration
  factory OdooClient({required OdooClientConfig config}) {
    final httpClient = OdooHttpClient(config: config);
    final crudApi = OdooCrudApi(httpClient: httpClient);
    return OdooClient._(httpClient: httpClient, crudApi: crudApi);
  }

  /// Low-level HTTP client (for advanced use cases)
  OdooHttpClient get http => _httpClient;

  /// CRUD operations (search_read, read, write, create, unlink)
  OdooCrudApi get crud => _crudApi;

  /// Stable model-operation contract for feature code.
  ///
  /// This keeps JSON-2 URLs and HTTP implementation details inside the SDK.
  /// Existing callers can continue using [crud] and the convenience methods.
  OdooTransport get transport => _transport;

  /// The detected Odoo server version. Call [fetchVersion] first.
  OdooVersion get version => _version;

  /// Detect the Odoo server version by reading the base module version.
  /// Returns the detected version and caches it.
  ///
  /// Reintenta internamente hasta [maxAttempts] veces (con [retryDelay] entre
  /// cada intento) para absorber fallas transitorias de red durante el
  /// arranque. Si todos los intentos fallan, [version] queda en
  /// [OdooVersion.unknown] (o conserva el último valor detectado con éxito).
  ///
  /// IMPORTANTE: mientras la versión sea `unknown`, los flags derivados
  /// (`hasBankModel`, `hasStockScrapModel`, `hasLegacyUomFields`) asumen el
  /// comportamiento de Odoo 19.1 por defecto — ver [OdooVersion.hasBankModel].
  /// El llamador (p.ej. `AppInitializer`) debe reintentar más tarde cuando la
  /// conectividad se restablezca.
  Future<OdooVersion> fetchVersion({
    int maxAttempts = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final generation = _credentialsGeneration;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final result = await searchRead(
          model: 'ir.module.module',
          fields: ['latest_version'],
          domain: [
            ['name', '=', 'base'],
          ],
          limit: 1,
        );
        if (result.isNotEmpty) {
          final versionStr = result.first['latest_version']?.toString() ?? '';
          if (generation == _credentialsGeneration) {
            _version = OdooVersion.parse(versionStr);
          }
        }
        return _version;
      } catch (_) {
        // Si no es el último intento, esperamos un poco y reintentamos
        // (falla transitoria de red durante el arranque).
        if (attempt < maxAttempts) {
          await Future.delayed(retryDelay);
        }
        // Si es el último intento, dejamos _version como estaba (unknown
        // si nunca se detectó con éxito antes).
      }
    }
    return _version;
  }

  /// Current configuration
  OdooClientConfig get config => _httpClient.config;

  /// Whether the client has valid credentials
  bool get isConfigured => _httpClient.isConfigured;

  /// API key (for external use like WebSocket)
  String get apiKey => _httpClient.config.apiKey;

  /// Update client credentials
  void setCredentials(String baseUrl, String apiKey, String? database) {
    _httpClient.updateConfig(
      OdooClientConfig(baseUrl: baseUrl, apiKey: apiKey, database: database),
    );
    // Version and field metadata belong to a server/database identity. Never
    // let either leak across a credential switch.
    _version = OdooVersion.unknown;
    _credentialsGeneration++;
    _modelFieldsCache.clear();
  }

  // ============================================================
  // Convenience methods that delegate to components
  // These maintain API compatibility with the original OdooProvider
  // All methods support optional CancelToken for request cancellation
  // ============================================================

  /// Generic Odoo method call.
  ///
  /// [ids] selects the recordset, [kwargs] contains the method's named
  /// parameters, and [context] contains Odoo execution context. These are
  /// separate parameters in the JSON-2 HTTP contract.
  ///
  /// Pass a [cancelToken] to allow cancelling long-running operations.
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    @Deprecated(
      'El dispatcher JSON-2 estándar de Odoo (/json/2/<model>/<method>) NO '
      'trata "args" como argumentos posicionales: el body se pasa como '
      '**kwargs al método destino, así que "args" termina siendo un kwarg '
      'literal llamado "args" y falla con "unexpected keyword argument '
      '\'args\'" salvo que el método acepte ese nombre. Usa kwargs: {} con '
      'los nombres reales de los parámetros de Python. La única excepción '
      'válida es cuando el propio servidor expone un controller HTTP custom '
      'que lee "args" manualmente del body (ver '
      'product.template/get_stock_by_warehouse en '
      'l10n_ec_collection_box_pos).',
    )
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
    CancelToken? cancelToken,
  }) => _crudApi.call(
    model: model,
    method: method,
    ids: ids,
    args: args,
    kwargs: kwargs,
    context: context,
    cancelToken: cancelToken,
  );

  /// Search and read records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
    CancelToken? cancelToken,
  }) => _crudApi.searchRead(
    model: model,
    fields: fields,
    domain: domain,
    limit: limit,
    offset: offset,
    order: order,
    cancelToken: cancelToken,
  );

  /// Count records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<int?> searchCount({
    required String model,
    List<dynamic>? domain,
    CancelToken? cancelToken,
  }) => _crudApi.searchCount(
    model: model,
    domain: domain,
    cancelToken: cancelToken,
  );

  /// Get modified records since timestamp.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> getModifiedSince({
    required String model,
    required List<String> fields,
    required DateTime lastSync,
    List<dynamic>? additionalDomain,
    CancelToken? cancelToken,
  }) => _crudApi.getModifiedSince(
    model: model,
    fields: fields,
    lastSync: lastSync,
    additionalDomain: additionalDomain,
    cancelToken: cancelToken,
  );

  /// Read records by IDs.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<List<Map<String, dynamic>>> read({
    required String model,
    required List<int> ids,
    required List<String> fields,
    CancelToken? cancelToken,
  }) => _crudApi.read(
    model: model,
    ids: ids,
    fields: fields,
    cancelToken: cancelToken,
  );

  /// Update records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<bool> write({
    required String model,
    required List<int> ids,
    required Map<String, dynamic> values,
    CancelToken? cancelToken,
  }) => _crudApi.write(
    model: model,
    ids: ids,
    values: values,
    cancelToken: cancelToken,
  );

  /// Create a record.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<int?> create({
    required String model,
    required Map<String, dynamic> values,
    CancelToken? cancelToken,
  }) => _crudApi.create(model: model, values: values, cancelToken: cancelToken);

  /// Delete records.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<bool> unlink({
    required String model,
    required List<int> ids,
    CancelToken? cancelToken,
  }) => _crudApi.unlink(model: model, ids: ids, cancelToken: cancelToken);

  /// Get field metadata.
  ///
  /// Pass a [cancelToken] to allow cancelling the request.
  Future<Map<String, dynamic>> fieldsGet({
    required String model,
    List<String>? fields,
    List<String>? attributes,
    CancelToken? cancelToken,
  }) => _crudApi.fieldsGet(
    model: model,
    fields: fields,
    attributes: attributes,
    cancelToken: cancelToken,
  );

  /// Return all readable field metadata for [model], cached per client.
  ///
  /// An empty map is a successful, complete response and means that no
  /// fields were returned. Transport/Odoo errors are thrown and are not
  /// cached, so callers can distinguish a failed probe from an absent field.
  /// A model cache always represents the complete metadata discovery.
  Future<Map<String, dynamic>> getModelFields(
    String model, {
    CancelToken? cancelToken,
  }) {
    final cached = _modelFieldsCache[model];
    if (cached != null) return cached;

    final rawRequest = _fetchModelFields(model, cancelToken: cancelToken);
    late Future<Map<String, dynamic>> request;
    request = () async {
      try {
        return await rawRequest;
      } catch (_) {
        _modelFieldsCache.remove(model);
        rethrow;
      }
    }();
    _modelFieldsCache[model] = request;
    return request;
  }

  /// Whether [field] is present on [model].
  ///
  /// Returns `false` only after a successful metadata read proves absence;
  /// failed discovery throws the underlying SDK exception.
  Future<bool> hasField(String model, String field) async {
    final fields = await getModelFields(model);
    return fields.containsKey(field);
  }

  Future<Map<String, dynamic>> _fetchModelFields(
    String model, {
    CancelToken? cancelToken,
  }) async {
    final response = await _crudApi.call(
      model: model,
      method: 'fields_get',
      kwargs: {
        'attributes': ['type', 'string', 'selection', 'relation'],
      },
      cancelToken: cancelToken,
    );
    if (response is Map) return Map<String, dynamic>.from(response);
    throw OdooException(
      message: 'Invalid fields_get response for model $model',
      model: model,
      method: 'fields_get',
    );
  }
}
