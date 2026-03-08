// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Keypad input handling for FastSaleNotifier.
///
/// Manages digit entry, sign toggling, and applying keypad values
/// to the selected order line (quantity, discount, search).
extension FastSaleNotifierKeypad on FastSaleNotifier {
  /// Set the keypad input mode
  void setInputMode(KeypadInputMode mode) {
    state = state.copyWith(inputMode: mode, keypadValue: '');
  }

  /// Append a digit to keypad value
  void appendKeypadDigit(String digit) {
    // Validate input
    if (digit == '.' && state.keypadValue.contains('.')) {
      return; // Only one decimal point allowed
    }

    state = state.copyWith(keypadValue: state.keypadValue + digit);
  }

  /// Delete last character from keypad value
  void deleteKeypadChar() {
    if (state.keypadValue.isNotEmpty) {
      state = state.copyWith(
        keypadValue: state.keypadValue.substring(
          0,
          state.keypadValue.length - 1,
        ),
      );
    }
  }

  /// Clear keypad value
  void clearKeypad() {
    state = state.copyWith(keypadValue: '');
  }

  /// Set keypad value directly (for text input in search mode)
  void setKeypadValue(String value) {
    state = state.copyWith(keypadValue: value);
  }

  /// Toggle sign (for quantity adjustments)
  void toggleSign() {
    if (state.keypadValue.isEmpty) return;

    if (state.keypadValue.startsWith('-')) {
      state = state.copyWith(keypadValue: state.keypadValue.substring(1));
    } else {
      state = state.copyWith(keypadValue: '-${state.keypadValue}');
    }
  }

  /// Apply the keypad value to the selected line
  ///
  /// Requires order to be editable for all modes (including search,
  /// since search leads to adding products).
  Future<void> applyKeypadValue() async {
    // Block all modes if order is not editable
    if (!_ensureCanModify('applyKeypadValue')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final value = double.tryParse(state.keypadValue);
    if (value == null && state.inputMode != KeypadInputMode.search) return;

    switch (state.inputMode) {
      case KeypadInputMode.quantity:
        await _updateSelectedLineQuantity(value ?? 1);
        break;

      case KeypadInputMode.price:
        // Price editing is disabled in POS - prices come from Odoo pricelists
        state = state.copyWith(
          error:
              'El precio no se puede modificar desde el POS. Use las listas de precios de Odoo.',
          inputMode: KeypadInputMode.quantity,
        );
        break;

      case KeypadInputMode.discount:
        await _updateSelectedLineDiscount(value ?? 0);
        break;

      case KeypadInputMode.search:
        state = state.copyWith(searchQuery: state.keypadValue);
        break;
    }

    // Clear keypad after applying
    state = state.copyWith(keypadValue: '');
  }
}
