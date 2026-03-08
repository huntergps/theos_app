/// Model Managers - Unified model management layer
///
/// These managers bridge the annotated models from odoo_model_manager
/// with the existing database tables in theos_pos, providing:
/// - Offline-first CRUD operations
/// - Automatic sync to/from Odoo
/// - WebSocket event handling via ModelRegistry
///
/// Managers are now located in their respective feature folders.
/// This file re-exports them for backward compatibility.
library;

// Infrastructure (stays in core)
export 'manager_providers.dart';
export 'model_registry_integration.dart';

// Re-export managers from features
export '../../features/products/managers/managers.dart';
export '../../features/sales/managers/managers.dart';
export '../../features/collection/managers/managers.dart';
export '../../features/clients/managers/managers.dart';
export '../../features/taxes/managers/managers.dart';
export '../../features/users/managers/managers.dart';
export '../../features/prices/managers/managers.dart';
export '../../features/payment_terms/managers/managers.dart';
