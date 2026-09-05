import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        ResCountry,
        ResCountryState,
        ResLang,
        ResourceCalendar,
        Client,
        User,
        MailActivity,
        mailActivityManager,
        CollectionConfig,
        collectionConfigManager,
        CollectionSession,
        collectionSessionManager,
        CollectionSessionDeposit,
        collectionSessionDepositManager,
        CashOut,
        cashOutManager,
        taxManager,
        clientManager,
        ClientManagerBusiness,
        resCountryManager,
        resCountryStateManager,
        resLangManager,
        resourceCalendarManager,
        userManager;

import 'package:theos_pos_core/theos_pos_core.dart'
    show PricelistCalculatorService;

import '../../features/collection/services/session_service.dart';

import '../services/config_service.dart';
import '../../features/taxes/taxes.dart';
import '../../features/sales/services/sale_order_line_service.dart';
// Repositories (Simplified)
import 'repositories/repository_providers.dart';
import '../managers/manager_providers.dart';
part 'providers.g.dart';

@Riverpod(keepAlive: true)
PricelistCalculatorService pricelistCalculator(Ref ref) {
  return PricelistCalculatorService(ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
TaxCalculatorService taxCalculator(Ref ref) {
  return TaxCalculatorService(ref.watch(appDatabaseProvider));
}

/// Reactive stream of tax names cache from local DB.
///
/// Uses `taxManager.watchLocalSearch()` so UI auto-updates
/// when taxes are synced or modified locally.
final taxNamesCacheProvider = StreamProvider<Map<int, String>>((ref) {
  return taxManager.watchLocalSearch().map(
    (taxes) => {for (var tax in taxes) tax.id: tax.name},
  );
});

/// Helper function to get tax names from tax IDs string
String getTaxNamesFromIds(String? taxIds, Map<int, String> taxNamesCache) {
  if (taxIds == null || taxIds.isEmpty) return '';

  final ids = TaxCalculatorService.parseTaxIds(taxIds);
  if (ids.isEmpty) return '';

  final names = ids
      .map((id) => taxNamesCache[id])
      .where((name) => name != null)
      .toList();

  return names.join(', ');
}

@Riverpod(keepAlive: true)
SaleOrderLineService saleOrderLineService(Ref ref) {
  return SaleOrderLineService(
    taxCalculator: ref.watch(taxCalculatorProvider),
    pricelistCalculator: ref.watch(pricelistCalculatorProvider),
  );
}

@Riverpod(keepAlive: true)
SaleOrderLineCollectionService saleOrderLineCollectionService(Ref ref) {
  return const SaleOrderLineCollectionService();
}

@Riverpod(keepAlive: true)
bool repositoriesReady(Ref ref) {
  return areCoreProvidersReadyFromRef(ref);
}

/// Reactive stream of all countries from local DB.
///
/// Uses `resCountryManager.watchLocalSearch()` so UI auto-updates
/// when countries are synced or modified locally.
final countriesProvider = StreamProvider<List<ResCountry>>((ref) {
  return resCountryManager.watchLocalSearch(orderBy: 'name asc');
});

/// Reactive stream of country states filtered by country from local DB.
///
/// Uses `resCountryStateManager.watchLocalSearch()` so UI auto-updates
/// when states are synced or modified locally.
///
/// `autoDispose`: es `.family` por `countryId` transitorio — sin esto,
/// cada país consultado durante la sesión dejaría un stream de Drift
/// `.watch()` vivo para siempre (memory leak). Verificado: el único
/// consumidor (`user_preferences_dialog.dart`) lo lee vía
/// `ref.read(statesProvider(id).future)` puntual — patrón seguro y
/// oficialmente soportado para autoDispose (el `.future` mantiene el
/// provider vivo hasta que resuelve el valor).
final statesProvider = StreamProvider.autoDispose
    .family<List<ResCountryState>, int?>((ref, countryId) {
      if (countryId == null) {
        return resCountryStateManager.watchLocalSearch(orderBy: 'name asc');
      }
      return resCountryStateManager.watchLocalSearch(
        domain: [
          ['country_id', '=', countryId],
        ],
        orderBy: 'name asc',
      );
    });

/// Reactive stream of the current user from local DB.
///
/// Uses `userManager.watchLocalSearch()` filtered by `is_current_user`
/// so UI auto-updates when the current user changes or is modified locally.
final currentUserProvider = StreamProvider<User?>((ref) {
  return userManager
      .watchLocalSearch(
        domain: [
          ['is_current_user', '=', true],
        ],
        limit: 1,
      )
      .map((users) => users.isNotEmpty ? users.first : null);
});

/// Reactive stream of a partner by ID from local DB.
///
/// Delegates to `clientManager.watchPartner()` so UI auto-updates
/// when the partner record is synced or modified locally.
///
/// `autoDispose`: es `.family` por `partnerId` transitorio (memory leak
/// corregido). Verificado: ambos consumidores (`pos_customer_keypad_panel.dart`,
/// `form_fields.dart`) lo observan vía `ref.watch()` dentro de `build()` —
/// patrón reactivo estándar, seguro con autoDispose.
final partnerProvider = StreamProvider.autoDispose.family<Client?, int>((
  ref,
  partnerId,
) {
  return clientManager.watchPartner(partnerId);
});

/// Reactive stream of all active languages from local DB.
///
/// Uses `resLangManager.watchLocalSearch()` so UI auto-updates
/// when languages are synced or modified locally.
final languagesProvider = StreamProvider<List<ResLang>>((ref) {
  return resLangManager.watchLocalSearch(
    domain: [
      ['active', '=', true],
    ],
    orderBy: 'name asc',
  );
});

/// Reactive stream of all resource calendars from local DB.
///
/// Uses `resourceCalendarManager.watchLocalSearch()` so UI auto-updates
/// when calendars are synced or modified locally.
final calendarsProvider = StreamProvider<List<ResourceCalendar>>((ref) {
  return resourceCalendarManager.watchLocalSearch(orderBy: 'name asc');
});

/// Timezones — lee de cache local (FieldSelections), con default Ecuador.
///
/// Dato de referencia estático. Se lee una vez del cache local (~1ms).
/// Si no hay cache y hay conexión, busca en Odoo y cachea para futuro.
/// Si no hay cache ni conexión, retorna default America/Guayaquil.
final timezonesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(commonRepositoryProvider);
  if (repo != null) {
    final timezones = await repo.getTimezones();
    if (timezones.isNotEmpty) return timezones;
  }
  // Default Ecuador si no hay cache ni conexión
  return [
    ['America/Guayaquil', 'America/Guayaquil'],
  ];
});

/// Notification types — lee de cache local (FieldSelections), con default.
///
/// Dato de referencia estático. Se lee una vez del cache local.
/// Default: email + inbox (valores estándar de Odoo).
final notificationTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.watch(commonRepositoryProvider);
  if (repo != null) {
    final types = await repo.getNotificationTypes();
    if (types.isNotEmpty) return types;
  }
  return [
    ['email', 'Correo electrónico'],
    ['inbox', 'Bandeja de entrada'],
  ];
});

/// Reactive stream of all activities from local DB.
///
/// Uses `mailActivityManager.watchLocalSearch()` so UI auto-updates
/// when activities are synced, created, or modified locally.
final activitiesProvider = StreamProvider<List<MailActivity>>((ref) {
  return mailActivityManager.watchLocalSearch();
});

// ============ Collection Providers ============

/// Reactive stream of all collection configs from local DB.
///
/// Uses `collectionConfigManager.watchLocalSearch()` so UI auto-updates
/// when collection configs are synced or modified locally.
final collectionConfigsProvider = StreamProvider<List<CollectionConfig>>((ref) {
  return collectionConfigManager.watchLocalSearch();
});

/// Reactive stream of all active sessions (state != closed) from local DB.
///
/// Uses `collectionSessionManager.watchLocalSearch()` with a domain filter
/// so the list auto-updates whenever any session state changes.
/// Ordered by start_at descending (most recent first).
///
/// Intended for supervisor use — shows every open cajero session.
final activeSessionsProvider = StreamProvider<List<CollectionSession>>((ref) {
  return collectionSessionManager.watchLocalSearch(
    domain: [
      ['state', '!=', 'closed'],
    ],
    orderBy: 'start_at desc',
  );
});

@Riverpod(keepAlive: true)
class CurrentSession extends _$CurrentSession {
  @override
  CollectionSession? build() => null;

  void set(CollectionSession? session) => state = session;

  /// Carga la sesión activa desde la base de datos local si aún no está en el
  /// provider.  Es seguro llamarlo desde dentro del build de otro provider
  /// porque la escritura ocurre aquí (en el notifier) y no directamente desde
  /// el provider consumidor.
  ///
  /// Retorna la sesión activa (la que ya estaba o la que se encontró en BD),
  /// o null si no existe ninguna.
  Future<CollectionSession?> ensureLoaded() async {
    if (state != null) return state;

    final collectionRepo = ref.read(collectionRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);
    if (collectionRepo == null || userRepo == null) return null;

    try {
      final user = await userRepo.getCurrentUser();
      if (user == null) return null;

      final session = await collectionRepo.getActiveUserSession(user.id);
      if (session != null) {
        state = session;
      }
      return session;
    } catch (e) {
      return null;
    }
  }
}

/// Reactive stream of cash outs for a collection session.
///
/// Uses `cashOutManager.watchLocalSearch()` so UI auto-updates
/// when cash outs are created, modified, or synced locally.
///
/// `autoDispose`: es `.family` por `sessionId` transitorio (memory leak
/// corregido). Verificado: el único consumidor (`cash_outs_tab.dart`) lo
/// observa vía `ref.watch()` en `build()` — patrón reactivo estándar.
final sessionCashOutsProvider = StreamProvider.autoDispose
    .family<List<CashOut>, int>((ref, sessionId) {
      return cashOutManager.watchLocalSearch(
        domain: [
          ['collection_session_id', '=', sessionId],
        ],
      );
    });

/// Reactive stream of deposits for a collection session.
///
/// Uses `collectionSessionDepositManager.watchLocalSearch()` so UI auto-updates
/// when deposits are created, modified, or synced locally.
///
/// `autoDispose`: es `.family` por `sessionId` transitorio (memory leak
/// corregido). Verificado: el único consumidor (`deposits_tab.dart`) lo
/// observa vía `ref.watch()` en `build()` (y usa `ref.invalidate()` para
/// forzar refresh, patrón compatible con autoDispose).
final sessionDepositsProvider = StreamProvider.autoDispose
    .family<List<CollectionSessionDeposit>, int>((ref, sessionId) {
      return collectionSessionDepositManager.watchLocalSearch(
        domain: [
          ['collection_session_id', '=', sessionId],
        ],
      );
    });

@Riverpod(keepAlive: true)
SessionService? sessionService(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return null;

  final sessionManager = ref.watch(collectionSessionManagerProvider);
  final paymentManager = ref.watch(accountPaymentManagerProvider);
  final cashOutManager = ref.watch(cashOutManagerProvider);
  final depositManager = ref.watch(collectionSessionDepositManagerProvider);

  return SessionService(
    dbHelper,
    sessionManager: sessionManager,
    paymentManager: paymentManager,
    cashOutManager: cashOutManager,
    depositManager: depositManager,
  );
}

@Riverpod(keepAlive: true)
int maxSyncRetries(Ref ref) {
  final config = ref.watch(configServiceProvider);
  return config.maxSyncRetries;
}

@Riverpod(keepAlive: true)
int errorNotificationDuration(Ref ref) {
  final config = ref.watch(configServiceProvider);
  return config.errorNotificationDuration;
}

@Riverpod(keepAlive: true)
int successNotificationDuration(Ref ref) {
  final config = ref.watch(configServiceProvider);
  return config.successNotificationDuration;
}

@Riverpod(keepAlive: true)
int warningNotificationDuration(Ref ref) {
  final config = ref.watch(configServiceProvider);
  return config.warningNotificationDuration;
}

@Riverpod(keepAlive: true)
int infoNotificationDuration(Ref ref) {
  final config = ref.watch(configServiceProvider);
  return config.infoNotificationDuration;
}
