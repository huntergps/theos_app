/// Base sync repository - App adapter
///
/// Extends the generic core BaseSyncRepository and binds it to AppDatabase.
library;

import 'package:odoo_sdk/odoo_sdk.dart' as core;

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../../core/database/database_helper.dart';

abstract class BaseSyncRepository extends core.BaseSyncRepository<DatabaseHelper> {
  /// Access to the Drift database instance.
  final AppDatabase appDb;

  BaseSyncRepository({required super.db, super.odooClient, required this.appDb});
}
