import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Generic mock for OdooModelManager.
///
/// Use this when you need to mock a specific model's manager.
/// For specific models, consider creating dedicated mocks.
class MockOdooModelManager<T> extends Mock implements OdooModelManager<T> {
  MockOdooModelManager();
}

/// Helper class for setting up OdooModelManager mock behaviors.
class ModelManagerMockHelper<T> {
  final MockOdooModelManager<T> manager;

  ModelManagerMockHelper(this.manager);

  /// Setup readLocal to return a specific record.
  void setupReadLocal(int id, T? record) {
    when(() => manager.readLocal(id)).thenAnswer((_) async => record);
  }

  /// Setup readLocalByUuid to return a specific record.
  void setupReadLocalByUuid(String uuid, T? record) {
    when(() => manager.readLocalByUuid(uuid)).thenAnswer((_) async => record);
  }

  /// Setup searchLocal to return records.
  void setupSearchLocal(List<T> records) {
    when(() => manager.searchLocal(
          domain: any(named: 'domain'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          orderBy: any(named: 'orderBy'),
        )).thenAnswer((_) async => records);
  }

  /// Setup countLocal to return a count.
  void setupCountLocal(int count) {
    when(() => manager.countLocal(domain: any(named: 'domain')))
        .thenAnswer((_) async => count);
  }

  /// Setup create to return an ID.
  void setupCreate(int returnId) {
    when(() => manager.create(any())).thenAnswer((_) async => returnId);
  }

  /// Setup update to succeed.
  void setupUpdate({bool success = true}) {
    when(() => manager.update(any())).thenAnswer((_) async => success);
  }

  /// Setup delete to succeed.
  void setupDelete({bool success = true}) {
    when(() => manager.delete(any())).thenAnswer((_) async => success);
  }

  /// Setup upsertLocal.
  void setupUpsertLocal() {
    when(() => manager.upsertLocal(any())).thenAnswer((_) async {});
  }

  /// Setup deleteLocal.
  void setupDeleteLocal() {
    when(() => manager.deleteLocal(any())).thenAnswer((_) async {});
  }

  /// Setup getUnsyncedRecords.
  void setupGetUnsyncedRecords(List<T> records) {
    when(() => manager.getUnsyncedRecords()).thenAnswer((_) async => records);
  }

  /// Setup callOdooAction to return a value.
  void setupCallOdooAction({
    required String action,
    dynamic returnValue,
  }) {
    when(() => manager.callOdooAction(
          any(),
          action,
          kwargs: any(named: 'kwargs'),
        )).thenAnswer((_) async => returnValue);
  }

  /// Setup isOnline property.
  void setupIsOnline(bool isOnline) {
    when(() => manager.isOnline).thenReturn(isOnline);
  }
}

/// Fake for ValidationException registration.
class FakeValidationException extends Fake implements ValidationException {}
