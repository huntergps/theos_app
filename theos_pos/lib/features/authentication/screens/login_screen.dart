import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/odoo_service.dart';
import '../services/server_service.dart';
import '../services/offline_session_attempt_guard.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/app_initializer.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/navigation/route_access_policy.dart';
import '../../../../core/services/auth_event_service.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/managers/manager_providers.dart';
import '../../../../core/theme/spacing.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../shared/widgets/theos_logo.dart';
import '../../../../shared/providers/user_provider.dart';

import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooAuthenticationException, OdooAccessDeniedException;
import 'package:theos_pos_core/theos_pos_core.dart'
    show userManager, User, UserManagerBusiness;

import '../widgets/login_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with WindowListener {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();

  ServerConfig? _selectedServer;
  bool _isLoading = false;
  bool _showPassword = false;
  String _loadingStage = '';
  Timer? _saveDebounceTimer;
  bool _isMaximized = false;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return [
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    ].contains(defaultTargetPlatform);
  }

  @override
  void initState() {
    if (_isDesktop) {
      windowManager.addListener(this);
      unawaited(() async {
        _isMaximized = await windowManager.isMaximized();
      }());
    }
    super.initState();
  }

  @override
  void dispose() {
    _saveDebounceTimer?.cancel();
    if (_isDesktop) {
      windowManager.removeListener(this);
    }
    _apiKeyController.dispose();
    super.dispose();
  }

  /// Save window state with debounce to avoid excessive saves during resize
  void _saveWindowState() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!_isDesktop) return;

      final isMaximized = await windowManager.isMaximized();
      final bounds = await windowManager.getBounds();

      ref
          .read(configServiceProvider.notifier)
          .updateWindowPosition(
            bounds.width,
            bounds.height,
            bounds.topLeft.dx,
            bounds.topLeft.dy,
            isMaximized: isMaximized,
          );
    });
  }

  @override
  void onWindowResized() {
    if (!_isMaximized) {
      _saveWindowState();
    }
  }

  @override
  void onWindowMoved() {
    if (!_isMaximized) {
      _saveWindowState();
    }
  }

  @override
  void onWindowMaximize() {
    _isMaximized = true;
    _saveWindowState();
  }

  @override
  void onWindowUnmaximize() {
    _isMaximized = false;
    _saveWindowState();
  }

  @override
  void onWindowClose() async {
    if (!_isDesktop) return;
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      showDialog(
        context: context,
        builder: (_) {
          return ContentDialog(
            title: const Text('Confirmar cierre'),
            content: const Text(
              '¿Estás seguro de que deseas cerrar la aplicación?',
            ),
            actions: [
              Button(
                child: const Text('No'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              FilledButton(
                child: const Text('Sí'),
                onPressed: () async {
                  Navigator.pop(context);

                  // Save window bounds and maximized state
                  final bounds = await windowManager.getBounds();
                  final isMaximized = await windowManager.isMaximized();

                  // Update config service
                  ref
                      .read(configServiceProvider.notifier)
                      .updateWindowPosition(
                        bounds.width,
                        bounds.height,
                        bounds.topLeft.dx,
                        bounds.topLeft.dy,
                        isMaximized: isMaximized,
                      );

                  windowManager.destroy();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(serverServiceProvider);
    final spacing = ref.watch(themedSpacingProvider);

    // Auto-select first server if none selected
    if (_selectedServer == null && servers.isNotEmpty) {
      final initialServer = servers.first;
      _selectedServer = initialServer;
      final initialApiKey = initialServer.apiKey;
      if (_apiKeyController.text.isEmpty &&
          initialApiKey != null &&
          initialApiKey.isNotEmpty) {
        _apiKeyController.text = initialApiKey;
      }
    }

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobileLayout = constraints.maxWidth < 800;

              if (isMobileLayout) {
                // Mobile Layout (Single Column)
                return Container(
                  color: AppColors.loginBackground,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: spacing.all.lg,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo area
                          TheosLogoName(height: 150, color: Colors.white),
                          spacing.vertical.xl,
                          // Form area
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            padding: spacing.all.lg,
                            decoration: BoxDecoration(
                              color: FluentTheme.of(context)
                                  .scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(spacing.sm),
                            ),
                            child: LoginForm(
                              formKey: _formKey,
                              controller: _apiKeyController,
                              servers: servers,
                              selectedServer: _selectedServer,
                              spacing: spacing,
                              showPassword: _showPassword,
                              isLoading: _isLoading,
                              loadingStage: _loadingStage,
                              onServerChanged: (value) {
                                setState(() {
                                  _selectedServer = value;
                                  if (value?.apiKey != null) {
                                    _apiKeyController.text = value!.apiKey!;
                                  } else {
                                    _apiKeyController.clear();
                                  }
                                });
                              },
                              onTogglePassword: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                              onSubmit: _login,
                              onManageServers: () =>
                                  _showManageServersDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                // Desktop Layout (Split View)
                return Row(
                  children: [
                    // Left Panel
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: AppColors.loginBackground,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TheosLogoName(height: 300, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    // Right Panel
                    Expanded(
                      flex: 2,
                      child: Container(
                        color: FluentTheme.of(context).scaffoldBackgroundColor,
                        padding: EdgeInsets.symmetric(horizontal: spacing.xl),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bienvenido',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  spacing.vertical.sm,
                                  const Text(
                                    'Inicia sesión para continuar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  spacing.vertical.xl,
                                  LoginForm(
                                    formKey: _formKey,
                                    controller: _apiKeyController,
                                    servers: servers,
                                    selectedServer: _selectedServer,
                                    spacing: spacing,
                                    showPassword: _showPassword,
                                    isLoading: _isLoading,
                                    loadingStage: _loadingStage,
                                    onServerChanged: (value) {
                                      setState(() {
                                        _selectedServer = value;
                                        if (value?.apiKey != null) {
                                          _apiKeyController.text =
                                              value!.apiKey!;
                                        } else {
                                          _apiKeyController.clear();
                                        }
                                      });
                                    },
                                    onTogglePassword: () => setState(
                                      () => _showPassword = !_showPassword,
                                    ),
                                    onSubmit: _login,
                                    onManageServers: () =>
                                        _showManageServersDialog(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          // Custom Window Title Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SizedBox(
                height: 50,
                child: Row(
                  children: [
                    const Expanded(
                      child: DragToMoveArea(child: SizedBox.expand()),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: IconButton(
                        icon: Icon(
                          FluentTheme.of(context).brightness == Brightness.dark
                              ? FluentIcons.sunny
                              : FluentIcons.clear_night,
                        ),
                        onPressed: () {
                          final currentMode = ref
                              .read(configServiceProvider)
                              .themeMode;
                          final newMode = currentMode == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                          ref
                              .read(configServiceProvider.notifier)
                              .setThemeMode(newMode);
                        },
                      ),
                    ),
                    if (!kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.windows ||
                            defaultTargetPlatform == TargetPlatform.macOS ||
                            defaultTargetPlatform == TargetPlatform.linux))
                      SizedBox(
                        width: 138,
                        height: 50,
                        child: WindowCaption(
                          brightness: FluentTheme.of(context).brightness,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageServersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          title: const Text('Gestionar Servidores'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: Consumer(
              builder: (context, ref, child) {
                final servers = ref.watch(serverServiceProvider);
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: servers.length,
                        itemBuilder: (context, index) {
                          final server = servers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Card(
                              padding: const EdgeInsets.all(8.0),
                              child: ListTile(
                                leading: const Icon(FluentIcons.cloud),
                                title: Text(
                                  server.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'URL: ${server.url}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'BD: ${server.database}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(FluentIcons.edit),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showServerDialog(
                                          context,
                                          server: server,
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        FluentIcons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => ContentDialog(
                                            title: const Text(
                                              'Eliminar servidor',
                                            ),
                                            content: Text(
                                              '¿Está seguro de que desea eliminar el servidor "${server.name}"? Esta acción no se puede deshacer.',
                                            ),
                                            actions: [
                                              Button(
                                                child: const Text('Cancelar'),
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                              ),
                                              FilledButton(
                                                style: ButtonStyle(
                                                  backgroundColor:
                                                      WidgetStatePropertyAll(
                                                        Colors.red,
                                                      ),
                                                ),
                                                child: const Text('Eliminar'),
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          ref
                                              .read(
                                                serverServiceProvider.notifier,
                                              )
                                              .removeServer(server);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      child: const Text('Agregar Nuevo'),
                      onPressed: () {
                        Navigator.pop(context);
                        _showServerDialog(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            Button(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showServerDialog(
    BuildContext context, {
    ServerConfig? server,
  }) async {
    final nameCtrl = TextEditingController(text: server?.name);
    final urlCtrl = TextEditingController(text: server?.url);
    final dbCtrl = TextEditingController(text: server?.database);
    final apiKeyCtrl = TextEditingController(text: server?.apiKey);

    try {
      await showDialog(
        context: context,
        builder: (context) {
          return ContentDialog(
            title: Text(
              server == null ? 'Agregar Servidor' : 'Editar Servidor',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormBox(
                  controller: nameCtrl,
                  placeholder: 'Nombre (ej. Local)',
                ),
                const SizedBox(height: 8),
                TextFormBox(
                  controller: urlCtrl,
                  placeholder: 'URL (ej. http://localhost:8069)',
                ),
                const SizedBox(height: 8),
                TextFormBox(controller: dbCtrl, placeholder: 'Base de Datos'),
                const SizedBox(height: 8),
                TextFormBox(
                  controller: apiKeyCtrl,
                  placeholder: 'Clave API (Opcional)',
                ),
              ],
            ),
            actions: [
              Button(
                child: const Text('Cancelar'),
                onPressed: () {
                  Navigator.pop(context);
                  // Re-open manage dialog if we were editing/adding from there
                  _showManageServersDialog(context);
                },
              ),
              FilledButton(
                child: const Text('Guardar'),
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty &&
                      urlCtrl.text.isNotEmpty &&
                      dbCtrl.text.isNotEmpty) {
                    final newServer = ServerConfig(
                      name: nameCtrl.text,
                      url: urlCtrl.text,
                      database: dbCtrl.text,
                      apiKey: apiKeyCtrl.text.isNotEmpty
                          ? apiKeyCtrl.text
                          : null,
                    );

                    if (server != null) {
                      ref
                          .read(serverServiceProvider.notifier)
                          .updateServer(server, newServer);
                    } else {
                      ref
                          .read(serverServiceProvider.notifier)
                          .addServer(newServer);
                    }

                    Navigator.pop(context);
                    _showManageServersDialog(context);
                  } else {
                    CopyableInfoBar.showWarning(
                      context,
                      title: 'Datos incompletos',
                      message: 'Por favor complete todos los campos obligatorios (Nombre, URL, Base de Datos).',
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      urlCtrl.dispose();
      dbCtrl.dispose();
      apiKeyCtrl.dispose();
    }
  }

  void _setStage(String stage) {
    if (mounted) setState(() => _loadingStage = stage);
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() != true) {
      logger.d('[LOGIN] ⚠️ Formulario inválido');
      CopyableInfoBar.showWarning(
        context,
        title: 'Datos incompletos',
        message: 'Por favor complete todos los campos requeridos.',
      );
      return;
    }
    if (_selectedServer == null) {
      CopyableInfoBar.showError(
        context,
        title: 'Error de conexion',
        message: 'Selecciona un servidor',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingStage = 'Conectando...';
    });

    final url = _selectedServer!.url;
    final db = _selectedServer!.database;
    final apiKey = _apiKeyController.text.trim();
    var scopeActivated = false;
    var sessionCommitted = false;

    try {
      final odoo = ref.read(odooServiceProvider);
      odoo.setCredentials(url, apiKey, db);

      bool success = false;
      bool isOfflineLogin = false;
      int? authenticatedUserId;
      User? authenticatedUser;

      try {
        _setStage('Verificando credenciales...');
        authenticatedUserId = await odoo.resolveCurrentUserId();
        success = true;
      } on OdooAuthenticationException {
        // HTTP 401 — API key is invalid/expired. Do NOT fall through to offline login.
        logger.w('[LOGIN] 🔑 Authentication failed (HTTP 401)');
        if (mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Clave API invalida',
            message:
                'La clave API proporcionada no es valida o ha expirado. '
                'Verifique sus credenciales e intente nuevamente.',
          );
        }
        return;
      } on OdooAccessDeniedException {
        // HTTP 403 — user lacks permission
        logger.w('[LOGIN] 🚫 Access denied (HTTP 403)');
        if (mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Acceso denegado',
            message:
                'No tiene permisos para acceder a esta base de datos. '
                'Contacte al administrador.',
          );
        }
        return;
      } catch (e) {
        if (!isOfflineFallbackEligible(e)) rethrow;

        // A genuine transport outage may use the already committed local
        // scope. Server/protocol/programming errors are never hidden here.
        logger.d('[LOGIN] 🔴 Connection failed: $e');
        logger.d('[LOGIN] 🔄 Attempting offline login...');

        final offlineResult = await _attemptOfflineLogin(url, db, apiKey);
        if (offlineResult) {
          success = true;
          isOfflineLogin = true;
          scopeActivated = true;
        } else {
          // Re-throw to show error to user
          rethrow;
        }
      }

      if (success && mounted) {
        // If offline login, skip online-only operations
        if (isOfflineLogin) {
          await _completeOfflineLogin(url, db, apiKey);
          sessionCommitted = true;
          return;
        }
        // Update the selected server with the new API key if it changed
        final updatedServer = ServerConfig(
          name: _selectedServer!.name,
          url: url,
          database: db,
          apiKey: apiKey,
        );

        // Update in the list
        await ref.read(serverServiceProvider.notifier).addServer(updatedServer);

        // Save as last used
        await ref
            .read(serverServiceProvider.notifier)
            .saveLastServer(updatedServer);

        // Reset auth event service debounce on successful login
        final authEventService = ref.read(authEventServiceProvider);
        authEventService.reset();

        final resolvedUserId = authenticatedUserId;
        if (resolvedUserId == null || resolvedUserId <= 0) {
          throw StateError('El servidor no devolvio un usuario valido');
        }

        // Open and commit the user-owned scope before any scoped Drift
        // repository is exposed. A failure here aborts login fail-closed.
        await AppInitializer.activateSessionScope(
          baseUrl: url,
          database: db,
          userId: resolvedUserId,
        );
        scopeActivated = true;

        // Initialize app dependencies for the authenticated user scope.
        _setStage('Inicializando datos...');
        logger.d('[LOGIN] 🔧 Initializing AppInitializer...');
        final initResult = await AppInitializer.initialize(
          baseUrl: url,
          apiKey: apiKey,
          database: db,
          authEventService: authEventService,
          userId: resolvedUserId,
        );
        logger.d('[LOGIN] ✅ AppInitializer completed');

        // Set repository providers first so they're available for further queries
        _setStage('Preparando repositorios...');
        logger.d('[LOGIN] 📦 Initializing repository providers...');
        ref.read(odooClientProvider.notifier).set(initResult.odooClient);
        ref
            .read(databaseHelperProvider.notifier)
            .set(initResult.databaseHelper);
        logger.d('[LOGIN] ✅ Repository providers initialized');

        // Initialize model managers with the database (required for userManager, etc.)
        _setStage('Inicializando managers...');
        logger.d('[LOGIN] 🔧 Initializing model managers...');
        final managerQueueStore = ref.read(offlineQueueDataSourceProvider);
        if (managerQueueStore == null) {
          throw StateError('No se pudo inicializar la cola del scope actual');
        }
        await initializeModelManagers(
          client: initResult.odooClient,
          db: ref.read(appDatabaseProvider),
          queueStore: managerQueueStore,
        );
        logger.d('[LOGIN] ✅ Model managers initialized');

        // Invalidate repository providers that capture appDb reference
        // (prevents stale DB connection after server switch)
        ref.invalidate(catalogSyncRepositoryProvider);
        logger.d('[LOGIN] ✅ Repository providers invalidated for new DB');

        // Resolve the partner identity associated with the bearer user.
        int? partnerId;
        String? imStatusAccessToken;

        _setStage('Cargando datos de usuario...');
        // JSON-2 has no webclient session_info. Identity and partner data
        // come from the bearer-authenticated res.users record.
        final userRepo = ref.read(userRepositoryProvider);
        authenticatedUser = userRepo != null
            ? await userRepo.getCurrentUser(knownUserId: resolvedUserId)
            : null;
        final user = authenticatedUser;
        if (user == null) {
          throw StateError('No se pudo cargar la identidad del usuario');
        }
        partnerId = user.partnerId;
        if (partnerId != null) {
          logger.d('[LOGIN] ✅ Partner ID obtained from res.users: $partnerId');
        }

        // Only the current identity and its known group memberships are
        // required to enter. A full user catalog remains an explicit manual
        // sync and must not compete with first-login rendering.
        try {
          final catalogRepo = ref.read(
            authenticatedCatalogSyncRepositoryProvider,
          );
          if (catalogRepo != null) {
            _setStage('Sincronizando permisos...');
            logger.d('[LOGIN] 🔄 Syncing groups + user memberships...');
            await catalogRepo.syncUserGroups(user.id);
            logger.d('[LOGIN] ✅ Groups + memberships synced');
            await ref.read(userProvider.notifier).fetchUser();
          }
        } catch (e) {
          // Permission snapshots are atomic and fail closed. Cached groups can
          // still authorize offline-capable routes when the remote read fails.
          logger.d(
            '[LOGIN] ⚠️ Failed to sync groups; using atomic cached snapshot: $e',
          );
        }

        final finalUser = ref.read(userProvider) ?? user;
        await ref
            .read(userProvider.notifier)
            .setUser(finalUser, isOffline: false);

        // Credential persistence is part of the login commit. Continuing
        // after a keychain failure would appear successful but force another
        // login on the next launch.
        // The offline credential and resumable session are one persistence
        // commit. A keychain/preferences failure rolls both sides back.
        logger.d('[LOGIN] 💾 Committing offline credential and session...');
        await ref
            .read(serverServiceProvider.notifier)
            .commitAuthenticatedSession(
              config: updatedServer,
              userId: finalUser.id,
              partnerId: partnerId,
              imStatusAccessToken: imStatusAccessToken,
            );
        logger.d('[LOGIN] ✅ Credential and session committed');
        sessionCommitted = true;

        // Publish identity only after scope, vault credential and current
        // session have all committed successfully.
        AppRouter.session.value = RouteSessionSnapshot(
          userId: finalUser.id,
          permissions: finalUser.permissions,
          developerMode: ref.read(configServiceProvider).developerMode,
        );

        if (mounted) {
          _setStage('¡Listo!');
          final destination = RouteAccessPolicy.destinationAfterLogin(
            returnTo: GoRouterState.of(context).uri.queryParameters['returnTo'],
            permissions: finalUser.permissions,
            developerMode: ref.read(configServiceProvider).developerMode,
          );
          logger.d('[LOGIN] 🚀 Navigating to $destination...');
          context.go(destination);
          logger.d('[LOGIN] ✅ Navigation completed');
        } else {
          logger.d('[LOGIN] ⚠️ Widget not mounted, skipping navigation');
        }
      } else {
        if (mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Error de conexión',
            message: 'No se pudo conectar al servidor. Verifique los datos.',
          );
        }
      }
    } catch (e) {
      if (scopeActivated && !sessionCommitted) {
        AppRouter.session.value = const RouteSessionSnapshot();
        ref.read(userProvider.notifier).clearUser();
        resetModelManagersSession();
        try {
          await AppInitializer.deactivateSessionScope();
        } catch (rollbackError) {
          logger.e('[LOGIN] Session rollback failed: $rollbackError');
        }
      }
      if (mounted) {
        final message = e.toString().replaceAll('Exception: ', '');
        CopyableInfoBar.showError(
          context,
          title: 'Error de conexión',
          message: message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Attempt to login using locally cached data when offline
  ///
  /// Returns true if offline login is possible, false otherwise.
  /// Offline login requires:
  /// 1. A stored credential matching the server, database, and API key
  /// 2. The user exists in the local database
  Future<bool> _attemptOfflineLogin(
    String url,
    String db,
    String apiKey,
  ) async {
    final attemptGuard = OfflineSessionAttemptGuard(
      AppInitializer.deactivateSessionScope,
    );
    try {
      final serverService = ref.read(serverServiceProvider.notifier);

      // 1. Find stored credential for this API key
      final credential = await serverService.findCredentialAsync(
        serverUrl: url,
        database: db,
        apiKey: apiKey,
      );

      if (credential == null) {
        logger.d('[LOGIN] 🔴 No stored credential found for this API key');
        logger.d('[LOGIN]    This user has never logged in online before');
        return false;
      }

      logger.d(
        '[LOGIN] ✅ Found stored credential for user ID: ${credential.userId}',
      );
      logger.d('[LOGIN]    Last login: ${credential.lastLoginAt}');

      // 2. Activate the user-scoped database before touching local models.
      logger.d('[LOGIN] 📂 Initializing scoped database for offline login...');
      await AppInitializer.activateSessionScope(
        baseUrl: url,
        database: db,
        userId: credential.userId,
        offline: true,
      );

      // 3. Check if the user exists in local database
      final localUser = await userManager.getUser(credential.userId);
      if (localUser == null) {
        logger.d(
          '[LOGIN] 🔴 User ${credential.userId} not found in local database',
        );
        return false;
      }

      logger.d('[LOGIN] ✅ Offline login possible for user: ${localUser.name}');
      attemptGuard.markSucceeded();
      return true;
    } catch (e) {
      logger.e('[LOGIN] 🔴 Error attempting offline login: $e');
      rethrow;
    } finally {
      await attemptGuard.close();
    }
  }

  /// Complete the offline login process
  Future<void> _completeOfflineLogin(
    String url,
    String db,
    String apiKey,
  ) async {
    try {
      logger.d('[LOGIN] 🔌 Completing offline login...');

      final serverService = ref.read(serverServiceProvider.notifier);

      // Get the stored credential to find the user ID
      final credential = await serverService.findCredentialAsync(
        serverUrl: url,
        database: db,
        apiKey: apiKey,
      );

      if (credential == null) {
        throw Exception('No credential found for offline login');
      }

      // Update the selected server
      final updatedServer = ServerConfig(
        name: _selectedServer!.name,
        url: url,
        database: db,
        apiKey: apiKey,
      );

      // Save as last used server
      await serverService.addServer(updatedServer);
      await serverService.saveLastServer(updatedServer);

      // Initialize database helper provider
      logger.d('[LOGIN] 📦 Setting database helper provider...');
      ref.read(databaseHelperProvider.notifier).set(DatabaseHelper.instance);

      // Initialize model managers with the database (required for userManager, etc.)
      logger.d('[LOGIN] 🔧 Initializing model managers (offline)...');
      final managerQueueStore = ref.read(offlineQueueDataSourceProvider);
      if (managerQueueStore == null) {
        throw StateError('No se pudo inicializar la cola del scope offline');
      }
      await initializeModelManagers(
        db: ref.read(appDatabaseProvider),
        queueStore: managerQueueStore,
      );
      ref.invalidate(catalogSyncRepositoryProvider);
      logger.d('[LOGIN] ✅ Model managers initialized');

      // Load the specific user from local database by ID
      final localUser = await userManager.getUser(credential.userId);
      if (localUser != null) {
        logger.d(
          '[LOGIN] 👤 Loading user ${credential.userId} from local database: ${localUser.name}',
        );

        // Mark this user as current in the database
        await userManager.upsertUser(localUser, isCurrent: true);

        // Set user in provider with offline flag
        await ref
            .read(userProvider.notifier)
            .setUser(localUser, isOffline: true);

        logger.d('[LOGIN] ✅ User loaded in offline mode');
      } else {
        throw Exception(
          'User ${credential.userId} not found in local database',
        );
      }

      // Set current session
      await serverService.setCurrentSession(
        updatedServer,
        partnerId: localUser.partnerId,
      );

      // Publish authentication only after the offline session commit. This
      // keeps GoRouter from disposing LoginScreen while persistence is active.
      AppRouter.session.value = RouteSessionSnapshot(
        userId: localUser.id,
        permissions: localUser.permissions,
        developerMode: ref.read(configServiceProvider).developerMode,
      );

      if (mounted) {
        // Show offline mode indicator
        CopyableInfoBar.showWarning(
          context,
          title: 'Modo Offline',
          message: 'Iniciando sesión sin conexión. Algunas funciones pueden no estar disponibles.',
        );

        final destination = RouteAccessPolicy.destinationAfterLogin(
          returnTo: GoRouterState.of(context).uri.queryParameters['returnTo'],
          permissions: localUser.permissions,
          developerMode: ref.read(configServiceProvider).developerMode,
        );
        logger.d('[LOGIN] 🚀 Navigating to $destination (offline mode)...');
        context.go(destination);
        logger.d('[LOGIN] ✅ Offline login completed');
      }
    } catch (e) {
      logger.e('[LOGIN] 🔴 Error completing offline login: $e');
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
