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

import '../../core/services/app_initializer.dart';
import '../../core/services/auth_event_service.dart';
import '../../core/database/providers.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/managers/managers.dart';
import '../../core/providers/data_layer_provider.dart';
import '../../features/sync/providers/sync_provider.dart';
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
          (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux)) {
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

    // Minimum splash duration
    logger.d('[SPLASH] ⏱️  Esperando 2 segundos (splash mínimo)...');
    await Future.delayed(const Duration(seconds: 2));
    logger.d('[SPLASH] ✅ Espera de 2 segundos completada');

    if (!mounted) {
      logger.d('[SPLASH] ⚠️  Widget no está montado, saliendo...');
      return;
    }

    _setStatus('Cargando configuración...');
    logger.d('[SPLASH] 🔍 Cargando último servidor...');
    final serverService = ref.read(serverServiceProvider.notifier);
    final lastServer = await serverService.loadLastServer();

    if (!mounted) return;

    if (lastServer != null && lastServer.apiKey != null) {
      _setStatus('Conectando a ${lastServer.url}...');
      logger.d('[SPLASH] ✅ Servidor encontrado: ${lastServer.url}');
      final odoo = ref.read(odooServiceProvider);
      odoo.setCredentials(
        lastServer.url,
        lastServer.apiKey!,
        lastServer.database,
      );
      logger.d('[SPLASH] 🔐 Credenciales configuradas');

      // OFFLINE-FIRST: Always initialize app dependencies regardless of connection
      _setStatus('Inicializando base de datos...');
      logger.d('[SPLASH] 🗄️ Inicializando AppInitializer (offline-first)...');
      final authEventService = ref.read(authEventServiceProvider);
      final initResult = await AppInitializer.initialize(
        baseUrl: lastServer.url,
        apiKey: lastServer.apiKey!,
        database: lastServer.database,
        authEventService: authEventService,
      );
      logger.d('[SPLASH] ✅ AppInitializer completado');

      if (!mounted) return;

      // Set repository providers
      logger.d('[SPLASH] 📦 Initializing repository providers...');
      ref.read(odooClientProvider.notifier).set(initResult.odooClient);
      ref.read(databaseHelperProvider.notifier).set(initResult.databaseHelper);
      logger.d('[SPLASH] ✅ Repository providers initialized');

      // Initialize ModelManagers with ModelRegistry
      _setStatus('Inicializando servicios...');
      logger.d('[SPLASH] 🔧 Initializing ModelManagers...');
      initializeModelManagers();
      logger.d('[SPLASH] ✅ ModelManagers initialized and registered');

      // Initialize OdooDataLayer context (progressive migration)
      // Non-blocking: failures here don't affect existing flow
      try {
        logger.d('[SPLASH] 🧩 Initializing OdooDataLayer context...');
        await initializeDataContext(
          ref,
          sessionId: '${lastServer.database}@${lastServer.url}',
          label: 'POS - ${lastServer.database}',
          baseUrl: lastServer.url,
          database: lastServer.database,
          apiKey: lastServer.apiKey!,
        );
        logger.d('[SPLASH] ✅ OdooDataLayer context initialized');
      } catch (e) {
        logger.d('[SPLASH] ⚠️ OdooDataLayer init failed (non-critical): $e');
      }

      // OFFLINE-FIRST: Initialize Report Templates from Database
      // This ensures we can print offline immediately after startup
      _setStatus('Cargando plantillas de reportes...');
      logger.d('[SPLASH] 📄 Loading cached report templates...');
      final reportService = ref.read(reportServiceProvider);
      final templateRepo = ref.read(qwebTemplateRepositoryProvider);

      if (templateRepo != null) {
        await reportService.loadTemplatesFromDatabase(templateRepo);
        logger.d('[SPLASH] ✅ Report templates loaded');
      } else {
        logger.d(
          '[SPLASH] ⚠️ Failed to load report templates: Repository is null',
        );
      }

      if (!mounted) return;

      // Try to connect to Odoo (but don't block if it fails)
      bool isOnline = false;
      Map<String, dynamic>? sessionInfo;
      int? partnerId;
      String? imStatusAccessToken;

      try {
        _setStatus('Verificando conexión con Odoo...');
        logger.d('[SPLASH] 🌐 Probando conexión con Odoo...');
        isOnline = await odoo.testConnection();
        if (isOnline) {
          logger.d('[SPLASH] ✅ Conexión exitosa - modo online');

          // Retry unsynced sessions in background (only if online)
          logger.d('[SPLASH] 🔄 Reintentando sesiones no sincronizadas...');
          final maxRetries = ref.read(maxSyncRetriesProvider);
          logger.d('[SPLASH] 📊 Límite de reintentos configurado: $maxRetries');
          final collectionRepo = ref.read(collectionRepositoryProvider);
          if (collectionRepo != null) {
            collectionRepo
                .retryUnsyncedSessions(maxRetries: maxRetries)
                .then((syncedCount) {
                  if (syncedCount > 0) {
                    logger.d(
                      '[SPLASH] ✅ Se sincronizaron $syncedCount sesiones pendientes',
                    );
                  }
                })
                .catchError((e) {
                  logger.d(
                    '[SPLASH] ⚠️ Error al reintentar sincronización: $e',
                  );
                });
          }

          // IMPORTANT: Load current user FIRST (before sync) to avoid database contention
          // This ensures is_current_user flag is properly set
          _setStatus('Cargando usuario actual...');
          logger.d(
            '[SPLASH] 👤 Cargando usuario actual (antes de sincronización)...',
          );
          try {
            final userRepo = ref.read(userRepositoryProvider);
            if (userRepo != null) {
              final user = await userRepo.getCurrentUser();
              if (user != null) {
                partnerId = user.partnerId;
                logger.d(
                  '[SPLASH] ✅ Usuario cargado: ${user.name}, partnerId: $partnerId',
                );

                // Load user permissions/groups (offline-first)
                logger.d('[SPLASH] 🔐 Cargando permisos de usuario...');
                try {
                  // First try to load from local cache
                  var permissions = await userRepo.getCurrentUserGroups();
                  logger.d(
                    '[SPLASH] 📦 Permisos locales: ${permissions.length} grupos',
                  );

                  // If no local permissions, sync from Odoo
                  if (permissions.isEmpty) {
                    _setStatus('Sincronizando permisos de usuario...');
                    logger.d(
                      '[SPLASH] ⚠️ Sin permisos locales, sincronizando desde Odoo...',
                    );
                    final catalogRepo = ref.read(catalogSyncRepositoryProvider);
                    if (catalogRepo != null) {
                      // Sync groups from Odoo (res.groups)
                      logger.d(
                        '[SPLASH] 🔄 Sincronizando grupos (res.groups)...',
                      );
                      await catalogRepo.syncGroups();
                      logger.d('[SPLASH] ✅ Grupos sincronizados');

                      // Sync user-group relationships for current user
                      logger.d(
                        '[SPLASH] 🔄 Sincronizando permisos del usuario ${user.id}...',
                      );
                      await catalogRepo.syncUserGroups(user.id);
                      logger.d('[SPLASH] ✅ Permisos del usuario sincronizados');

                      // Reload permissions from local DB
                      permissions = await userRepo.getCurrentUserGroups();
                      logger.d(
                        '[SPLASH] ✅ Permisos recargados: ${permissions.length} grupos',
                      );
                    }
                  }

                  if (permissions.isNotEmpty) {
                    logger.d(
                      '[SPLASH] 📋 Grupos: ${permissions.take(5).join(", ")}${permissions.length > 5 ? "..." : ""}',
                    );
                  }
                  // Update user provider with permissions so menu can use them
                  await ref.read(userProvider.notifier).fetchUser();
                  logger.d('[SPLASH] ✅ UserProvider actualizado con permisos');

                  // Load active collection session for the user
                  logger.d('[SPLASH] 💼 Cargando sesión de cobranza activa...');
                  try {
                    final collectionRepo = ref.read(
                      collectionRepositoryProvider,
                    );
                    if (collectionRepo != null) {
                      // User.id IS the Odoo user ID in the Freezed model
                      // (the local autoIncrement id only exists in the Drift table)
                      final activeSession = await collectionRepo
                          .getActiveUserSession(user.id);
                      if (activeSession != null) {
                        ref
                            .read(currentSessionProvider.notifier)
                            .set(activeSession);
                        logger.d(
                          '[SPLASH] ✅ Sesión activa cargada: ${activeSession.name} (id=${activeSession.id})',
                        );
                      } else {
                        logger.d(
                          '[SPLASH] ℹ️ No hay sesión de cobranza activa para el usuario',
                        );
                      }
                    }
                  } catch (e) {
                    logger.d(
                      '[SPLASH] ⚠️ Error cargando sesión de cobranza: $e',
                    );
                  }
                } catch (e) {
                  logger.d('[SPLASH] ⚠️ Error sincronizando permisos: $e');
                }
              }
            }
          } catch (e) {
            logger.d('[SPLASH] ⚠️ Error cargando usuario: $e');
          }

          // Sync master catalogs in background using SyncNotifier (only if online)
          // This ensures the sync progress is visible in SyncScreen
          _setStatus('Sincronizando catálogos...');
          logger.d(
            '[SPLASH] 📦 Iniciando sincronización de catálogos via SyncNotifier...',
          );

          // Reset any previous sync errors before starting
          await ref.read(syncProvider.notifier).resetAllErrors();

          ref
              .read(syncProvider.notifier)
              .syncAll()
              .then((_) {
                logger.d('[SPLASH] ✅ Sincronización de catálogos completada');
              })
              .catchError((e) {
                logger.d('[SPLASH] ⚠️ Error sincronizando catálogos: $e');
              });

          // Get session_info for presence token (only if online)
          logger.d('[SPLASH] 🔍 Obteniendo session_info para presencia...');
          try {
            sessionInfo = await initResult.odooClient.getSessionInfo();

            if (sessionInfo != null) {
              logger.d(
                '[SPLASH] 📄 session_info obtenido: ${sessionInfo.keys.toList()}',
              );

              // Extract partner_id from session_info if not already set
              if (partnerId == null) {
                if (sessionInfo['partner_id'] is List &&
                    sessionInfo['partner_id'].isNotEmpty) {
                  partnerId = sessionInfo['partner_id'][0] as int?;
                } else if (sessionInfo['partner_id'] is int) {
                  partnerId = sessionInfo['partner_id'] as int;
                }

                // If partner_id is null, try to get it from storeData.Store.self_partner
                if (partnerId == null && sessionInfo.containsKey('storeData')) {
                  final storeData =
                      sessionInfo['storeData'] as Map<String, dynamic>?;
                  if (storeData != null && storeData.containsKey('Store')) {
                    final store = storeData['Store'] as Map<String, dynamic>?;
                    if (store != null && store.containsKey('self_partner')) {
                      partnerId = store['self_partner'] as int?;
                      logger.d(
                        '[SPLASH] 👤 Partner ID encontrado en storeData.Store.self_partner: $partnerId',
                      );
                    }
                  }
                }
              }

              // Extract im_status_access_token
              imStatusAccessToken =
                  sessionInfo['im_status_access_token'] as String?;

              // If not at top level, try to get it from storeData.res.partner
              if (imStatusAccessToken == null &&
                  sessionInfo.containsKey('storeData')) {
                final storeData =
                    sessionInfo['storeData'] as Map<String, dynamic>?;
                if (storeData != null && storeData.containsKey('res.partner')) {
                  final resPartner = storeData['res.partner'] as List?;
                  if (resPartner != null && resPartner.isNotEmpty) {
                    for (final partner in resPartner) {
                      if (partner is Map<String, dynamic>) {
                        final token =
                            partner['im_status_access_token'] as String?;
                        if (token != null) {
                          imStatusAccessToken = token;
                          logger.d(
                            '[SPLASH] 🔑 Token encontrado en storeData.res.partner',
                          );
                          break;
                        }
                      }
                    }
                  }
                }
              }

              logger.d('[SPLASH] 👤 Partner ID from session_info: $partnerId');
              logger.d(
                '[SPLASH] 🔑 IM Status Token: ${imStatusAccessToken != null ? "presente" : "ausente"}',
              );
            }
          } catch (e) {
            logger.d('[SPLASH] ⚠️ Error obteniendo session_info: $e');
          }
        } else {
          _setStatus('Sin conexión - modo offline');
          logger.d('[SPLASH] ⚠️ Sin conexión a Odoo - modo offline');
        }
      } on OdooAuthenticationException catch (e) {
        // HTTP 401 — API key invalid/expired. Redirect to login, don't go offline.
        logger.w('[SPLASH] 🔑 API key inválida o expirada: $e');
        if (mounted) {
          context.go('/login');
        }
        return;
      } on OdooAccessDeniedException catch (e) {
        // HTTP 403 — access denied. Redirect to login.
        logger.w('[SPLASH] 🚫 Acceso denegado: $e');
        if (mounted) {
          context.go('/login');
        }
        return;
      } catch (e) {
        // Network/connection error — true offline mode
        logger.d('[SPLASH] ⚠️ Error de conexión (modo offline): $e');
        isOnline = false;
      }

      if (!mounted) return;

      // Set current session (works offline with saved data)
      logger.d('[SPLASH] 🔐 Guardando sesión actual...');
      await serverService.setCurrentSession(
        lastServer,
        lastServer.apiKey!,
        partnerId: partnerId,
        imStatusAccessToken: imStatusAccessToken,
      );
      logger.d(
        '[SPLASH] ✅ Sesión guardada (online: $isOnline, partner_id: $partnerId)',
      );

      // OFFLINE-FIRST: Always navigate to home if we have credentials
      _setStatus('Cargando punto de venta...');
      logger.d(
        '[SPLASH] 🚀 Navegando a home (${isOnline ? "online" : "offline"})...',
      );
      if (mounted) {
        context.go('/');
      }
      return;
    } else {
      logger.d('[SPLASH] ℹ️  No hay servidor guardado');
    }

    if (mounted) {
      logger.d('[SPLASH] 🔑 Navegando a login (sin credenciales guardadas)');
      context.go('/login');
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
                      style: FluentTheme.of(context).typography.caption?.copyWith(
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
