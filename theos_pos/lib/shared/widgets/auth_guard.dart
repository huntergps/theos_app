import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show userManager, UserManagerBusiness;

import '../../core/database/repositories/base_repository.dart';
import '../../core/services/auth_event_service.dart';
import '../../core/services/logger_service.dart';
import '../../features/authentication/services/server_service.dart';
import '../providers/user_provider.dart';
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
