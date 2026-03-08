/// Core repositories module - exports base and common repository classes
///
/// Feature-specific repositories are located in their respective
/// feature directories:
/// - features/users/repositories/
/// - features/collection/repositories/
/// - features/clients/repositories/
/// - features/products/repositories/
/// - features/sales/repositories/
/// - features/reports/repositories/
library;

// Base
export 'base_repository.dart';

// Common
export 'common_repository.dart';

// Feature repositories (re-exported for convenience)
export '../../../features/banks/repositories/bank_repository.dart';
export '../../../features/company/repositories/company_repository.dart';

// Providers
export 'repository_providers.dart';
