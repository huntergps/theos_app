import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/providers/base_feature_state.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

part 'auth_state.freezed.dart';

/// Authentication status
enum AuthStatus {
  /// Initial state - checking stored credentials
  initial,

  /// User is authenticated
  authenticated,

  /// User is not authenticated
  unauthenticated,

  /// Authentication in progress
  loading,

  /// Authentication failed
  error,
}

/// State for authentication
///
/// Implements [BaseFeatureState] for standardized loading/error handling.
@freezed
abstract class AuthState with _$AuthState implements BaseFeatureState {
  const factory AuthState({
    @Default(AuthStatus.initial) AuthStatus status,
    User? user,
    String? errorMessage,
    @Default(false) bool isInitializing,
  }) = _AuthState;

  const AuthState._();

  /// Whether the user is authenticated
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  /// Whether authentication is in progress
  @override
  bool get isLoading => status == AuthStatus.loading || isInitializing;

  /// Whether saving/syncing is in progress (not applicable for auth)
  @override
  bool get isSaving => false;

  /// Last sync timestamp (not applicable for auth)
  @override
  DateTime? get lastSyncAt => null;

  @override
  bool get isProcessing => isLoading;

  /// Whether there's an error
  @override
  bool get hasError => status == AuthStatus.error && errorMessage != null;

  /// Create initial state
  factory AuthState.initial() =>
      const AuthState(status: AuthStatus.initial, isInitializing: true);

  /// Create loading state
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);

  /// Create authenticated state
  factory AuthState.authenticated(User user) =>
      AuthState(status: AuthStatus.authenticated, user: user);

  /// Create unauthenticated state
  factory AuthState.unauthenticated() =>
      const AuthState(status: AuthStatus.unauthenticated);

  /// Create error state
  factory AuthState.error(String message) =>
      AuthState(status: AuthStatus.error, errorMessage: message);
}
