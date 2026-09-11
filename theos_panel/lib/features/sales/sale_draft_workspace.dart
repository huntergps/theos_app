import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import 'durable_sale_draft_store.dart';
import 'sale_editor.dart';

typedef SaleDraftControllerFactory = SaleDraftController Function(
  SaleDraftStore store,
);

/// Owns the open editor controllers for a scope. Durable draft IDs are tab
/// identity; command IDs remain inside each [SaleDraftSnapshot].
final class SaleDraftWorkspace extends ChangeNotifier {
  SaleDraftWorkspace({
    required this.store,
    required this.scopeKey,
    required this.controllerFactory,
    this.pageSize = 200,
  }) {
    if (pageSize < 1 || pageSize > 200) {
      throw ArgumentError.value(pageSize, 'pageSize');
    }
  }

  final EditableDraftStore store;
  final String scopeKey;
  final SaleDraftControllerFactory controllerFactory;
  final int pageSize;

  final Map<String, SaleDraftController> _controllers = {};
  final List<String> _draftIds = [];
  String? _selectedDraftId;
  Object? _error;
  bool _busy = false;
  bool _initialized = false;
  bool _disposed = false;
  Future<void>? _initialization;
  Future<void> _operationTail = Future<void>.value();

  List<String> get draftIds => List.unmodifiable(_draftIds);
  String? get selectedDraftId => _selectedDraftId;
  SaleDraftController? get selectedController =>
      _selectedDraftId == null ? null : _controllers[_selectedDraftId];
  Map<String, SaleDraftController> get controllers =>
      Map.unmodifiable(_controllers);
  Object? get error => _error;
  bool get busy => _busy;
  bool get initialized => _initialized;

  /// Discovers durable documents for reopening without exposing their payloads
  /// or creating a second editable list in the presentation widgets.
  Future<List<String>> availableDraftIds() async {
    _ensureAlive();
    final ids = <String>[];
    String? after;
    do {
      final page = await store.list(limit: pageSize, afterDraftId: after);
      _ensureAlive();
      ids.addAll(page.map((record) => record.key.draftId));
      after = page.length == pageSize ? page.last.key.draftId : null;
    } while (after != null);
    return List.unmodifiable(ids);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _ensureAlive();
    final existing = _initialization;
    if (existing != null) return existing;
    final operation = _enqueue(() async {
      if (_initialized || _disposed) return;
      _setBusy(true);
      try {
        final ids = <String>[];
        String? after;
        do {
          final page = await store.list(limit: pageSize, afterDraftId: after);
          _ensureAlive();
          ids.addAll(page.map((record) => record.key.draftId));
          after = page.length == pageSize ? page.last.key.draftId : null;
        } while (after != null && !_disposed);
        _draftIds
          ..clear()
          ..addAll(ids);
        if (_disposed) return;
        if (ids.isEmpty) {
          await _createAndSelect();
          if (_disposed) return;
        } else {
          final legacy = ids.indexOf('workspace-active-editor');
          _selectedDraftId = legacy >= 0 ? ids[legacy] : ids.first;
          await _openController(_selectedDraftId!);
        }
        _ensureAlive();
        _error = null;
        _initialized = true;
        notifyListeners();
      } finally {
        _setBusy(false);
      }
    });
    _initialization = operation;
    try {
      await operation;
    } catch (_) {
      // Scope disposal cancels recovery; it is not a user-facing load error.
      if (!_disposed) rethrow;
    } finally {
      _initialization = null;
    }
  }

  Future<void> select(String draftId) async {
    return _enqueue(() async {
      _requireKnown(draftId);
      if (draftId == _selectedDraftId) return;
      await _prepareSwitch();
      if (!_controllers.containsKey(draftId)) await _openController(draftId);
      _ensureAlive();
      _selectedDraftId = draftId;
      notifyListeners();
    });
  }

  Future<String> create() async {
    return _enqueue(() async {
      await _prepareSwitch();
      _setBusy(true);
      try {
        final id = _newDraftId();
        await _openController(id);
        _ensureAlive();
        // update() queues the initial snapshot through the injected durable
        // store; this never creates an outbox operation.
        _controllers[id]!.update();
        await _controllers[id]!.flush();
        _ensureAlive();
        _draftIds.add(id);
        _draftIds.sort();
        _selectedDraftId = id;
        _error = null;
        notifyListeners();
        return id;
      } finally {
        _setBusy(false);
      }
    });
  }

  /// Reopens a previously closed durable document; never creates a missing ID.
  Future<void> reopen(String draftId) => _enqueue(() async {
    await _prepareSwitch();
    final record = await store.read(draftId);
    _ensureAlive();
    if (record == null) throw StateError('El borrador ya no está disponible');
    if (!_controllers.containsKey(draftId)) await _openController(draftId);
    _ensureAlive();
    if (!_draftIds.contains(draftId)) _draftIds.add(draftId);
    _selectedDraftId = draftId;
    notifyListeners();
  });

  /// Flushes and disposes a tab but intentionally leaves its durable row.
  Future<void> close(String draftId) async {
    return _enqueue(() async {
      _requireKnown(draftId);
      final controller = _controllers[draftId];
      if (controller?.busy == true) {
        throw StateError('La venta está procesando una operación');
      }
      await controller?.flush();
      _ensureAlive();
      final next = _draftIds.where((id) => id != draftId).firstOrNull;
      if (_selectedDraftId == draftId &&
          next != null &&
          !_controllers.containsKey(next)) {
        await _openController(next);
      }
      _ensureAlive();
      await controller?.dispose();
      _ensureAlive();
      _controllers.remove(draftId);
      _draftIds.remove(draftId);
      if (_selectedDraftId == draftId) {
        _selectedDraftId = _draftIds.isEmpty ? null : _draftIds.first;
      }
      notifyListeners();
    });
  }

  Future<void> disposeAsync() async {
    if (_disposed) return;
    _disposed = true;
    await _operationTail;
    for (final controller in List<SaleDraftController>.from(
      _controllers.values,
    )) {
      await controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _prepareSwitch() async {
    final current = selectedController;
    if (current == null) {
      return;
    }
    if (current.busy) {
      throw StateError('La venta está procesando una operación');
    }
    await current.flush();
    _ensureAlive();
  }

  Future<void> _openController(String id) async {
    _ensureAlive();
    final durable = DurableSaleDraftStore(
      store: store,
      scopeKey: scopeKey,
      draftId: id,
    );
    final controller = controllerFactory(durable);
    _controllers[id] = controller;
    await controller.restore();
    _ensureAlive();
    final failure = controller.saveError;
    if (failure != null) {
      await controller.dispose();
      _controllers.remove(id);
      throw StateError('No se pudo recuperar el borrador "$id": $failure');
    }
  }

  Future<void> _createAndSelect() async {
    if (_disposed) return;
    final id = _newDraftId();
    await _openController(id);
    if (_disposed || !_controllers.containsKey(id)) return;
    _controllers[id]!.update();
    await _controllers[id]!.flush();
    _ensureAlive();
    _draftIds.add(id);
    _selectedDraftId = id;
  }

  void _requireKnown(String id) {
    if (!_draftIds.contains(id)) {
      throw ArgumentError.value(id, 'draftId', 'is not an open draft');
    }
  }

  String _newDraftId() {
    final bytes = List<int>.generate(18, (_) => Random.secure().nextInt(256));
    return 'draft-${base64UrlEncode(bytes).replaceAll('=', '')}';
  }

  void _setBusy(bool value) {
    if (_disposed) return;
    if (_busy == value) return;
    _busy = value;
    notifyListeners();
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final run = _operationTail.then((_) async {
      _ensureAlive();
      _setBusy(true);
      try {
        final result = await action();
        _ensureAlive();
        _error = null;
        return result;
      } catch (error) {
        _error = error;
        if (!_disposed) notifyListeners();
        rethrow;
      } finally {
        _setBusy(false);
      }
    });
    _operationTail = run.then<void>((_) {}, onError: (error, stack) {});
    return run;
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('Workspace is disposed');
  }
}
