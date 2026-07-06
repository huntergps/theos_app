import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/platform/server_connectivity_service.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/common/theos_info_bars.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../utils/keyboard_shortcuts.dart';
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
    final action = POSKeyboardShortcuts.getAction(event, isSearchMode: isSearchMode);

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
        // Reload the current order from cache/server
        notifier.initialize();
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
        // TODO: Wire print receipt when print service is available
        CopyableInfoBar.showInfo(
          context,
          title: 'Impresión no disponible',
          message: 'La impresión aún no está disponible.',
        );
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
          _showUndoDeleteInfoBar(
            deletedLine.productName ?? deletedLine.name,
          );
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
    final screenWidth = MediaQuery.of(context).size.width;

    // Watch loading state
    final isLoading = ref.watch(fastSaleProvider.select((s) => s.isLoading));

    // Show errors
    ref.listen<String?>(
      fastSaleProvider.select((s) => s.error),
      (previous, next) {
        if (next != null && next.isNotEmpty && mounted) {
          CopyableInfoBar.showError(context, title: 'Error en punto de venta', message: next);
          ref.read(fastSaleProvider.notifier).clearError();
        }
      },
    );

    if (isLoading) {
      return ScaffoldPage(
        header: const PageHeader(title: Text('Punto de Venta')),
        content: const Center(child: ProgressRing()),
      );
    }

    // Check if there are no orders (empty state)
    final hasTabs = ref.watch(fastSaleProvider.select((s) => s.tabs.isNotEmpty));
    final totalOrdersCount = ref.watch(
      fastSaleProvider.select((s) => s.totalOrdersCount),
    );

    // Session guard: relevant only to users with collection permissions
    final hasCollectionPermissions = ref.watch(hasCollectionPermissionsProvider);
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
              Text(
                'No hay órdenes de venta',
                style: theme.typography.subtitle,
              ),
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

    // Responsive layout
    final isDesktop = screenWidth >= ScreenBreakpoints.tabletMaxWidth;
    final isTablet = screenWidth >= ScreenBreakpoints.mobileMaxWidth &&
        screenWidth < ScreenBreakpoints.tabletMaxWidth;

    // Check server connectivity for offline indicator
    final isServerOnline = ref.watch(isServerOnlineProvider);

    // Mostrar FAB táctil solo en tablet/móvil sin teclado físico
    final hasPhysicalKeyboard = ref.watch(hasPhysicalKeyboardProvider);
    final showTouchFab = !isDesktop && !hasPhysicalKeyboard;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
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
                  message: 'Las ventas se guardan localmente y se sincronizarán '
                      'con Odoo al recuperar la conexión.',
                ),

              // Main content area — envuelto en Stack para el FAB táctil
              Expanded(
                child: showTouchFab
                    ? Stack(
                        children: [
                          isTablet
                              ? _buildTabletLayout(theme, hasCollectionPermissions)
                              : _buildMobileLayout(theme, hasCollectionPermissions),
                          // FAB táctil flotante sobre el contenido
                          const TouchActionsFab(),
                        ],
                      )
                    : isDesktop
                        ? _buildDesktopLayout(theme, hasCollectionPermissions)
                        : isTablet
                            ? _buildTabletLayout(theme, hasCollectionPermissions)
                            : _buildMobileLayout(theme, hasCollectionPermissions),
              ),
            ],
          ),
        ),
      ), // cierra BarcodeListenerWidget
    );
  }

  /// Desktop layout: 3 columns side by side
  Widget _buildDesktopLayout(FluentThemeData theme, bool hasCollectionPermissions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left column: Order lines (~55%)
        const Expanded(
          flex: 55,
          child: POSOrderLinesPanel(),
        ),

        // Divider
        Container(
          width: 1,
          color: theme.resources.dividerStrokeColorDefault,
        ),

        // Center column: Customer + Keypad (~35%)
        const Expanded(
          flex: 35,
          child: POSCustomerKeypadPanel(),
        ),

        // Right column: Actions (~140px) - only for collection users
        if (hasCollectionPermissions) ...[
          Container(
            width: 1,
            color: theme.resources.dividerStrokeColorDefault,
          ),
          const SizedBox(
            width: 140,
            child: POSActionsPanel(),
          ),
        ],
      ],
    );
  }

  /// Tablet layout: 2 columns with actions as bottom bar
  Widget _buildTabletLayout(FluentThemeData theme, bool hasCollectionPermissions) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Order lines
              const Expanded(
                flex: 55,
                child: POSOrderLinesPanel(),
              ),

              // Divider
              Container(
                width: 1,
                color: theme.resources.dividerStrokeColorDefault,
              ),

              // Right: Customer + Keypad
              const Expanded(
                flex: 45,
                child: POSCustomerKeypadPanel(),
              ),
            ],
          ),
        ),

        // Bottom: Actions bar - only for collection users
        if (hasCollectionPermissions)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: const POSActionsPanel(isHorizontal: true),
          ),
      ],
    );
  }

  /// Mobile layout: Stacked with tabs
  Widget _buildMobileLayout(FluentThemeData theme, bool hasCollectionPermissions) {
    // For mobile, we use a different approach with a bottom sheet or tabs
    return Column(
      children: [
        // Main content: Order lines
        const Expanded(
          child: POSOrderLinesPanel(),
        ),

        // Customer info + keypad (scrollable so nothing is hidden)
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: const SingleChildScrollView(
            child: POSCustomerKeypadPanel(),
          ),
        ),

        // Actions bar at bottom - only for collection users
        if (hasCollectionPermissions)
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: const POSActionsPanel(isHorizontal: true, isCompact: true),
          ),
      ],
    );
  }
}
