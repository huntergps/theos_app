import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/collection_repository.dart';
import '../../../core/database/repositories/repository_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../shared/utils/formatting_utils.dart';
import 'collection_session_state.dart';

part 'collection_session_notifier.g.dart';

/// Tag para logs de este notifier
const String _tag = '[CollectionSessionNotifier]';

/// Notifier para manejar el estado de la sesion de cobranza
///
/// Encapsula toda la logica de negocio relacionada con:
/// - Sincronizacion de sesiones locales con Odoo
/// - Registro de fondo de apertura
/// - Registro de efectivo de cierre
/// - Cierre de sesiones
/// - Actualizacion/refresco de datos
@Riverpod(keepAlive: true)
class CollectionSessionNotifier extends _$CollectionSessionNotifier {
  CollectionRepository? _repository;

  @override
  CollectionSessionScreenState build() {
    _repository = ref.watch(collectionRepositoryProvider);
    return const CollectionSessionScreenState();
  }

  /// Inicializa el notifier con un session ID específico
  void initialize(int sessionId) {
    if (_repository != null) {
      loadSession(sessionId);
    }
  }

  /// Carga una sesion por su ID
  ///
  /// Actualiza el estado con loading=true mientras carga,
  /// y luego actualiza con la sesion o el error.
  Future<void> loadSession(int sessionId) async {
    if (_repository == null) return;

    logger.d(_tag, 'Loading session with ID: $sessionId');

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      errorCode: null,
    );

    try {
      final session = await _repository!.getCollectionSession(sessionId);

      if (session != null) {
        logger.i(_tag, 'Session loaded: ${session.name}');
        state = state.copyWith(isLoading: false, session: session);
      } else {
        logger.w(_tag, 'Session not found: $sessionId');
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sesion no encontrada',
          errorCode: 'NOT_FOUND',
        );
      }
    } catch (e) {
      logger.e(_tag, 'Error loading session', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al cargar la sesion: $e',
        errorCode: 'LOAD_ERROR',
      );
    }
  }

  /// Actualiza la sesion en el estado
  ///
  /// Util cuando se recibe una sesion actualizada desde otro provider
  void updateSession(CollectionSession? session) {
    if (session != null) {
      logger.d(_tag, 'Updating session in state: ${session.name}');
    }
    state = state.copyWith(session: session);
  }

  /// Sincroniza una sesion local con Odoo
  ///
  /// Retorna el resultado de la operacion.
  Future<OperationResult<CollectionSession>> syncSession(
    CollectionSession session,
    CollectionConfig config,
  ) async {
    if (_repository == null) {
      return const OperationFailure(
        message: 'Repositorio no inicializado',
        code: 'NO_REPO',
      );
    }

    logger.d(_tag, 'Manual sync triggered for session: ${session.name}');

    state = state.copyWith(
      isSyncing: true,
      errorMessage: null,
      errorCode: null,
      operationSuccess: false,
      successMessage: null,
      newSessionId: null,
    );

    try {
      final result = await _repository!.syncLocalSession(
        localSession: session,
        config: config,
      );

      return result.fold(
        (failure) {
          logger.e(_tag, 'Sync failed: ${failure.message}');
          state = state.copyWith(
            isSyncing: false,
            errorMessage: failure.message,
            errorCode: failure.code,
          );
          return OperationFailure(message: failure.message, code: failure.code);
        },
        (syncedSession) {
          logger.i(
            _tag,
            'Session synced successfully: ${syncedSession.name} (ID: ${syncedSession.id})',
          );

          // Verificar si el ID cambio (sesion local a sesion de Odoo)
          final needsRedirect = syncedSession.id != session.id;

          state = state.copyWith(
            isSyncing: false,
            session: syncedSession,
            operationSuccess: true,
            successMessage:
                'Sesion ${syncedSession.name} sincronizada correctamente',
            newSessionId: needsRedirect ? syncedSession.id : null,
          );

          return OperationSuccess(
            data: syncedSession,
            message: 'Sesion sincronizada correctamente',
          );
        },
      );
    } catch (e) {
      logger.e(_tag, 'Unexpected error during sync', e);
      state = state.copyWith(
        isSyncing: false,
        errorMessage: 'Error inesperado al sincronizar: $e',
        errorCode: 'SYNC_ERROR',
      );
      return OperationFailure(
        message: 'Error inesperado al sincronizar: $e',
        code: 'SYNC_ERROR',
      );
    }
  }

  /// Registra el fondo de apertura de la sesion
  ///
  /// Retorna el resultado de la operacion.
  Future<OperationResult<CollectionSession>> registerOpeningCash(
    CollectionSessionCash cash,
  ) async {
    if (_repository == null) {
      return const OperationFailure(
        message: 'Repositorio no inicializado',
        code: 'NO_REPO',
      );
    }

    final session = state.session;
    if (session == null) {
      logger.w(_tag, 'Cannot register opening cash: no session loaded');
      return const OperationFailure(
        message: 'No hay sesion cargada',
        code: 'NO_SESSION',
      );
    }

    logger.d(_tag, 'Registering opening cash for session: ${session.name}');

    state = state.copyWith(
      isRegisteringOpeningCash: true,
      errorMessage: null,
      errorCode: null,
      operationSuccess: false,
      successMessage: null,
    );

    try {
      final result = await _repository!.registerOpeningCash(
        sessionId: session.id,
        cash: cash,
      );

      return result.fold(
        (failure) {
          logger.e(_tag, 'Failed to register opening cash: ${failure.message}');
          state = state.copyWith(
            isRegisteringOpeningCash: false,
            errorMessage: failure.message,
            errorCode: failure.code,
          );
          return OperationFailure(message: failure.message, code: failure.code);
        },
        (updatedSession) {
          final isSessionOpened =
              updatedSession.state == SessionState.opened &&
              session.state == SessionState.openingControl;

          final message = isSessionOpened
              ? 'Sesion abierta con fondo inicial: ${cash.cashTotal.toCurrency()}'
              : 'Fondo registrado: ${cash.cashTotal.toCurrency()}';

          logger.i(_tag, message);

          state = state.copyWith(
            isRegisteringOpeningCash: false,
            session: updatedSession,
            operationSuccess: true,
            successMessage: message,
          );

          return OperationSuccess(data: updatedSession, message: message);
        },
      );
    } catch (e) {
      logger.e(_tag, 'Unexpected error registering opening cash', e);
      state = state.copyWith(
        isRegisteringOpeningCash: false,
        errorMessage: 'Error al registrar fondo: $e',
        errorCode: 'OPENING_CASH_ERROR',
      );
      return OperationFailure(
        message: 'Error al registrar fondo: $e',
        code: 'OPENING_CASH_ERROR',
      );
    }
  }

  /// Registra el efectivo de cierre de la sesion
  ///
  /// Retorna el resultado de la operacion.
  Future<OperationResult<CollectionSession>> registerClosingCash(
    CollectionSessionCash cash,
  ) async {
    if (_repository == null) {
      return const OperationFailure(
        message: 'Repositorio no inicializado',
        code: 'NO_REPO',
      );
    }

    final session = state.session;
    if (session == null) {
      logger.w(_tag, 'Cannot register closing cash: no session loaded');
      return const OperationFailure(
        message: 'No hay sesion cargada',
        code: 'NO_SESSION',
      );
    }

    logger.d(_tag, 'Registering closing cash for session: ${session.name}');

    state = state.copyWith(
      isRegisteringClosingCash: true,
      errorMessage: null,
      errorCode: null,
      operationSuccess: false,
      successMessage: null,
    );

    try {
      final result = await _repository!.registerClosingCash(
        sessionId: session.id,
        cash: cash,
      );

      return result.fold(
        (failure) {
          logger.e(_tag, 'Failed to register closing cash: ${failure.message}');
          state = state.copyWith(
            isRegisteringClosingCash: false,
            errorMessage: failure.message,
            errorCode: failure.code,
          );
          return OperationFailure(message: failure.message, code: failure.code);
        },
        (updatedSession) {
          final isClosingControlStarted =
              updatedSession.state == SessionState.closingControl &&
              session.state == SessionState.opened;

          final message = isClosingControlStarted
              ? 'Control de cierre iniciado: ${cash.cashTotal.toCurrency()}'
              : 'Efectivo actualizado: ${cash.cashTotal.toCurrency()}';

          logger.i(_tag, message);

          state = state.copyWith(
            isRegisteringClosingCash: false,
            session: updatedSession,
            operationSuccess: true,
            successMessage: message,
          );

          return OperationSuccess(data: updatedSession, message: message);
        },
      );
    } catch (e) {
      logger.e(_tag, 'Unexpected error registering closing cash', e);
      state = state.copyWith(
        isRegisteringClosingCash: false,
        errorMessage: 'Error al registrar efectivo: $e',
        errorCode: 'CLOSING_CASH_ERROR',
      );
      return OperationFailure(
        message: 'Error al registrar efectivo: $e',
        code: 'CLOSING_CASH_ERROR',
      );
    }
  }

  /// Cierra la sesion de cobranza
  ///
  /// Retorna el resultado de la operacion.
  Future<OperationResult<CollectionSession>> closeSession() async {
    if (_repository == null) {
      return const OperationFailure(
        message: 'Repositorio no inicializado',
        code: 'NO_REPO',
      );
    }

    final session = state.session;
    if (session == null) {
      logger.w(_tag, 'Cannot close session: no session loaded');
      return const OperationFailure(
        message: 'No hay sesion cargada',
        code: 'NO_SESSION',
      );
    }

    logger.d(_tag, 'Closing session: ${session.name}');

    state = state.copyWith(
      isClosingSession: true,
      errorMessage: null,
      errorCode: null,
      operationSuccess: false,
      successMessage: null,
    );

    try {
      final updatedSession = await _repository!.closeCollectionSession(
        session.id,
      );

      if (updatedSession != null) {
        logger.i(_tag, 'Session closed successfully: ${updatedSession.name}');

        state = state.copyWith(
          isClosingSession: false,
          session: updatedSession,
          operationSuccess: true,
          successMessage: 'Sesion cerrada exitosamente',
        );

        return OperationSuccess(
          data: updatedSession,
          message: 'Sesion cerrada exitosamente',
        );
      } else {
        logger.e(_tag, 'Failed to close session: no response from repository');
        state = state.copyWith(
          isClosingSession: false,
          errorMessage: 'No se pudo obtener la sesion actualizada',
          errorCode: 'CLOSE_ERROR',
        );
        return const OperationFailure(
          message: 'No se pudo obtener la sesion actualizada',
          code: 'CLOSE_ERROR',
        );
      }
    } catch (e) {
      logger.e(_tag, 'Error closing session', e);
      state = state.copyWith(
        isClosingSession: false,
        errorMessage: 'Error al cerrar la sesion: $e',
        errorCode: 'CLOSE_ERROR',
      );
      return OperationFailure(
        message: 'Error al cerrar la sesion: $e',
        code: 'CLOSE_ERROR',
      );
    }
  }

  /// Refresca los datos de la sesion desde el repositorio
  ///
  /// Util para actualizar la UI despues de cambios externos.
  Future<void> refreshSession() async {
    if (_repository == null) return;

    final session = state.session;
    if (session == null) {
      logger.w(_tag, 'Cannot refresh: no session loaded');
      return;
    }

    logger.d(_tag, 'Refreshing session: ${session.name}');

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      errorCode: null,
    );

    try {
      final refreshedSession = await _repository!.getCollectionSession(
        session.id,
        forceRefresh: true,
      );

      if (refreshedSession != null) {
        logger.i(_tag, 'Session refreshed: ${refreshedSession.name}');
        state = state.copyWith(isLoading: false, session: refreshedSession);
      } else {
        logger.w(_tag, 'Session no longer exists: ${session.id}');
        state = state.copyWith(
          isLoading: false,
          session: null,
          errorMessage: 'La sesion ya no existe',
          errorCode: 'NOT_FOUND',
        );
      }
    } catch (e) {
      logger.e(_tag, 'Error refreshing session', e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error al actualizar: $e',
        errorCode: 'REFRESH_ERROR',
      );
    }
  }

  /// Obtiene los detalles del conteo de efectivo existente
  ///
  /// [cashType] indica si es apertura o cierre
  Future<CollectionSessionCash?> getExistingCashDetails(
    CashType cashType,
  ) async {
    if (_repository == null) return null;

    final session = state.session;
    if (session == null) return null;

    try {
      return await _repository!.getSessionCashDetails(
        sessionId: session.id,
        cashType: cashType,
      );
    } catch (e) {
      logger.w(_tag, 'Error getting existing cash details: $e');
      return null;
    }
  }

  /// Limpia el mensaje de exito
  void clearSuccessMessage() {
    state = state.copyWith(operationSuccess: false, successMessage: null);
  }

  /// Limpia el mensaje de error
  void clearError() {
    state = state.copyWith(errorMessage: null, errorCode: null);
  }

  /// Limpia la redireccion pendiente
  void clearRedirect() {
    state = state.copyWith(newSessionId: null);
  }
}
