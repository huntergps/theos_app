import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Mock implementation of OdooClient for testing.
class MockOdooClient extends Mock implements OdooClient {
  /// Default constructor creates a basic mock.
  MockOdooClient();

  /// Create a mock that simulates online state.
  factory MockOdooClient.online() {
    final mock = MockOdooClient();
    when(() => mock.isConfigured).thenReturn(true);
    return mock;
  }

  /// Create a mock that simulates offline state.
  factory MockOdooClient.offline() {
    final mock = MockOdooClient();
    when(() => mock.isConfigured).thenReturn(false);
    return mock;
  }
}

/// Helper class for setting up common OdooClient mock behaviors.
class OdooClientMockHelper {
  final MockOdooClient client;

  OdooClientMockHelper(this.client);

  /// Setup successful create operation.
  void setupCreate({
    required String model,
    required int returnId,
  }) {
    when(() => client.create(
          model: model,
          values: any(named: 'values'),
        )).thenAnswer((_) async => returnId);
  }

  /// Setup successful read operation.
  void setupRead({
    required String model,
    required List<Map<String, dynamic>> returnData,
  }) {
    when(() => client.read(
          model: model,
          ids: any(named: 'ids'),
          fields: any(named: 'fields'),
        )).thenAnswer((_) async => returnData);
  }

  /// Setup successful searchRead operation.
  void setupSearchRead({
    required String model,
    required List<Map<String, dynamic>> returnData,
  }) {
    when(() => client.searchRead(
          model: model,
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        )).thenAnswer((_) async => returnData);
  }

  /// Setup successful write operation.
  void setupWrite({
    required String model,
    bool success = true,
  }) {
    when(() => client.write(
          model: model,
          ids: any(named: 'ids'),
          values: any(named: 'values'),
        )).thenAnswer((_) async => success);
  }

  /// Setup successful unlink operation.
  void setupUnlink({
    required String model,
    bool success = true,
  }) {
    when(() => client.unlink(
          model: model,
          ids: any(named: 'ids'),
        )).thenAnswer((_) async => success);
  }

  /// Setup successful searchCount operation.
  void setupSearchCount({
    required String model,
    required int count,
  }) {
    when(() => client.searchCount(
          model: model,
          domain: any(named: 'domain'),
        )).thenAnswer((_) async => count);
  }

  /// Setup successful call (action) operation.
  void setupCall({
    required String model,
    required String method,
    dynamic returnValue,
  }) {
    when(() => client.call(
          model: model,
          method: method,
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        )).thenAnswer((_) async => returnValue);
  }

  /// Setup error for any operation.
  void setupError({
    required String model,
    required Exception error,
  }) {
    when(() => client.create(
          model: model,
          values: any(named: 'values'),
        )).thenThrow(error);

    when(() => client.read(
          model: model,
          ids: any(named: 'ids'),
          fields: any(named: 'fields'),
        )).thenThrow(error);

    when(() => client.write(
          model: model,
          ids: any(named: 'ids'),
          values: any(named: 'values'),
        )).thenThrow(error);
  }
}

/// Fake values for mocktail registration.
class FakeOdooClientConfig extends Fake implements OdooClientConfig {}
