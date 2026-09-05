import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooAuthenticationException, OdooAccessDeniedException;

import '../widgets/theos_logo.dart';

import 'package:window_manager/window_manager.dart';

import '../../core/services/odoo_service.dart';
import '../../features/authentication/services/server_service.dart';
import '../../features/authentication/services/offline_session_attempt_guard.dart';

import '../../core/services/app_initializer.dart';
import '../../core/services/auth_event_service.dart';
import '../../core/navigation/app_router.dart';
import '../../core/navigation/route_access_policy.dart';
import '../../core/services/config_service.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/repository_providers.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../core/managers/managers.dart';
import '../../features/collection/repositories/collection_repository.dart';
import '../../features/reports/repositories/qweb_template_repository.dart';
import '../../features/reports/services/report_service.dart';
import '../providers/user_provider.dart';
import '../providers/report_provider.dart';
import '../../features/reports/providers/qweb_template_repository_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusMessage = '';

  void _setStatus(String message) {
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  @override
  void initState() {
    super.initState();
    logger.d('[SPLASH] 🎬 initState() llamado');

    // Show window after first frame is rendered (desktop only)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      logger.d('[SPLASH] 🎨 Primer frame renderizado');
      // window_manager only works on desktop platforms (Windows, macOS, Linux)
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        logger.d('[SPLASH] 👁️  Mostrando ventana (desktop)...');
        await windowManager.show();
        await windowManager.focus();
        logger.d('[SPLASH] ✅ Ventana mostrada y enfocada');
      } else {
        logger.d(
          '[SPLASH] ℹ️  Plataforma móvil/web - window_manager no aplicable',
        );
      }
    });

    _checkSession();
  }

  Future<void> _checkSession() async {
    logger.d('[SPLASH] ⏳ Iniciando _checkSession()...');

    // Load the last server immediately; the loading indicator already gives
    // users feedback while secure storage and database initialization run.
    final serverService = ref.read(serverServiceProvider.notifier);
    ServerConfig? lastServer;
    try {
      lastServer = await serverService.loadLastServer();
    } catch (error, stackTrace) {
      logger.e(
        '[SPLASH]',
        'No se pudo cargar la sesión persistida',
        error,
        stackTrace,
      );
      await AppInitializer.deactivateSessionScope();
      _goToLogin();
      return;
    }
    logger.d('[SPLASH] ✅ Carga de servidor completada');

    if (!mounted) {
      logger.d('[SPLASH] ⚠️  Widget no está montado, saliendo...');
      return;
    }

    _setStatus('Cargando configuración...');
    logger.d('[SPLASH] 🔍 Servidor cargado: ${lastServer?.url ?? "ninguno"}');

    if (!mounted) return;

    final apiKey = lastServer?.apiKey;
    if (lastServer != null && apiKey != null && apiKey.isNotEmpty) {
      final attemptGuard = OfflineSessionAttemptGuard(
        AppInitializer.deactivateSessionScope,
      );
      try {
        // A committed identity is the only session that may reopen its scoped
        // database. No network request belongs to this normal resume path.
        final storedCredential = await serverService.findCredentialAsync(
          serverUrl: lastServer.url,
          database: lastServer.database,
          apiKey: apiKey,
        );
        if (storedCredential == null) {
          logger.w(
            '[SPLASH] Stored credential is missing or expired; clearing session',
          );
          await serverService.clearSession();
          return;
        }

        if (!await AppInitializer.hasCommittedSessionScope(
          baseUrl: lastServer.url,
          database: lastServer.database,
          userId: storedCredential.userId,
        )) {
          logger.d('[SPLASH] No secure committed session; showing login');
          return;
        }

        _setStatus('Inicializando datos locales...');
        final odoo = ref.read(odooServiceProvider);
        odoo.setCredentials(lastServer.url, apiKey, lastServer.database);

        final initResult = await AppInitializer.initialize(
          baseUrl: lastServer.url,
          apiKey: apiKey,
          database: lastServer.database,
          userId: storedCredential.userId,
          authEventService: ref.read(authEventServiceProvider),
          waitForServerVersion: false,
        );
        await AppInitializer.activateSessionScope(
          baseUrl: lastServer.url,
          database: lastServer.database,
          userId: storedCredential.userId,
          offline: true,
        );
        if (!mounted) return;

        ref.read(odooClientProvider.notifier).set(initResult.odooClient);
        ref
            .read(databaseHelperProvider.notifier)
            .set(initResult.databaseHelper);
        final managerQueueStore = ref.read(offlineQueueDataSourceProvider);
        if (managerQueueStore == null) {
          throw StateError('No se pudo restaurar la cola del scope actual');
        }
        await initializeModelManagers(
          client: initResult.odooClient,
          db: ref.read(appDatabaseProvider),
          queueStore: managerQueueStore,
        );

        _setStatus('Restaurando sesión...');
        final userNotifier = ref.read(userProvider.notifier);
        var user = await userNotifier.restoreCachedUser();
        var permissionSnapshot = ref.read(permissionSnapshotProvider);

        // Fail closed only for an incomplete local scope. This recovery path is
        // intentionally minimal: one user read and the known group memberships,
        // never a complete catalog synchronization.
        if (user == null ||
            permissionSnapshot.phase != PermissionSnapshotPhase.ready) {
          try {
            final userRepo = ref.read(userRepositoryProvider);
            final catalogRepo = ref.read(
              authenticatedCatalogSyncRepositoryProvider,
            );
            final remoteUser = await userRepo?.getCurrentUser(
              knownUserId: storedCredential.userId,
            );
            if (remoteUser == null || catalogRepo == null) {
              throw StateError('No se pudo restaurar la identidad local');
            }
            await catalogRepo.syncUserGroups(remoteUser.id);
            await userNotifier.setUser(remoteUser, isOffline: false);
            user = ref.read(userProvider);
            permissionSnapshot = ref.read(permissionSnapshotProvider);
          } on OdooAuthenticationException catch (error) {
            logger.w('[SPLASH] API key inválida o expirada: $error');
            return;
          } on OdooAccessDeniedException catch (error) {
            logger.w('[SPLASH] Acceso denegado: $error');
            return;
          } catch (error) {
            logger.w('[SPLASH] Sesión local incompleta: $error');
            return;
          }
        }

        if (user == null ||
            user.id <= 0 ||
            permissionSnapshot.phase != PermissionSnapshotPhase.ready) {
          logger.w(
            '[SPLASH] Identity or permission snapshot unavailable; showing login',
          );
          return;
        }

        final developerMode = ref.read(configServiceProvider).developerMode;
        if (serverService.currentSession == null) {
          await serverService.setCurrentSession(
            lastServer,
            partnerId: user.partnerId,
          );
        }
        if (!mounted) return;

        // Route authorization becomes visible only after the persisted server
        // session has been restored successfully.
        AppRouter.session.value = RouteSessionSnapshot(
          userId: user.id,
          permissions: user.permissions,
          developerMode: developerMode,
        );

        final reportService = ref.read(reportServiceProvider);
        final templateRepo = ref.read(qwebTemplateRepositoryProvider);
        final collectionRepo = ref.read(collectionRepositoryProvider);
        final currentSessionNotifier = ref.read(
          currentSessionProvider.notifier,
        );
        final destination = RouteAccessPolicy.destinationAfterLogin(
          returnTo: GoRouterState.of(context).uri.queryParameters['returnTo'],
          permissions: user.permissions,
          developerMode: developerMode,
        );

        _setStatus('Cargando punto de venta...');
        logger.d(
          '[SPLASH] 🚀 Sesión local restaurada; navegando a $destination',
        );
        attemptGuard.markSucceeded();
        context.go(destination);

        unawaited(
          _finishLocalWarmup(
            reportService: reportService,
            templateRepo: templateRepo,
            collectionRepo: collectionRepo,
            currentSessionNotifier: currentSessionNotifier,
            userId: user.id,
          ),
        );
        return;
      } catch (error, stackTrace) {
        logger.e(
          '[SPLASH]',
          'No se pudo restaurar la sesión offline',
          error,
          stackTrace,
        );
      } finally {
        if (!attemptGuard.succeeded) {
          try {
            await attemptGuard.close();
          } catch (error, stackTrace) {
            logger.e(
              '[SPLASH]',
              'No se pudo desactivar el scope offline fallido',
              error,
              stackTrace,
            );
          }
          _goToLogin();
        }
      }
      return;
    } else {
      logger.d('[SPLASH] ℹ️  No hay servidor guardado');
    }

    if (mounted) {
      logger.d('[SPLASH] 🔑 Navegando a login (sin credenciales guardadas)');
      _goToLogin();
    }
  }

  /// Keeps a guarded deep-link destination across the session recovery and
  /// explicit-login paths. Login validates the value again with
  /// [RouteAccessPolicy], so unknown/external destinations still fall back to
  /// Home.
  void _goToLogin() {
    if (!mounted) return;
    final returnTo = GoRouterState.of(context).uri.queryParameters['returnTo'];
    final location = Uri(
      path: AppRouter.login,
      queryParameters: returnTo == null || returnTo.isEmpty
          ? null
          : {'returnTo': returnTo},
    );
    context.go(location.toString());
  }

  Future<void> _finishLocalWarmup({
    required ReportService reportService,
    required QwebTemplateRepository? templateRepo,
    required CollectionRepository? collectionRepo,
    required CurrentSession currentSessionNotifier,
    required int userId,
  }) async {
    if (templateRepo != null) {
      try {
        await reportService.loadTemplatesFromDatabase(templateRepo);
        logger.d('[SPLASH] ✅ Cached report templates ready');
      } catch (error) {
        logger.w('[SPLASH] Cached report warmup skipped: $error');
      }
    }

    if (collectionRepo != null) {
      try {
        final activeSession = await collectionRepo.getActiveUserSession(userId);
        if (activeSession != null) currentSessionNotifier.set(activeSession);
      } catch (error) {
        logger.w('[SPLASH] Active collection session warmup skipped: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // En móvil, extender contenido debajo de la barra de estado del sistema
    final isMobile =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    return Container(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // Padding superior solo en móvil para empujar contenido debajo de status bar
          if (isMobile) SizedBox(height: MediaQuery.of(context).padding.top),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TheosLogo(size: 150, animate: true),
                  const SizedBox(height: 16),
                  TheosNameSvg(height: 40),
                  const SizedBox(height: 20),
                  const ProgressBar(),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusMessage,
                      key: ValueKey(_statusMessage),
                      style: FluentTheme.of(context).typography.caption
                          ?.copyWith(
                            color: FluentTheme.of(context).inactiveColor,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
