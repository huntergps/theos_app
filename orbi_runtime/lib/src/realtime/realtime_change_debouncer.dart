/// Traduce avisos `app_sync/changed` del bus en peticiones de sincronización
/// incremental, UNA por ráfaga, nunca una por aviso.
///
/// El aviso es una PISTA, la verdad la sigue teniendo la sincronización
/// incremental por cursor que ya existe (`CatalogSyncJob`, con cursor y
/// bajas): esta clase sólo decide QUÉ trabajos correr y CUÁNDO, nunca toca
/// Drift ni interpreta el payload más allá de `model`/`company_id`.
// Private fields select the injected callbacks without exposing
// implementation details as public constructor parameters.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

import 'package:odoo_sdk/odoo_sdk.dart' show OdooRawNotificationEvent;

const _appSyncChangedType = 'app_sync/changed';

/// [modelJobIds] es la única fuente de verdad de «qué modelo sincroniza la
/// app»: un modelo ausente de este mapa se ignora por completo (no dispara
/// nada), tal como decide el diseño. Lo construye quien compone el runtime
/// (conoce los ids reales de los `SyncJob` que existen); esta clase no los
/// inventa.
///
/// [activeCompanyId] puede devolver `null` cuando todavía no se conoce la
/// empresa activa (arranque, restauración offline) — en ese caso NO se
/// filtra por empresa: un aviso de más aquí sólo cuesta una sincronización
/// extra e inofensiva, mientras que descartarlo de más perdería un cambio
/// real. Un `company_id` presente en el aviso que no coincide con la
/// empresa activa CONOCIDA sí se ignora.
final class RealtimeChangeDebouncer {
  RealtimeChangeDebouncer({
    required Stream<OdooRawNotificationEvent> notifications,
    required Map<String, Set<String>> modelJobIds,
    required int? Function() activeCompanyId,
    required void Function(Set<String> jobIds) onDebounced,
    this.debounce = const Duration(milliseconds: 400),
  }) : _modelJobIds = modelJobIds,
       _activeCompanyId = activeCompanyId,
       _onDebounced = onDebounced {
    _subscription = notifications.listen(_onNotification);
  }

  final Map<String, Set<String>> _modelJobIds;
  final int? Function() _activeCompanyId;
  final void Function(Set<String> jobIds) _onDebounced;
  final Duration debounce;

  late final StreamSubscription<OdooRawNotificationEvent> _subscription;
  final Set<String> _pendingJobIds = {};
  Timer? _timer;

  void _onNotification(OdooRawNotificationEvent event) {
    if (event.type != _appSyncChangedType) return;
    final payload = event.payload;
    final model = payload['model'];
    if (model is! String) return;
    final jobIds = _modelJobIds[model];
    if (jobIds == null || jobIds.isEmpty) return; // modelo no sincronizado

    final companyId = (payload['company_id'] as num?)?.toInt();
    if (companyId != null) {
      final active = _activeCompanyId();
      if (active != null && companyId != active) return; // otra empresa
    }

    _pendingJobIds.addAll(jobIds);
    _timer?.cancel();
    _timer = Timer(debounce, _flush);
  }

  void _flush() {
    _timer = null;
    if (_pendingJobIds.isEmpty) return;
    final jobIds = Set<String>.unmodifiable(_pendingJobIds);
    _pendingJobIds.clear();
    _onDebounced(jobIds);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _subscription.cancel();
  }
}
