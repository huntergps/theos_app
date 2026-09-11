import 'package:flutter/foundation.dart';

/// The state of a field command.  Persistence is deliberately supplied by the
/// caller; this type does not know about a database, transport, or Odoo.
enum FieldBindingStatus { pristine, dirty, saving, saved, error, conflict }

typedef FieldSaveCallback<T> = Future<void> Function(T value);

/// A small, typed editing bridge for one field of a draft.
///
/// `setExternalValue` represents an observable update from the owner of the
/// draft.  It never replaces an active local edit: such an update becomes a
/// conflict and the local value remains available for an explicit resolution.
class FieldBinding<T> extends ChangeNotifier {
  FieldBinding({required T initialValue, required this.onSave})
    : _persistedValue = initialValue,
      _value = initialValue;

  T _persistedValue;
  T _value;
  final FieldSaveCallback<T> onSave;
  FieldBindingStatus _status = FieldBindingStatus.pristine;
  Object? _error;
  T? _remoteValue;
  int _operation = 0;
  bool _inFlight = false;
  bool _revertWhileSaving = false;
  bool _disposed = false;

  T get value => _value;
  T get persistedValue => _persistedValue;
  FieldBindingStatus get status => _status;
  Object? get error => _error;
  T? get remoteValue => _remoteValue;
  bool get isDirty => _status == FieldBindingStatus.dirty;
  bool get isSaving => _inFlight;

  /// Changes only the local draft; it does not invoke [onSave].
  void edit(T value) {
    if (_disposed) return;
    _value = value;
    _error = null;
    if (_status != FieldBindingStatus.conflict) {
      _remoteValue = null;
      _status = _value == _persistedValue
          ? FieldBindingStatus.pristine
          : FieldBindingStatus.dirty;
    }
    notifyListeners();
  }

  /// Applies an update observed from the draft owner.
  void setExternalValue(T value) {
    if (_disposed) return;
    if (value == _persistedValue &&
        (_status == FieldBindingStatus.dirty ||
            _status == FieldBindingStatus.saving ||
            _status == FieldBindingStatus.error)) {
      // This is an old observable snapshot; it cannot conflict with local
      // work and must not reset the draft.
      return;
    }
    if (_status == FieldBindingStatus.dirty ||
        _status == FieldBindingStatus.saving ||
        _status == FieldBindingStatus.conflict ||
        _status == FieldBindingStatus.error) {
      if (value == _value) return;
      _remoteValue = value;
      _status = FieldBindingStatus.conflict;
      notifyListeners();
      return;
    }
    _persistedValue = value;
    _value = value;
    _remoteValue = null;
    _error = null;
    _status = FieldBindingStatus.pristine;
    notifyListeners();
  }

  /// Resolves a conflict in favour of the observed external value.
  void acceptExternal() {
    if (_disposed || _remoteValue == null) return;
    _persistedValue = _remoteValue as T;
    _value = _persistedValue;
    _remoteValue = null;
    _error = null;
    _status = FieldBindingStatus.pristine;
    notifyListeners();
  }

  Future<bool> save() async {
    if (_disposed || _inFlight || _status == FieldBindingStatus.conflict) {
      return false;
    }
    if (_value == _persistedValue) {
      _status = FieldBindingStatus.pristine;
      notifyListeners();
      return true;
    }
    final operation = ++_operation;
    final valueAtStart = _value;
    _inFlight = true;
    _revertWhileSaving = false;
    _status = FieldBindingStatus.saving;
    _error = null;
    notifyListeners();
    try {
      await onSave(valueAtStart);
      if (_disposed || operation != _operation) return false;
      _inFlight = false;
      _persistedValue = valueAtStart;
      if (_revertWhileSaving) {
        _revertWhileSaving = false;
        _remoteValue = valueAtStart;
        _status = FieldBindingStatus.conflict;
        notifyListeners();
        return false;
      }
      // A remote update during save must remain a conflict, and the local
      // draft must not be silently replaced by the response.
      if (_status == FieldBindingStatus.conflict || _value != valueAtStart) {
        notifyListeners();
        return false;
      }
      _status = FieldBindingStatus.saved;
      notifyListeners();
      return true;
    } catch (error) {
      if (_disposed || operation != _operation) return false;
      _inFlight = false;
      _error = error;
      // A concurrent external update remains a conflict; the failed write is
      // not allowed to turn it into an apparently resolvable plain error.
      if (_status != FieldBindingStatus.conflict) {
        _status = FieldBindingStatus.error;
      }
      notifyListeners();
      return false;
    }
  }

  void revert() {
    if (_disposed) return;
    if (_inFlight) _revertWhileSaving = true;
    _value = _persistedValue;
    _remoteValue = null;
    _error = null;
    _status = FieldBindingStatus.pristine;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_operation;
    super.dispose();
  }
}
