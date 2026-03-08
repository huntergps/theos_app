/// Payment Terms feature module
///
/// Centralizes all payment term-related functionality.
///
/// **Models:**
/// - [PaymentTerm] - Freezed model wrapping AccountPaymentTermData
///
/// **Providers:**
/// - [paymentTermsProvider] - All payment terms
/// - [cashPaymentTermsProvider] - Cash payment terms
/// - [creditPaymentTermsProvider] - Credit payment terms
library;

export 'providers/providers.dart';
