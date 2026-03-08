/// Advances feature module
///
/// Provides management for customer/supplier advances (anticipos).
/// Advances are prepayments that can be applied to invoices.
///
/// Usage:
/// ```dart
/// import 'package:theos_pos/features/advances/advances.dart';
///
/// // Use the advance service
/// final advanceService = ref.watch(advanceServiceProvider);
/// final advances = await advanceService.getAvailableAdvances(partnerId);
/// ```
library;

export 'services/services.dart';
export 'widgets/widgets.dart';
export 'providers/providers.dart';
