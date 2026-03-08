import 'package:fluent_ui/fluent_ui.dart' hide showDialog;
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/repository_providers.dart'
    show salesRepositoryProvider;
import '../../repositories/sales_repository.dart'; // Extension methods (getWithLines, etc.)
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../clients/clients.dart'
    show clientWithCreditProvider, clientCreditServiceProvider, clientRepositoryProvider;
import '../../../invoices/invoices.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../providers/providers.dart';
import '../../widgets/totals/sales_order_totals.dart';
import 'conflict_banner.dart';
import 'form_header.dart';
import 'form_lines.dart';
import 'form_sections.dart';

/// Pantalla unificada de orden de venta (ver/crear/editar)
///
/// Usa un solo provider (saleOrderFormProvider) para todos los modos.
/// El modo (vista/edición) se controla con state.isEditing.
///
/// ## Modos
/// - Vista (isEditing: false): Solo lectura
/// - Edición (isEditing: true): Modificar orden existente
/// - Nueva (order == null, isEditing: true): Crear nueva orden
///
/// ## 5-Section Architecture
/// - Section 1: Header (title, back button, action buttons)
/// - Section 2: Client info + Dates/Config cards
/// - Section 3: Order lines
/// - Section 4: Totals
/// - Section 5: Notes
///
// Phase3-Item11: Reactive streams migration — ALL 4 STEPS COMPLETE.
//
// ✅ Step 1 — View mode only: ref.listen() on stream providers auto-applies
//   updates when !isEditing && !isSaving.
//
// ✅ Step 2 — Edit mode indicator: When isEditing=true, stream updates set
//   serverUpdatePending flag + store pending data. An InfoBar shows with an
//   "Aplicar" button. On exitEditMode(), pending updates auto-apply.
//
// ✅ Step 3 — Conflict-aware merge: applyPendingServerUpdate uses
//   ConflictDetectionService for fine-grained field-level merging. Non-dirty
//   fields auto-merge; overlapping dirty fields show ConflictBanner with
//   per-field resolution.
//
// ✅ Step 4 — _handleSyncData() manual reload removed. loadOrder() kept for
//   initial load since Drift streams need at least one DB row to emit.
class SaleOrderFormScreen extends ConsumerStatefulWidget {
  final int orderId;
  final bool isNew;
  final bool startInEditMode;

  const SaleOrderFormScreen({
    super.key,
    required this.orderId,
    this.isNew = false,
    this.startInEditMode = false,
  });

  @override
  ConsumerState<SaleOrderFormScreen> createState() =>
      _SaleOrderFormScreenState();
}

class _SaleOrderFormScreenState extends ConsumerState<SaleOrderFormScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    logger.i(
      '[SaleOrderFormScreen]',
      'Initializing: isNew=${widget.isNew}, orderId=${widget.orderId}, startInEditMode=${widget.startInEditMode}',
    );

    Future.microtask(() async {
      if (!mounted) return;
      final notifier = ref.read(saleOrderFormProvider.notifier);

      if (widget.isNew) {
        // Nueva orden - siempre en modo edición
        notifier.initNewOrder();
      } else {
        // Orden existente - cargar datos
        final currentState = ref.read(saleOrderFormProvider);

        // Si ya tenemos esta orden cargada, no recargar
        if (currentState.order?.id == widget.orderId &&
            !currentState.isLoading) {
          // Solo cambiar modo si es necesario
          if (widget.startInEditMode && !currentState.isEditing) {
            notifier.enterEditMode();
          }
          return;
        }

        // Cargar orden
        await notifier.loadOrder(widget.orderId);
        // Después de cargar, entrar en modo edición si se solicitó
        if (widget.startInEditMode) {
          if (!mounted) return;
          ref.read(saleOrderFormProvider.notifier).enterEditMode();
        }
      }
    });
  }

  @override
  void didUpdateWidget(SaleOrderFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Si cambió el ID, recargar
    if (oldWidget.orderId != widget.orderId) {
      _initialize();
      return;
    }

    // Si cambió el modo en los props, sincronizar con el form provider
    // Solo actuar si el estado actual no coincide (evitar doble actualización)
    if (oldWidget.startInEditMode != widget.startInEditMode) {
      final currentState = ref.read(saleOrderFormProvider);
      final notifier = ref.read(saleOrderFormProvider.notifier);

      if (widget.startInEditMode && !currentState.isEditing) {
        notifier.enterEditMode();
      } else if (!widget.startInEditMode && currentState.isEditing) {
        notifier.exitEditMode();
      }
    }
  }

  /// Sync ALL data related to the current order (client, credit, order, lines)
  Future<void> _handleSyncData() async {
    final order = ref.read(saleOrderFormProvider).order;
    if (order == null) return;

    final partnerId = order.partnerId;
    final orderId = order.id;

    logger.i('[SaleOrderForm]', '🔄 Starting data sync for partner $partnerId, order $orderId');

    // Show loading dialog
    if (!mounted) return;

    bool dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const ContentDialog(
        content: SizedBox(
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(),
                SizedBox(height: Spacing.sm),
                Text('Sincronizando datos...'),
              ],
            ),
          ),
        ),
      ),
    );

    void closeDialog() {
      if (dialogOpen && mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    final syncedItems = <String>[];
    final errors = <String>[];

    try {
      // 1. Sync partner/client data
      if (partnerId != null) {
        try {
          final clientRepo = ref.read(clientRepositoryProvider);
          if (clientRepo != null) {
            await clientRepo.refreshCreditData(partnerId);
            syncedItems.add('Cliente');
          }
        } catch (e) {
          logger.e('[SaleOrderForm]', 'Error syncing client: $e');
          errors.add('Cliente: $e');
        }
      }

      // 2. Sync sale order from server -> save to local DB
      if (orderId > 0) {
        try {
          final salesRepo = ref.read(salesRepositoryProvider);
          if (salesRepo != null) {
            // forceRefresh: true -> fetch from server and save to local
            await salesRepo.getWithLines(orderId, forceRefresh: true);
            syncedItems.addAll(['Orden', 'Líneas', 'Pagos']);
          }
        } catch (e) {
          logger.e('[SaleOrderForm]', 'Error syncing order: $e');
          errors.add('Orden: $e');
        }
      }

      // 3. Refresh credit info from server -> save to local DB
      if (partnerId != null) {
        try {
          final creditService = ref.read(clientCreditServiceProvider);
          if (creditService != null) {
            await creditService.getClientWithCredit(partnerId, forceRefresh: true);
            syncedItems.add('Crédito');
          }
          // Invalidate the provider to reload UI
          ref.invalidate(clientWithCreditProvider(partnerId));
        } catch (e) {
          logger.e('[SaleOrderForm]', 'Error syncing credit: $e');
          errors.add('Crédito: $e');
        }
      }

      // 4. Reload from LOCAL DB (offline-first pattern)
      if (orderId > 0) {
        try {
          final salesRepo = ref.read(salesRepositoryProvider);
          if (salesRepo != null) {
            // forceRefresh: false -> read from local DB only
            final result = await salesRepo.getWithLines(orderId, forceRefresh: false);
            final localOrder = result.$1;
            final localLines = result.$2;

            if (localOrder != null) {
              // Update form state with data from local DB (no loading flash)
              ref.read(saleOrderFormProvider.notifier).updateOrderFromSync(
                localOrder,
                localLines,
              );
            }
          }
        } catch (e) {
          logger.e('[SaleOrderForm]', 'Error reloading from local: $e');
        }
      }

      // Close dialog
      closeDialog();

      logger.i('[SaleOrderForm]', 'Sync completed. Items: ${syncedItems.join(", ")}. Errors: ${errors.length}');

      // Show result
      if (!mounted) return;
      if (errors.isEmpty) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Sincronizado',
          message: 'Actualizado: ${syncedItems.join(", ")}',
        );
      } else {
        CopyableInfoBar.showWarning(
          context,
          title: 'Sincronización parcial',
          message: 'OK: ${syncedItems.join(", ")}\n\nErrores:\n${errors.join("\n")}',
        );
      }
    } catch (e) {
      // Close dialog
      closeDialog();

      logger.e('[SaleOrderForm]', 'Sync data error: $e');

      if (!mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de sincronización',
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SELECTORES GRANULARES - Solo se reconstruye cuando cambian estos campos específicos
    // Esto evita que cambios en campos individuales (como fechas) regeneren toda la UI
    final isLoading = ref.watch(
      saleOrderFormProvider.select((s) => s.isLoading),
    );
    final isEditing = ref.watch(
      saleOrderFormProvider.select((s) => s.isEditing),
    );
    final order = ref.watch(saleOrderFormProvider.select((s) => s.order));

    // ── Step 1: View-mode reactive streams ──────────────────────────────
    // When the form is NOT editing and NOT saving, automatically apply
    // updates from the local DB stream (Drift watch) so the user sees
    // real-time changes from sync / WebSocket / other tabs.
    // When editing, show a non-intrusive notification instead.
    if (!widget.isNew && widget.orderId > 0) {
      // Listen to order header changes
      ref.listen<AsyncValue<SaleOrder?>>(
        saleOrderStreamProvider(widget.orderId),
        (previous, next) {
          final newOrder = next.value;
          if (newOrder == null) return;
          if (!mounted) return;

          final formState = ref.read(saleOrderFormProvider);
          // Skip during save or loading to avoid stale data race
          if (formState.isSaving || formState.isLoading) return;

          // View mode: auto-apply stream update
          if (!formState.isEditing) {
            // Only update if the order actually changed
            if (formState.order != newOrder) {
              ref.read(saleOrderFormProvider.notifier).updateOrderFromSync(
                newOrder,
                formState.lines, // lines handled separately below
              );
            }
            return;
          }

          // Edit mode: set pending flag instead of overwriting user changes
          if (formState.order != newOrder) {
            ref.read(saleOrderFormProvider.notifier).setServerUpdatePending(
              newOrder,
              null, // lines handled separately below
            );
          }
        },
      );

      // Listen to order lines changes
      ref.listen<AsyncValue<List<SaleOrderLine>>>(
        saleOrderLinesStreamProvider(widget.orderId),
        (previous, next) {
          final newLines = next.value;
          if (newLines == null) return;
          if (!mounted) return;

          final formState = ref.read(saleOrderFormProvider);
          if (formState.isSaving || formState.isLoading) return;

          // View mode: auto-apply line updates
          if (!formState.isEditing && formState.order != null) {
            if (formState.lines != newLines) {
              ref.read(saleOrderFormProvider.notifier).updateOrderFromSync(
                formState.order!,
                newLines,
              );
            }
            return;
          }

          // Edit mode: update pending with lines
          if (formState.isEditing && formState.lines != newLines) {
            final notifier = ref.read(saleOrderFormProvider.notifier);
            // Use the already-pending order or current order
            final pendingOrder =
                formState.pendingServerOrder ?? formState.order;
            if (pendingOrder != null) {
              notifier.setServerUpdatePending(pendingOrder, newLines);
            }
          }
        },
      );
    }

    // Escuchar errores y mostrar info bar
    ref.listen<String?>(saleOrderFormProvider.select((s) => s.errorMessage), (
      previous,
      next,
    ) {
      if (next != null && next.isNotEmpty && mounted) {
        CopyableInfoBar.showError(context, title: 'Error', message: next);
        ref.read(saleOrderFormProvider.notifier).clearError();
      }
    });

    // Estado de carga
    if (isLoading) {
      return _buildLoadingState(
        widget.isNew
            ? 'Nueva Orden'
            : (isEditing ? 'Editar Orden' : 'Cargando...'),
      );
    }

    // Sin orden cargada (y no es nueva)
    if (order == null && !widget.isNew) {
      return _buildNotFoundState(FluentTheme.of(context));
    }

    // Construir contenido según el modo
    return _buildContent(isEditing: isEditing, order: order);
  }

  Widget _buildContent({
    required bool isEditing,
    required SaleOrder? order,
  }) {
    final effectiveIsEditing = isEditing || widget.isNew;
    final visibleLines = ref.watch(saleOrderFormVisibleLinesProvider);

    // Detectar si el teclado nativo está visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 100;

    // Verificar conflictos de edición (usando provider unificado)
    final hasConflict = ref.watch(
      saleOrderFormProvider.select((s) => s.hasConflict),
    );
    final conflictMessage = ref.watch(
      saleOrderFormProvider.select((s) => s.conflictMessage),
    );
    final conflicts = ref.watch(
      saleOrderFormProvider.select((s) => s.conflicts),
    );

    // Server update pending indicator (Phase 3 - Step 2)
    final serverUpdatePending = ref.watch(
      saleOrderFormProvider.select((s) => s.serverUpdatePending),
    );

    return ScaffoldPage(
      header: SaleOrderFormHeader(
        orderId: widget.orderId,
        isNew: widget.isNew,
        isEditing: effectiveIsEditing,
        order: order,
        isKeyboardVisible: isKeyboardVisible,
        onRefresh: effectiveIsEditing ? null : _handleSyncData,
      ),
      content: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de conflicto si existe (ocultar cuando teclado visible)
            if (hasConflict &&
                conflictMessage != null &&
                !isKeyboardVisible)
              ConflictBanner(
                message: conflictMessage,
                conflicts: conflicts,
                onAcceptServer: () {
                  ref
                      .read(saleOrderFormProvider.notifier)
                      .acceptServerChanges();
                },
                onKeepLocal: () {
                  ref.read(saleOrderFormProvider.notifier).keepLocalChanges();
                },
              ),

            // Server update pending indicator (ocultar cuando teclado visible)
            if (serverUpdatePending &&
                effectiveIsEditing &&
                !isKeyboardVisible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBar(
                  title: const Text('Actualización disponible'),
                  content: const Text(
                    'Se detectaron cambios en el servidor. '
                    'Puede aplicar la actualización o continuar editando.',
                  ),
                  severity: InfoBarSeverity.info,
                  isLong: true,
                  action: Button(
                    onPressed: () {
                      ref
                          .read(saleOrderFormProvider.notifier)
                          .applyPendingServerUpdate();
                    },
                    child: const Text('Aplicar'),
                  ),
                  onClose: () {
                    ref
                        .read(saleOrderFormProvider.notifier)
                        .clearServerUpdatePending();
                  },
                ),
              ),

            // Section 3: Order lines - EXPANDED to fill available space
            Expanded(
              child: SaleOrderFormLines(
                orderId: widget.orderId,
                isNew: widget.isNew,
                isEditing: effectiveIsEditing,
              ),
            ),

            // Footer: Notes (left) + Totals (right) - ocultar cuando teclado visible
            if (!isKeyboardVisible) ...[
              const SizedBox(height: 16),
              _buildFooter(
                isEditing: effectiveIsEditing,
                order: order,
                visibleLines: visibleLines,
              ),
            ],

            // Invoice section (modo vista, orden facturada, ocultar cuando teclado visible)
            if (!effectiveIsEditing &&
                order != null &&
                order.isSynced &&
                order.invoiceCount > 0 &&
                !isKeyboardVisible) ...[
              const SizedBox(height: 16),
              InvoiceSection(orderId: order.id),
            ],

            // Sync warning (modo vista, orden no sincronizada, ocultar cuando teclado visible)
            if (!effectiveIsEditing &&
                order != null &&
                !order.isSynced &&
                !isKeyboardVisible) ...[
              const SizedBox(height: 16),
              _buildSyncWarning(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooter({
    required bool isEditing,
    required SaleOrder? order,
    required List<SaleOrderLine> visibleLines,
  }) {
    // ✅ SELECTOR GRANULAR para note - solo se reconstruye cuando note cambia
    final note = ref.watch(saleOrderFormProvider.select((s) => s.note));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: side by side
        if (constraints.maxWidth >= ScreenBreakpoints.mobileMaxWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Notes (always visible, editable only in edit mode)
              Expanded(
                child: FormSection5Notes(
                  note: isEditing ? note : order?.note,
                  isEditing: isEditing,
                  onNoteChanged: isEditing
                      ? (value) => ref
                            .read(saleOrderFormProvider.notifier)
                            .updateField('note', value)
                      : null,
                ),
              ),
              const SizedBox(width: 24),
              // Right: Totals (fixed width)
              SizedBox(
                width: 320,
                child: SalesOrderTotals(
                  order: order,
                  lines: visibleLines,
                ),
              ),
            ],
          );
        }

        // Mobile: stacked vertically
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Totals first on mobile
            FormSection4Totals(order: order, lines: visibleLines),
            const SizedBox(height: 16),
            // Notes (always visible, editable only in edit mode)
            FormSection5Notes(
              note: isEditing ? note : order?.note,
              isEditing: isEditing,
              onNoteChanged: isEditing
                  ? (value) => ref
                        .read(saleOrderFormProvider.notifier)
                        .updateField('note', value)
                  : null,
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // WIDGETS AUXILIARES
  // ============================================================

  Widget _buildLoadingState(String title) {
    return ScaffoldPage(
      header: PageHeader(title: Text(title)),
      content: const Center(child: ProgressRing()),
    );
  }

  Widget _buildNotFoundState(FluentThemeData theme) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('Orden no encontrada')),
      content: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.search_issue,
              size: 64,
              color: theme.inactiveColor,
            ),
            const SizedBox(height: 16),
            Text(
              'La orden no existe o fue eliminada',
              style: theme.typography.subtitle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncWarning() {
    return InfoBar(
      title: const Text('Pendiente de sincronizar'),
      content: const Text('Esta orden está pendiente de sincronizar'),
      severity: InfoBarSeverity.warning,
      isLong: true,
    );
  }
}

