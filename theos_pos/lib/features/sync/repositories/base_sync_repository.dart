/// Base sync repository - App adapter
///
/// Extends the generic core BaseSyncRepository and binds it to AppDatabase.
library;

import 'package:odoo_sdk/odoo_sdk.dart' as core;

import 'package:theos_pos_core/theos_pos_core.dart';

abstract class BaseSyncRepository extends core.BaseSyncRepository<AppDatabase> {
  AppDatabase get appDb => db;

  BaseSyncRepository({required super.db, super.odooClient});
}
