import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  test(
    'opening the runtime database creates orbi_envases_operations without a '
    'separate manual call',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final db = await owner.open(
        AppScope(
          appId: 'orbi',
          installationId: 'i',
          normalizedServerUrl: 'https://erp.test',
          database: 'db',
          userId: 1,
        ),
      );
      addTearDown(owner.close);

      final rows = await db.database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='orbi_envases_operations'",
          )
          .get();

      expect(rows, hasLength(1));
    },
  );
}
