/// Barrel file for Collection providers
///
/// Este archivo exporta todos los providers del modulo de cobranza,
/// tanto de datos como de presentacion.
library;

// Re-export data providers from core for convenience
export '../../../core/database/providers.dart'
    show
        collectionConfigsProvider,
        currentSessionProvider,
        sessionByIdProvider,
        sessionPaymentsProvider,
        sessionCashOutsProvider,
        sessionDepositsProvider;

// Export presentation providers
export 'collection_session_state.dart';
export 'collection_session_notifier.dart';
export 'collection_session_provider.dart';

// Manager providers are now exported through core/managers/manager_providers.dart
