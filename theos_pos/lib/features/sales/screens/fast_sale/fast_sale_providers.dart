import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/database/providers.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../../../shared/providers/company_config_provider.dart'
    show getMaxDiscountPercentage;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../providers/providers.dart' hide ConflictDetail;
import '../../../clients/clients.dart'
    show
        Client,
        CreditCheckType,
        clientCreditServiceProvider,
        clientRepositoryProvider;
import '../../utils/partner_utils.dart' as partner_utils;
import '../../providers/base_order_state.dart' show ConflictDetail;
import '../../services/conflict_detection_service.dart';
import '../../services/credit_validation_ui_service.dart'
    show UnifiedCreditResult;
import 'widgets/pos_payment_tab.dart'
    show posWithholdLinesByOrderProvider, posPaymentLinesByOrderProvider;

part 'fast_sale_providers.freezed.dart';
part 'fast_sale_providers.g.dart';

// Part files containing FastSaleNotifier extension methods
part 'fast_sale_notifier_init.dart';
part 'fast_sale_notifier_tabs.dart';
part 'fast_sale_notifier_keypad.dart';
part 'fast_sale_notifier_lines.dart';
part 'fast_sale_notifier_customer.dart';
part 'fast_sale_notifier_save.dart';
part 'fast_sale_notifier_confirm.dart';
part 'fast_sale_notifier_websocket.dart';

/// Sub-tab type for the order panel (Lines | Payments/Credit)
enum OrderPanelTab { lines, payments }

/// Notifier for the current panel tab (Lines | Payments)
class OrderPanelTabNotifier extends Notifier<OrderPanelTab> {
  @override
  OrderPanelTab build() => OrderPanelTab.lines;

  void setTab(OrderPanelTab tab) {
    state = tab;
  }

  void goToLines() => state = OrderPanelTab.lines;
  void goToPayments() => state = OrderPanelTab.payments;
}

/// Provider for the current panel tab (Lines | Payments)
/// This allows external widgets (like POSActionsPanel) to switch tabs
final orderPanelTabProvider = NotifierProvider<OrderPanelTabNotifier, OrderPanelTab>(
  () => OrderPanelTabNotifier(),
);

/// Input mode for the POS keypad
enum KeypadInputMode {
  /// Entering product quantity
  quantity,

  /// Searching for products
  search,

  /// Entering price override
  price,

  /// Entering discount percentage
  discount,
}

/// Result of searching and adding a product by code
enum ProductSearchAddResult {
  /// Product found and added successfully
  success,

  /// Product found, quantity incremented on existing line
  incrementedQuantity,

  /// No product found with the given code
  notFound,

  /// Multiple products found, user needs to select one
  multipleMatches,

  /// Operation cancelled or error
  cancelled,
}

/// State for a single POS order tab
@freezed
abstract class FastSaleTabState with _$FastSaleTabState {
  const FastSaleTabState._();

  const factory FastSaleTabState({
    /// Order ID (negative for unsaved local orders)
    required int orderId,

    /// Order reference name (e.g., "1016", "Nueva")
    required String orderName,

    /// The sale order data
    SaleOrder? order,

    /// Order lines
    @Default([]) List<SaleOrderLine> lines,

    /// Currently selected line index (-1 for none)
    @Default(-1) int selectedLineIndex,

    /// Whether this tab has unsaved changes
    @Default(false) bool hasChanges,

    /// Loading state
    @Default(false) bool isLoading,

    /// Error message if any
    String? error,

    /// Authorized payment term IDs for the current partner
    @Default([]) List<int> partnerPaymentTermIds,

    /// Version counter for lines - incremented on WebSocket updates to force UI rebuild
    @Default(0) int linesVersion,

    // ---- Conflict Detection State ----
    /// Indicates if there's a detected conflict with server
    @Default(false) bool hasConflict,

    /// Details of conflicts by field
    Map<String, ConflictDetail>? conflicts,

    /// Conflict message for user
    String? conflictMessage,

    /// Set of locally modified line IDs (for conflict detection)
    @Default({}) Set<int> modifiedLineIds,

    /// Map of locally changed header fields with their values
    @Default({}) Map<String, dynamic> changedFields,
  }) = _FastSaleTabState;

  /// Check if this is a new unsaved order
  bool get isNewOrder => orderId < 0;

  /// Get selected line or null
  SaleOrderLine? get selectedLine =>
      selectedLineIndex >= 0 && selectedLineIndex < lines.length
      ? lines[selectedLineIndex]
      : null;

  /// Calculate subtotal
  double get subtotal => lines
      .where((l) => l.isProductLine)
      .fold(0.0, (sum, line) => sum + line.priceSubtotal);

  /// Calculate tax total
  double get taxTotal => lines
      .where((l) => l.isProductLine)
      .fold(0.0, (sum, line) => sum + line.priceTax);

  /// Calculate grand total
  double get total => lines
      .where((l) => l.isProductLine)
      .fold(0.0, (sum, line) => sum + line.priceTotal);
}

/// State for the Fast Sale (POS) screen
@freezed
abstract class FastSaleState with _$FastSaleState {
  const FastSaleState._();

  const factory FastSaleState({
    /// List of open order tabs
    @Default([]) List<FastSaleTabState> tabs,

    /// Index of currently active tab
    @Default(0) int activeTabIndex,

    /// Current keypad input mode
    @Default(KeypadInputMode.quantity) KeypadInputMode inputMode,

    /// Current keypad input value (as string for editing)
    @Default('') String keypadValue,

    /// Search query for products
    @Default('') String searchQuery,

    /// Whether the customer panel is expanded
    @Default(true) bool isCustomerPanelExpanded,

    /// Global loading state
    @Default(false) bool isLoading,

    /// Whether the provider has been initialized
    @Default(false) bool isInitialized,

    /// Global error message
    String? error,

    /// Last credit issue from confirmation attempt (for showing dialog)
    CreditIssue? lastCreditIssue,

    /// Total count of orders available (for showing "more" indicator)
    @Default(0) int totalOrdersCount,

    /// Counter for generating friendly new order names (Nueva 1, Nueva 2, etc.)
    @Default(0) int newOrderCounter,

    /// Maximum tabs to show (rest accessible via search)
    @Default(10) int maxTabs,
  }) = _FastSaleState;

  /// Get active tab or null
  FastSaleTabState? get activeTab =>
      activeTabIndex >= 0 && activeTabIndex < tabs.length
      ? tabs[activeTabIndex]
      : null;

  /// Check if there are any unsaved changes in any tab
  bool get hasAnyChanges => tabs.any((tab) => tab.hasChanges);

  /// Check if there are more orders than currently shown
  bool get hasMoreOrders => totalOrdersCount > tabs.length;

  /// Check if there's a credit issue that needs user action
  bool get hasCreditIssue => lastCreditIssue != null;
}

/// Notifier for Fast Sale (POS) functionality
///
/// All methods are organized into extension files:
/// - [FastSaleNotifierInit] - Initialization, cache sync, validation helpers
/// - [FastSaleNotifierTabs] - Tab management (add, switch, close, load)
/// - [FastSaleNotifierKeypad] - Keypad input handling
/// - [FastSaleNotifierLines] - Line operations (select, add, update, delete)
/// - [FastSaleNotifierCustomer] - Customer management
/// - [FastSaleNotifierSave] - Save operations
/// - [FastSaleNotifierConfirm] - Confirmation and credit validation
/// - [FastSaleNotifierWebSocket] - WebSocket updates, state management, conflict resolution
@Riverpod(keepAlive: true)
class FastSaleNotifier extends _$FastSaleNotifier {
  /// Last deleted line for undo support (used by FastSaleNotifierLines extension)
  SaleOrderLine? lastDeletedLine;
  int? lastDeletedLineIndex;

  @override
  FastSaleState build() {
    // Listen to cache changes and sync open orders
    ref.listen<OrderCacheState>(orderCacheProvider, (previous, next) {
      if (previous?.version != next.version) {
        // _syncFromCache is in FastSaleNotifierInit extension
        _syncFromCache(next);
      }
    });

    return const FastSaleState();
  }
}

/// Provider for active tab state (for granular rebuilds)
///
/// Uses multiple selectors to ensure updates when:
/// - Active tab index changes
/// - Tabs list changes (including when tab content is updated)
final fastSaleActiveTabProvider = Provider<FastSaleTabState?>((ref) {
  final state = ref.watch(fastSaleProvider);
  return state.activeTab;
});

/// Provider for active tab lines
final fastSaleActiveLinesProvider = Provider<List<SaleOrderLine>>((ref) {
  return ref.watch(fastSaleActiveTabProvider)?.lines ?? [];
});

/// Provider for keypad value
final fastSaleKeypadValueProvider = Provider<String>((ref) {
  return ref.watch(fastSaleProvider.select((s) => s.keypadValue));
});

/// Provider for input mode
final fastSaleInputModeProvider = Provider<KeypadInputMode>((ref) {
  return ref.watch(fastSaleProvider.select((s) => s.inputMode));
});

/// Provider to check if active order can be modified
///
/// Returns true only for draft and sent states.
/// Use this to disable UI controls when order cannot be edited.
final fastSaleCanEditProvider = Provider<bool>((ref) {
  final order = ref.watch(fastSaleActiveTabProvider)?.order;
  // New orders (no order yet) are always editable
  if (order == null) return true;
  return order.isEditable;
});

/// Global callback to focus the search input
///
/// Set by _SearchInputField and called by _NumericKeypad when mode buttons are pressed.
void Function()? _searchInputFocusCallback;

/// Set the search input focus callback
void setSearchInputFocusCallback(void Function()? callback) {
  _searchInputFocusCallback = callback;
}

/// Request focus on the search input
void requestSearchInputFocus() {
  _searchInputFocusCallback?.call();
}
