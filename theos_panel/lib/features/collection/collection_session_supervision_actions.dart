/// A supervisor action on ANOTHER cashier's `collection.session`. Each maps
/// 1:1 to the `CollectionSessionSupervisionPort` method of the same name
/// (`orbi_runtime`), which calls the matching `action_session_*` Odoo
/// method directly — never through the offline queue.
enum CollectionSupervisionAction { pause, resume, validate, close, reopenClosed }

/// Which of the five actions make sense to OFFER right now, given the raw
/// `collection.session.state` and who is looking. This is deliberately
/// narrower than each method's bare top-level guard in
/// `l10n_ec_collection_box/models/collection_session.py` — offering a
/// button that Odoo's OWN internal call chain would reject one level down
/// is still a dead end, even if the outer method's guard alone would have
/// let it through:
///
/// - `pause`/`resume`: dueño o supervisor
///   (`collection_session.py:2382-2384`, `:2416-2418`); estados
///   `opened`/`closing_control` para pausar (`:2369`), `paused` para
///   reanudar (`:2411-2412`).
/// - `validate`: sólo supervisor (`:2620-2621`); estado `closing_control`
///   (`:2616-2617`).
/// - `close`: sólo supervisor (`:3218-3219`). El guardia de tope sólo
///   excluye `closed` (`:3214-3215`), pero internamente encadena a
///   `action_session_validate` (`:3221-3224`), que exige `closing_control`
///   — así que ofrecerlo fuera de `opened`/`closing_control` sólo
///   produciría el rechazo de esa validación interna; se restringe aquí a
///   los dos estados donde de verdad puede completarse.
/// - `reopenClosed`: sólo supervisor (`:2512-2513`); estado `closed`
///   (`:2505-2508`).
Set<CollectionSupervisionAction> availableSupervisionActions({
  required String rawState,
  required bool isOwner,
  required bool isSupervisor,
}) {
  final canPauseOrResume = isOwner || isSupervisor;
  return {
    if (canPauseOrResume &&
        (rawState == 'opened' || rawState == 'closing_control'))
      CollectionSupervisionAction.pause,
    if (canPauseOrResume && rawState == 'paused')
      CollectionSupervisionAction.resume,
    if (isSupervisor && rawState == 'closing_control')
      CollectionSupervisionAction.validate,
    if (isSupervisor && (rawState == 'opened' || rawState == 'closing_control'))
      CollectionSupervisionAction.close,
    if (isSupervisor && rawState == 'closed')
      CollectionSupervisionAction.reopenClosed,
  };
}

/// Display text for the tile/dialog. Kept alongside the gating function
/// because both describe the same fixed set of five actions.
final class CollectionSupervisionActionText {
  const CollectionSupervisionActionText._();

  static String label(CollectionSupervisionAction action) => switch (action) {
    CollectionSupervisionAction.pause => 'Pausar',
    CollectionSupervisionAction.resume => 'Reanudar',
    CollectionSupervisionAction.validate => 'Validar cierre',
    CollectionSupervisionAction.close => 'Cerrar turno',
    CollectionSupervisionAction.reopenClosed => 'Reabrir para corregir',
  };

  static String description(CollectionSupervisionAction action) =>
      switch (action) {
        CollectionSupervisionAction.pause =>
          'Pausar el turno de este cajero temporalmente.',
        CollectionSupervisionAction.resume =>
          'Reanudar el turno pausado de este cajero.',
        CollectionSupervisionAction.validate =>
          'Validar el arqueo y cerrar el turno.',
        CollectionSupervisionAction.close =>
          'Cerrar directamente el turno de este cajero.',
        CollectionSupervisionAction.reopenClosed =>
          'Reabrir el turno cerrado para corregir su fecha de cierre.',
      };

  /// Confirmation-dialog body: the three touching-money-or-state actions get
  /// an explicit warning; pause/resume a plain confirmation.
  static bool requiresStrongConfirmation(CollectionSupervisionAction action) =>
      switch (action) {
        CollectionSupervisionAction.validate ||
        CollectionSupervisionAction.close ||
        CollectionSupervisionAction.reopenClosed => true,
        CollectionSupervisionAction.pause ||
        CollectionSupervisionAction.resume => false,
      };
}
