import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

/// Keyboard shortcuts for POS/Fast Sale screen
///
/// Standard shortcuts for quick operation:
/// - F2: Search product
/// - F3: Search/select client
/// - F4: Add new order
/// - F5: Refresh/reload order
/// - F8: Toggle payment mode
/// - F9: Confirm order
/// - F10: Save order (draft)
/// - F12: Print receipt
/// - Escape: Cancel/clear input
/// - Enter: Confirm current action
/// - +/-: Increment/decrement quantity
/// - Delete: Remove selected line
/// - Up/Down: Navigate lines
/// - Ctrl+N: New order
/// - Ctrl+S: Save order
/// - Ctrl+P: Print
class POSKeyboardShortcuts {
  /// Map of logical key to shortcut action
  static final Map<LogicalKeyboardKey, POSShortcutAction> functionKeyMap = {
    LogicalKeyboardKey.f2: POSShortcutAction.searchProduct,
    LogicalKeyboardKey.f3: POSShortcutAction.searchClient,
    LogicalKeyboardKey.f4: POSShortcutAction.newOrder,
    LogicalKeyboardKey.f5: POSShortcutAction.refresh,
    LogicalKeyboardKey.f8: POSShortcutAction.togglePaymentMode,
    LogicalKeyboardKey.f9: POSShortcutAction.confirmOrder,
    LogicalKeyboardKey.f10: POSShortcutAction.saveOrder,
    LogicalKeyboardKey.f12: POSShortcutAction.printReceipt,
    LogicalKeyboardKey.escape: POSShortcutAction.cancel,
  };

  /// Process a key event and return the action to perform
  static POSShortcutAction? getAction(KeyEvent event, {bool isSearchMode = false}) {
    if (event is! KeyDownEvent) return null;

    final key = event.logicalKey;

    // Check function keys
    if (functionKeyMap.containsKey(key)) {
      return functionKeyMap[key];
    }

    // Check modifier combinations (Ctrl+key)
    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final hasModifier = isCtrlPressed || isMetaPressed;

    if (hasModifier) {
      switch (key) {
        case LogicalKeyboardKey.keyN:
          return POSShortcutAction.newOrder;
        case LogicalKeyboardKey.keyS:
          return POSShortcutAction.saveOrder;
        case LogicalKeyboardKey.keyP:
          return POSShortcutAction.printReceipt;
        case LogicalKeyboardKey.keyF:
          return POSShortcutAction.searchProduct;
        case LogicalKeyboardKey.keyR:
          return POSShortcutAction.refresh;
      }
    }

    // Navigation and quantity keys (only when not in search mode)
    if (!isSearchMode) {
      switch (key) {
        case LogicalKeyboardKey.arrowUp:
          return POSShortcutAction.navigateUp;
        case LogicalKeyboardKey.arrowDown:
          return POSShortcutAction.navigateDown;
        case LogicalKeyboardKey.add:
        case LogicalKeyboardKey.numpadAdd:
          return POSShortcutAction.incrementQuantity;
        case LogicalKeyboardKey.minus:
        case LogicalKeyboardKey.numpadSubtract:
          return POSShortcutAction.decrementQuantity;
        case LogicalKeyboardKey.delete:
          return POSShortcutAction.deleteLine;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.numpadEnter:
          return POSShortcutAction.confirm;
      }
    }

    return null;
  }

  /// Get human-readable label for a shortcut
  static String getShortcutLabel(POSShortcutAction action) {
    switch (action) {
      case POSShortcutAction.searchProduct:
        return 'F2';
      case POSShortcutAction.searchClient:
        return 'F3';
      case POSShortcutAction.newOrder:
        return 'F4';
      case POSShortcutAction.refresh:
        return 'F5';
      case POSShortcutAction.togglePaymentMode:
        return 'F8';
      case POSShortcutAction.confirmOrder:
        return 'F9';
      case POSShortcutAction.saveOrder:
        return 'F10';
      case POSShortcutAction.printReceipt:
        return 'F12';
      case POSShortcutAction.cancel:
        return 'Esc';
      case POSShortcutAction.confirm:
        return 'Enter';
      case POSShortcutAction.navigateUp:
        return '↑';
      case POSShortcutAction.navigateDown:
        return '↓';
      case POSShortcutAction.incrementQuantity:
        return '+';
      case POSShortcutAction.decrementQuantity:
        return '-';
      case POSShortcutAction.deleteLine:
        return 'Del';
    }
  }

  /// Get tooltip with action name and shortcut
  static String getTooltip(POSShortcutAction action, String actionName) {
    return '$actionName (${getShortcutLabel(action)})';
  }
}

/// POS shortcut actions
enum POSShortcutAction {
  // Function key actions
  searchProduct,
  searchClient,
  newOrder,
  refresh,
  togglePaymentMode,
  confirmOrder,
  saveOrder,
  printReceipt,
  cancel,

  // Navigation actions
  navigateUp,
  navigateDown,

  // Line actions
  incrementQuantity,
  decrementQuantity,
  deleteLine,

  // Confirmation
  confirm,
}

/// Widget that shows keyboard shortcut hint
class ShortcutHint extends StatelessWidget {
  final String shortcut;
  final String? label;
  final bool isCompact;

  const ShortcutHint({
    super.key,
    required this.shortcut,
    this.label,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 4 : 6,
        vertical: isCompact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: theme.inactiveColor.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.inactiveColor.withAlpha(50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            shortcut,
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 10 : 11,
              fontFamily: 'monospace',
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: theme.typography.caption?.copyWith(
                fontSize: isCompact ? 10 : 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget showing all available shortcuts in a help panel
class ShortcutHelpPanel extends StatelessWidget {
  const ShortcutHelpPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(FluentIcons.keyboard_classic, size: 20, color: theme.accentColor),
              const SizedBox(width: 8),
              Text('Atajos de Teclado', style: theme.typography.bodyStrong),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Main actions
          Text('Acciones principales', style: theme.typography.caption),
          const SizedBox(height: 8),
          _buildShortcutRow('F2', 'Buscar producto'),
          _buildShortcutRow('F3', 'Buscar cliente'),
          _buildShortcutRow('F4', 'Nueva orden'),
          _buildShortcutRow('F9', 'Confirmar orden'),
          _buildShortcutRow('F10', 'Guardar borrador'),
          _buildShortcutRow('F12', 'Imprimir'),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Navigation
          Text('Navegación', style: theme.typography.caption),
          const SizedBox(height: 8),
          _buildShortcutRow('↑ / ↓', 'Navegar líneas'),
          _buildShortcutRow('+ / -', 'Cambiar cantidad'),
          _buildShortcutRow('Del', 'Eliminar línea'),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Modifiers
          Text('Otros', style: theme.typography.caption),
          const SizedBox(height: 8),
          _buildShortcutRow('Ctrl+N', 'Nueva orden'),
          _buildShortcutRow('Ctrl+S', 'Guardar'),
          _buildShortcutRow('Ctrl+P', 'Imprimir'),
          _buildShortcutRow('Esc', 'Cancelar'),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String shortcut, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: ShortcutHint(shortcut: shortcut),
          ),
          const SizedBox(width: 12),
          Text(description),
        ],
      ),
    );
  }
}

/// Dialog to show keyboard shortcuts help
Future<void> showShortcutHelpDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => ContentDialog(
      title: const Text('Atajos de Teclado'),
      content: const ShortcutHelpPanel(),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
