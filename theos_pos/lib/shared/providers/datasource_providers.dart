import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/datasources/datasources.dart';
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;

part 'datasource_providers.g.dart';

@Riverpod(keepAlive: true)
FieldSelectionDatasource fieldSelectionDatasource(Ref ref) {
  return FieldSelectionDatasource(ref.watch(appDatabaseProvider));
}
