import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleOrderState, InvoiceStatus;

/// UI extensions for SaleOrderState (colors, icons)
/// These are presentation-layer concerns and should not be in the domain layer.
extension SaleOrderStateUI on SaleOrderState {
  Color get color {
    switch (this) {
      case SaleOrderState.draft:
        return Colors.grey;
      case SaleOrderState.sent:
        return Colors.blue;
      case SaleOrderState.waitingApproval:
        return Colors.orange;
      case SaleOrderState.approved:
        return Colors.blue;
      case SaleOrderState.rejected:
        return Colors.red;
      case SaleOrderState.sale:
        return Colors.green;
      case SaleOrderState.done:
        return Colors.teal;
      case SaleOrderState.cancel:
        return Colors.red;
    }
  }

  /// Background color for badge/chip display
  Color get backgroundColor {
    switch (this) {
      case SaleOrderState.draft:
        return Colors.grey[40];
      case SaleOrderState.sent:
        return Colors.blue.lightest;
      case SaleOrderState.waitingApproval:
        return Colors.orange.lightest;
      case SaleOrderState.approved:
        return Colors.teal.lightest;
      case SaleOrderState.rejected:
        return Colors.red.lightest;
      case SaleOrderState.sale:
        return Colors.green.lightest;
      case SaleOrderState.done:
        return Colors.purple.lightest;
      case SaleOrderState.cancel:
        return Colors.red.lightest;
    }
  }

  /// Text color for badge/chip display
  Color get textColor {
    switch (this) {
      case SaleOrderState.draft:
        return Colors.grey[160];
      case SaleOrderState.sent:
        return Colors.blue.dark;
      case SaleOrderState.waitingApproval:
        return Colors.orange.dark;
      case SaleOrderState.approved:
        return Colors.teal.dark;
      case SaleOrderState.rejected:
        return Colors.red.dark;
      case SaleOrderState.sale:
        return Colors.green.dark;
      case SaleOrderState.done:
        return Colors.purple.dark;
      case SaleOrderState.cancel:
        return Colors.red.dark;
    }
  }

  IconData get icon {
    switch (this) {
      case SaleOrderState.draft:
        return FluentIcons.edit;
      case SaleOrderState.sent:
        return FluentIcons.send;
      case SaleOrderState.waitingApproval:
        return FluentIcons.clock;
      case SaleOrderState.approved:
        return FluentIcons.check_mark;
      case SaleOrderState.rejected:
        return FluentIcons.error_badge;
      case SaleOrderState.sale:
        return FluentIcons.shopping_cart;
      case SaleOrderState.done:
        return FluentIcons.lock;
      case SaleOrderState.cancel:
        return FluentIcons.cancel;
    }
  }
}

/// UI extensions for InvoiceStatus (colors, icons)
extension InvoiceStatusUI on InvoiceStatus {
  Color get color {
    switch (this) {
      case InvoiceStatus.no:
        return Colors.transparent;
      case InvoiceStatus.toInvoice:
        return Colors.orange;
      case InvoiceStatus.invoiced:
        return Colors.green;
      case InvoiceStatus.upselling:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case InvoiceStatus.no:
        return FluentIcons.circle_ring;
      case InvoiceStatus.toInvoice:
        return FluentIcons.receipt_processing;
      case InvoiceStatus.invoiced:
        return FluentIcons.receipt_check;
      case InvoiceStatus.upselling:
        return FluentIcons.trending12;
    }
  }
}
