// Barrel file for collection models/DTOs
library;

export 'collection_config.model.dart';
// Hide generated CollectionSessionManager - we use the one from managers/
export 'collection_session.model.dart' hide CollectionSessionManager;
export 'collection_session_extensions.dart';
export 'collection_session_cash.model.dart';
export 'collection_session_deposit.model.dart';
export 'account_payment.model.dart';
export 'cash_out.model.dart';

// Note: Advance model moved to features/advances/models/advance.model.dart
// Import from 'package:theos_pos/features/advances/advances.dart' instead
