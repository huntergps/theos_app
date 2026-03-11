import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers.dart' show partnerProvider;
import '../../../../../core/services/platform/global_notification_service.dart';
import '../../../../../shared/widgets/reactive/reactive_field_base.dart';
import '../../../../../shared/widgets/reactive/reactive_partner_card.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../widgets/credit_info_card.dart';
import '../../sale_order_form/edit_dialogs.dart';
import '../fast_sale_providers.dart';
import 'pos_order_config_card.dart';

/// Center panel with customer info and numeric keypad
///
/// Layout:
/// - Customer card (avatar, name, contact info, address)
/// - Customer info table (loyalty card, balance, etc.)
/// - Search/quantity input field
/// - Numeric keypad (calculator style)
class POSCustomerKeypadPanel extends ConsumerWidget {
  /// Whether to show in compact mode (for mobile)
  final bool isCompact;

  const POSCustomerKeypadPanel({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final isExpanded = ref.watch(
      fastSaleProvider.select((s) => s.isCustomerPanelExpanded),
    );

    if (isCompact) {
      return _buildCompactView(context, ref, theme, activeTab);
    }

    // Only editable in draft or sent state
    final canEdit = activeTab?.order?.isEditable ?? true;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 1. Order configuration card (pricelist, warehouse, etc.)
          const Padding(
            padding: EdgeInsets.all(Spacing.sm),
            child: POSOrderConfigCard(),
          ),

          // 2. Customer card using ReactivePartnerCard
          // Get partner details from database for complete info
          Builder(
            builder: (context) {
              final partnerId = activeTab?.order?.partnerId;
              final partnerAsync = partnerId != null
                  ? ref.watch(partnerProvider(partnerId))
                  : null;

              // Get partner data from async provider (or use fallback from order)
              final partner = partnerAsync?.value;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                child: ReactivePartnerCard(
                  config: ReactiveFieldConfig(
                    label: 'Cliente',
                    isEditing: canEdit, // Only editable in draft/sent
                    isCompact: !isExpanded,
                  ),
                  partner: PartnerInfo(
                    id: partner?.id ?? activeTab?.order?.partnerId,
                    name: partner?.name ?? activeTab?.order?.partnerName,
                    vat: partner?.vat ?? activeTab?.order?.partnerVat,
                    street: partner?.street ?? activeTab?.order?.partnerStreet,
                    phone: partner?.phone ?? activeTab?.order?.partnerPhone,
                    email: partner?.email ?? activeTab?.order?.partnerEmail,
                    avatar: partner?.avatar128 ?? activeTab?.order?.partnerAvatar,
                    isFinalConsumer: activeTab?.order?.isFinalConsumer ?? false,
                    endCustomerName: activeTab?.order?.endCustomerName,
                    endCustomerPhone: activeTab?.order?.endCustomerPhone,
                    endCustomerEmail: activeTab?.order?.endCustomerEmail,
                    referrerId: activeTab?.order?.referrerId,
                    referrerName: activeTab?.order?.referrerName,
                  ),
                  callbacks: PartnerCardCallbacks(
                    onSelectPartner: canEdit
                        ? () => _showCustomerSearchDialog(context, ref)
                        : null,
                    onCreatePartner: canEdit
                        ? () => _showCreatePartnerDialog(context, ref)
                        : null,
                    onPhoneChanged: canEdit
                        ? (value) => ref
                              .read(fastSaleProvider.notifier)
                              .updatePartnerPhone(value)
                        : null,
                    onEmailChanged: canEdit
                        ? (value) => ref
                              .read(fastSaleProvider.notifier)
                              .updatePartnerEmail(value)
                        : null,
                    onEndCustomerNameChanged: canEdit
                        ? (value) => ref
                              .read(fastSaleProvider.notifier)
                              .updateEndCustomerName(value)
                        : null,
                    onEndCustomerPhoneChanged: canEdit
                        ? (value) => ref
                              .read(fastSaleProvider.notifier)
                              .updateEndCustomerPhone(value)
                        : null,
                    onEndCustomerEmailChanged: canEdit
                        ? (value) => ref
                              .read(fastSaleProvider.notifier)
                              .updateEndCustomerEmail(value)
                        : null,
                    onSelectReferrer: canEdit
                        ? () => _showSelectReferrerDialog(context, ref)
                        : null,
                  ),
                  isCompact: !isExpanded,
                ),
              );
            },
          ),

          // 3. Credit info table (shows when partner selected)
          // Note: hideSyncButton=true because sync is handled in POSActionsPanel
          if (activeTab?.order?.partnerId != null) ...[
            const SizedBox(height: Spacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
              child: PartnerCreditInfoCard(
                partnerId: activeTab?.order?.partnerId,
                orderId: activeTab?.order?.id,
                isCompact: !isExpanded,
                hideSyncButton: true,
              ),
            ),
            if (isExpanded) const SizedBox(height: Spacing.sm),
          ],

          // Spacer
          const Spacer(),

          // Search/input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: _SearchInputField(),
          ),
          const SizedBox(height: Spacing.sm),

          // Numeric keypad
          const _NumericKeypad(),

          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }

  Widget _buildCompactView(
    BuildContext context,
    WidgetRef ref,
    FluentThemeData theme,
    FastSaleTabState? activeTab,
  ) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      child: Row(
        children: [
          // Customer name
          Expanded(
            child: GestureDetector(
              onTap: () => _showCustomerSearchDialog(context, ref),
              child: Row(
                children: [
                  Icon(FluentIcons.contact, size: 16),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    activeTab?.order?.partnerName ?? 'Seleccionar cliente',
                    style: theme.typography.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: Spacing.xxs),
                  Icon(FluentIcons.chevron_down, size: 12),
                ],
              ),
            ),
          ),

          // Total
          Text(
            (activeTab?.total ?? 0).toCurrency(),
            style: theme.typography.bodyStrong?.copyWith(
              fontSize: 18,
              color: theme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomerSearchDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    debugPrint('[POSCustomerKeypad] >>> _showCustomerSearchDialog: Opening dialog...');
    final client = await showSelectClientDialog(context);

    debugPrint('[POSCustomerKeypad] >>> _showCustomerSearchDialog: Dialog returned client=$client');
    if (client != null) {
      debugPrint(
        '[POSCustomerKeypad] >>> _showCustomerSearchDialog: Client selected: '
        'id=${client.id}, name=${client.name}, vat=${client.vat}',
      );
      debugPrint('[POSCustomerKeypad] >>> _showCustomerSearchDialog: Calling setCustomer...');
      await ref
          .read(fastSaleProvider.notifier)
          .setCustomer(
            partnerId: client.id,
            partnerName: client.name,
            partnerVat: client.vat,
            partnerStreet: client.street,
            partnerPhone: client.effectivePhone,
            partnerEmail: client.email,
            partnerAvatar: client.avatar128,
          );
      debugPrint('[POSCustomerKeypad] >>> _showCustomerSearchDialog: setCustomer DONE');
    } else {
      debugPrint('[POSCustomerKeypad] >>> _showCustomerSearchDialog: Dialog cancelled (client is null)');
    }
  }

  /// Show dialog to create a new partner offline
  Future<void> _showCreatePartnerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateClientOfflineDialog(),
    );

    if (result != null) {
      ref
          .read(fastSaleProvider.notifier)
          .setCustomer(
            partnerId: result['id'] as int,
            partnerName: result['name'] as String? ?? '',
            partnerVat: result['vat'] as String?,
            partnerStreet: result['street'] as String?,
            partnerPhone: result['phone'] as String?,
            partnerEmail: result['email'] as String?,
          );
    }
  }

  /// Show dialog to select a referrer
  Future<void> _showSelectReferrerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final client = await showSelectClientDialog(context);

    if (client != null) {
      ref
          .read(fastSaleProvider.notifier)
          .setReferrer(
            referrerId: client.id,
            referrerName: client.name,
          );
    }
  }
}

/// Search/quantity input field
///
/// When in search mode, shows a real TextBox for alphanumeric input.
/// For other modes, shows the keypad value display.
class _SearchInputField extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchInputField> createState() => _SearchInputFieldState();
}

class _SearchInputFieldState extends ConsumerState<_SearchInputField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Register focus callback for keypad mode buttons
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setSearchInputFocusCallback(_requestFocus);
    });
  }

  /// Request focus on the search input field
  void _requestFocus() {
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    // Clear the focus callback
    setSearchInputFocusCallback(null);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle keyboard input for quantity/discount modes ONLY
  ///
  /// Returns KeyEventResult.handled if the event was consumed (to prevent
  /// it from reaching the TextBox), or KeyEventResult.ignored to let it pass.
  ///
  /// Note: This is only used when NOT in search mode.
  KeyEventResult _handleNumericKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final notifier = ref.read(fastSaleProvider.notifier);

    // Handle + key for increment
    if (event.logicalKey == LogicalKeyboardKey.add ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      notifier.incrementSelectedLineQuantity();
      return KeyEventResult.handled; // Consume the event
    }

    // Handle - key for decrement
    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      notifier.decrementSelectedLineQuantity();
      return KeyEventResult.handled; // Consume the event
    }

    // Let other keys pass through
    return KeyEventResult.ignored;
  }

  /// Open product search dialog (like the grid code field)
  Future<void> _openProductSearchDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          SelectProductDialog(initialSearch: _controller.text),
    );

    if (result != null && mounted) {
      // Get quantity and discount from prefixed values if present
      final quantity = (result['_quantity'] as num?)?.toDouble() ?? 1.0;
      final discount = (result['_discount'] as num?)?.toDouble() ?? 0.0;

      // Add the product to the order
      await ref
          .read(fastSaleProvider.notifier)
          .addProduct(
            productId: result['id'] as int,
            productName: result['name'] as String? ?? '',
            productCode: result['default_code'] as String?,
            quantity: quantity,
            priceUnit: (result['list_price'] as num?)?.toDouble() ?? 0.0,
            discount: discount,
            uomId: result['uom_id'] is List
                ? (result['uom_id'] as List)[0] as int
                : result['uom_id'] as int?,
            uomName: result['uom_id'] is List
                ? (result['uom_id'] as List)[1] as String
                : null,
            taxIds: (result['taxes_id'] as List<dynamic>?)?.cast<int>(),
          );

      // Show success feedback
      _showSuccessFeedback(result['name'] as String? ?? 'Producto');

      // Clear the search field after adding product
      _controller.clear();
      ref.read(fastSaleProvider.notifier).clearKeypad();
    }
  }

  /// Search product by code and add to order
  Future<void> _searchAndAddProduct(String input) async {
    if (input.trim().isEmpty) return;

    final notifier = ref.read(fastSaleProvider.notifier);
    final (result, matches) = await notifier.searchAndAddProductByCode(input);

    if (!mounted) return;

    switch (result) {
      case ProductSearchAddResult.success:
        // Product found and added - show success feedback
        _showSuccessFeedback('Producto agregado');
        _clearField();
        break;

      case ProductSearchAddResult.incrementedQuantity:
        // Quantity incremented on existing line - show feedback
        _showSuccessFeedback('Cantidad incrementada');
        _clearField();
        break;

      case ProductSearchAddResult.notFound:
        // No product found - show warning and keep text for correction
        ref
            .read(globalNotificationProvider)
            .showWarning(
              context,
              title: 'No encontrado',
              message: 'Código: ${input.trim()}',
              durationSeconds: 2,
            );
        // Select all text for easy correction
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
        break;

      case ProductSearchAddResult.multipleMatches:
        // Multiple matches - open dialog with pre-filtered results
        if (matches != null && matches.isNotEmpty) {
          final selected = await showDialog<Map<String, dynamic>>(
            context: context,
            builder: (context) =>
                SelectProductDialog(initialSearch: input.trim()),
          );

          if (selected != null && mounted) {
            // Get quantity and discount from the matches list
            final quantity =
                (matches.first['_quantity'] as num?)?.toDouble() ?? 1.0;
            final discount =
                (matches.first['_discount'] as num?)?.toDouble() ?? 0.0;

            await notifier.addProduct(
              productId: selected['id'] as int,
              productName: selected['name'] as String? ?? '',
              productCode: selected['default_code'] as String?,
              quantity: quantity,
              priceUnit: (selected['list_price'] as num?)?.toDouble() ?? 0.0,
              discount: discount,
              uomId: selected['uom_id'] is List
                  ? (selected['uom_id'] as List)[0] as int
                  : selected['uom_id'] as int?,
              uomName: selected['uom_id'] is List
                  ? (selected['uom_id'] as List)[1] as String
                  : null,
              taxIds: (selected['taxes_id'] as List<dynamic>?)?.cast<int>(),
            );

            _showSuccessFeedback(selected['name'] as String? ?? 'Producto');
            _clearField();
          }
        }
        break;

      case ProductSearchAddResult.cancelled:
        // Do nothing
        break;
    }
  }

  void _clearField() {
    _controller.clear();
    ref.read(fastSaleProvider.notifier).clearKeypad();
  }

  void _showSuccessFeedback(String productName) {
    // Show brief success notification
    ref
        .read(globalNotificationProvider)
        .showSuccess(
          context,
          title: '✓ Agregado',
          message: productName,
          durationSeconds: 1,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final keypadValue = ref.watch(fastSaleKeypadValueProvider);
    final inputMode = ref.watch(fastSaleInputModeProvider);
    final notifier = ref.read(fastSaleProvider.notifier);

    // Sync controller with keypad value if changed externally (e.g., by virtual keypad)
    if (_controller.text != keypadValue) {
      _controller.text = keypadValue;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: keypadValue.length),
      );
    }

    // Determine placeholder and icon based on mode
    String placeholder;
    IconData icon;
    bool isSearchMode = inputMode == KeypadInputMode.search;

    switch (inputMode) {
      case KeypadInputMode.search:
        placeholder = 'Buscar producto por código o nombre';
        icon = FluentIcons.search;
        break;
      case KeypadInputMode.quantity:
        placeholder = 'Cantidad (+/-/Enter)';
        icon = FluentIcons.number_field;
        break;
      case KeypadInputMode.discount:
        placeholder = 'Descuento % (+/-/Enter)';
        icon = FluentIcons.calculator_percentage;
        break;
      case KeypadInputMode.price:
        placeholder = 'Precio';
        icon = FluentIcons.money;
        break;
    }

    // Build the TextBox
    final textBox = TextBox(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: placeholder,
      keyboardType: isSearchMode
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isSearchMode
          ? null
          : [
              // Allow digits, period, and the current value for editing
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
      prefix: Padding(
        padding: const EdgeInsets.only(left: Spacing.xs),
        child: Icon(icon, size: 16),
      ),
      suffix: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search icon button to open product dialog (only in search mode)
          if (isSearchMode)
            GestureDetector(
              onTap: _openProductSearchDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
                child: Icon(
                  FluentIcons.search,
                  size: 14,
                  color: theme.accentColor,
                ),
              ),
            ),
          // Clear button when there's text
          if (keypadValue.isNotEmpty)
            IconButton(
              icon: const Icon(FluentIcons.chrome_close, size: 14),
              onPressed: _clearField,
            ),
        ],
      ),
      onChanged: (value) {
        // Update provider state as user types
        notifier.setKeypadValue(value);
      },
      onSubmitted: (value) {
        if (isSearchMode) {
          // Search and add product when Enter is pressed
          _searchAndAddProduct(value);
        } else {
          // Apply the value (quantity or discount)
          notifier.applyKeypadValue();
          _clearField();
        }
      },
    );

    // In search mode, return TextBox directly (no key interception for +/-)
    if (isSearchMode) {
      return textBox;
    }

    // In quantity/discount modes, wrap with Focus to intercept +/- keys
    return Focus(onKeyEvent: _handleNumericKeyEvent, child: textBox);
  }
}

/// Numeric keypad (calculator style) - Similar to Odoo POS
///
/// Layout:
/// ```
/// ┌─────┬─────┬─────┬─────┐
/// │  7  │  8  │  9  │  ⌫  │
/// ├─────┼─────┼─────┼─────┤
/// │  4  │  5  │  6  │  +  │  ← Increment quantity
/// ├─────┼─────┼─────┼─────┤
/// │  1  │  2  │  3  │  -  │  ← Decrement quantity
/// ├─────┴─────┼─────┼─────┤
/// │     0     │  .  │  C  │  ← Clear
/// ├───────────┴─────┴─────┤
/// │ Cant │ Desc% │ Precio │  ← Mode buttons
/// ├───────────────────────┤
/// │        ENTER          │
/// └───────────────────────┘
/// ```
class _NumericKeypad extends ConsumerWidget {
  const _NumericKeypad();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final notifier = ref.read(fastSaleProvider.notifier);
    final inputMode = ref.watch(fastSaleInputModeProvider);
    final canEdit = ref.watch(fastSaleCanEditProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        children: [
          // Row 1: 7, 8, 9, Backspace
          Row(
            children: [
              _KeypadButton(
                label: '7',
                onTap: () => notifier.appendKeypadDigit('7'),
              ),
              _KeypadButton(
                label: '8',
                onTap: () => notifier.appendKeypadDigit('8'),
              ),
              _KeypadButton(
                label: '9',
                onTap: () => notifier.appendKeypadDigit('9'),
              ),
              _KeypadButton(
                icon: FluentIcons.back,
                onTap: () => notifier.deleteKeypadChar(),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),

          // Row 2: 4, 5, 6, + (action depends on mode)
          Row(
            children: [
              _KeypadButton(
                label: '4',
                onTap: () => notifier.appendKeypadDigit('4'),
              ),
              _KeypadButton(
                label: '5',
                onTap: () => notifier.appendKeypadDigit('5'),
              ),
              _KeypadButton(
                label: '6',
                onTap: () => notifier.appendKeypadDigit('6'),
              ),
              _KeypadButton(
                icon: FluentIcons.add,
                onTap: () {
                  switch (inputMode) {
                    case KeypadInputMode.search:
                      // In search mode, append '+' to the input
                      notifier.appendKeypadDigit('+');
                      break;
                    case KeypadInputMode.quantity:
                      // In quantity mode, increment quantity
                      notifier.incrementSelectedLineQuantity();
                      break;
                    case KeypadInputMode.discount:
                      // In discount mode, increment discount by 1%
                      notifier.incrementSelectedLineDiscount();
                      break;
                    case KeypadInputMode.price:
                      // Price mode not used, default to quantity
                      notifier.incrementSelectedLineQuantity();
                      break;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),

          // Row 3: 1, 2, 3, - (action depends on mode)
          Row(
            children: [
              _KeypadButton(
                label: '1',
                onTap: () => notifier.appendKeypadDigit('1'),
              ),
              _KeypadButton(
                label: '2',
                onTap: () => notifier.appendKeypadDigit('2'),
              ),
              _KeypadButton(
                label: '3',
                onTap: () => notifier.appendKeypadDigit('3'),
              ),
              _KeypadButton(
                icon: FluentIcons.remove,
                onTap: () {
                  switch (inputMode) {
                    case KeypadInputMode.search:
                      // In search mode, append '-' to the input
                      notifier.appendKeypadDigit('-');
                      break;
                    case KeypadInputMode.quantity:
                      // In quantity mode, decrement quantity
                      notifier.decrementSelectedLineQuantity();
                      break;
                    case KeypadInputMode.discount:
                      // In discount mode, decrement discount by 1%
                      notifier.decrementSelectedLineDiscount();
                      break;
                    case KeypadInputMode.price:
                      // Price mode not used, default to quantity
                      notifier.decrementSelectedLineQuantity();
                      break;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),

          // Row 4: 0, ., C (clear)
          Row(
            children: [
              _KeypadButton(
                label: '0',
                onTap: () => notifier.appendKeypadDigit('0'),
                flex: 2,
              ),
              _KeypadButton(
                label: '.',
                onTap: () => notifier.appendKeypadDigit('.'),
              ),
              _KeypadButton(label: 'C', onTap: () => notifier.clearKeypad()),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // Row 5: Mode buttons (Qty, Disc%, Search)
          // Note: Price is NOT editable from POS - prices come from Odoo pricelists
          Row(
            children: [
              _ModeButton(
                label: 'Cantidad',
                icon: FluentIcons.number_field,
                isActive: inputMode == KeypadInputMode.quantity,
                onTap: () {
                  notifier.setInputMode(KeypadInputMode.quantity);
                  // Focus the input field after changing mode
                  requestSearchInputFocus();
                },
                theme: theme,
              ),
              const SizedBox(width: Spacing.xs),
              _ModeButton(
                label: 'Descuento',
                icon: FluentIcons.calculator_percentage,
                isActive: inputMode == KeypadInputMode.discount,
                onTap: () {
                  notifier.setInputMode(KeypadInputMode.discount);
                  // Focus the input field after changing mode
                  requestSearchInputFocus();
                },
                theme: theme,
              ),
              const SizedBox(width: Spacing.xs),
              _ModeButton(
                label: 'Buscar',
                icon: FluentIcons.search,
                isActive: inputMode == KeypadInputMode.search,
                onTap: () {
                  notifier.setInputMode(KeypadInputMode.search);
                  // Focus the input field after changing mode
                  requestSearchInputFocus();
                },
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // Row 6: Enter (full width)
          // Disabled when order is not editable
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: canEdit ? () => notifier.applyKeypadValue() : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FluentIcons.return_key, size: 16),
                  const SizedBox(width: Spacing.xs),
                  const Text('Aplicar'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode button for switching between Quantity, Discount, Price
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final FluentThemeData theme;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 44,
        child: isActive
            ? FilledButton(
                onPressed: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 14),
                    const SizedBox(width: Spacing.xxs),
                    Text(label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : Button(
                onPressed: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 14),
                    const SizedBox(width: Spacing.xxs),
                    Text(label, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Individual keypad button
class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final int flex;

  const _KeypadButton({
    this.label,
    this.icon,
    required this.onTap,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
        child: SizedBox(
          height: 48,
          child: Button(
            onPressed: onTap,
            child: icon != null
                ? Icon(icon, size: 18)
                : Text(
                    label ?? '',
                    style: theme.typography.bodyLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
