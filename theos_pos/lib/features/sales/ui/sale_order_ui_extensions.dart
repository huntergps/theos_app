import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleOrderState, InvoiceStatus;

import '../../../core/constants/app_colors.dart';

/// UI extensions for SaleOrderState (colors, icons)
/// These are presentation-layer concerns and should not be in the domain layer.
extension SaleOrderStateUI on SaleOrderState {
  Color get color {
    switch (this) {
      case SaleOrderState.draft:
        return Colors.grey;
      case SaleOrderState.sent:
        return AppColors.info;
      case SaleOrderState.waitingApproval:
        return AppColors.warning;
      case SaleOrderState.approved:
        return AppColors.info;
      case SaleOrderState.rejected:
        return AppColors.danger;
      case SaleOrderState.sale:
        return AppColors.success;
      case SaleOrderState.done:
        return AppColors.done;
      case SaleOrderState.cancel:
        return AppColors.danger;
    }
  }

  /// Background color for badge/chip display
  Color get backgroundColor {
    switch (this) {
      case SaleOrderState.draft:
        return Colors.grey[40];
      case SaleOrderState.sent:
        return AppColors.info.withAlpha(25);
      case SaleOrderState.waitingApproval:
        return AppColors.warning.withAlpha(25);
      case SaleOrderState.approved:
        return AppColors.info.withAlpha(25);
      case SaleOrderState.rejected:
        return AppColors.danger.withAlpha(25);
      case SaleOrderState.sale:
        return AppColors.success.withAlpha(25);
      case SaleOrderState.done:
        return AppColors.done.withAlpha(25);
      case SaleOrderState.cancel:
        return AppColors.danger.withAlpha(25);
    }
  }

  /// Text color for badge/chip display
  Color get textColor {
    switch (this) {
      case SaleOrderState.draft:
        return Colors.grey[160];
      case SaleOrderState.sent:
        return AppColors.info;
      case SaleOrderState.waitingApproval:
        return AppColors.warning;
      case SaleOrderState.approved:
        return AppColors.info;
      case SaleOrderState.rejected:
        return AppColors.danger;
      case SaleOrderState.sale:
        return AppColors.success;
      case SaleOrderState.done:
        return AppColors.done;
      case SaleOrderState.cancel:
        return AppColors.danger;
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
        return AppColors.warning;
      case InvoiceStatus.invoiced:
        return AppColors.success;
      case InvoiceStatus.upselling:
        return AppColors.upselling;
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
