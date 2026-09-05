import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/database/database_helper.dart';

void main() {
  test('cleanup excludes current, registered scope and recovery copy', () {
    final now = DateTime.utc(2026, 8, 24);
    final files = [
      _file('current.sqlite', now, isCurrent: true),
      _file('scope_a.sqlite', now.subtract(const Duration(days: 30))),
      _file(
        'scope_a__recovery_copy.sqlite',
        now.subtract(const Duration(days: 40)),
      ),
      _file('recent_disposable.sqlite', now.subtract(const Duration(days: 1))),
      _file('old_disposable.sqlite', now.subtract(const Duration(days: 2))),
    ];

    final selected = DatabaseHelper.selectCleanupCandidates(
      files: files,
      keepCount: 1,
      protectedDatabaseNames: {
        'scope_a',
        '/registered/recovery/scope_a__recovery_copy.sqlite',
      },
    );

    expect(selected.map((file) => file.name), ['old_disposable.sqlite']);
  });

  test('cleanup rejects negative retention instead of widening deletion', () {
    expect(
      () => DatabaseHelper.selectCleanupCandidates(
        files: const [],
        keepCount: -1,
        protectedDatabaseNames: const {},
      ),
      throwsArgumentError,
    );
  });
}

DatabaseFileInfo _file(
  String name,
  DateTime lastModified, {
  bool isCurrent = false,
}) {
  return DatabaseFileInfo(
    path: '/databases/$name',
    name: name,
    sizeBytes: 100,
    lastModified: lastModified,
    isCurrent: isCurrent,
  );
}
