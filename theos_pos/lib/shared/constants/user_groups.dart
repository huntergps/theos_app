/// Matriz central de roles y grupos de usuario de Odoo.
///
/// Los external IDs se declaran exclusivamente aquí para que menú, rutas y
/// sincronización de permisos compartan el mismo contrato.
library;

/// Roles funcionales reconocidos por Theos POS.
enum TheosUserRole { seller, cashier, supervisor, administrator }

/// External IDs de grupos Odoo utilizados por la aplicación.
abstract final class OdooUserGroup {
  static const internalUser = 'base.group_user';
  static const systemAdministrator = 'base.group_system';
  static const accountManager = 'account.group_account_manager';
  static const salesUser = 'sales_team.group_sale_salesman';
  static const salesManager = 'sales_team.group_sale_manager';
  static const collectionUser = 'l10n_ec_collection_box.group_collection_user';
  static const collectionManager =
      'l10n_ec_collection_box.group_collection_manager';
  static const creditApprover = 'l10n_ec_sale_credit.group_credit_approver';
  static const saleConfirm = 'l10n_ec_base.group_sale_confirm';
  static const allowDeleteRecords = 'l10n_ec_base.group_allow_delete_records';
  static const saleDelete = 'l10n_ec_sale_base.group_sale_delete';
}

const kSellerGroups = [OdooUserGroup.salesUser, OdooUserGroup.salesManager];

const kCashierGroups = [
  OdooUserGroup.collectionUser,
  OdooUserGroup.collectionManager,
];

/// Grupos que pueden aprobar y consultar información de supervisión.
const kSupervisorGroups = [
  OdooUserGroup.collectionManager,
  OdooUserGroup.salesManager,
  OdooUserGroup.accountManager,
  OdooUserGroup.systemAdministrator,
];

/// Grupos con acceso administrativo a sincronización y diagnóstico.
const kAdministratorGroups = [
  OdooUserGroup.accountManager,
  OdooUserGroup.systemAdministrator,
];

/// Relación canónica rol -> grupos Odoo.
const kTheosRoleGroups = <TheosUserRole, List<String>>{
  TheosUserRole.seller: kSellerGroups,
  TheosUserRole.cashier: kCashierGroups,
  TheosUserRole.supervisor: kSupervisorGroups,
  TheosUserRole.administrator: kAdministratorGroups,
};

/// Todos los grupos cuya membresía debe resolver la sincronización de sesión.
const kKnownTheosUserGroups = <String>[
  OdooUserGroup.internalUser,
  OdooUserGroup.systemAdministrator,
  OdooUserGroup.accountManager,
  OdooUserGroup.salesUser,
  OdooUserGroup.salesManager,
  OdooUserGroup.collectionUser,
  OdooUserGroup.collectionManager,
  OdooUserGroup.creditApprover,
  OdooUserGroup.saleConfirm,
  OdooUserGroup.allowDeleteRecords,
  OdooUserGroup.saleDelete,
];

/// Resuelve los roles funcionales representados por una lista de XML IDs.
Set<TheosUserRole> resolveTheosUserRoles(Iterable<String> permissions) {
  final permissionSet = permissions.toSet();
  return {
    for (final entry in kTheosRoleGroups.entries)
      if (entry.value.any(permissionSet.contains)) entry.key,
  };
}
