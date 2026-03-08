import '../../clients/clients.dart' show Client, CreditStatus, ClientCalculatorService;
import '../../../shared/utils/formatting_utils.dart';

/// Helper functions for credit display across widgets
///
/// Used by both CreditInfoCard (Material) and POSCreditInfoCard (Fluent).
/// Centralizes credit status logic to ensure consistency.
class CreditDisplayUtils {
  /// Get the display text for credit status
  static String getStatusText(CreditStatus status) {
    switch (status) {
      case CreditStatus.exceeded:
        return 'EXCEDIDO';
      case CreditStatus.warning:
        return 'ALERTA';
      case CreditStatus.ok:
        return 'OK';
      case CreditStatus.noLimit:
        return 'SIN LÍMITE';
      case CreditStatus.overdueDebt:
        return 'VENCIDO';
    }
  }

  /// Format currency amount for Ecuador (e.g., "$1,234.56")
  static String formatAmount(double amount) {
    return amount.toCurrency();
  }

  /// Format last sync time as relative text
  static String formatLastSync(DateTime lastSync) {
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 1) {
      return 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else {
      return 'Hace ${diff.inDays}d';
    }
  }

  /// Check if partner needs credit data sync
  ///
  /// Returns true if:
  /// - Credit data was never synced
  /// - Data is older than [maxAgeHours] (default: 1 hour)
  static bool needsSync(Client partner, {int maxAgeHours = 1}) {
    if (partner.creditLastSyncDate == null) return true;
    final age = DateTime.now().difference(partner.creditLastSyncDate!);
    return age.inHours >= maxAgeHours;
  }

  /// Calculate if partner has any credit-related data to display
  ///
  /// Returns true if partner has:
  /// - A credit limit configured, OR
  /// - Any credit used, OR
  /// - Any overdue debt
  static bool hasCreditData(Client partner) {
    if (partner.hasCreditLimit) return true;
    if ((partner.credit ?? 0) > 0) return true;
    if ((partner.totalOverdue ?? 0) > 0) return true;
    return false;
  }

  /// Get credit summary for quick display
  ///
  /// Returns a record with precomputed values for UI display.
  static ({
    double available,
    double usagePercentage,
    CreditStatus status,
    bool hasOverdue,
    bool hasCredit,
  })
  getCreditSummary(Client partner) {
    final hasCredit = partner.hasCreditLimit;
    final available = hasCredit
        ? (ClientCalculatorService.computeCreditAvailable(partner) ?? 0)
        : 0.0;
    final usagePercentage = hasCredit
        ? (ClientCalculatorService.computeCreditUsagePercentage(partner) ?? 0)
        : 0.0;
    final status = partner.creditStatus;
    final hasOverdue = (partner.totalOverdue ?? 0) > 0;

    return (
      available: available,
      usagePercentage: usagePercentage,
      status: status,
      hasOverdue: hasOverdue,
      hasCredit: hasCredit,
    );
  }
}
