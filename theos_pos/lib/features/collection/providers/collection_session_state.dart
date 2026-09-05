import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/providers/base_feature_state.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

part 'collection_session_state.freezed.dart';

/// Estado inmutable para la pantalla de sesion de cobranza
///
/// Maneja el estado de carga, sincronizacion, errores y la sesion actual.
/// Utiliza Freezed para generar copyWith, equals, hashCode y toString.
/// Implements [BaseFeatureState] for standardized loading/error handling.
@freezed
abstract class CollectionSessionScreenState
    with _$CollectionSessionScreenState
    implements BaseFeatureState {
  const factory CollectionSessionScreenState({
    /// Indica si se esta cargando la sesion
    @Default(false) bool isLoading,

    /// Indica si se esta guardando o sincronizando la sesion con Odoo
    @Default(false) bool isSaving,

    /// Indica si se esta registrando el fondo de apertura
    @Default(false) bool isRegisteringOpeningCash,

    /// Indica si se esta registrando el efectivo de cierre
    @Default(false) bool isRegisteringClosingCash,

    /// Indica si se esta cerrando la sesion
    @Default(false) bool isClosingSession,

    /// La sesion actual
    CollectionSession? session,

    /// Mensaje de error si ocurrio alguno
    String? errorMessage,

    /// Codigo de error para manejo especifico
    String? errorCode,

    /// Indica si la operacion fue exitosa (para mostrar mensaje)
    @Default(false) bool operationSuccess,

    /// Mensaje de exito para mostrar al usuario
    String? successMessage,

    /// ID de sesion nuevo despues de sincronizacion (para redireccion)
    int? newSessionId,

    /// Last sync timestamp
    DateTime? lastSyncAt,
  }) = _CollectionSessionScreenState;

  const CollectionSessionScreenState._();

  /// Verifica si hay alguna operacion en progreso
  @override
  bool get isProcessing =>
      isLoading ||
      isSaving ||
      isRegisteringOpeningCash ||
      isRegisteringClosingCash ||
      isClosingSession;

  /// Verifica si hay un error
  @override
  bool get hasError => errorMessage != null;

  /// Verifica si la sesion esta cargada
  bool get hasSession => session != null;

  /// Verifica si la sesion necesita sincronizacion
  bool get needsSync => session != null && !session!.isSynced;

  /// Verifica si hay una redireccion pendiente
  bool get hasRedirect => newSessionId != null;
}
