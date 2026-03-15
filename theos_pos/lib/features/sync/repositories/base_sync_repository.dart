/// Base sync repository - App adapter
///
/// Extends the generic core BaseSyncRepository and binds it to AppDatabase.
library;

import 'package:odoo_sdk/odoo_sdk.dart' as core;

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../../core/database/database_helper.dart';

abstract class BaseSyncRepository extends core.BaseSyncRepository<DatabaseHelper> {
  /// Access to the CURRENT Drift database instance.
  /// Uses DatabaseHelper.db to avoid stale references after server switch.
  // ignore: deprecated_member_use_from_same_package
  AppDatabase get appDb => DatabaseHelper.db;

  BaseSyncRepository({required super.db, super.odooClient});
}
