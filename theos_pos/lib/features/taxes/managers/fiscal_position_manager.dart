/// Re-export FiscalPositionManager and FiscalPositionTaxManager from theos_pos_core
///
/// FiscalPositionManager is generated (from fiscal_position.model.dart).
/// FiscalPositionTaxManager is manual (from fiscal_position_manager.dart).
/// FiscalPositionManagerBusiness extension provides getById/getAll.
library;

export 'package:theos_pos_core/theos_pos_core.dart' show FiscalPositionManager, FiscalPositionTaxManager, fiscalPositionManager;
export 'package:theos_pos_core/src/managers/taxes/fiscal_position_manager.dart' show FiscalPositionManagerBusiness;
