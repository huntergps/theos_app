import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/repositories/repository_providers.dart';

// Re-export del estado y notifier para uso externo
export 'collection_session_state.dart';
export 'collection_session_notifier.dart';

part 'collection_session_provider.g.dart';

/// Provider para verificar si el repositorio esta listo
@Riverpod(keepAlive: true)
bool collectionSessionReady(Ref ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo != null;
}
