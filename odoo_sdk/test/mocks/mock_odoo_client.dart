import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Mock implementation of OdooClient for testing.
///
/// Usage:
/// ```dart
/// final mockClient = MockOdooClient();
///
/// // Setup responses
/// when(() => mockClient.searchRead(
///   model: 'product.product',
///   fields: any(named: 'fields'),
///   domain: any(named: 'domain'),
/// )).thenAnswer((_) async => [
///   {'id': 1, 'name': 'Product 1'},
/// ]);
///
/// // Use in manager
/// manager.initialize(client: mockClient, ...);
/// ```
class MockOdooClient extends Mock implements OdooClient {}

/// Mock implementation of OdooCrudApi for testing CRUD operations.
class MockOdooCrudApi extends Mock implements OdooCrudApi {}

/// Mock implementation of OdooHttpClient for low-level HTTP testing.
class MockOdooHttpClient extends Mock implements OdooHttpClient {}

/// Mock CancelToken for testing cancellation.
class MockCancelToken extends Mock implements CancelToken {}

/// Fake classes for mocktail registerFallbackValue
class FakeCancelToken extends Fake implements CancelToken {}

/// Setup function to register all fallback values.
///
/// Call this in setUpAll() before using mocks:
/// ```dart
/// setUpAll(() {
///   registerOdooClientFallbacks();
/// });
/// ```
void registerOdooClientFallbacks() {
  registerFallbackValue(FakeCancelToken());
  registerFallbackValue(<dynamic>[]);
  registerFallbackValue(<String, dynamic>{});
  registerFallbackValue(<String>[]);
  registerFallbackValue(<int>[]);
}

/// Extension methods for common mock setups.
extension MockOdooClientSetup on MockOdooClient {
  /// Configure mock to return true for isConfigured.
  void setupConfigured() {
    when(() => isConfigured).thenReturn(true);
    when(() => apiKey).thenReturn('test-api-key');
  }

  /// Configure mock to return false for isConfigured.
  void setupNotConfigured() {
    when(() => isConfigured).thenReturn(false);
  }

  /// Setup a successful searchRead response.
  void setupSearchRead({
    required String model,
    required List<Map<String, dynamic>> results,
    List<dynamic>? domain,
    List<String>? fields,
    int? limit,
    int? offset,
    String? order,
  }) {
    when(() => searchRead(
          model: model,
          fields: fields ?? any(named: 'fields'),
          domain: domain ?? any(named: 'domain'),
          limit: limit ?? any(named: 'limit'),
          offset: offset ?? any(named: 'offset'),
          order: order ?? any(named: 'order'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => results);
  }

  /// Setup a successful read response.
  void setupRead({
    required String model,
    required List<int> ids,
    required List<Map<String, dynamic>> results,
    List<String>? fields,
  }) {
    when(() => read(
          model: model,
          ids: ids,
          fields: fields ?? any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => results);
  }

  /// Setup a successful create response.
  void setupCreate({
    required String model,
    required int resultId,
    Map<String, dynamic>? values,
  }) {
    when(() => create(
          model: model,
          values: values ?? any(named: 'values'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => resultId);
  }

  /// Setup a successful write response.
  void setupWrite({
    required String model,
    List<int>? ids,
    Map<String, dynamic>? values,
    bool result = true,
  }) {
    when(() => write(
          model: model,
          ids: ids ?? any(named: 'ids'),
          values: values ?? any(named: 'values'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => result);
  }

  /// Setup a successful unlink response.
  void setupUnlink({
    required String model,
    List<int>? ids,
    bool result = true,
  }) {
    when(() => unlink(
          model: model,
          ids: ids ?? any(named: 'ids'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => result);
  }

  /// Setup a successful searchCount response.
  void setupSearchCount({
    required String model,
    required int count,
    List<dynamic>? domain,
  }) {
    when(() => searchCount(
          model: model,
          domain: domain ?? any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        )).thenAnswer((_) async => count);
  }

  /// Setup a network error for any operation.
  void setupNetworkError({String message = 'Network error'}) {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
      message: message,
    );

    when(() => searchRead(
          model: any(named: 'model'),
          fields: any(named: 'fields'),
          domain: any(named: 'domain'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(error);

    when(() => read(
          model: any(named: 'model'),
          ids: any(named: 'ids'),
          fields: any(named: 'fields'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(error);

    when(() => create(
          model: any(named: 'model'),
          values: any(named: 'values'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(error);

    when(() => write(
          model: any(named: 'model'),
          ids: any(named: 'ids'),
          values: any(named: 'values'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(error);

    when(() => unlink(
          model: any(named: 'model'),
          ids: any(named: 'ids'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(error);
  }

  /// Setup an Odoo server error.
  void setupServerError({
    int statusCode = 500,
    String message = 'Internal Server Error',
  }) {
    final error = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.badResponse,
      response: Response(
        requestOptions: RequestOptions(path: '/'),
        statusCode: statusCode,
        statusMessage: message,
      ),
    );

    when(() => searchRead(
          model: any(named: 'model'),
          fields: any(named: 'fields'),
          domain: any(named: 'domain'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
          cancelToken: any(named: 'cancelToken'),
        )).thenThrow(error);
  }
}
