/// Shared order services and mixins for sale order management
///
/// This file exports all shared services and utilities that can be used
/// by both Fast Sale (POS) and Sale Order Form screens.
///
/// Services:
/// - [OrderLineCreationService] - Creates order lines with offline-first pricing
/// - [OrderConfirmationService] - Confirms orders with credit validation
/// - [ConflictDetectionService] - Detects conflicts between local and server data
/// - [OrderDefaultsService] - Loads order defaults with offline-first approach
///
/// Mixins:
/// - [OrderFieldUpdateMixin] - Shared field update operations
/// - [OrderLinesController] - Shared line manipulation operations
///
/// State:
/// - [BaseOrderState] - Common interface for order state
/// - [ConflictDetail] - Conflict detail information
library;

export 'base_order_state.dart';
export 'order_field_update_mixin.dart';
export 'order_lines_controller.dart';
export '../services/order_line_creation_service.dart';
export '../services/order_confirmation_service.dart';
export '../services/conflict_detection_service.dart';
export '../services/order_defaults_service.dart';
export '../services/line_operations_helper.dart';
