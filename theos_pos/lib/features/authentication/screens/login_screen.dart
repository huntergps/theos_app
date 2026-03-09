import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/odoo_service.dart';
import '../services/server_service.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/app_initializer.dart';
import '../../../../core/services/auth_event_service.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/services/platform/device_service.dart';
import '../../../../core/services/platform/server_database_service.dart'
    show AppServerDatabaseService;
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/form/form_fields.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../shared/widgets/theos_logo.dart';
import '../../../../shared/providers/user_provider.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooAuthenticationException, OdooAccessDeniedException;
import 'package:theos_pos_core/theos_pos_core.dart'
    show userManager, UserManagerBusiness;

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
      _selectedServer = servers.first;
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
                              color: FluentTheme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(spacing.sm),
                            ),
                            child: _buildLoginForm(context, servers, spacing),
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
                          children: [TheosLogoName(height: 300, color: Colors.white)],
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
                                  _buildLoginForm(context, servers, spacing),
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

  Widget _buildLoginForm(
    BuildContext context,
    List<ServerConfig> servers,
    ThemedSpacing spacing,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormComboBox<ServerConfig>(
            label: 'Servidor',
            value: _selectedServer,
            items: servers.map((e) {
              return ComboBoxItem(
                value: e,
                child: Text('${e.name} (${e.url})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedServer = value;
                if (value != null && value.apiKey != null) {
                  _apiKeyController.text = value.apiKey!;
                } else {
                  _apiKeyController.clear();
                }
              });
            },
            placeholder: 'Selecciona un servidor',
          ),
          spacing.vertical.md,

          if (_selectedServer != null) ...[
            FormTextField(
              label: 'Base de Datos',
              placeholder: _selectedServer!.database,
              readOnly: true,
              enabled: false,
            ),
            spacing.vertical.md,
          ],

          FormTextField(
            label: 'Clave API',
            controller: _apiKeyController,
            placeholder: 'Ingresa tu Clave API',
            obscureText: !_showPassword,
            prefix: Padding(
              padding: EdgeInsets.only(left: spacing.sm),
              child: const Icon(FluentIcons.lock),
            ),
            suffix: IconButton(
              icon: Icon(_showPassword ? FluentIcons.view : FluentIcons.hide),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),

          spacing.vertical.lg,

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _login,
              child: Padding(
                padding: spacing.symmetric.vSm(),
                child: _isLoading
                    ? const ProgressRing(activeColor: Colors.white)
                    : const Text('Conectar'),
              ),
            ),
          ),

          spacing.vertical.ml,
          Center(
            child: HyperlinkButton(
              child: const Text('Gestionar Servidores'),
              onPressed: () {
                _showManageServersDialog(context);
              },
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
                                      onPressed: () {
                                        ref
                                            .read(
                                              serverServiceProvider.notifier,
                                            )
                                            .removeServer(server);
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

  void _showServerDialog(BuildContext context, {ServerConfig? server}) {
    showDialog(
      context: context,
      builder: (context) {
        final nameCtrl = TextEditingController(text: server?.name);
        final urlCtrl = TextEditingController(text: server?.url);
        final dbCtrl = TextEditingController(text: server?.database);
        final apiKeyCtrl = TextEditingController(text: server?.apiKey);

        return ContentDialog(
          title: Text(server == null ? 'Agregar Servidor' : 'Editar Servidor'),
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
                    apiKey: apiKeyCtrl.text.isNotEmpty ? apiKeyCtrl.text : null,
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
                    message:
                        'Por favor complete todos los campos obligatorios (Nombre, URL, Base de Datos).',
                  );
                }
              },
            ),
          ],
        );
      },
    );
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
        title: 'Error',
        message: 'Selecciona un servidor',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final url = _selectedServer!.url;
    final db = _selectedServer!.database;
    final apiKey = _apiKeyController.text.trim();

    try {
      final odoo = ref.read(odooServiceProvider);
      odoo.setCredentials(url, apiKey, db);

      bool success = false;
      bool isOfflineLogin = false;

      try {
        success = await odoo.testConnection();
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
        // Network/connection error - try offline login
        logger.d('[LOGIN] 🔴 Connection failed: $e');
        logger.d('[LOGIN] 🔄 Attempting offline login...');

        final offlineResult = await _attemptOfflineLogin(url, db, apiKey);
        if (offlineResult) {
          success = true;
          isOfflineLogin = true;
        } else {
          // Re-throw to show error to user
          rethrow;
        }
      }

      if (success && mounted) {
        // If offline login, skip online-only operations
        if (isOfflineLogin) {
          await _completeOfflineLogin(url, db, apiKey);
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

        // Initialize app dependencies with force re-init for fresh credentials
        logger.d('[LOGIN] 🔧 Initializing AppInitializer...');
        final initResult = await AppInitializer.initialize(
          baseUrl: url,
          apiKey: apiKey,
          database: db,
          forceReinitialize: true, // Always force re-init on login
          authEventService: authEventService,
        );
        logger.d('[LOGIN] ✅ AppInitializer completed');

        // Set repository providers first so they're available for further queries
        logger.d('[LOGIN] 📦 Initializing repository providers...');
        ref.read(odooClientProvider.notifier).set(initResult.odooClient);
        ref
            .read(databaseHelperProvider.notifier)
            .set(initResult.databaseHelper);
        logger.d('[LOGIN] ✅ Repository providers initialized');

        // Get partner_id from session_info for WebSocket
        int? partnerId;
        String? imStatusAccessToken;

        try {
          logger.d('[LOGIN] 📄 Getting session_info to extract partner_id...');
          final sessionInfo = await initResult.odooClient.getSessionInfo();

          if (sessionInfo != null) {
            // Extract partner_id (can be int or [id, name])
            if (sessionInfo['partner_id'] is List &&
                (sessionInfo['partner_id'] as List).isNotEmpty) {
              partnerId = (sessionInfo['partner_id'] as List)[0] as int?;
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
                    '[LOGIN] 👤 Partner ID found in storeData.Store.self_partner: $partnerId',
                  );
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
                          '[LOGIN] 🔑 Token found in storeData.res.partner',
                        );
                        break;
                      }
                    }
                  }
                }
              }
            }

            logger.d('[LOGIN] 👤 Partner ID from session_info: $partnerId');
            logger.d(
              '[LOGIN] 🔑 IM Status Token: ${imStatusAccessToken != null ? "present" : "absent"}',
            );
          }

          // Get partner_id from res.users if not available from session_info
          if (partnerId == null) {
            logger.d(
              '[LOGIN] 👤 Partner ID not available in session_info, getting from res.users...',
            );
            final userRepo = ref.read(userRepositoryProvider);
            final user = userRepo != null
                ? await userRepo.getCurrentUser()
                : null;
            if (user != null && user.partnerId != null) {
              partnerId = user.partnerId;
              logger.d(
                '[LOGIN] ✅ Partner ID obtained from res.users: $partnerId',
              );

              // Sync ALL users and groups for offline support
              try {
                final catalogRepo = ref.read(catalogSyncRepositoryProvider);
                if (catalogRepo != null) {
                  logger.d(
                    '[LOGIN] 🔄 Syncing all users for offline support...',
                  );
                  await catalogRepo.syncUsers();
                  logger.d('[LOGIN] ✅ All users synced');

                  logger.d('[LOGIN] 🔄 Syncing all groups...');
                  await catalogRepo.syncGroups();
                  logger.d('[LOGIN] ✅ All groups synced');
                }
              } catch (e) {
                // Non-blocking: sync failure shouldn't prevent login
                logger.d(
                  '[LOGIN] ⚠️ Failed to sync users/groups (will use cached): $e',
                );
              }

              // Store credential for offline login
              try {
                logger.d('[LOGIN] 💾 Storing credential for offline login...');
                await ref
                    .read(serverServiceProvider.notifier)
                    .storeCredential(
                      serverUrl: url,
                      database: db,
                      apiKey: apiKey,
                      userId: user.id,
                    );
                logger.d('[LOGIN] ✅ Credential stored for user ${user.id}');
              } catch (e) {
                logger.d('[LOGIN] ⚠️ Failed to store credential: $e');
              }
            } else {
              logger.d('[LOGIN] ⚠️ Could not obtain partner_id from res.users');
            }
          }
        } catch (e) {
          logger.d('[LOGIN] ⚠️ Error getting partner_id: $e');
        }

        // Get real session_id for WebSocket authentication (required on Web)
        String? realSessionId;
        if (kIsWeb) {
          logger.d(
            '[LOGIN] 🌐 Web platform: Getting real session_id for WebSocket...',
          );
          final sessionResult = await initResult.odooClient
              .authenticateSession();
          if (sessionResult != null) {
            realSessionId = sessionResult.sessionId;
            logger.d('[LOGIN] ✅ Got real session_id for WebSocket');
          } else {
            logger.d(
              '[LOGIN] ⚠️ Could not get real session_id, WebSocket may not work',
            );
          }
        }

        // Set current session for WebSocket authentication (with partner_id)
        // On Web, use real session_id; on native, use API key (cookies handle it)
        final sessionIdForWebSocket = realSessionId ?? apiKey;
        logger.d(
          '[LOGIN] 🔐 Saving current session with partner_id: $partnerId...',
        );
        await ref
            .read(serverServiceProvider.notifier)
            .setCurrentSession(
              updatedServer,
              sessionIdForWebSocket,
              partnerId: partnerId,
              imStatusAccessToken: imStatusAccessToken,
            );
        logger.d('[LOGIN] ✅ Session saved with partner_id');

        if (mounted) {
          logger.d('[LOGIN] 🚀 Navigating to home screen...');
          context.go('/');
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
    try {
      final serverService = ref.read(serverServiceProvider.notifier);

      // 1. Find stored credential for this API key
      final credential = serverService.findCredential(
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

      // 2. Initialize the database for this server
      logger.d('[LOGIN] 📂 Initializing database for offline login...');
      final serverConfig = ServerConfig(
        name: 'Offline Server',
        url: url,
        database: db,
      );
      final deviceService = createDeviceService();
      final serverDbService = AppServerDatabaseService(deviceService);
      final dbName = serverDbService.generateDatabaseName(serverConfig);
      await DatabaseHelper.initializeForServer(dbName);

      // 3. Check if the user exists in local database
      final localUser = await userManager.getUser(credential.userId);
      if (localUser == null) {
        logger.d(
          '[LOGIN] 🔴 User ${credential.userId} not found in local database',
        );
        return false;
      }

      logger.d('[LOGIN] ✅ Offline login possible for user: ${localUser.name}');
      return true;
    } catch (e) {
      logger.e('[LOGIN] 🔴 Error attempting offline login: $e');
      return false;
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
      final credential = serverService.findCredential(
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
        apiKey, // Use API key as session ID in offline mode
        partnerId: localUser.partnerId,
      );

      if (mounted) {
        // Show offline mode indicator
        CopyableInfoBar.showWarning(
          context,
          title: 'Modo Offline',
          message:
              'Iniciando sesión sin conexión. Algunas funciones pueden no estar disponibles.',
        );

        logger.d('[LOGIN] 🚀 Navigating to home screen (offline mode)...');
        context.go('/');
        logger.d('[LOGIN] ✅ Offline login completed');
      }
    } catch (e) {
      logger.e('[LOGIN] 🔴 Error completing offline login: $e');
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de inicio offline',
          message: 'No se pudo iniciar sesión sin conexión: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
