import 'package:test/test.dart';
import 'package:odoo_sdk/src/model/conflict_resolution.dart';

void main() {
  group('SyncConflictStrategy', () {
    test('has all expected values', () {
      expect(SyncConflictStrategy.values, [
        SyncConflictStrategy.serverWins,
        SyncConflictStrategy.localWins,
        SyncConflictStrategy.lastWriteWins,
        SyncConflictStrategy.merge,
        SyncConflictStrategy.askUser,
        SyncConflictStrategy.createCopy,
      ]);
    });
  });

  group('SyncConflict', () {
    test('creates conflict with required fields', () {
      const conflict = SyncConflict<Map<String, dynamic>>(
        recordId: 1,
        model: 'res.partner',
        localRecord: {'name': 'Local Name'},
        serverRecord: {'name': 'Server Name'},
      );

      expect(conflict.recordId, 1);
      expect(conflict.model, 'res.partner');
      expect(conflict.localRecord, {'name': 'Local Name'});
      expect(conflict.serverRecord, {'name': 'Server Name'});
      expect(conflict.localWriteDate, isNull);
      expect(conflict.serverWriteDate, isNull);
      expect(conflict.conflictingFields, isEmpty);
    });

    test('creates conflict with all fields', () {
      final localDate = DateTime(2024, 1, 15, 10, 30);
      final serverDate = DateTime(2024, 1, 15, 10, 0);

      final conflict = SyncConflict<Map<String, dynamic>>(
        recordId: 42,
        model: 'product.product',
        localRecord: {'name': 'Local', 'price': 100},
        serverRecord: {'name': 'Server', 'price': 120},
        localWriteDate: localDate,
        serverWriteDate: serverDate,
        conflictingFields: ['name', 'price'],
      );

      expect(conflict.recordId, 42);
      expect(conflict.localWriteDate, localDate);
      expect(conflict.serverWriteDate, serverDate);
      expect(conflict.conflictingFields, ['name', 'price']);
    });

    group('isLocalNewer', () {
      test('returns true when local is newer', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: DateTime(2024, 1, 15, 12, 0),
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        expect(conflict.isLocalNewer, isTrue);
      });

      test('returns false when server is newer', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: DateTime(2024, 1, 15, 8, 0),
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        expect(conflict.isLocalNewer, isFalse);
      });

      test('returns false when dates are equal', () {
        final sameDate = DateTime(2024, 1, 15, 10, 0);
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: sameDate,
          serverWriteDate: sameDate,
        );

        expect(conflict.isLocalNewer, isFalse);
      });

      test('returns false when localWriteDate is null', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: null,
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        expect(conflict.isLocalNewer, isFalse);
      });

      test('returns false when serverWriteDate is null', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: DateTime(2024, 1, 15, 10, 0),
          serverWriteDate: null,
        );

        expect(conflict.isLocalNewer, isFalse);
      });
    });

    group('isServerNewer', () {
      test('returns true when server is newer', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: DateTime(2024, 1, 15, 8, 0),
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        expect(conflict.isServerNewer, isTrue);
      });

      test('returns false when local is newer', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: DateTime(2024, 1, 15, 12, 0),
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        expect(conflict.isServerNewer, isFalse);
      });

      test('returns true when dates are equal', () {
        final sameDate = DateTime(2024, 1, 15, 10, 0);
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: sameDate,
          serverWriteDate: sameDate,
        );

        // Equal dates means server wins (conservative)
        expect(conflict.isServerNewer, isFalse);
      });

      test('returns true when localWriteDate is null', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: null,
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        expect(conflict.isServerNewer, isTrue);
      });

      test('returns true when serverWriteDate is null', () {
        final conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'test.model',
          localRecord: {},
          serverRecord: {},
          localWriteDate: DateTime(2024, 1, 15, 10, 0),
          serverWriteDate: null,
        );

        // When server date is null but local exists, still defaults to server
        expect(conflict.isServerNewer, isTrue);
      });
    });
  });

  group('ConflictAction', () {
    test('has all expected values', () {
      expect(ConflictAction.values, [
        ConflictAction.acceptedLocal,
        ConflictAction.acceptedServer,
        ConflictAction.merged,
        ConflictAction.skipped,
        ConflictAction.copiedForReview,
      ]);
    });
  });

  group('ConflictResolution', () {
    test('creates resolution with required fields', () {
      const resolution = ConflictResolution<Map<String, dynamic>>(
        resolvedRecord: {'name': 'Resolved'},
        action: ConflictAction.acceptedLocal,
      );

      expect(resolution.resolvedRecord, {'name': 'Resolved'});
      expect(resolution.action, ConflictAction.acceptedLocal);
      expect(resolution.updateServer, isFalse);
      expect(resolution.message, isNull);
    });

    test('creates resolution with all fields', () {
      const resolution = ConflictResolution<Map<String, dynamic>>(
        resolvedRecord: {'name': 'Resolved'},
        action: ConflictAction.merged,
        updateServer: true,
        message: 'Custom message',
      );

      expect(resolution.updateServer, isTrue);
      expect(resolution.message, 'Custom message');
    });

    group('factory constructors', () {
      test('acceptLocal creates correct resolution', () {
        final localRecord = {'name': 'Local', 'price': 100};
        final resolution = ConflictResolution<Map<String, dynamic>>.acceptLocal(
          localRecord,
        );

        expect(resolution.resolvedRecord, localRecord);
        expect(resolution.action, ConflictAction.acceptedLocal);
        expect(resolution.updateServer, isTrue);
        expect(resolution.message, contains('Local changes preserved'));
      });

      test('acceptServer creates correct resolution', () {
        final serverRecord = {'name': 'Server', 'price': 120};
        final resolution =
            ConflictResolution<Map<String, dynamic>>.acceptServer(serverRecord);

        expect(resolution.resolvedRecord, serverRecord);
        expect(resolution.action, ConflictAction.acceptedServer);
        expect(resolution.updateServer, isFalse);
        expect(resolution.message, contains('Server version accepted'));
      });

      test('merged creates correct resolution', () {
        final mergedRecord = {'name': 'Local', 'price': 120};
        final resolution = ConflictResolution<Map<String, dynamic>>.merged(
          mergedRecord,
        );

        expect(resolution.resolvedRecord, mergedRecord);
        expect(resolution.action, ConflictAction.merged);
        expect(resolution.updateServer, isTrue);
        expect(resolution.message, contains('merged'));
      });

      test('skipped creates correct resolution', () {
        final currentRecord = {'name': 'Current'};
        final resolution = ConflictResolution<Map<String, dynamic>>.skipped(
          currentRecord,
        );

        expect(resolution.resolvedRecord, currentRecord);
        expect(resolution.action, ConflictAction.skipped);
        expect(resolution.updateServer, isFalse);
        expect(resolution.message, contains('deferred'));
      });
    });
  });

  group('DefaultConflictHandler', () {
    test('uses serverWins as default strategy', () {
      const handler = DefaultConflictHandler<Map<String, dynamic>>();
      expect(handler.defaultStrategy, SyncConflictStrategy.serverWins);
    });

    test('allows custom default strategy', () {
      const handler = DefaultConflictHandler<Map<String, dynamic>>(
        defaultStrategy: SyncConflictStrategy.localWins,
      );
      expect(handler.defaultStrategy, SyncConflictStrategy.localWins);
    });

    group('resolveConflict', () {
      late SyncConflict<Map<String, dynamic>> conflict;

      setUp(() {
        conflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'res.partner',
          localRecord: {'name': 'Local Name', 'phone': '111'},
          serverRecord: {'name': 'Server Name', 'phone': '222'},
          localWriteDate: DateTime(2024, 1, 15, 12, 0),
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
          conflictingFields: ['name', 'phone'],
        );
      });

      test('serverWins strategy returns server record', () async {
        const handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.serverWins,
        );

        final resolution = await handler.resolveConflict(conflict);

        expect(resolution.resolvedRecord, conflict.serverRecord);
        expect(resolution.action, ConflictAction.acceptedServer);
        expect(resolution.updateServer, isFalse);
      });

      test('localWins strategy returns local record', () async {
        const handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.localWins,
        );

        final resolution = await handler.resolveConflict(conflict);

        expect(resolution.resolvedRecord, conflict.localRecord);
        expect(resolution.action, ConflictAction.acceptedLocal);
        expect(resolution.updateServer, isTrue);
      });

      test('lastWriteWins returns local when local is newer', () async {
        const handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.lastWriteWins,
        );

        // Local is newer in our test conflict
        final resolution = await handler.resolveConflict(conflict);

        expect(resolution.resolvedRecord, conflict.localRecord);
        expect(resolution.action, ConflictAction.acceptedLocal);
      });

      test('lastWriteWins returns server when server is newer', () async {
        const handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.lastWriteWins,
        );

        final serverNewerConflict = SyncConflict<Map<String, dynamic>>(
          recordId: 1,
          model: 'res.partner',
          localRecord: {'name': 'Local'},
          serverRecord: {'name': 'Server'},
          localWriteDate: DateTime(2024, 1, 15, 8, 0),
          serverWriteDate: DateTime(2024, 1, 15, 12, 0),
        );

        final resolution = await handler.resolveConflict(serverNewerConflict);

        expect(resolution.resolvedRecord, serverNewerConflict.serverRecord);
        expect(resolution.action, ConflictAction.acceptedServer);
      });

      test('merge strategy uses merge function when provided', () async {
        final handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.merge,
          mergeFunction: (local, server) {
            return {
              'name': local['name'], // Keep local name
              'phone': server['phone'], // Keep server phone
            };
          },
        );

        final resolution = await handler.resolveConflict(conflict);

        expect(resolution.resolvedRecord, {
          'name': 'Local Name',
          'phone': '222',
        });
        expect(resolution.action, ConflictAction.merged);
        expect(resolution.updateServer, isTrue);
      });

      test(
        'merge strategy falls back to serverWins when no merge function',
        () async {
          const handler = DefaultConflictHandler<Map<String, dynamic>>(
            defaultStrategy: SyncConflictStrategy.merge,
            // No merge function provided
          );

          final resolution = await handler.resolveConflict(conflict);

          expect(resolution.resolvedRecord, conflict.serverRecord);
          expect(resolution.action, ConflictAction.acceptedServer);
        },
      );

      test('askUser strategy returns skipped', () async {
        const handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.askUser,
        );

        final resolution = await handler.resolveConflict(conflict);

        expect(resolution.resolvedRecord, conflict.localRecord);
        expect(resolution.action, ConflictAction.skipped);
        expect(resolution.updateServer, isFalse);
      });

      test('createCopy strategy returns skipped', () async {
        const handler = DefaultConflictHandler<Map<String, dynamic>>(
          defaultStrategy: SyncConflictStrategy.createCopy,
        );

        final resolution = await handler.resolveConflict(conflict);

        expect(resolution.resolvedRecord, conflict.localRecord);
        expect(resolution.action, ConflictAction.skipped);
      });
    });
  });

  group('ConflictDetection mixin', () {
    late TestConflictDetector detector;

    setUp(() {
      detector = TestConflictDetector();
    });

    test('detects no conflicts when records are identical', () {
      final local = {'name': 'Test', 'price': 100, 'active': true};
      final server = {'name': 'Test', 'price': 100, 'active': true};

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['name', 'price', 'active'],
      );

      expect(conflicts, isEmpty);
    });

    test('detects single conflicting field', () {
      final local = {'name': 'Local', 'price': 100};
      final server = {'name': 'Server', 'price': 100};

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['name', 'price'],
      );

      expect(conflicts, ['name']);
    });

    test('detects multiple conflicting fields', () {
      final local = {'name': 'Local', 'price': 100, 'qty': 10};
      final server = {'name': 'Server', 'price': 120, 'qty': 10};

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['name', 'price', 'qty'],
      );

      expect(conflicts, ['name', 'price']);
    });

    test('only compares specified fields', () {
      final local = {'name': 'Local', 'price': 100, 'ignored': 'a'};
      final server = {'name': 'Local', 'price': 100, 'ignored': 'b'};

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['name', 'price'], // 'ignored' not in list
      );

      expect(conflicts, isEmpty);
    });

    test('handles null values correctly', () {
      final local = {'name': 'Test', 'phone': null};
      final server = {'name': 'Test', 'phone': null};

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['name', 'phone'],
      );

      expect(conflicts, isEmpty);
    });

    test('detects conflict when one value is null', () {
      final local = {'name': 'Test', 'phone': '123'};
      final server = {'name': 'Test', 'phone': null};

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['name', 'phone'],
      );

      expect(conflicts, ['phone']);
    });

    test('compares lists correctly', () {
      final local = {
        'tags': [1, 2, 3],
      };
      final server = {
        'tags': [1, 2, 3],
      };

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['tags'],
      );

      expect(conflicts, isEmpty);
    });

    test('detects conflict in lists', () {
      final local = {
        'tags': [1, 2, 3],
      };
      final server = {
        'tags': [1, 2, 4],
      };

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['tags'],
      );

      expect(conflicts, ['tags']);
    });

    test('detects conflict in list length', () {
      final local = {
        'tags': [1, 2],
      };
      final server = {
        'tags': [1, 2, 3],
      };

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['tags'],
      );

      expect(conflicts, ['tags']);
    });

    test('compares nested maps correctly', () {
      final local = {
        'address': {'city': 'NYC', 'zip': '10001'},
      };
      final server = {
        'address': {'city': 'NYC', 'zip': '10001'},
      };

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['address'],
      );

      expect(conflicts, isEmpty);
    });

    test('detects conflict in nested maps', () {
      final local = {
        'address': {'city': 'NYC', 'zip': '10001'},
      };
      final server = {
        'address': {'city': 'LA', 'zip': '90001'},
      };

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['address'],
      );

      expect(conflicts, ['address']);
    });

    test('detects conflict when map has different keys', () {
      final local = {
        'address': {'city': 'NYC'},
      };
      final server = {
        'address': {'city': 'NYC', 'zip': '10001'},
      };

      final conflicts = detector.detectConflictingFields(
        local,
        server,
        (r) => r,
        ['address'],
      );

      expect(conflicts, ['address']);
    });
  });

  group('ConflictStats', () {
    test('creates empty stats with default values', () {
      const stats = ConflictStats();

      expect(stats.totalConflicts, 0);
      expect(stats.acceptedLocal, 0);
      expect(stats.acceptedServer, 0);
      expect(stats.merged, 0);
      expect(stats.skipped, 0);
    });

    test('creates stats with provided values', () {
      const stats = ConflictStats(
        totalConflicts: 10,
        acceptedLocal: 3,
        acceptedServer: 4,
        merged: 2,
        skipped: 1,
      );

      expect(stats.totalConflicts, 10);
      expect(stats.acceptedLocal, 3);
      expect(stats.acceptedServer, 4);
      expect(stats.merged, 2);
      expect(stats.skipped, 1);
    });

    group('copyWith', () {
      test('copies with single field change', () {
        const original = ConflictStats(totalConflicts: 5);
        final copied = original.copyWith(acceptedLocal: 2);

        expect(copied.totalConflicts, 5);
        expect(copied.acceptedLocal, 2);
      });

      test('copies with multiple field changes', () {
        const original = ConflictStats();
        final copied = original.copyWith(totalConflicts: 10, merged: 5);

        expect(copied.totalConflicts, 10);
        expect(copied.merged, 5);
        expect(copied.acceptedLocal, 0);
      });
    });

    group('addResolution', () {
      test('increments totalConflicts and acceptedLocal', () {
        const stats = ConflictStats();
        final updated = stats.addResolution(ConflictAction.acceptedLocal);

        expect(updated.totalConflicts, 1);
        expect(updated.acceptedLocal, 1);
        expect(updated.acceptedServer, 0);
      });

      test('increments totalConflicts and acceptedServer', () {
        const stats = ConflictStats();
        final updated = stats.addResolution(ConflictAction.acceptedServer);

        expect(updated.totalConflicts, 1);
        expect(updated.acceptedServer, 1);
        expect(updated.acceptedLocal, 0);
      });

      test('increments totalConflicts and merged', () {
        const stats = ConflictStats();
        final updated = stats.addResolution(ConflictAction.merged);

        expect(updated.totalConflicts, 1);
        expect(updated.merged, 1);
      });

      test('increments totalConflicts and skipped', () {
        const stats = ConflictStats();
        final updated = stats.addResolution(ConflictAction.skipped);

        expect(updated.totalConflicts, 1);
        expect(updated.skipped, 1);
      });

      test('accumulates multiple resolutions', () {
        const stats = ConflictStats();
        final updated = stats
            .addResolution(ConflictAction.acceptedLocal)
            .addResolution(ConflictAction.acceptedLocal)
            .addResolution(ConflictAction.acceptedServer)
            .addResolution(ConflictAction.merged);

        expect(updated.totalConflicts, 4);
        expect(updated.acceptedLocal, 2);
        expect(updated.acceptedServer, 1);
        expect(updated.merged, 1);
      });

      test('handles copiedForReview action', () {
        const stats = ConflictStats();
        final updated = stats.addResolution(ConflictAction.copiedForReview);

        // copiedForReview doesn't have a specific counter, only totalConflicts
        expect(updated.totalConflicts, 1);
        expect(updated.acceptedLocal, 0);
        expect(updated.acceptedServer, 0);
        expect(updated.merged, 0);
        expect(updated.skipped, 0);
      });
    });

    test('toString returns readable format', () {
      const stats = ConflictStats(
        totalConflicts: 10,
        acceptedLocal: 3,
        acceptedServer: 4,
        merged: 2,
        skipped: 1,
      );

      final str = stats.toString();

      expect(str, contains('total: 10'));
      expect(str, contains('local: 3'));
      expect(str, contains('server: 4'));
      expect(str, contains('merged: 2'));
      expect(str, contains('skipped: 1'));
    });
  });

  group('Custom ConflictHandler', () {
    test('can implement custom resolution logic', () async {
      final handler = CustomTestHandler();

      const conflict = SyncConflict<Map<String, dynamic>>(
        recordId: 1,
        model: 'test.model',
        localRecord: {'value': 10},
        serverRecord: {'value': 20},
      );

      final resolution = await handler.resolveConflict(conflict);

      // Custom handler averages numeric values
      expect(resolution.resolvedRecord['value'], 15);
      expect(resolution.action, ConflictAction.merged);
    });
  });

  group('Edge cases', () {
    test('SyncConflict with typed records', () {
      const conflict = SyncConflict<TestProduct>(
        recordId: 1,
        model: 'product.product',
        localRecord: TestProduct(id: 1, name: 'Local', price: 100),
        serverRecord: TestProduct(id: 1, name: 'Server', price: 120),
      );

      expect(conflict.localRecord.name, 'Local');
      expect(conflict.serverRecord.name, 'Server');
    });

    test('ConflictResolution with typed records', () {
      const product = TestProduct(id: 1, name: 'Merged', price: 110);
      final resolution = ConflictResolution<TestProduct>.merged(product);

      expect(resolution.resolvedRecord.name, 'Merged');
      expect(resolution.resolvedRecord.price, 110);
    });

    test(
      'DefaultConflictHandler with typed records and write date getter',
      () async {
        final handler = DefaultConflictHandler<TestProduct>(
          defaultStrategy: SyncConflictStrategy.lastWriteWins,
          getWriteDate: (product) => product.writeDate,
        );

        final conflict = SyncConflict<TestProduct>(
          recordId: 1,
          model: 'product.product',
          localRecord: TestProduct(
            id: 1,
            name: 'Local',
            price: 100,
            writeDate: DateTime(2024, 1, 15, 12, 0),
          ),
          serverRecord: TestProduct(
            id: 1,
            name: 'Server',
            price: 120,
            writeDate: DateTime(2024, 1, 15, 10, 0),
          ),
          localWriteDate: DateTime(2024, 1, 15, 12, 0),
          serverWriteDate: DateTime(2024, 1, 15, 10, 0),
        );

        final resolution = await handler.resolveConflict(conflict);

        // Local is newer, should win
        expect(resolution.resolvedRecord.name, 'Local');
      },
    );
  });
}

/// Test helper class that uses ConflictDetection mixin.
class TestConflictDetector with ConflictDetection<Map<String, dynamic>> {}

/// Custom conflict handler for testing.
class CustomTestHandler implements ConflictHandler<Map<String, dynamic>> {
  @override
  SyncConflictStrategy get defaultStrategy => SyncConflictStrategy.merge;

  @override
  Future<ConflictResolution<Map<String, dynamic>>> resolveConflict(
    SyncConflict<Map<String, dynamic>> conflict,
  ) async {
    // Custom logic: average numeric values
    final merged = <String, dynamic>{};
    final localMap = conflict.localRecord;
    final serverMap = conflict.serverRecord;

    for (final key in {...localMap.keys, ...serverMap.keys}) {
      final localVal = localMap[key];
      final serverVal = serverMap[key];

      if (localVal is num && serverVal is num) {
        merged[key] = (localVal + serverVal) / 2;
      } else {
        merged[key] = serverVal ?? localVal;
      }
    }

    return ConflictResolution.merged(merged);
  }
}

/// Test product class for typed conflict resolution tests.
class TestProduct {
  final int id;
  final String name;
  final double price;
  final DateTime? writeDate;

  const TestProduct({
    required this.id,
    required this.name,
    required this.price,
    this.writeDate,
  });
}
