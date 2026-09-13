import 'package:odoo_sdk/odoo_sdk.dart' show OdooException;

import 'sale_runtime_adapters.dart' show SaleOdooActions;

/// Outcome of a single supervisor action against ANOTHER cashier's
/// `collection.session`. Never `queued`: see [CollectionSessionSupervisionPort].
enum CollectionSupervisionOutcome { applied, rejected }

final class CollectionSupervisionResult {
  const CollectionSupervisionResult.applied()
    : outcome = CollectionSupervisionOutcome.applied,
      serverMessage = null;
  const CollectionSupervisionResult.rejected(this.serverMessage)
    : outcome = CollectionSupervisionOutcome.rejected;

  final CollectionSupervisionOutcome outcome;

  /// Odoo's own `UserError` text, shown to the supervisor verbatim — never
  /// a client-invented paraphrase (the exact wording tells them what to fix:
  /// "no hay depósito registrado", "hay una orden con dinero cobrado sin
  /// facturar", "el asiento está conciliado"...). Null only for a bare
  /// `False` return with no message attached.
  final String? serverMessage;

  bool get isSuccess => outcome == CollectionSupervisionOutcome.applied;
}

/// Cross-user, ONLINE-ONLY actions a supervisor takes on ANOTHER cashier's
/// `collection.session` — never queued through the offline outbox.
///
/// These are in-person authorizations over someone else's till: the same
/// trust model as clicking the button in Odoo's own web client. Queuing them
/// would let a supervisor "approve" a foreign close while offline and have
/// it materialize unattended, later, with nobody present to see it applied —
/// exactly the guarantee the real workflow depends on breaking. If
/// connectivity resilience is ever wanted here, `validate`/`close`/
/// `reopenClosed` should use `OfflineReplayPolicy.manualAfterAmbiguous`
/// (they touch the cash-difference accounting entry; an ambiguous retry must
/// never auto-repeat) — not `retrySafe`.
final class CollectionSessionSupervisionPort {
  const CollectionSessionSupervisionPort(this.actions);
  final SaleOdooActions actions;

  /// `l10n_ec_collection_box/models/collection_session.py:2371-2406`.
  /// Dueño o supervisor; estados `opened`/`closing_control`.
  Future<CollectionSupervisionResult> pause(int sessionId) =>
      _call('action_session_pause', sessionId);

  /// `collection_session.py:2408-2476`. Dueño o supervisor; estado `paused`.
  Future<CollectionSupervisionResult> resume(int sessionId) =>
      _call('action_session_resume', sessionId);

  /// `collection_session.py:2613-2658`. Sólo supervisor; estado
  /// `closing_control`.
  Future<CollectionSupervisionResult> validate(int sessionId) =>
      _call('action_session_validate', sessionId);

  /// `collection_session.py:3211-3226`. Sólo supervisor; cualquier estado
  /// menos `closed` (encadena `closing_control`→`validate` internamente).
  Future<CollectionSupervisionResult> close(int sessionId) =>
      _call('action_session_close', sessionId);

  /// `collection_session.py:2478-2536`. Sólo supervisor; estado `closed`.
  Future<CollectionSupervisionResult> reopenClosed(int sessionId) =>
      _call('action_session_reabrir_cerrada', sessionId);

  Future<CollectionSupervisionResult> _call(String method, int sessionId) async {
    try {
      final result = await actions.call(
        model: 'collection.session',
        method: method,
        ids: [sessionId],
      );
      if (result == false) {
        return const CollectionSupervisionResult.rejected(null);
      }
      return const CollectionSupervisionResult.applied();
    } on OdooException catch (error) {
      return CollectionSupervisionResult.rejected(error.message);
    }
  }
}
