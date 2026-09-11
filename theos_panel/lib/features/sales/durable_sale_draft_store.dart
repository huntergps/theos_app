import 'package:orbi_runtime/orbi_runtime.dart';

import 'sale_draft_codec.dart';
import 'sale_editor.dart';

/// Bridges the current editor to a durable, explicitly identified draft.
/// This ID is presentation-document identity, never a command/idempotency ID.
/// A future tab owner supplies one ID per tab; the store supports them already.
final class DurableSaleDraftStore implements SaleDraftStore {
  DurableSaleDraftStore({
    required this.store,
    required this.scopeKey,
    required this.draftId,
  });

  final EditableDraftStore store;
  final String scopeKey;
  final String draftId;
  int _revision = 0;
  bool _loaded = false;
  String? _commandIdentity;
  bool _saving = false;

  void _checkScope(String scope) {
    if (scope != scopeKey) throw StateError('Draft belongs to another scope');
  }

  @override
  Future<SaleDraftSnapshot?> load(String scopeKey) async {
    _checkScope(scopeKey);
    if (_saving) throw StateError('Cannot reload while saving a draft');
    final record = await store.read(draftId);
    final draft = record == null ? null : SaleDraftCodec.decode(record.payload);
    if (draft != null) _checkScope(draft.scopeKey);
    _revision = record?.revision ?? 0;
    _commandIdentity = draft?.commandId;
    _loaded = true;
    return draft;
  }

  @override
  Future<void> save(SaleDraftSnapshot draft) async {
    _checkScope(draft.scopeKey);
    if (!_loaded) throw StateError('Wait for draft recovery before editing');
    if (_saving) throw StateError('Concurrent editor write');
    // An edit started before recovery must not silently replace another draft.
    if (_commandIdentity != null && _commandIdentity != draft.commandId) {
      throw StateError('Recover the existing draft before replacing it');
    }
    _saving = true;
    try {
      final saved = await store.save(
        draftId,
        SaleDraftCodec.encode(draft),
        expectedRevision: _revision,
      );
      _revision = saved.revision;
      _commandIdentity = draft.commandId;
    } finally {
      _saving = false;
    }
  }
}

/// No fallback to volatile memory or unpartitioned preferences in production.
final class UnavailableSaleDraftStore implements SaleDraftStore {
  const UnavailableSaleDraftStore();
  @override
  Future<SaleDraftSnapshot?> load(String scopeKey) async => null;
  @override
  Future<void> save(SaleDraftSnapshot draft) async =>
      throw StateError('No active local database and company for this draft');
}
