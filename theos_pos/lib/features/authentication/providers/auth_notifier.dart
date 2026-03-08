import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../repositories/auth_repository.dart';
import 'auth_state.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

part 'auth_notifier.g.dart';

/// Notifier for managing authentication state
///
/// Handles:
/// - Checking stored credentials on app start
/// - Login/logout operations
/// - Current user state
@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  late AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    return AuthState.initial();
  }

  /// Check if user is already logged in (on app start)
  Future<void> checkAuthStatus() async {
    state = state.copyWith(isInitializing: true);

    final result = await _repository.getCurrentUser();

    result.fold(
      (failure) {
        state = AuthState.unauthenticated();
      },
      (user) {
        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          state = AuthState.unauthenticated();
        }
      },
    );
  }

  /// Set authenticated user (called after successful login elsewhere)
  void setAuthenticated(User user) {
    state = AuthState.authenticated(user);
  }

  /// Logout current user
  Future<void> logout() async {
    state = AuthState.loading();

    final result = await _repository.logout();

    result.fold(
      (failure) {
        state = AuthState.error(failure.message);
      },
      (_) {
        state = AuthState.unauthenticated();
      },
    );
  }

  /// Clear any error state
  void clearError() {
    if (state.hasError) {
      state = state.copyWith(
        status: state.user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        errorMessage: null,
      );
    }
  }
}
