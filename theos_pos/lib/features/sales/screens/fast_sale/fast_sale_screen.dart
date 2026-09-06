import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/adaptive/adaptive_layout_policy.dart';
import '../../../../core/services/platform/server_connectivity_service.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/common/theos_info_bars.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../utils/keyboard_shortcuts.dart';
import '../../providers/sale_order_tabs_provider.dart';
import 'fast_sale_providers.dart';
import 'widgets/barcode_listener_widget.dart';
import 'widgets/confirm_order_handler.dart' show confirmOrderWithCreditCheck;
import 'widgets/pos_actions_panel.dart';
import 'widgets/pos_customer_keypad_panel.dart';
import 'widgets/pos_order_lines_panel.dart';
import 'widgets/pos_order_tabs.dart' show POSOrderTabs, showSearchOrdersDialog;
import 'widgets/touch_actions_fab.dart';

export 'widgets/pos_actions_panel.dart' show hasCollectionPermissionsProvider;

/// Fast Sale (Point of Sale) screen
///
/// A 3-column layout optimized for quick sales:
/// - Left (~55%): Order lines with product list
/// - Center (~35%): Customer info + Numeric keypad
/// - Right (~100px): Quick action buttons (narrow)
class FastSaleScreen extends ConsumerStatefulWidget {
  const FastSaleScreen({super.key});

  @override
  ConsumerState<FastSaleScreen> createState() => _FastSaleScreenState();
}

class _FastSaleScreenState extends ConsumerState<FastSaleScreen> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize Fast Sale provider
    Future.microtask(() {
      if (!mounted) return;
      ref.read(fastSaleProvider.notifier).initialize();
      // Request focus for keyboard navigation
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard events for line navigation, quantity changes, and shortcuts
  ///
  /// Shortcuts:
  /// - F2: Search product
  /// - F3: Search/select client
  /// - F4: Add new order
  /// - F5: Refresh
  /// - F6: Go to payments (Cobrar)
  /// - F9: Confirm order
  /// - F10: Save order (draft)
  /// - F12: Print
  /// - Esc: Cancel/clear
  /// - +/-: Increment/decrement quantity
  /// - Up/Down: Navigate lines
  /// - Delete: Remove selected line
  /// - Ctrl+N: New order
  /// - Ctrl+S: Save order
  /// - F1: Show shortcuts help
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final notifier = ref.read(fastSaleProvider.notifier);
    final inputMode = ref.read(fastSaleInputModeProvider);
    final isSearchMode = inputMode == KeypadInputMode.search;

    // Use the keyboard shortcuts helper
    final action = POSKeyboardShortcuts.getAction(
      event,
      isSearchMode: isSearchMode,
    );

    if (action == null) {
      // Check for F1 (help) separately
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        showShortcutHelpDialog(context);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Handle the action
    switch (action) {
      case POSShortcutAction.searchProduct:
        // Focus on product search and request focus
        notifier.setInputMode(KeypadInputMode.search);
        requestSearchInputFocus();
        return KeyEventResult.handled;

      case POSShortcutAction.searchClient:
        // Toggle customer panel to show client selector
        notifier.toggleCustomerPanel();
        return KeyEventResult.handled;

      case POSShortcutAction.newOrder:
        notifier.addNewTab();
        return KeyEventResult.handled;

      case POSShortcutAction.refresh:
        // Refresh remote headers when online, then rebuild from scoped cache.
        notifier.initialize(force: true);
        return KeyEventResult.handled;

      case POSShortcutAction.togglePaymentMode:
        // Toggle customer panel (shows payment options)
        notifier.toggleCustomerPanel();
        return KeyEventResult.handled;

      case POSShortcutAction.goToPayments:
        // F6: abre el flujo de cobro (mismo handler que el botón "Cobrar"
        // del panel de acciones — confirma la orden primero si es borrador).
        goToPaymentsWithAutoConfirm(
          context,
          ref,
          ref.read(fastSaleActiveTabProvider),
        );
        return KeyEventResult.handled;

      case POSShortcutAction.confirmOrder:
        // Usa el flujo unificado (validación de crédito + diálogo de bypass)
        // — antes llamaba a notifier.confirmActiveOrder() directo, lo que
        // permitía saltarse la validación de crédito desde el teclado.
        confirmOrderWithCreditCheck(context, ref);
        return KeyEventResult.handled;

      case POSShortcutAction.saveOrder:
        notifier.saveActiveOrder();
        return KeyEventResult.handled;

      case POSShortcutAction.printReceipt:
        final activeTab = ref.read(fastSaleActiveTabProvider);
        if (activeTab == null || activeTab.orderId <= 0) {
          CopyableInfoBar.showInfo(
            context,
            title: 'Guarda la orden primero',
            message: 'Confirma o guarda la orden antes de imprimir el recibo.',
          );
        } else {
          // Reuse the established sale-order tab and its PDF/print pipeline.
          // This keeps report rendering in one place and avoids generating a
          // different receipt from the fast-sale shortcut.
          ref
              .read(saleOrderTabsProvider.notifier)
              .openOrder(activeTab.orderId, activeTab.orderName);
          CopyableInfoBar.showInfo(
            context,
            title: 'Orden lista para imprimir',
            message: 'Usa el botón Imprimir en la pestaña de la orden.',
          );
        }
        return KeyEventResult.handled;

      case POSShortcutAction.cancel:
        // Clear current input or cancel operation
        if (isSearchMode) {
          notifier.clearKeypad();
          notifier.setInputMode(KeypadInputMode.quantity);
        }
        return KeyEventResult.handled;

      case POSShortcutAction.navigateUp:
        notifier.selectPreviousLine();
        return KeyEventResult.handled;

      case POSShortcutAction.navigateDown:
        notifier.selectNextLine();
        return KeyEventResult.handled;

      case POSShortcutAction.incrementQuantity:
        notifier.incrementSelectedLineQuantity();
        return KeyEventResult.handled;

      case POSShortcutAction.decrementQuantity:
        notifier.decrementSelectedLineQuantity();
        return KeyEventResult.handled;

      case POSShortcutAction.deleteLine:
        final activeTab = ref.read(fastSaleProvider).activeTab;
        if (activeTab != null && activeTab.selectedLineIndex >= 0) {
          final deletedLine = activeTab.lines[activeTab.selectedLineIndex];
          notifier.deleteLine(activeTab.selectedLineIndex);
          _showUndoDeleteInfoBar(deletedLine.productName ?? deletedLine.name);
        }
        return KeyEventResult.handled;

      case POSShortcutAction.confirm:
        // Confirm is context-dependent and handled elsewhere
        return KeyEventResult.ignored;
    }
  }

  /// Show an InfoBar with undo option after deleting a line
  void _showUndoDeleteInfoBar(String productName) {
    if (!mounted) return;
    CopyableInfoBar.showWarning(
      context,
      title: 'Línea eliminada',
      message: productName,
      duration: const Duration(seconds: 5),
      action: HyperlinkButton(
        child: const Text('Deshacer'),
        onPressed: () {
          ref.read(fastSaleProvider.notifier).undoDeleteLine();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Watch loading state
    final isLoading = ref.watch(fastSaleProvider.select((s) => s.isLoading));

    // Show errors
    ref.listen<String?>(fastSaleProvider.select((s) => s.error), (
      previous,
      next,
    ) {
      if (next != null && next.isNotEmpty && mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error en punto de venta',
          message: next,
        );
        ref.read(fastSaleProvider.notifier).clearError();
      }
    });

    if (isLoading) {
      return ScaffoldPage(
        header: const PageHeader(title: Text('Punto de Venta')),
        content: const Center(child: ProgressRing()),
      );
    }

    // Check if there are no orders (empty state)
    final hasTabs = ref.watch(
      fastSaleProvider.select((s) => s.tabs.isNotEmpty),
    );
    final totalOrdersCount = ref.watch(
      fastSaleProvider.select((s) => s.totalOrdersCount),
    );

    // Session guard: relevant only to users with collection permissions
    final hasCollectionPermissions = ref.watch(
      hasCollectionPermissionsProvider,
    );
    // hasActiveSession se valida en pos_actions_panel al intentar cobrar

    if (!hasTabs) {
      return ScaffoldPage(
        header: const PageHeader(title: Text('Punto de Venta')),
        content: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.shopping_cart,
                size: 64,
                color: theme.inactiveColor,
              ),
              const SizedBox(height: Spacing.md),
              Text('No hay órdenes de venta', style: theme.typography.subtitle),
              const SizedBox(height: Spacing.xs),
              Text(
                'Crea una nueva orden o busca una existente',
                style: theme.typography.body?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: () {
                      ref.read(fastSaleProvider.notifier).addNewTab();
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 14),
                        SizedBox(width: Spacing.xs),
                        Text('Nueva Orden'),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Button(
                    onPressed: () => showSearchOrdersDialog(context, ref),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.search, size: 14),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          totalOrdersCount > 0
                              ? 'Buscar ($totalOrdersCount)'
                              : 'Buscar',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Check server connectivity for offline indicator
    final isServerOnline = ref.watch(isServerOnlineProvider);

    // Las capacidades son explícitas y pueden coexistir. En particular, un
    // teclado conectado no elimina los controles táctiles de un iPad/tablet.
    final inputCapabilities = ref.watch(fastSaleInputCapabilitiesProvider);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: inputCapabilities.hardwareKeyboard ? _handleKeyEvent : null,
      autofocus: true,
      // BarcodeListenerWidget detecta secuencias de lectores HID (USB/Bluetooth)
      // y las procesa automáticamente sin interferir con atajos F1-F12 ni TextBoxes.
      child: BarcodeListenerWidget(
        child: ScaffoldPage(
          padding: EdgeInsets.zero,
          content: Column(
            children: [
              // Order tabs at the top
              const POSOrderTabs(),

              // Persistent offline warning bar
              if (!isServerOnline)
                TheosInfoBars.warning(
                  title: 'Sin conexión al servidor — puedes seguir vendiendo',
                  message:
                      'Las ventas se guardan localmente y se sincronizarán '
                      'con Odoo al recuperar la conexión.',
                ),

              // Main content area — envuelto en Stack para el FAB táctil
              Expanded(
                child: FastSaleAdaptiveLayout(
                  inputCapabilities: inputCapabilities,
                  showActions: hasCollectionPermissions,
                  orderLinesPanel: const POSOrderLinesPanel(),
                  customerKeypadPanel: const POSCustomerKeypadPanel(),
                  compactCustomerPanel: const POSCustomerKeypadPanel(
                    isCompact: true,
                  ),
                  actionsPanel: const POSActionsPanel(),
                  horizontalActionsPanel: const POSActionsPanel(
                    isHorizontal: true,
                  ),
                  compactActionsPanel: const POSActionsPanel(
                    isHorizontal: true,
                    isCompact: true,
                  ),
                  touchActions: const TouchActionsFab(),
                ),
              ),
            ],
          ),
        ),
      ), // cierra BarcodeListenerWidget
    );
  }
}

/// Layout presentacional de Venta Rápida, aislado de sus providers de dominio.
///
/// Decide por el ancho que realmente recibe mediante [LayoutBuilder]. Los
/// widgets hijos conservan la propiedad de su estado; esta capa solo los
/// distribuye en una, dos o tres columnas.
class FastSaleAdaptiveLayout extends StatelessWidget {
  const FastSaleAdaptiveLayout({
    super.key,
    required this.inputCapabilities,
    required this.showActions,
    required this.orderLinesPanel,
    required this.customerKeypadPanel,
    required this.compactCustomerPanel,
    required this.actionsPanel,
    required this.horizontalActionsPanel,
    required this.compactActionsPanel,
    required this.touchActions,
  });

  static const compactKey = Key('fast-sale-layout-compact');
  static const mediumKey = Key('fast-sale-layout-medium');
  static const expandedKey = Key('fast-sale-layout-expanded');
  static const touchActionsKey = Key('fast-sale-touch-actions');

  final AdaptiveInputCapabilities inputCapabilities;
  final bool showActions;
  final Widget orderLinesPanel;
  final Widget customerKeypadPanel;
  final Widget compactCustomerPanel;
  final Widget actionsPanel;
  final Widget horizontalActionsPanel;
  final Widget compactActionsPanel;
  final Widget touchActions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaSize.width;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaSize.height;
        final environment = AdaptiveEnvironment(
          width: width,
          height: height,
          inputs: inputCapabilities,
        );
        final policy = AdaptiveUiPolicy(environment);

        final layout = switch (environment.sizeClass) {
          AdaptiveSizeClass.compact => _buildCompactLayout(context),
          AdaptiveSizeClass.medium => _buildMediumLayout(context),
          AdaptiveSizeClass.expanded => _buildExpandedLayout(context),
        };

        if (!inputCapabilities.touch || policy.usesSplitView) {
          return layout;
        }

        return Stack(
          children: [
            Positioned.fill(child: layout),
            KeyedSubtree(key: touchActionsKey, child: touchActions),
          ],
        );
      },
    );
  }

  /// Expanded layout: 3 columns side by side.
  Widget _buildExpandedLayout(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      key: expandedKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left column: Order lines (~55%)
        Expanded(flex: 55, child: orderLinesPanel),

        // Divider
        Container(width: 1, color: theme.resources.dividerStrokeColorDefault),

        // Center column: Customer + Keypad (~35%)
        Expanded(flex: 35, child: customerKeypadPanel),

        // Right column: Actions (~140px) - only for collection users
        if (showActions) ...[
          Container(width: 1, color: theme.resources.dividerStrokeColorDefault),
          SizedBox(width: 140, child: actionsPanel),
        ],
      ],
    );
  }

  /// Medium layout: 2 columns with actions as bottom bar.
  Widget _buildMediumLayout(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      key: mediumKey,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Order lines
              Expanded(flex: 55, child: orderLinesPanel),

              // Divider
              Container(
                width: 1,
                color: theme.resources.dividerStrokeColorDefault,
              ),

              // Right: Customer + Keypad
              Expanded(flex: 45, child: customerKeypadPanel),
            ],
          ),
        ),

        // Bottom: Actions bar - only for collection users
        if (showActions)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: horizontalActionsPanel,
          ),
      ],
    );
  }

  /// Compact layout: one content column with contextual controls stacked.
  Widget _buildCompactLayout(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      key: compactKey,
      children: [
        // Main content: Order lines
        Expanded(child: orderLinesPanel),

        // Customer info + keypad (scrollable so nothing is hidden)
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
            ),
          ),
          child: compactCustomerPanel,
        ),

        // Actions bar at bottom - only for collection users
        if (showActions)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: compactActionsPanel,
          ),
      ],
    );
  }
}
