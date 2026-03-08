/// Drift Test Helper
///
/// Provides utilities for testing with in-memory Drift databases.
/// Use these helpers to set up isolated database tests.
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

/// Creates an in-memory database executor for testing.
///
/// Example:
/// ```dart
/// late AppDatabase database;
///
/// setUp(() {
///   database = AppDatabase(createInMemoryExecutor());
/// });
///
/// tearDown(() async {
///   await database.close();
/// });
/// ```
QueryExecutor createInMemoryExecutor() {
  return NativeDatabase.memory();
}

/// Creates a temporary file-based database for testing.
///
/// Useful when you need to test persistence or when in-memory
/// databases don't support certain features.
///
/// Remember to delete the file in tearDown.
Future<(QueryExecutor, File)> createTempFileExecutor() async {
  final dir = Directory.systemTemp.createTempSync('theos_pos_test_');
  final file = File(p.join(dir.path, 'test_database.sqlite'));
  final executor = NativeDatabase(file);
  return (executor, file);
}

/// Helper class to manage test database lifecycle.
class TestDatabaseManager<T extends GeneratedDatabase> {
  T? _database;
  File? _tempFile;
  final T Function(QueryExecutor) _factory;

  TestDatabaseManager(this._factory);

  /// Create an in-memory database.
  T createInMemory() {
    _database = _factory(createInMemoryExecutor());
    return _database!;
  }

  /// Create a file-based database.
  Future<T> createFile() async {
    final (executor, file) = await createTempFileExecutor();
    _tempFile = file;
    _database = _factory(executor);
    return _database!;
  }

  /// Close and clean up the database.
  Future<void> dispose() async {
    await _database?.close();
    _database = null;

    if (_tempFile != null) {
      try {
        await _tempFile!.delete();
        await _tempFile!.parent.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
      _tempFile = null;
    }
  }

  /// Get the current database instance.
  T get database {
    if (_database == null) {
      throw StateError('Database not created. Call createInMemory() or createFile() first.');
    }
    return _database!;
  }
}

/// Extension methods for database testing.
extension DatabaseTestExtensions on GeneratedDatabase {
  /// Clear all data from all tables.
  ///
  /// Useful in setUp to ensure clean state.
  Future<void> clearAllTables() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  /// Count rows in a specific table.
  Future<int> countRows(TableInfo table) async {
    final count = await customSelect(
      'SELECT COUNT(*) as count FROM ${table.actualTableName}',
    ).getSingle();
    return count.read<int>('count');
  }
}

/// Matcher for database test assertions.
class DatabaseMatchers {
  /// Verify table has expected row count.
  static Future<void> expectRowCount(
    GeneratedDatabase db,
    TableInfo table,
    int expected,
  ) async {
    final count = await db.countRows(table);
    if (count != expected) {
      throw TestFailure(
        'Expected ${table.actualTableName} to have $expected rows, but had $count',
      );
    }
  }

  /// Verify table is empty.
  static Future<void> expectEmpty(GeneratedDatabase db, TableInfo table) async {
    await expectRowCount(db, table, 0);
  }

  /// Verify table is not empty.
  static Future<void> expectNotEmpty(GeneratedDatabase db, TableInfo table) async {
    final count = await db.countRows(table);
    if (count == 0) {
      throw TestFailure('Expected ${table.actualTableName} to have rows, but was empty');
    }
  }
}

/// Exception for test failures in database matchers.
class TestFailure implements Exception {
  final String message;
  TestFailure(this.message);

  @override
  String toString() => 'TestFailure: $message';
}
