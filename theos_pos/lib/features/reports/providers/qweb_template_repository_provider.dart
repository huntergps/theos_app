import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../repositories/qweb_template_repository.dart';

part 'qweb_template_repository_provider.g.dart';

@Riverpod(keepAlive: true)
QwebTemplateRepository? qwebTemplateRepository(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return null;

  return QwebTemplateRepository(ref.watch(appDatabaseProvider));
}
