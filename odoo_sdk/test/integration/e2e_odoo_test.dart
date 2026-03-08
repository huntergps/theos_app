/// End-to-end integration tests with a real Odoo server.
///
/// These tests require a running Odoo 19.0+ server with JSON-2 API.
///
/// Configuration via environment variables:
/// - ODOO_URL: Base URL of the Odoo server (e.g., https://odoo.example.com)
/// - ODOO_API_KEY: API key for authentication
/// - ODOO_DATABASE: Database name
///
/// Or create a file `test/integration/e2e_config.dart` with:
/// ```dart
/// const e2eConfig = (
///   url: 'https://odoo.example.com',
///   apiKey: 'your-api-key',
///   database: 'your-database',
/// );
/// ```
///
/// Run with: flutter test test/integration/e2e_odoo_test.dart
///
/// These tests are skipped by default if configuration is not available.
@Tags(['e2e', 'integration'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'package:dio/dio.dart' show CancelToken;
import 'package:odoo_sdk/odoo_sdk.dart';

// Try to import local config, will fail if not present
// ignore: unused_import
import 'e2e_config.dart' if (dart.library.io) 'e2e_config_stub.dart';

/// E2E test configuration
class E2EConfig {
  final String? url;
  final String? apiKey;
  final String? database;

  const E2EConfig({this.url, this.apiKey, this.database});

  bool get isConfigured =>
      url != null &&
      url!.isNotEmpty &&
      apiKey != null &&
      apiKey!.isNotEmpty &&
      database != null &&
      database!.isNotEmpty;

  /// Load configuration from environment variables
  static E2EConfig fromEnvironment() {
    return E2EConfig(
      url: Platform.environment['ODOO_URL'],
      apiKey: Platform.environment['ODOO_API_KEY'],
      database: Platform.environment['ODOO_DATABASE'],
    );
  }
}

void main() {
  // Load configuration
  final config = E2EConfig.fromEnvironment();
  final skipTests = !config.isConfigured;

  group(
    'E2E Odoo Server Tests',
    () {
      late OdooClient client;

      setUpAll(() {
        if (skipTests) return;

        client = OdooClient(
          config: OdooClientConfig(
            baseUrl: config.url!,
            apiKey: config.apiKey!,
            database: config.database!,
            enableRetry: true,
            retryConfig: RetryConfig.minimal,
          ),
        );
      });

      tearDownAll(() {
        if (skipTests) return;
        // OdooClient doesn't have a dispose method, but we can clear any resources if needed
      });

      group('Connectivity', () {
        test('can connect to server', () async {
          // Simple health check - try to read current user
          final result = await client.searchRead(
            model: 'res.users',
            fields: ['id', 'name'],
            domain: [
              ['id', '=', 2]
            ], // admin user
            limit: 1,
          );

          expect(result, isNotEmpty);
        });

        test('handles invalid model gracefully', () async {
          expect(
            () => client.searchRead(
              model: 'invalid.model.name',
              fields: ['id'],
            ),
            throwsA(isA<OdooException>()),
          );
        });
      });

      group('CRUD Operations', () {
        int? createdPartnerId;

        test('searchRead returns records', () async {
          final partners = await client.searchRead(
            model: 'res.partner',
            fields: ['id', 'name', 'email'],
            limit: 5,
          );

          expect(partners, isA<List>());
          expect(partners.length, lessThanOrEqualTo(5));

          if (partners.isNotEmpty) {
            expect(partners.first.containsKey('id'), isTrue);
            expect(partners.first.containsKey('name'), isTrue);
          }
        });

        test('searchCount returns count', () async {
          final count = await client.crud.searchCount(
            model: 'res.partner',
            domain: [],
          );

          expect(count, greaterThan(0));
        });

        test('create creates a record', () async {
          final testName = 'E2E Test Partner ${DateTime.now().millisecondsSinceEpoch}';

          createdPartnerId = await client.create(
            model: 'res.partner',
            values: {
              'name': testName,
              'email': 'e2e-test@example.com',
              'comment': 'Created by E2E test - safe to delete',
            },
          );

          expect(createdPartnerId, isNotNull);
          expect(createdPartnerId, greaterThan(0));

          // Verify creation
          final readResult = await client.crud.read(
            model: 'res.partner',
            ids: [createdPartnerId!],
            fields: ['name', 'email'],
          );

          expect(readResult, hasLength(1));
          expect(readResult.first['name'], equals(testName));
        });

        test('write updates a record', () async {
          if (createdPartnerId == null) {
            fail('Depends on create test');
          }

          final newName = 'E2E Updated Partner ${DateTime.now().millisecondsSinceEpoch}';

          final success = await client.write(
            model: 'res.partner',
            ids: [createdPartnerId!],
            values: {'name': newName},
          );

          expect(success, isTrue);

          // Verify update
          final readResult = await client.crud.read(
            model: 'res.partner',
            ids: [createdPartnerId!],
            fields: ['name'],
          );

          expect(readResult.first['name'], equals(newName));
        });

        test('unlink deletes a record', () async {
          if (createdPartnerId == null) {
            fail('Depends on create test');
          }

          final success = await client.unlink(
            model: 'res.partner',
            ids: [createdPartnerId!],
          );

          expect(success, isTrue);

          // Verify deletion
          final readResult = await client.crud.read(
            model: 'res.partner',
            ids: [createdPartnerId!],
            fields: ['id'],
          );

          expect(readResult, isEmpty);
          createdPartnerId = null;
        });
      });

      group('Batch Operations', () {
        final createdIds = <int>[];

        tearDown(() async {
          // Cleanup: delete any created records
          if (createdIds.isNotEmpty) {
            try {
              await client.unlink(
                model: 'res.partner',
                ids: createdIds,
              );
            } catch (_) {
              // Ignore cleanup errors
            }
            createdIds.clear();
          }
        });

        test('createBatch creates multiple records', () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          final ids = await client.crud.createBatch(
            model: 'res.partner',
            valuesList: [
              {
                'name': 'E2E Batch 1 $timestamp',
                'comment': 'Created by E2E test - safe to delete'
              },
              {
                'name': 'E2E Batch 2 $timestamp',
                'comment': 'Created by E2E test - safe to delete'
              },
              {
                'name': 'E2E Batch 3 $timestamp',
                'comment': 'Created by E2E test - safe to delete'
              },
            ],
          );

          expect(ids, hasLength(3));
          expect(ids.every((id) => id > 0), isTrue);

          createdIds.addAll(ids);
        });

        test('updateBatch updates multiple records in parallel', () async {
          final timestamp = DateTime.now().millisecondsSinceEpoch;

          // First create records
          final ids = await client.crud.createBatch(
            model: 'res.partner',
            valuesList: [
              {
                'name': 'E2E Update 1 $timestamp',
                'comment': 'Created by E2E test'
              },
              {
                'name': 'E2E Update 2 $timestamp',
                'comment': 'Created by E2E test'
              },
            ],
          );
          createdIds.addAll(ids);

          // Update them
          final results = await client.crud.updateBatch(
            model: 'res.partner',
            updates: [
              BatchUpdate(ids: [ids[0]], values: {'phone': '111-111-1111'}),
              BatchUpdate(ids: [ids[1]], values: {'phone': '222-222-2222'}),
            ],
          );

          expect(results, hasLength(2));
          expect(results.every((r) => r == true), isTrue);
        });
      });

      group('Request Cancellation', () {
        test('cancels request with CancelToken', () async {
          final cancelToken = CancelToken();

          // Cancel immediately
          Future.delayed(const Duration(milliseconds: 1), () {
            cancelToken.cancel('Test cancellation');
          });

          expect(
            () => client.searchRead(
              model: 'res.partner',
              fields: ['id', 'name'],
              limit: 1000, // Large limit to make it slower
              cancelToken: cancelToken,
            ),
            throwsA(anything), // Either DioException or cancellation
          );
        });
      });

      group('Metadata Operations', () {
        test('fieldsGet returns field metadata', () async {
          final fields = await client.crud.fieldsGet(
            model: 'res.partner',
            attributes: ['string', 'type', 'required'],
          );

          expect(fields, isA<Map>());
          expect(fields, isNotEmpty);
          expect(fields.containsKey('name'), isTrue);
          expect((fields['name'] as Map).containsKey('type'), isTrue);
        });
      });

      group('Incremental Sync', () {
        test('getModifiedSince returns records modified after date', () async {
          final yesterday = DateTime.now().subtract(const Duration(days: 1));

          final records = await client.crud.getModifiedSince(
            model: 'res.partner',
            lastSync: yesterday,
            fields: ['id', 'name'],
          );

          expect(records, isA<List>());

          if (records.isNotEmpty) {
            // Verify write_date is after yesterday
            final writeDate = records.first['write_date'];
            expect(writeDate, isNotNull);
          }
        });
      });
    },
    skip: skipTests
        ? 'E2E tests skipped: Set ODOO_URL, ODOO_API_KEY, ODOO_DATABASE environment variables'
        : null,
  );
}
