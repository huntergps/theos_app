/// Barrel file for shared widgets.
///
/// Este archivo exporta todos los widgets compartidos del proyecto.
/// Usar este import para acceder a cualquier widget:
/// ```dart
/// import 'package:theos_pos/shared/widgets/widgets.dart';
/// ```
library;

// ===== LEGACY EXPORTS (mantener por compatibilidad) =====
export 'common_form_widgets.dart';
export 'common_grid_widgets.dart';
export 'model_status_bar.dart';
export 'user_preferences_dialog.dart';
export 'websocket_status_widget.dart';

// ===== COMMON WIDGETS =====
// Widgets de uso general
export 'common/chip_is_local.dart';
export 'common/theos_info_row.dart';
export 'common/loading_overlay.dart';
export 'common/theos_search_filter_bar.dart';
export 'common/theos_state_chip.dart';
// Nuevos widgets comunes unificados
export 'common/theos_info_bars.dart';
export 'common/loading_indicators.dart';
export 'common/theos_chips.dart';

// ===== DIALOG WIDGETS =====
// Diálogos y sus clases base
export 'dialogs/copyable_info_bar.dart';
export 'dialogs/confirm_action_dialog.dart';
export 'dialogs/theos_dialogs.dart';
export 'dialogs/base_search_dialog.dart';
// Nuevas clases base para diálogos
export 'dialogs/base_form_dialog.dart';
export 'dialogs/base_detail_dialog.dart';

// ===== FORM WIDGETS =====
// Widgets de formulario
export 'form/form_fields.dart';       // Form* widgets (FormTextField, FormComboBox, FormSection, etc.)
export 'form/theos_responsive_row.dart';

// ===== GRID WIDGETS =====
// Widgets para grids y tablas
export 'grid/theos_date_cell.dart';
export 'grid/theos_number_cell.dart';
export 'grid/theos_data_grid.dart';
export 'grid/theos_data_grid_source.dart';

// ===== BUILDER WIDGETS =====
// Widgets builder para manejo de estados
export 'builders/async_content_builder.dart';
export 'builders/either_result_handler.dart';

// ===== CARD WIDGETS =====
// Widgets tipo card
export 'cards/info_display_card.dart';
export 'cards/section_card.dart';
export 'order_config_card.dart';

// ===== REACTIVE WIDGETS =====
// Widgets reactivos con modo vista/edición
export 'reactive/reactive_widgets.dart';

// ===== RELATED FIELD WIDGETS =====
export 'related_field_text.dart';

// ===== SYNC WIDGETS =====
// Widgets de sincronización (moved to features/sync/)
export '../../features/sync/widgets/sync_widgets.dart';

// ===== STATUS WIDGETS =====
export 'status_indicator.dart';
export 'server_status_widget.dart';

// ===== SCREEN UTILITIES =====
export 'auth_guard.dart';
export 'deferred_screen.dart';
