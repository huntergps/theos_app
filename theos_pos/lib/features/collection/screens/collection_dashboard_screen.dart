import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        CollectionConfig,
        CollectionSession,
        CollectionSessionCash,
        SessionState,
        CashType;

import '../../../../core/database/providers.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import 'cash_count_dialog.dart';
import 'widgets/widgets.dart';

class CollectionDashboardScreen extends ConsumerStatefulWidget {
  const CollectionDashboardScreen({super.key});

  @override
  ConsumerState<CollectionDashboardScreen> createState() =>
      _CollectionDashboardScreenState();
}

class _CollectionDashboardScreenState
    extends ConsumerState<CollectionDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load any unsynced local sessions on startup
    Future.microtask(() {
      if (!mounted) return;
      _loadUnsyncedLocalSession();
    });
  }

  /// Loads an unsynced local session into currentSessionProvider if exists
  Future<void> _loadUnsyncedLocalSession() async {
    final currentSession = ref.read(currentSessionProvider);

    // If there's already a session in the provider, don't override
    if (currentSession != null) return;

    try {
      // Use CollectionRepository via provider
      final collectionRepo = ref.read(collectionRepositoryProvider);
      if (collectionRepo == null) {
        logger.d('[Dashboard] ⚠️ CollectionRepository not initialized yet');
        return;
      }

      // Get all local sessions
      final sessions = await collectionRepo.getCollectionSessions();

      // Find the first unsynced, non-closed session
      final unsyncedSession = sessions.cast<CollectionSession?>().firstWhere(
        (s) =>
            s != null &&
            (!s.isSynced || s.id < 0) &&
            s.state != SessionState.closed, // DTO state for repository query
        orElse: () => null,
      );

      if (unsyncedSession != null && context.mounted) {
        logger.d(
          '[Dashboard] 📂 Loading unsynced local session: ${unsyncedSession.name} (id=${unsyncedSession.id})',
        );
        ref.read(currentSessionProvider.notifier).set(unsyncedSession);
      }
    } catch (e) {
      logger.d('[Dashboard] ❌ Error loading unsynced session: $e');
    }
  }

  /// Syncs a local session with Odoo.
  /// Returns true if successful, false otherwise.
  Future<bool> _syncLocalSession(
    BuildContext context,
    CollectionSession localSession,
    CollectionConfig config,
  ) async {
    logger.d(
      '[Dashboard] 🔄 Manual sync triggered for session: ${localSession.name}',
    );

    try {
      final repo = ref.read(collectionRepositoryProvider);
      if (repo == null) {
        throw Exception('No hay conexión con el servidor');
      }

      // Get opening cash details from local DB via CollectionRepository
      final collectionRepo = ref.read(collectionRepositoryProvider);
      if (collectionRepo == null) {
        throw Exception('CollectionRepository no inicializado');
      }
      final openingCash = await collectionRepo.getSessionCashByType(
        localSession.id,
        CashType.opening,
      );

      final openingBalance =
          openingCash?.cashTotal ?? localSession.cashRegisterBalanceStart;

      // Create session in Odoo
      final createdSessionId = await repo.createCollectionSession(
        configId: config.id,
        userId: localSession.userId ?? 2,
        cashRegisterBalanceStart: openingBalance,
        sessionUuid: localSession.sessionUuid,
      );

      logger.d(
        '[Dashboard] ✅ Session created in Odoo with ID: $createdSessionId',
      );

      // Fetch complete session from Odoo
      final odooSession = await repo.fetchSessionFromOdoo(createdSessionId);
      if (odooSession == null) {
        throw Exception('No se pudo obtener la sesión de Odoo');
      }

      // Update local session with Odoo data
      await collectionRepo.updateSessionFromOdooByUuid(
        localSession.sessionUuid!,
        odooSession,
      );

      // Update cash count session ID if exists
      if (openingCash != null) {
        await repo.updateSessionCashLocalSessionId(
          oldSessionId: localSession.id,
          newSessionId: createdSessionId,
        );

        // Sync cash with Odoo
        final cashWithRealId = openingCash.copyWith(
          collectionSessionId: createdSessionId,
        );
        await repo.saveSessionCash(cashWithRealId);
      }

      // Update provider with synced session
      ref.read(currentSessionProvider.notifier).set(odooSession);
      ref.invalidate(collectionConfigsProvider);

      // Show success message
      if (context.mounted) {
        final successDuration = ref.read(successNotificationDurationProvider);
        CopyableInfoBar.showSuccess(
          context,
          title: 'Sincronizado',
          message: 'Sesión ${odooSession.name} sincronizada correctamente',
          durationSeconds: successDuration,
        );
      }

      return true;
    } catch (e) {
      logger.d('[Dashboard] ❌ Sync failed: $e');

      if (context.mounted) {
        final errorDuration = ref.read(errorNotificationDurationProvider);
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'No se pudo sincronizar: $e',
          durationSeconds: errorDuration,
        );
      }

      return false;
    }
  }

  void _refreshConfigs() {
    ref.invalidate(collectionConfigsProvider);
    // Also try to load any unsynced sessions
    _loadUnsyncedLocalSession();
  }

  @override
  Widget build(BuildContext context) {
    final configsAsync = ref.watch(collectionConfigsProvider);
    final currentSession = ref.watch(currentSessionProvider);
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Caja de Cobros'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: _refreshConfigs,
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: spacing.all.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note: Active session info is now shown in the config card below
            // with a "Pendiente de sincronizar" indicator if not synced
            if (currentSession != null) spacing.vertical.lg,

            // Failed Sync Sessions Warning (if exists)
            FailedSyncSessionsCard(),
            spacing.vertical.md,

            // Collection Points Section
            Text('Puntos de Cobro', style: theme.typography.subtitle),
            spacing.vertical.ms,

            configsAsync.when(
              data: (configs) {
                if (configs.isEmpty) {
                  return const InfoBar(
                    title: Text('Sin puntos de cobro'),
                    content: Text(
                      'No tiene puntos de cobro asignados. Contacte al administrador.',
                    ),
                    severity: InfoBarSeverity.warning,
                  );
                }

                // Debug: Log configs
                for (final c in configs) {
                  logger.d(
                    '[Dashboard] Config: ${c.name}, sessionId: ${c.currentSessionId}, state: ${c.currentSessionState}',
                  );
                  logger.d(
                    '[Dashboard] --> userName: ${c.currentSessionUserName}, stateDisplay: ${c.currentSessionStateDisplay}, rescue: ${c.numberOfRescueSession}',
                  );
                }

                return Wrap(
                  spacing: spacing.md,
                  runSpacing: spacing.md,
                  children: configs.map((config) {
                    // Check if there's a local session for this config (not synced with Odoo)
                    final hasLocalSession =
                        currentSession != null &&
                        currentSession.configId == config.id;

                    final isLocalOnly =
                        hasLocalSession &&
                        (!currentSession.isSynced || currentSession.id < 0);

                    return CollectionConfigCard(
                      config: config,
                      isLocalOnly: isLocalOnly,
                      // Pass the local session so the card can display its info
                      localSession: hasLocalSession ? currentSession : null,
                      onOpenSession: () => _openNewSession(context, config),
                      onContinueSession: () {
                        logger.d(
                          '[Dashboard] Continuar sesion: config=${config.name}, sessionId=${config.currentSessionId}, localSessionId=${currentSession?.id}',
                        );
                        // If local session exists, use its ID; otherwise use config's session ID
                        final sessionId = hasLocalSession
                            ? currentSession.id
                            : config.currentSessionId;

                        // ✅ OFFLINE-FIRST: Allow navigation to local sessions (negative IDs)
                        if (sessionId != null) {
                          context.go('/collection/session/$sessionId');
                        } else {
                          CopyableInfoBar.showWarning(
                            context,
                            title: 'Sin sesion activa',
                            message: 'No hay una sesion activa para continuar.',
                          );
                        }
                      },
                      // ✅ Sync callback for local sessions
                      onSyncSession: isLocalOnly && hasLocalSession
                          ? () => _syncLocalSession(
                              context,
                              currentSession,
                              config,
                            )
                          : null,
                    );
                  }).toList(),
                );
              },
              loading: () => Center(
                child: Padding(
                  padding: spacing.all.xl,
                  child: const ProgressRing(),
                ),
              ),
              error: (error, _) => InfoBar(
                title: const Text('Error'),
                content: Text(error.toString()),
                severity: InfoBarSeverity.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sincronizar sesión con Odoo en background
  /// El cash count ya está guardado localmente con ID temporal
  Future<void> _syncSessionWithOdoo(
    CollectionSession localSession,
    CollectionConfig config,
    CollectionSessionCash localCash,
  ) async {
    try {
      logger.d('[Dashboard] 🔄 Sincronizando sesión con Odoo en background...');

      // Check mounted before using ref
      if (!mounted) {
        logger.d('[Dashboard] ⚠️ Widget disposed before sync started');
        return;
      }

      final repo = ref.read(collectionRepositoryProvider);
      if (repo == null) {
        logger.d('[Dashboard] ❌ Repository no disponible para sincronizar');
        logger.d(
          '[Dashboard] 💾 Datos guardados localmente, se sincronizarán después',
        );
        return;
      }

      // 1. Crear sesión en Odoo (pasando el UUID local para mantener consistencia)
      final createdSessionId = await repo.createCollectionSession(
        configId: config.id,
        userId: localSession.userId!,
        cashRegisterBalanceStart: localCash.cashTotal,
        sessionUuid:
            localSession.sessionUuid, // Pasar UUID local para sincronización
      );

      logger.d('[Dashboard] ✅ Sesión creada en Odoo con ID: $createdSessionId');

      // 2. Obtener sesión completa desde Odoo (con nombre real)
      // IMPORTANTE: Usar fetchSessionFromOdoo para NO crear duplicados en DB local
      final odooSession = await repo.fetchSessionFromOdoo(createdSessionId);

      if (odooSession == null) {
        throw Exception(
          'No se pudo obtener la sesión de Odoo después de crearla',
        );
      }

      logger.d(
        '[Dashboard] 📋 Sesión de Odoo: name="${odooSession.name}", state=${odooSession.state}',
      );

      // 3. Actualizar TODOS los datos de la sesión local con los de Odoo (incluyendo nombre)
      // Esto preserva el UUID local y actualiza nombre, estado, etc.
      final collectionRepo = ref.read(collectionRepositoryProvider);
      if (collectionRepo == null) {
        throw Exception('CollectionRepository no inicializado');
      }
      await collectionRepo.updateSessionFromOdooByUuid(
        localSession.sessionUuid!,
        odooSession,
      );
      logger.d(
        '[Dashboard] ✅ Sesión local actualizada con nombre="${odooSession.name}" ID=${odooSession.id}',
      );

      // 4. Actualizar el cash count local con el ID real y sincronizar con Odoo
      final cashWithRealSessionId = localCash.copyWith(
        collectionSessionId: createdSessionId,
      );

      // Actualizar localmente primero (cambiar sessionId temporal por real)
      await repo.updateSessionCashLocalSessionId(
        oldSessionId: localSession.id, // ID temporal
        newSessionId: createdSessionId, // ID real de Odoo
      );

      // Luego sincronizar con Odoo
      await repo.saveSessionCash(cashWithRealSessionId);
      logger.d(
        '[Dashboard] ✅ Detalle de efectivo sincronizado para sesión $createdSessionId',
      );

      // 5. Obtener la sesión actualizada desde la base de datos local (con nombre de Odoo)
      final updatedLocalSession = await collectionRepo
          .getCollectionSessionByUuid(localSession.sessionUuid!);

      logger.d(
        '[Dashboard] 📋 Updated local session: name="${updatedLocalSession?.name}" id=${updatedLocalSession?.id}',
      );

      // 6. Actualizar provider con sesión sincronizada (con nombre real de Odoo)
      // IMPORTANT: Check mounted before using ref to avoid "ref after disposed" error
      if (!mounted) {
        logger.d('[Dashboard] ⚠️ Widget disposed, skipping provider updates');
        return;
      }

      final currentSession = ref.read(currentSessionProvider);
      logger.d(
        '[Dashboard] 🔍 Current session UUID: ${currentSession?.sessionUuid}, Local UUID: ${localSession.sessionUuid}',
      );
      logger.d(
        '[Dashboard] 🔍 Updated session: name="${updatedLocalSession?.name}", state=${updatedLocalSession?.state}',
      );

      // ALWAYS update currentSessionProvider with the synced session
      // The synced session has the real name and correct state from Odoo
      final sessionToUse = updatedLocalSession ?? odooSession;
      logger.d(
        '[Dashboard] 🔄 Updating currentSessionProvider with: name="${sessionToUse.name}", id=${sessionToUse.id}',
      );
      ref.read(currentSessionProvider.notifier).set(sessionToUse);

      // 7. Invalidar providers para refrescar UI con el nombre correcto
      ref.invalidate(sessionByIdProvider(createdSessionId));
      // También invalidar el ID temporal - la próxima lectura obtendrá los datos actualizados
      ref.invalidate(sessionByIdProvider(localSession.id));
      ref.invalidate(collectionConfigsProvider);

      logger.d(
        '[Dashboard] ✅ Sesión sincronizada: ${odooSession.name} (ID: $createdSessionId)',
      );

      // 8. Mostrar notificación de éxito con nombre real
      if (context.mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Sesion sincronizada',
          message: 'Sesion ${odooSession.name} lista',
        );
      }
    } catch (e) {
      logger.d('[Dashboard] ❌ Error sincronizando sesión: $e');
      logger.d(
        '[Dashboard] 💾 Sesión y cash count guardados localmente, se reintentará después',
      );

      if (context.mounted) {
        final warningDuration = ref.read(warningNotificationDurationProvider);
        CopyableInfoBar.showWarning(
          context,
          title: 'Guardado localmente',
          message:
              'La sesion se guardó localmente. Se sincronizará con el servidor cuando haya conexión.',
          durationSeconds: warningDuration,
        );
      }
    }
  }

  Future<void> _openNewSession(
    BuildContext context,
    CollectionConfig config,
  ) async {
    // ✅ Check if there's already a local session for this config
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession != null && currentSession.configId == config.id) {
      // There's already a local session for this config
      if (context.mounted) {
        final warningDuration = ref.read(warningNotificationDurationProvider);
        CopyableInfoBar.showWarning(
          context,
          title: 'Sesión existente',
          message:
              'Ya existe una sesión activa para ${config.name}. Use "Continuar Sesión" en su lugar.',
          durationSeconds: warningDuration,
        );
      }
      return;
    }

    // ✅ Also check in local database for unsynced sessions
    final sessionService = ref.read(sessionServiceProvider);
    if (sessionService == null) return;
    final hasUnsynced = await sessionService.hasUnsyncedSessionForConfig(
      config.id,
    );
    if (hasUnsynced) {
      if (context.mounted) {
        final warningDuration = ref.read(warningNotificationDurationProvider);
        CopyableInfoBar.showWarning(
          context,
          title: 'Sesión pendiente',
          message:
              'Existe una sesión local pendiente de sincronizar para ${config.name}. Por favor espere a que se sincronice o ciérrela primero.',
          durationSeconds: warningDuration,
        );
      }
      return;
    }

    // Show opening cash count dialog (using the same dialog as _registerOpeningCash)
    if (!context.mounted) return;
    final result = await showDialog<CollectionSessionCash>(
      context: context,
      builder: (context) => CashCountDialog(
        title: 'Abrir Sesión - ${config.name}',
        sessionId: null, // No session yet, will be assigned after creation
        sessionState: SessionState.openingControl, // New session state
        cashType: CashType.opening,
        description:
            'Ingrese el efectivo inicial de la caja para abrir la sesión.',
      ),
    );

    if (result != null && context.mounted) {
      try {
        final currentUser = await ref.read(currentUserProvider.future);
        if (currentUser == null) {
          if (context.mounted) {
            final errorDuration = ref.read(errorNotificationDurationProvider);
            CopyableInfoBar.showError(
              context,
              title: 'Error',
              message: 'No se pudo obtener el usuario actual',
              durationSeconds: errorDuration,
            );
          }
          return;
        }

        // 1. Crear sesión localmente primero (UI responsive)
        final localSession = await sessionService.openSession(
          config,
          result.cashTotal, // Use the total from the cash count
          currentUser.id,
          currentUser.name,
        );

        // 2. ✅ OFFLINE-FIRST: Guardar cash count localmente con ID temporal
        final localCash = result.copyWith(
          collectionSessionId: localSession.id, // ID temporal (negativo)
        );
        final repo = ref.read(collectionRepositoryProvider);
        if (repo != null) {
          await repo.saveSessionCashLocally(localCash);
          logger.d(
            '[Dashboard] 💾 Cash count guardado localmente con sessionId temporal: ${localSession.id}',
          );
        }

        // 3. Actualizar provider con sesión local
        ref.read(currentSessionProvider.notifier).set(localSession);

        if (context.mounted) {
          CopyableInfoBar.showInfo(
            context,
            title: 'Sesion creada',
            message: 'Creando sesion en servidor...',
          );

          // Navigate to session con ID temporal
          context.go('/collection/session/${localSession.id}');
        }

        // 4. Sincronizar con Odoo en background (no bloquea UI)
        // Ahora también actualiza el cash count con el ID real de Odoo
        _syncSessionWithOdoo(localSession, config, localCash);
      } catch (e) {
        if (context.mounted) {
          final errorDuration = ref.read(errorNotificationDurationProvider);
          CopyableInfoBar.showError(
            context,
            title: 'Error',
            message: 'No se pudo crear la sesion: $e',
            durationSeconds: errorDuration,
          );
        }
      }
    }
  }
}
