import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';
import 'package:theos_pos/core/services/platform/server_database_service.dart';
import 'package:theos_pos/core/services/platform/device_service.dart';

void main() {
  group('AppServerDatabaseService', () {
    late AppServerDatabaseService service;
    late DeviceService deviceService;

    setUp(() {
      deviceService = createDeviceService();
      service = AppServerDatabaseService(deviceService);
    });

    group('generateDatabaseName', () {
      test('generates unique name for localhost server', () {
        final server = ServerConfig(
          name: 'Local',
          url: 'http://localhost:8069',
          database: 'empresa_a',
        );

        final dbName = service.generateDatabaseName(server);

        expect(dbName, startsWith('theos_pos_'));
        expect(dbName, contains('localhost'));
        expect(dbName, contains('8069'));
        expect(dbName, contains('empresa_a'));
      });

      test('generates unique name for production server', () {
        final server = ServerConfig(
          name: 'Production',
          url: 'https://erp1.tecnosmart.com.ec',
          database: 'production_db',
        );

        final dbName = service.generateDatabaseName(server);

        expect(dbName, startsWith('theos_pos_'));
        expect(dbName, contains('erp1_tecnosmart_com_ec'));
        expect(dbName, contains('production_db'));
        // No port for standard HTTPS
        expect(dbName.contains('443'), isFalse);
      });

      test('generates different names for different servers', () {
        final server1 = ServerConfig(
          name: 'Server 1',
          url: 'http://localhost:8069',
          database: 'empresa_a',
        );

        final server2 = ServerConfig(
          name: 'Server 2',
          url: 'http://localhost:8070',
          database: 'empresa_b',
        );

        final server3 = ServerConfig(
          name: 'Server 3',
          url: 'https://cloud.odoo.com',
          database: 'empresa_c',
        );

        final dbName1 = service.generateDatabaseName(server1);
        final dbName2 = service.generateDatabaseName(server2);
        final dbName3 = service.generateDatabaseName(server3);

        expect(dbName1, isNot(equals(dbName2)));
        expect(dbName2, isNot(equals(dbName3)));
        expect(dbName1, isNot(equals(dbName3)));
      });

      test('generates same name for same server config', () {
        final server1 = ServerConfig(
          name: 'Server A',
          url: 'http://localhost:8069',
          database: 'test_db',
        );

        final server2 = ServerConfig(
          name: 'Different Name',
          url: 'http://localhost:8069',
          database: 'test_db',
        );

        final dbName1 = service.generateDatabaseName(server1);
        final dbName2 = service.generateDatabaseName(server2);

        // Same URL and database = same DB file (name is cosmetic)
        expect(dbName1, equals(dbName2));
      });

      test('sanitizes special characters in URL and database', () {
        final server = ServerConfig(
          name: 'Test',
          url: 'https://my-server.example.com:8443',
          database: 'db-with-dashes',
        );

        final dbName = service.generateDatabaseName(server);

        // Should only contain alphanumeric and underscores
        expect(dbName, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(dbName, contains('my_server_example_com'));
        expect(dbName, contains('8443'));
      });

      test('handles very long identifiers by truncating', () {
        final server = ServerConfig(
          name: 'Test',
          url: 'https://very-long-subdomain-name-that-goes-on-and-on.example-domain-with-many-parts.com',
          database: 'this_is_a_very_long_database_name_that_exceeds_normal_limits_for_testing',
        );

        final dbName = service.generateDatabaseName(server);

        // Should be truncated to reasonable length
        expect(dbName.length, lessThanOrEqualTo(120));
        expect(dbName, startsWith('theos_pos_'));
      });

      test('includes non-standard ports in identifier', () {
        final server8069 = ServerConfig(
          name: 'Odoo 8069',
          url: 'http://localhost:8069',
          database: 'test',
        );

        final server8070 = ServerConfig(
          name: 'Odoo 8070',
          url: 'http://localhost:8070',
          database: 'test',
        );

        final dbName8069 = service.generateDatabaseName(server8069);
        final dbName8070 = service.generateDatabaseName(server8070);

        expect(dbName8069, contains('8069'));
        expect(dbName8070, contains('8070'));
        expect(dbName8069, isNot(equals(dbName8070)));
      });

      test('excludes standard ports from identifier', () {
        final server80 = ServerConfig(
          name: 'HTTP',
          url: 'http://example.com:80',
          database: 'test',
        );

        final server443 = ServerConfig(
          name: 'HTTPS',
          url: 'https://example.com:443',
          database: 'test',
        );

        final dbName80 = service.generateDatabaseName(server80);
        final dbName443 = service.generateDatabaseName(server443);

        expect(dbName80.contains('_80_'), isFalse);
        expect(dbName443.contains('_443_'), isFalse);
      });
    });

    group('getServerIdentifier', () {
      test('returns consistent identifier for same server', () {
        final server = ServerConfig(
          name: 'Test',
          url: 'http://localhost:8069',
          database: 'test_db',
        );

        final id1 = service.getServerIdentifier(server);
        final id2 = service.getServerIdentifier(server);

        expect(id1, equals(id2));
      });

      test('returns different identifiers for different databases on same server', () {
        final server1 = ServerConfig(
          name: 'Test 1',
          url: 'http://localhost:8069',
          database: 'db_a',
        );

        final server2 = ServerConfig(
          name: 'Test 2',
          url: 'http://localhost:8069',
          database: 'db_b',
        );

        final id1 = service.getServerIdentifier(server1);
        final id2 = service.getServerIdentifier(server2);

        expect(id1, isNot(equals(id2)));
      });
    });
  });

  group('Multi-Server Scenarios', () {
    late AppServerDatabaseService service;
    late DeviceService deviceService;

    setUp(() {
      deviceService = createDeviceService();
      service = AppServerDatabaseService(deviceService);
    });

    test('supports multiple companies on different servers', () {
      // Scenario: User manages 3 companies, each on different Odoo servers
      final empresaA = ServerConfig(
        name: 'Empresa A - Quito',
        url: 'http://192.168.1.100:8069',
        database: 'empresa_a',
      );

      final empresaB = ServerConfig(
        name: 'Empresa B - Guayaquil',
        url: 'http://192.168.1.101:8069',
        database: 'empresa_b',
      );

      final empresaC = ServerConfig(
        name: 'Empresa C - Cloud',
        url: 'https://erp.empresac.com',
        database: 'production',
      );

      final dbA = service.generateDatabaseName(empresaA);
      final dbB = service.generateDatabaseName(empresaB);
      final dbC = service.generateDatabaseName(empresaC);

      // All three should have unique database files
      expect({dbA, dbB, dbC}.length, equals(3));

      // Each should be valid filename
      for (final db in [dbA, dbB, dbC]) {
        expect(db, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(db.length, lessThan(150));
      }
    });

    test('supports same company with dev/staging/prod environments', () {
      final dev = ServerConfig(
        name: 'Development',
        url: 'http://localhost:8069',
        database: 'empresa_dev',
      );

      final staging = ServerConfig(
        name: 'Staging',
        url: 'https://staging.empresa.com',
        database: 'empresa_staging',
      );

      final prod = ServerConfig(
        name: 'Production',
        url: 'https://erp.empresa.com',
        database: 'empresa_prod',
      );

      final dbDev = service.generateDatabaseName(dev);
      final dbStaging = service.generateDatabaseName(staging);
      final dbProd = service.generateDatabaseName(prod);

      // All environments should have unique database files
      expect({dbDev, dbStaging, dbProd}.length, equals(3));
    });

    test('supports multiple databases on same Odoo server', () {
      // Scenario: Single Odoo server hosts multiple companies
      final company1 = ServerConfig(
        name: 'Company 1',
        url: 'https://shared-odoo.com',
        database: 'company1_db',
      );

      final company2 = ServerConfig(
        name: 'Company 2',
        url: 'https://shared-odoo.com',
        database: 'company2_db',
      );

      final company3 = ServerConfig(
        name: 'Company 3',
        url: 'https://shared-odoo.com',
        database: 'company3_db',
      );

      final db1 = service.generateDatabaseName(company1);
      final db2 = service.generateDatabaseName(company2);
      final db3 = service.generateDatabaseName(company3);

      // Each company should have unique database
      expect({db1, db2, db3}.length, equals(3));

      // All should reference the same host
      expect(db1, contains('shared_odoo_com'));
      expect(db2, contains('shared_odoo_com'));
      expect(db3, contains('shared_odoo_com'));
    });
  });
}
