/// Constantes de grupos de usuario de Odoo
///
/// Centraliza los external IDs de grupos para evitar duplicacion.
/// Usar estas constantes en lugar de strings literales dispersos.
library;

/// Grupos que tienen permisos de supervisor en el POS.
///
/// Un usuario con cualquiera de estos grupos puede:
/// - Aprobar credito de clientes
/// - Ver el dashboard de supervisor
/// - Ver sesiones de caja de otros cajeros
const kSupervisorGroups = [
  'l10n_ec_collection_box.group_collection_manager',
  'sales_team.group_sale_manager',
  'account.group_account_manager',
  'base.group_system',
];
