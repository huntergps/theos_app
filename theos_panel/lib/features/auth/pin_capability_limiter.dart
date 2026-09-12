import 'package:orbi_runtime/orbi_runtime.dart' show CapabilitySnapshot;

/// The only permission PIN mode is ever allowed to grant, no matter what the
/// underlying multirole user actually has.
///
/// This is the non-negotiable rule from
/// `docs/orbi_panel/COORDINATOR_HANDOFF_2026_09_11.md`: "Usuarios multirrol
/// ven capacidades conjuntas; modo PIN limita a vendedor aunque tenga otros
/// roles. Cajeros/supervisores/admin/bodega acceden con credenciales." It is
/// echoed by `NAVIGATION_CAPABILITY_MATRIX.md`: "PIN no concede Caja,
/// Bodega, Envases, Aprobaciones, Sistema administrativo ni privilegios de
/// supervisor."
const Set<String> kSellerPinPermissions = {'seller'};

/// True when [snapshot] carries the seller permission PIN mode requires to
/// unlock at all.
///
/// PIN is the declared door for the seller role (ACC-02 /
/// `NAVIGATION_CAPABILITY_MATRIX.md` area 1: "PIN sólo puede llegar a
/// capacidades de Ventas"). A user whose full, credentialed snapshot does not
/// even include `seller` has nothing to scope down to — PIN is not a
/// generic weak-password door into whatever else they happen to hold, so
/// that case must be refused outright rather than "restored" with an empty
/// permission set that would look like a network/support problem instead of
/// a permission problem.
bool snapshotAllowsSellerPin(CapabilitySnapshot snapshot) =>
    snapshot.permissions.contains('seller');

/// Clamps a full, multirole [snapshot] down to the ceiling PIN mode may ever
/// grant, regardless of what other roles the same person holds.
///
/// This is a ceiling, not a projection of intent: a user who is both a
/// cashier and a seller keeps `cashier` on their normal Workspace
/// credentialed session, but loses it entirely the moment they come in
/// through PIN. Concretely: `permissions` is intersected with
/// [kSellerPinPermissions] — everything else (`cashier`, `approver`,
/// `warehouse`, `administrator`, `sync`, `view_all`, `orders.view_all`, and
/// any future permission this layer does not explicitly know is seller-safe)
/// is dropped.
///
/// `offlineOperations` and `counterPolicies` are cleared entirely rather than
/// filtered by name. This layer has no reliable catalogue of which offline
/// operation/counter-policy identifiers are seller-safe — inventing one here
/// would risk quietly granting a cash or approval operation through the
/// offline queue. Clearing is the fail-closed choice mandated by the same
/// rule ("el PIN es más débil... da menos poder"), not an oversight; widening
/// it later requires an explicit, reviewed allowlist, not a guess.
CapabilitySnapshot restrictSnapshotToSellerPin(CapabilitySnapshot snapshot) {
  return CapabilitySnapshot(
    scopeKey: snapshot.scopeKey,
    companyId: snapshot.companyId,
    pointId: snapshot.pointId,
    revision: snapshot.revision,
    fetchedAt: snapshot.fetchedAt,
    permissions: snapshot.permissions.where(kSellerPinPermissions.contains),
    counterPolicies: const [],
    offlineOperations: const [],
  );
}
