// lib/features/auth/presentation/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/repositories/auth_service.dart';

// ─── AUTH STATE CLASS ───────────────────────────────────────
// Holds all auth-related state
class AuthState {
  final UserModel? user;         // Current logged-in user
  final bool isLoading;          // Loading indicator
  final String? errorMessage;    // Error message to show
  final bool isAuthenticated;    // Is user logged in?

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  // Create a copy with some fields changed
  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,      // null clears error
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  // Initial state
  static const initial = AuthState(
    isLoading: false,
    isAuthenticated: false,
  );
}

// ─── AUTH NOTIFIER ──────────────────────────────────────────
// Contains all auth logic (register, login, logout)
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial) {
    // Check if user is already logged in when app starts
    _checkAuthStatus();
  }

  // ─── CHECK IF ALREADY LOGGED IN ──────────────────────
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        // Get fresh user data from API
        final user = await _authService.getCurrentUser();
        if (user != null) {
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );
        } else {
          // Token expired or invalid
          await _authService.logout();
          state = state.copyWith(
            isAuthenticated: false,
            isLoading: false,
          );
        }
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
      );
    }
  }

  // ─── REGISTER ────────────────────────────────────────
  Future<bool> register({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) async {
    // Clear previous errors and start loading
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final authResponse = await _authService.register(
        fullName: fullName,
        email: email,
        username: username,
        password: password,
      );

      // Success! Update state
      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        errorMessage: null,
      );

      return true; // Success

    } catch (e) {
      // Failed! Show error
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      return false; // Failed
    }
  }

  // ─── LOGIN ───────────────────────────────────────────
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final authResponse = await _authService.login(
        identifier: identifier,
        password: password,
      );

      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        errorMessage: null,
      );

      return true;

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      return false;
    }
  }

  // ─── LOGOUT ──────────────────────────────────────────
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _authService.logout();
    state = AuthState.initial; // Reset to initial state
  }

  // ─── CLEAR ERROR ─────────────────────────────────────
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // ─── UPDATE USER (after profile edit) ────────────────
  void updateUser(UserModel updatedUser) {
    state = state.copyWith(user: updatedUser);
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth state provider
// This is what screens will watch
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
// Use these in screens for cleaner code

// Just the current user
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

// Just is authenticated bool
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

// Just is loading bool
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});