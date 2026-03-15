import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show userManager, UserManagerBusiness;

import '../../core/database/repositories/base_repository.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/managers/model_registry_integration.dart';
import '../../core/services/auth_event_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/platform/server_connectivity_service.dart';
import '../../core/services/websocket/odoo_websocket_service.dart';
import '../../features/authentication/services/server_service.dart';
import '../../features/sync/services/connectivity_sync_orchestrator.dart';
import '../../features/products/providers/product_providers.dart';
import '../../features/sales/screens/fast_sale/fast_sale_providers.dart';
import '../../features/sales/providers/order_cache_provider.dart';
import '../providers/im_status_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/server_info_provider.dart';
import '../providers/user_provider.dart';
import '../../features/sales/providers/sale_order_form_notifier.dart';
import '../../features/sync/providers/sync_provider.dart';
import '../../core/database/providers.dart';
import 'dialogs/copyable_info_bar.dart';

/// Guards the app against expired/revoked authentication.
///
/// Listens to [AuthEventService] for session expired events and performs
/// the same logout cleanup as the MainScreen logout action, then
/// redirects to the login screen.
class AuthGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  StreamSubscription<AuthEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    final authEventService = ref.read(authEventServiceProvider);
    _subscription = authEventService.events.listen(_handleAuthEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthEvent(AuthEvent event) async {
    if (event != AuthEvent.sessionExpired) return;
    if (!mounted) return;

    // Skip if already on login or splash
    // GoRouter may not be in context when the app is still initializing
    final GoRouter router;
    try {
      router = GoRouter.of(context);
    } catch (_) {
      // GoRouter not yet available in widget tree — skip
      return;
    }
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
    if (currentLocation == '/login' || currentLocation == '/splash') {
      return;
    }

    logger.w('[AuthGuard] Session expired detected, performing logout...');

    // Tear down background services BEFORE clearing session
    // (stops WebSocket, health polling, sync orchestrator from talking to old server)
    try {
      ref.read(odooWebSocketServiceProvider).disconnect();
      ref.invalidate(serverHealthServiceProvider);
      ref.invalidate(serverInfoProvider);
      ref.invalidate(notificationCounterProvider);
      ref.invalidate(connectivitySyncOrchestratorProvider);
      ref.invalidate(modelRegistryIntegrationProvider);

      // Invalidate data-layer providers that cache DB/server-specific state
      ref.invalidate(offlineSyncServiceProvider);
      ref.invalidate(catalogServiceProvider);
      ref.invalidate(fastSaleProvider);
      ref.invalidate(orderCacheProvider);
      ref.invalidate(imStatusProvider);

      // Invalidate sync, session, and form state
      ref.invalidate(syncProvider);
      ref.invalidate(currentSessionProvider);
      ref.invalidate(saleOrderFormProvider);
      SyncNotifier.resetSyncFlag();
    } catch (e) {
      logger.e('[AuthGuard] Error during session teardown: $e');
    }

    // Perform logout cleanup (same as MainScreen logout)
    try {
      // Clear user state in provider
      ref.read(userProvider.notifier).clearUser();

      // Clear current user flag in database
      await userManager.clearCurrentUser();

      // Clear session info cache (prevents stale user data on re-login)
      SessionInfoCache.clearCache();

      // Clear server session
      await ref.read(serverServiceProvider.notifier).clearSession();
    } catch (e) {
      logger.e('[AuthGuard] Error during logout cleanup: $e');
    }

    if (!mounted) return;

    // Show error notification
    CopyableInfoBar.showError(
      context,
      title: 'Sesion expirada',
      message:
          'Su clave API ha expirado o fue revocada. Inicie sesion nuevamente.',
    );

    // Navigate to login
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
