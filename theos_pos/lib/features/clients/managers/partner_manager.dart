/// Re-export ClientManager from theos_pos_core for backwards compatibility
library;

export 'package:theos_pos_core/theos_pos_core.dart' show ClientManager, clientManager;

// Also export the extension methods
export 'package:theos_pos_core/src/managers/clients/partner_manager.dart';
