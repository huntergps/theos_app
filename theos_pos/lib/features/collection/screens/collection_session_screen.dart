import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSession, CollectionSessionCash, SessionState, CashType;

import '../../../../core/database/providers.dart';
import '../../../../core/services/config_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/platform/global_notification_service.dart';
import '../providers/collection_session_provider.dart';
import '../../../../shared/widgets/common/chip_is_local.dart';
import 'cash_count_dialog.dart';
import 'session_info_card.dart';
import 'stat_button_row.dart';
import 'state_chip.dart';
import 'collection_session/tabs/tabs.dart';
import 'collection_session/widgets/close_session_confirm_dialog.dart';
import '../widgets/session_validation_dialog.dart';

/// Tag para logs de esta pantalla
const String _tag = '[CollectionSessionScreen]';

/// Pantalla de detalle de sesion de cobranza
///
/// Muestra la informacion completa de una sesion de cobranza,
/// incluyendo:
/// - Informacion general de la sesion
/// - Estadisticas de cobros
/// - Tabs con resumen de cierre, conteo manual, retiros, depositos, cheques, documentos y notas
///
/// Utiliza [CollectionSessionNotifier] para manejar toda la logica de negocio,
/// manteniendo la UI limpia y enfocada en la presentacion.
class CollectionSessionScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const CollectionSessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<CollectionSessionScreen> createState() =>
      _CollectionSessionScreenState();
}

class _CollectionSessionScreenState
    extends ConsumerState<CollectionSessionScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    logger.d(_tag, 'Initializing screen for session: ${widget.sessionId}');
    // Inicializar el notifier con el sessionId
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(collectionSessionProvider.notifier)
          .initialize(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Verificar si el notifier esta listo
    final isReady = ref.watch(collectionSessionReadyProvider);

    if (!isReady) {
      logger.d(_tag, 'Notifier not ready, showing loading state');
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    // Observar el estado del notifier
    final sessionState = ref.watch(collectionSessionProvider);

    // Observar la sesion actual del provider global (para mantener compatibilidad)
    final currentSession = ref.watch(currentSessionProvider);

    // Escuchar cambios para manejar redirecciones y mensajes
    ref.listen<CollectionSessionScreenState>(
      collectionSessionProvider,
      (previous, next) {
        _handleStateChanges(previous, next);
      },
    );

    // Mostrar loading mientras se carga
    if (sessionState.isLoading && sessionState.session == null) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    // Manejar error sin sesion
    if (sessionState.hasError && sessionState.session == null) {
      return _buildErrorScreen(context, sessionState.errorMessage!);
    }

    // Obtener la sesion a mostrar
    CollectionSession? session = sessionState.session;

    // Fallback a currentSession si la sesion del estado es null
    if (session == null && currentSession != null) {
      if (currentSession.id == widget.sessionId ||
          (widget.sessionId < 0 && !currentSession.isSynced)) {
        logger.d(
          _tag,
          'Using currentSession as fallback: ${currentSession.name}',
        );
        session = currentSession;
      }
    }

    // Sesion no encontrada
    if (session == null) {
      logger.w(_tag, 'Session ${widget.sessionId} is null, redirecting');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/collection');
        }
      });

      return _buildNotFoundScreen(context);
    }

    // Verificar si la sesion fue sincronizada y tiene nuevo ID
    if (session.id != widget.sessionId && session.id > 0) {
      logger.d(
        _tag,
        'Session synced, redirecting from ${widget.sessionId} to ${session.id}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/collection/session/${session!.id}');
        }
      });

      return _buildSyncingRedirectScreen(context);
    }

    // Usar la sesion mas actualizada
    var displaySession = session;
    if (currentSession != null &&
        currentSession.sessionUuid == session.sessionUuid &&
        currentSession.isSynced == true &&
        currentSession.name != session.name) {
      logger.d(
        _tag,
        'Using currentSession with updated name: "${currentSession.name}"',
      );
      displaySession = currentSession;
    }

    return _buildSessionContent(context, theme, displaySession, sessionState);
  }

  /// Maneja los cambios de estado para mostrar mensajes y redirecciones
  void _handleStateChanges(
    CollectionSessionScreenState? previous,
    CollectionSessionScreenState next,
  ) {
    // Mostrar mensaje de exito
    if (next.operationSuccess && next.successMessage != null) {
      _showSuccessMessage(next.successMessage!);
      ref
          .read(collectionSessionProvider.notifier)
          .clearSuccessMessage();
    }

    // Mostrar mensaje de error
    if (next.hasError && previous?.errorMessage != next.errorMessage) {
      _showErrorMessage(next.errorMessage!);
    }

    // Manejar redireccion despues de sincronizacion
    if (next.hasRedirect && context.mounted) {
      final newId = next.newSessionId!;
      logger.i(_tag, 'Redirecting to synced session: $newId');

      ref.read(collectionSessionProvider.notifier).clearRedirect();

      if (next.session != null) {
        ref.read(currentSessionProvider.notifier).set(next.session);
      }
      ref.invalidate(sessionByIdProvider(widget.sessionId));
      ref.invalidate(collectionConfigsProvider);

      context.go('/collection/session/$newId');
    }
  }

  /// Muestra un mensaje de exito
  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ref.showSuccessNotification(context, title: 'Exito', message: message);
  }

  /// Muestra un mensaje de error
  void _showErrorMessage(String message) {
    if (!mounted) return;

    ref.showErrorNotification(context, title: 'Error de cobranza', message: message);
  }

  /// Construye la pantalla de error
  Widget _buildErrorScreen(BuildContext context, String error) {
    logger.e(_tag, 'Error loading session ${widget.sessionId}: $error');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.go('/collection');
      }
    });

    return ScaffoldPage(
      header: PageHeader(
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => context.go('/collection'),
        ),
        title: const Text('Error'),
      ),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error al cargar la sesion: $error'),
            const SizedBox(height: 16),
            const ProgressRing(),
          ],
        ),
      ),
    );
  }

  /// Construye la pantalla de sesion no encontrada
  Widget _buildNotFoundScreen(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => context.go('/collection'),
        ),
        title: const Text('Sesion no encontrada'),
      ),
      content: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48),
            SizedBox(height: 16),
            Text('La sesion fue eliminada o no existe'),
            SizedBox(height: 16),
            ProgressRing(),
          ],
        ),
      ),
    );
  }

  /// Construye la pantalla de redireccion despues de sincronizar
  Widget _buildSyncingRedirectScreen(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(title: Text('Actualizando sesion...')),
      content: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 16),
            Text('Sesion sincronizada, actualizando...'),
          ],
        ),
      ),
    );
  }

  /// Construye el contenido principal de la pantalla
  Widget _buildSessionContent(
    BuildContext context,
    FluentThemeData theme,
    CollectionSession session,
    CollectionSessionScreenState sessionState,
  ) {
    final appConfig = ref.read(configServiceProvider);
    // Construir formato datetime basado en el formato de fecha configurado
    final dateTimeFormat = _buildDateTimeFormat(appConfig.dateFormat);
    final dateFormat = DateFormat(dateTimeFormat, 'es');

    return ScaffoldPage(
      header: _buildHeader(context, theme, session, sessionState),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SessionInfoCard(session: session, dateFormat: dateFormat),
            const SizedBox(height: 6),
            StatButtonsRow(session: session),
            const SizedBox(height: 16),
            _buildTabView(session),
          ],
        ),
      ),
    );
  }

  /// Construye el header de la pantalla
  Widget _buildHeader(
    BuildContext context,
    FluentThemeData theme,
    CollectionSession session,
    CollectionSessionScreenState sessionState,
  ) {
    return PageHeader(
      leading: IconButton(
        icon: const Icon(FluentIcons.back),
        onPressed: () => context.go('/collection'),
      ),
      title: Row(
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: theme.typography.subtitle,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      session.configName ?? '-',
                      style: theme.typography.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!session.isSynced) ...[
                      const SizedBox(width: 8),
                      SyncPendingChip(
                        onSync: () => _handleSync(session),
                        style: SyncPendingStyle.text,
                        label: 'Sin sincronizar',
                        syncingLabel: 'Sincronizando...',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StateChip(state: session.state.toString().split('.').last),
        ],
      ),
      commandBar: _buildCommandBar(sessionState, session),
    );
  }

  /// Construye la barra de comandos
  Widget _buildCommandBar(
    CollectionSessionScreenState sessionState,
    CollectionSession session,
  ) {
    return CommandBar(
      mainAxisAlignment: MainAxisAlignment.end,
      primaryItems: [
        CommandBarButton(
          icon: sessionState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          onPressed: sessionState.isProcessing ? null : _handleRefresh,
        ),
        if (session.state != SessionState.closed)
          CommandBarButton(
            icon: sessionState.isRegisteringOpeningCash
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.money),
            label: const Text('Registrar Fondo'),
            onPressed: sessionState.isProcessing
                ? null
                : () => _handleRegisterOpeningCash(session),
          ),
        if (session.state == SessionState.opened ||
            session.state == SessionState.closingControl)
          CommandBarButton(
            icon: sessionState.isRegisteringClosingCash
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.calculator),
            label: const Text('Registrar Efectivo'),
            onPressed: sessionState.isProcessing
                ? null
                : () => _handleRegisterClosingCash(session),
          ),
        CommandBarButton(
          icon: sessionState.isClosingSession
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Icon(FluentIcons.completed),
          label: const Text('Cerrar Sesion'),
          onPressed: sessionState.isProcessing
              ? null
              : () => _handleCloseSession(session),
        ),
      ],
    );
  }

  /// Construye el TabView con todas las tabs
  Widget _buildTabView(CollectionSession session) {
    // Calcular altura basada en el tamaño de pantalla (menos header, info card, etc.)
    final screenHeight = MediaQuery.of(context).size.height;
    final tabViewHeight = (screenHeight - 280).clamp(400.0, double.infinity);
    return SizedBox(
      height: tabViewHeight,
          child: TabView(
            currentIndex: _selectedTab,
            onChanged: (index) => setState(() => _selectedTab = index),
            tabs: [
              Tab(
                text: const Text('Resumen de Cierre'),
                icon: const Icon(FluentIcons.calculator_multiply),
                body: ResumenCierreTab(session: session),
              ),
              Tab(
                text: const Text('Conteo Manual'),
                icon: const Icon(FluentIcons.edit),
                body: ConteoManualTab(session: session),
              ),
              Tab(
                text: Text('Retiros (${session.cashOutCount})'),
                icon: const Icon(FluentIcons.money),
                body: CashOutsTab(sessionId: widget.sessionId),
              ),
              Tab(
                text: Text('Depositos (${session.depositCount})'),
                icon: const Icon(FluentIcons.bank),
                body: DepositsTab(sessionId: widget.sessionId),
              ),
              Tab(
                text: Text('Cheques (${session.chequeRecibidoCount})'),
                icon: const Icon(FluentIcons.page),
                body: ChequesTab(session: session),
              ),
              Tab(
                text: Text('Anticipos (${session.advanceCount})'),
                icon: const Icon(FluentIcons.money),
                body: AdvancesTab(session: session),
              ),
              Tab(
                text: Text('Cobros (${session.paymentCount})'),
                icon: const Icon(FluentIcons.payment_card),
                body: PaymentsTab(session: session),
              ),
              Tab(
                text: const Text('Documentos'),
                icon: const Icon(FluentIcons.document_set),
                body: DocumentosTab(session: session),
              ),
              Tab(
                text: const Text('Notas'),
                icon: const Icon(FluentIcons.quick_note),
                body: NotasTab(session: session),
              ),
            ],
          ),
    );
  }

  // ============================================================================
  // HANDLERS - Delegan la logica al Notifier
  // ============================================================================

  /// Maneja la sincronizacion de la sesion
  Future<bool> _handleSync(CollectionSession session) async {
    logger.d(_tag, 'Manual sync triggered for session: ${session.name}');

    try {
      final configs = await ref.read(collectionConfigsProvider.future);
      final config = configs.firstWhere(
        (c) => c.id == session.configId,
        orElse: () => throw Exception('Configuracion no encontrada'),
      );

      final notifier = ref.read(collectionSessionProvider.notifier);

      final result = await notifier.syncSession(session, config);

      if (result is OperationSuccess<CollectionSession>) {
        final syncedSession = result.data;
        if (syncedSession != null) {
          ref.read(currentSessionProvider.notifier).set(syncedSession);
          ref.invalidate(sessionByIdProvider(widget.sessionId));
          ref.invalidate(collectionConfigsProvider);
        }
        return true;
      }
      return false;
    } catch (e) {
      logger.e(_tag, 'Error getting config for sync', e);
      _showErrorMessage('No se pudo obtener la configuracion: $e');
      return false;
    }
  }

  /// Maneja el refresco de la sesion
  Future<void> _handleRefresh() async {
    logger.d(_tag, 'Refresh triggered');

    final notifier = ref.read(collectionSessionProvider.notifier);

    await notifier.refreshSession();

    ref.invalidate(sessionByIdProvider(widget.sessionId));
    ref.invalidate(collectionConfigsProvider);
  }

  /// Maneja el registro de fondo de apertura
  Future<void> _handleRegisterOpeningCash(CollectionSession session) async {
    logger.d(_tag, 'Register opening cash triggered');

    final notifier = ref.read(collectionSessionProvider.notifier);

    final existingCash = await notifier.getExistingCashDetails(
      CashType.opening,
    );

    if (!mounted) return;
    final result = await showDialog<CollectionSessionCash>(
      context: context,
      builder: (context) => CashCountDialog(
        title: 'Registrar Fondo de Apertura',
        sessionId: session.id,
        sessionState: session.state,
        cashType: CashType.opening,
        description: 'Ingrese el efectivo inicial de la caja.',
        initialCash: existingCash,
      ),
    );

    if (result != null && mounted) {
      final opResult = await notifier.registerOpeningCash(result);

      if (opResult is OperationSuccess<CollectionSession>) {
        final updatedSession = opResult.data;
        if (updatedSession != null) {
          final currentSession = ref.read(currentSessionProvider);
          if (currentSession?.id == session.id) {
            ref.read(currentSessionProvider.notifier).set(updatedSession);
          }
          ref.invalidate(sessionByIdProvider(session.id));
        }
      }
    }
  }

  /// Maneja el registro de efectivo de cierre
  Future<void> _handleRegisterClosingCash(CollectionSession session) async {
    logger.d(_tag, 'Register closing cash triggered');

    final notifier = ref.read(collectionSessionProvider.notifier);

    final existingCash = await notifier.getExistingCashDetails(
      CashType.closing,
    );

    if (!mounted) return;
    final result = await showDialog<CollectionSessionCash>(
      context: context,
      builder: (context) => CashCountDialog(
        title: 'Registrar Efectivo de Cierre',
        sessionId: session.id,
        sessionState: session.state,
        cashType: CashType.closing,
        description: 'Ingrese el efectivo final de la caja.',
        initialCash: existingCash,
      ),
    );

    if (result != null && mounted) {
      final opResult = await notifier.registerClosingCash(result);

      if (opResult is OperationSuccess<CollectionSession>) {
        final updatedSession = opResult.data;
        if (updatedSession != null) {
          final currentSession = ref.read(currentSessionProvider);
          if (currentSession?.id == session.id) {
            ref.read(currentSessionProvider.notifier).set(updatedSession);
          }
          ref.invalidate(sessionByIdProvider(session.id));
        }
      }
    }
  }

  /// Maneja el cierre de la sesion
  Future<void> _handleCloseSession(CollectionSession session) async {
    logger.d(_tag, 'Close session triggered');

    // Paso 1: Confirmación básica
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CloseSessionConfirmDialog(session: session),
    );

    if (confirmed != true || !mounted) return;

    // Paso 2: Validación de supervisor (con resumen y notas)
    final validationResult = await SessionValidationDialog.show(
      context: context,
      session: session,
    );

    if (validationResult != null &&
        validationResult.success &&
        mounted) {
      // La sesión fue cerrada por el diálogo de validación
      final currentSession = ref.read(currentSessionProvider);
      if (currentSession?.id == session.id) {
        ref.read(currentSessionProvider.notifier).set(null);
      }
      ref.invalidate(sessionByIdProvider(session.id));
      ref.invalidate(collectionConfigsProvider);

      ref.showSuccessNotification(
        context,
        title: 'Sesión cerrada',
        message:
            validationResult.message ??
            'La sesión ha sido cerrada correctamente',
      );
    }
  }

  /// Construye un formato de fecha/hora basado en el formato de fecha base
  String _buildDateTimeFormat(String baseFormat) {
    if (baseFormat.contains('H') ||
        baseFormat.contains('h') ||
        (baseFormat.contains('m') && baseFormat.contains('a'))) {
      return baseFormat;
    }
    if (baseFormat == 'dd/MM/yyyy') {
      return 'dd/MM/yyyy HH:mm';
    } else if (baseFormat == 'MM/dd/yyyy') {
      return 'MM/dd/yyyy h:mm a';
    } else if (baseFormat == 'yyyy-MM-dd') {
      return 'yyyy-MM-dd HH:mm';
    } else if (baseFormat == 'd MMM, yyyy') {
      return 'd MMM, yyyy h:mm a';
    }
    return '$baseFormat HH:mm';
  }
}
