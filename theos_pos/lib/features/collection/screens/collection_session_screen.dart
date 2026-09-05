import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSession, CollectionSessionCash, SessionState, CashType;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/providers.dart';
import '../../../../core/providers/base_notifier.dart' show OperationSuccess;
import '../../../../core/services/config_service.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

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
  late final ProviderSubscription<CollectionSessionScreenState>
  _sessionStateSubscription;

  @override
  void initState() {
    super.initState();
    // Register once: registering ref.listen in build accumulated listeners
    // after every rebuild and could trigger duplicate redirects/toasts.
    _sessionStateSubscription = ref.listenManual<CollectionSessionScreenState>(
      collectionSessionProvider,
      (previous, next) => _handleStateChanges(previous, next),
    );
    logger.d(_tag, 'Initializing screen for session: ${widget.sessionId}');
    // Inicializar el notifier con el sessionId
    Future.microtask(() {
      if (!mounted) return;
      ref.read(collectionSessionProvider.notifier).initialize(widget.sessionId);
    });
  }

  @override
  void dispose() {
    _sessionStateSubscription.close();
    super.dispose();
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

    // Mostrar loading mientras se carga
    if (sessionState.isLoading && sessionState.session == null) {
      return const ScaffoldPage(content: Center(child: ProgressRing()));
    }

    // Manejar error sin sesión
    if (sessionState.hasError && sessionState.session == null) {
      return _buildErrorScreen(context, sessionState.errorMessage!);
    }

    // Obtener la sesión a mostrar
    CollectionSession? session = sessionState.session;

    // Fallback a currentSession si la sesión del estado es null
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
      ref.read(collectionSessionProvider.notifier).clearSuccessMessage();
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

    ref.showErrorNotification(
      context,
      title: 'Error de cobranza',
      message: message,
    );
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
        leading: Tooltip(
          message: 'Volver',
          child: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () => context.go('/collection'),
          ),
        ),
        title: const Text('Error'),
      ),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text('Error al cargar la sesión: $error'),
            const SizedBox(height: 16),
            const ProgressRing(),
          ],
        ),
      ),
    );
  }

  /// Construye la pantalla de sesión no encontrada
  Widget _buildNotFoundScreen(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        leading: Tooltip(
          message: 'Volver',
          child: IconButton(
            icon: const Icon(FluentIcons.back),
            onPressed: () => context.go('/collection'),
          ),
        ),
        title: const Text('Sesión no encontrada'),
      ),
      content: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48),
            SizedBox(height: 16),
            Text('La sesión fue eliminada o no existe'),
            SizedBox(height: 16),
            ProgressRing(),
          ],
        ),
      ),
    );
  }

  /// Construye la pantalla de redirección después de sincronizar
  Widget _buildSyncingRedirectScreen(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(title: Text('Actualizando sesión...')),
      content: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProgressRing(),
            SizedBox(height: 16),
            Text('Sesión sincronizada, actualizando...'),
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
      content: LayoutBuilder(
        builder: (context, constraints) {
          final compactLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape &&
              MediaQuery.sizeOf(context).height <= 560;
          // In short landscape the page itself owns the scroll. The tab body
          // gets the remaining viewport instead of a fixed 400px minimum.
          final padding = compactLandscape ? 8.0 : 16.0;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SessionInfoCard(session: session, dateFormat: dateFormat),
              SizedBox(height: compactLandscape ? 4 : 6),
              StatButtonsRow(session: session),
              SizedBox(height: compactLandscape ? 8 : 16),
              if (compactLandscape)
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, tabConstraints) => _buildTabView(
                      session,
                      compactLandscape: true,
                      availableHeight: tabConstraints.maxHeight,
                    ),
                  ),
                )
              else
                _buildTabView(session),
            ],
          );
          if (compactLandscape) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: SizedBox(height: constraints.maxHeight, child: content),
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: content,
          );
        },
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
      leading: Tooltip(
        message: 'Volver',
        child: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => context.go('/collection'),
        ),
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
        if (session.state == SessionState.opened ||
            session.state == SessionState.paused)
          CommandBarButton(
            icon: Icon(
              session.state == SessionState.paused
                  ? FluentIcons.play
                  : FluentIcons.pause,
            ),
            label: Text(
              session.state == SessionState.paused ? 'Reanudar' : 'Pausar',
            ),
            onPressed: sessionState.isProcessing
                ? null
                : () => _handleTogglePause(session),
          ),
        if (session.state == SessionState.openingControl ||
            session.state == SessionState.opened)
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
        if (session.state == SessionState.opened ||
            session.state == SessionState.closingControl)
          CommandBarButton(
            icon: sessionState.isClosingSession
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.completed),
            label: const Text('Cerrar Sesión'),
            onPressed: sessionState.isProcessing
                ? null
                : () => _handleCloseSession(session),
          ),
      ],
    );
  }

  /// Construye el TabView agrupado en 3 tabs logicas:
  ///   1. Efectivo  — Resumen de cierre + Contar billetes y monedas + Retiros
  ///   2. Cobros    — Anticipos + Cobros + Cheques + Depositos
  ///   3. Documentos y Notas — Documentos + Notas
  Widget _buildTabView(
    CollectionSession session, {
    bool compactLandscape = false,
    double? availableHeight,
  }) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Keep the tab within the page viewport in short landscape. The previous
    // 400px floor caused an overflow on 480px/landscape windows.
    final reservedHeight = compactLandscape ? 150.0 : 280.0;
    final minimumHeight = compactLandscape ? 160.0 : 400.0;
    final calculatedHeight = availableHeight ?? (screenHeight - reservedHeight);
    final tabViewHeight = calculatedHeight.clamp(minimumHeight, 900.0);
    // Altura disponible para el cuerpo de cada tab (menos la barra de tabs ~42 px)
    final tabBodyHeight = tabViewHeight - 42;

    return SizedBox(
      height: tabViewHeight,
      child: TabView(
        currentIndex: _selectedTab,
        onChanged: (index) => setState(() => _selectedTab = index),
        tabs: [
          // ----------------------------------------------------------------
          // TAB 1 — EFECTIVO
          // ----------------------------------------------------------------
          Tab(
            text: const Text('Efectivo'),
            icon: const Icon(FluentIcons.money),
            body: _EfectivoTab(
              session: session,
              sessionId: widget.sessionId,
              bodyHeight: tabBodyHeight,
            ),
          ),

          // ----------------------------------------------------------------
          // TAB 2 — COBROS
          // ----------------------------------------------------------------
          Tab(
            text: Text(
              'Cobros'
              '${_cobrosTotal(session) > 0 ? " (${_cobrosTotal(session)})" : ""}',
            ),
            icon: const Icon(FluentIcons.payment_card),
            body: _CobrosTab(
              session: session,
              sessionId: widget.sessionId,
              bodyHeight: tabBodyHeight,
            ),
          ),

          // ----------------------------------------------------------------
          // TAB 3 — DOCUMENTOS Y NOTAS
          // ----------------------------------------------------------------
          Tab(
            text: const Text('Documentos y Notas'),
            icon: const Icon(FluentIcons.document_set),
            body: _DocumentosNotasTab(session: session),
          ),
        ],
      ),
    );
  }

  /// Total combinado de cobros visibles en el badge del tab
  int _cobrosTotal(CollectionSession session) =>
      session.paymentCount + session.advanceCount;

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
        orElse: () => throw Exception('Configuración no encontrada'),
      );

      final notifier = ref.read(collectionSessionProvider.notifier);

      final result = await notifier.syncSession(session, config);

      if (result is OperationSuccess<CollectionSession>) {
        final syncedSession = result.data;
        if (syncedSession != null) {
          ref.read(currentSessionProvider.notifier).set(syncedSession);
          ref.invalidate(collectionConfigsProvider);
        }
        return true;
      }
      return false;
    } catch (e) {
      logger.e(_tag, 'Error getting config for sync', e);
      _showErrorMessage('No se pudo obtener la configuración: $e');
      return false;
    }
  }

  /// Maneja el refresco de la sesion
  Future<void> _handleRefresh() async {
    logger.d(_tag, 'Refresh triggered');

    final notifier = ref.read(collectionSessionProvider.notifier);

    await notifier.refreshSession();

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
        }
      }
    }
  }

  Future<void> _handleTogglePause(CollectionSession session) async {
    final result = await ref
        .read(collectionSessionProvider.notifier)
        .togglePause();
    if (!mounted || result is! OperationSuccess<CollectionSession>) return;
    final updated = result.data;
    if (updated == null) return;
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession?.id == session.id) {
      ref.read(currentSessionProvider.notifier).set(updated);
    }
  }

  /// Maneja el cierre de la sesion
  Future<void> _handleCloseSession(CollectionSession session) async {
    logger.d(_tag, 'Close session triggered');

    // Paso 1: Verificar si hay efectivo de cierre registrado
    if (session.state == SessionState.opened ||
        session.state == SessionState.closingControl) {
      final notifier = ref.read(collectionSessionProvider.notifier);
      final closingCash = await notifier.getExistingCashDetails(
        CashType.closing,
      );

      if (closingCash == null && mounted) {
        // No se ha registrado efectivo de cierre — advertir al supervisor
        final decision = await showDialog<_CloseWithoutCountDecision>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _NoClosingCashDialog(session: session),
        );

        if (!mounted) return;

        if (decision == null) {
          // El usuario cerró el diálogo sin elegir
          return;
        } else if (decision == _CloseWithoutCountDecision.registerCash) {
          // Abrir flujo de registro de efectivo de cierre
          await _handleRegisterClosingCash(session);
          return;
        }
        // decision == continueWithoutCount → continúa hacia la confirmación normal
      }
    }

    if (!mounted) return;

    // Paso 2: Confirmación básica
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

    if (validationResult != null && validationResult.success && mounted) {
      // La sesión fue cerrada por el diálogo de validación
      final currentSession = ref.read(currentSessionProvider);
      if (currentSession?.id == session.id) {
        ref.read(currentSessionProvider.notifier).set(null);
      }
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

// ============================================================================
// WIDGETS PRIVADOS — TABS AGRUPADAS
// ============================================================================

/// Altura minima garantizada para secciones con lista scrollable
const double _kSectionListHeight = 320.0;

/// Espaciado entre expanders dentro de una tab
const double _kExpanderSpacing = 8.0;

/// Decoracion comun para el header de sub-seccion con badge de conteo
Widget _buildSectionHeader(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Color iconColor,
  int? count,
}) {
  final theme = FluentTheme.of(context);
  return Row(
    children: [
      Icon(icon, size: 16, color: iconColor),
      const SizedBox(width: 8),
      Text(title, style: theme.typography.bodyStrong),
      if (count != null && count > 0) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: theme.typography.caption?.copyWith(
              color: iconColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ],
  );
}

// ----------------------------------------------------------------------------
// TAB 1 — EFECTIVO
// Agrupa: Resumen de Cierre + Contar Billetes y Monedas + Retiros
// ----------------------------------------------------------------------------
class _EfectivoTab extends StatefulWidget {
  final CollectionSession session;
  final int sessionId;
  final double bodyHeight;

  const _EfectivoTab({
    required this.session,
    required this.sessionId,
    required this.bodyHeight,
  });

  @override
  State<_EfectivoTab> createState() => _EfectivoTabState();
}

class _EfectivoTabState extends State<_EfectivoTab> {
  bool _resumenExpanded = true;
  bool _conteoExpanded = false;
  bool _retirosExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final cashOutCount = widget.session.cashOutCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Resumen de Cierre ----
          Expander(
            initiallyExpanded: _resumenExpanded,
            onStateChanged: (open) => setState(() => _resumenExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.calculator_multiply,
              title: 'Resumen de Cierre',
              iconColor: theme.accentColor,
            ),
            content: ResumenCierreTab(session: widget.session),
          ),

          const SizedBox(height: _kExpanderSpacing),

          // ---- Contar Billetes y Monedas ----
          Expander(
            initiallyExpanded: _conteoExpanded,
            onStateChanged: (open) => setState(() => _conteoExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.edit,
              title: 'Contar Billetes y Monedas',
              iconColor: Colors.teal,
            ),
            content: ConteoManualTab(session: widget.session),
          ),

          const SizedBox(height: _kExpanderSpacing),

          // ---- Retiros de Efectivo ----
          Expander(
            initiallyExpanded: _retirosExpanded,
            onStateChanged: (open) => setState(() => _retirosExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.money,
              title: 'Retiros de Efectivo',
              iconColor: AppColors.danger,
              count: cashOutCount,
            ),
            content: SizedBox(
              height: _kSectionListHeight,
              child: CashOutsTab(sessionId: widget.sessionId),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// TAB 2 — COBROS
// Agrupa: Anticipos + Cobros + Cheques + Depositos
// ----------------------------------------------------------------------------
class _CobrosTab extends StatefulWidget {
  final CollectionSession session;
  final int sessionId;
  final double bodyHeight;

  const _CobrosTab({
    required this.session,
    required this.sessionId,
    required this.bodyHeight,
  });

  @override
  State<_CobrosTab> createState() => _CobrosTabState();
}

class _CobrosTabState extends State<_CobrosTab> {
  bool _cobrosExpanded = true;
  bool _anticiposExpanded = false;
  bool _chequesExpanded = false;
  bool _depositosExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final paymentCount = widget.session.paymentCount;
    final advanceCount = widget.session.advanceCount;
    final chequeCount = widget.session.chequeRecibidoCount;
    final depositCount = widget.session.depositCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Cobros Registrados ----
          Expander(
            initiallyExpanded: _cobrosExpanded,
            onStateChanged: (open) => setState(() => _cobrosExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.payment_card,
              title: 'Cobros Registrados',
              iconColor: theme.accentColor,
              count: paymentCount,
            ),
            content: SizedBox(
              height: _kSectionListHeight,
              child: PaymentsTab(session: widget.session),
            ),
          ),

          const SizedBox(height: _kExpanderSpacing),

          // ---- Anticipos ----
          Expander(
            initiallyExpanded: _anticiposExpanded,
            onStateChanged: (open) => setState(() => _anticiposExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.money,
              title: 'Anticipos',
              iconColor: Colors.orange,
              count: advanceCount,
            ),
            content: SizedBox(
              height: _kSectionListHeight,
              child: AdvancesTab(session: widget.session),
            ),
          ),

          const SizedBox(height: _kExpanderSpacing),

          // ---- Cheques Recibidos ----
          Expander(
            initiallyExpanded: _chequesExpanded,
            onStateChanged: (open) => setState(() => _chequesExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.page,
              title: 'Cheques Recibidos',
              iconColor: Colors.blue,
              count: chequeCount,
            ),
            content: ChequesTab(session: widget.session),
          ),

          const SizedBox(height: _kExpanderSpacing),

          // ---- Depositos Bancarios ----
          Expander(
            initiallyExpanded: _depositosExpanded,
            onStateChanged: (open) => setState(() => _depositosExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.bank,
              title: 'Depósitos Bancarios',
              iconColor: Colors.purple,
              count: depositCount,
            ),
            content: SizedBox(
              height: _kSectionListHeight,
              child: DepositsTab(sessionId: widget.sessionId),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// TAB 3 — DOCUMENTOS Y NOTAS
// Agrupa: Documentos + Notas
// ----------------------------------------------------------------------------
class _DocumentosNotasTab extends StatefulWidget {
  final CollectionSession session;

  const _DocumentosNotasTab({required this.session});

  @override
  State<_DocumentosNotasTab> createState() => _DocumentosNotasTabState();
}

class _DocumentosNotasTabState extends State<_DocumentosNotasTab> {
  bool _documentosExpanded = true;
  bool _notasExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Documentos ----
          Expander(
            initiallyExpanded: _documentosExpanded,
            onStateChanged: (open) =>
                setState(() => _documentosExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.document_set,
              title: 'Documentos',
              iconColor: Colors.teal,
            ),
            content: DocumentosTab(session: widget.session),
          ),

          const SizedBox(height: _kExpanderSpacing),

          // ---- Notas ----
          Expander(
            initiallyExpanded: _notasExpanded,
            onStateChanged: (open) => setState(() => _notasExpanded = open),
            header: _buildSectionHeader(
              context,
              icon: FluentIcons.quick_note,
              title: 'Notas',
              iconColor: theme.accentColor,
            ),
            content: NotasTab(session: widget.session),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ENUM Y DIALOGO PARA CIERRE SIN CONTEO DE EFECTIVO (FIX 1)
// ============================================================================

/// Decisión del supervisor cuando intenta cerrar sin haber registrado
/// el efectivo de cierre.
enum _CloseWithoutCountDecision {
  /// Ir a registrar el efectivo de cierre antes de continuar
  registerCash,

  /// Cerrar la sesión de todas formas, sin conteo
  continueWithoutCount,
}

/// Diálogo de advertencia que aparece cuando el supervisor intenta cerrar
/// la sesión sin haber registrado el efectivo de cierre.
///
/// Opciones:
///   • "Registrar efectivo" → abre [CashCountDialog] de tipo cierre
///   • "Cerrar sin conteo"  → continúa hacia la confirmación de cierre normal
class _NoClosingCashDialog extends StatelessWidget {
  final CollectionSession session;

  const _NoClosingCashDialog({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 480),
      title: Row(
        children: [
          Icon(FluentIcons.warning, color: AppColors.warning),
          const SizedBox(width: 10),
          const Expanded(child: Text('Efectivo de cierre no registrado')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aún no registras el efectivo de cierre para la sesión '
            '"${session.name}".',
            style: theme.typography.body,
          ),
          const SizedBox(height: 8),
          InfoBar(
            title: const Text('Recomendación'),
            content: const Text(
              'Registrar el conteo de efectivo antes de cerrar evita '
              'descuadres en el balance de caja.',
            ),
            severity: InfoBarSeverity.warning,
          ),
          const SizedBox(height: 12),
          Text('¿Cómo deseas continuar?', style: theme.typography.bodyStrong),
        ],
      ),
      actions: [
        // Opción 1: Ir a registrar el efectivo
        FilledButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(_CloseWithoutCountDecision.registerCash),
          child: const Text('Registrar efectivo'),
        ),
        // Opción 2: Cerrar sin conteo (acción secundaria / menos prominente)
        Button(
          onPressed: () =>
              Navigator.of(context)
                  .pop(_CloseWithoutCountDecision.continueWithoutCount),
          child: const Text('Cerrar sin conteo'),
        ),
        // Cancelar todo
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
