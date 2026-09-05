import 'odoo_crud_api.dart';
import 'odoo_transport.dart';

/// Odoo 19/20 JSON-2 implementation of [OdooTransport].
///
/// The underlying [OdooCrudApi] owns JSON-2 request construction, context,
/// error handling and authentication. This adapter keeps those HTTP details
/// out of feature code while preserving the existing CRUD API.
final class Json2Transport implements OdooTransport {
  final OdooCrudApi _crudApi;

  Json2Transport({required OdooCrudApi crudApi}) : _crudApi = crudApi;

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic> domain = const [],
    int? limit,
    int? offset,
    String? order,
  }) => _crudApi.searchRead(
    model: model,
    fields: fields,
    domain: domain,
    limit: limit,
    offset: offset,
    order: order,
  );

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => _crudApi.call(model: model, method: method, ids: ids, kwargs: kwargs);
}
