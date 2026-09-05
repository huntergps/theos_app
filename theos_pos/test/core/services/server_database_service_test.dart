import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/session/session_scope.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';
import 'package:theos_pos/core/services/platform/server_database_service.dart';
import 'package:theos_pos/core/services/platform/device_service.dart';

void main() {
  test('SessionScope provides the only authenticated database name', () {
    final scope = SessionScope(
      serverUrl: 'https://erp.example.com',
      database: 'main',
      userId: 7,
    );
    expect(scope.driftDatabaseName, startsWith('theos_pos_'));
    expect(scope.driftDatabaseName, contains('_u7_'));
    expect(scope.driftDatabaseName, isNot(contains('api')));
  });

  test('server lock identifiers remain stable', () {
    final service = AppServerDatabaseService(createDeviceService());
    final server = ServerConfig(
      name: 'ERP',
      url: 'https://erp.example.com',
      database: 'main',
    );
    expect(service.getServerIdentifier(server), isNotEmpty);
    expect(
      service.getServerIdentifier(server),
      service.getServerIdentifier(server),
    );
  });
}
