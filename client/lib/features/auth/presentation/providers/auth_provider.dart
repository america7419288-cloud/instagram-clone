// lib/features/auth/presentation/providers/auth_provider.dart
// COMPLETE UPDATED FILE

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/repositories/auth_service.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../../core/router/main_shell.dart';
import '../../../messages/presentation/providers/message_provider.dart';
import '../../../notifications/presentation/pages/providers/notification_provider.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../story/presentation/providers/story_provider.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  static const initial = AuthState(isLoading: false, isAuthenticated: false);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthNotifier(this._authService, this._ref) : super(AuthState.initial) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (!mounted) return;

      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        if (!mounted) return;

        if (user != null) {
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );

          // ⭐ Connect socket when already logged in
          _connectSocket();
        } else {
          await _authService.logout();
          if (!mounted) return;
          state = state.copyWith(isAuthenticated: false, isLoading: false);
        }
      } else {
        if (!mounted) return;
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    }
  }

  // ─── REGISTER ─────────────────────────────────────────────
  Future<bool> register({
    required String fullName,
    required String email,
    required String username,
    required String password,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _disconnectSocket();
      _clearUserScopedProviders();

      final authResponse = await _authService.register(
        fullName: fullName,
        email: email,
        username: username,
        password: password,
      );
      if (!mounted) return false;

      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        errorMessage: null,
      );

      // ⭐ Connect socket after register
      _connectSocket();
      _refreshUserScopedProviders();

      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      return false;
    }
  }

  // ─── LOGIN ────────────────────────────────────────────────
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    if (!mounted) return false;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      _disconnectSocket();
      _clearUserScopedProviders();

      final authResponse = await _authService.login(
        identifier: identifier,
        password: password,
      );
      if (!mounted) return false;

      state = state.copyWith(
        user: authResponse.user,
        isAuthenticated: true,
        isLoading: false,
        errorMessage: null,
      );

      // ⭐ Connect socket after login
      _connectSocket();
      _refreshUserScopedProviders();

      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
        isAuthenticated: false,
      );
      return false;
    }
  }

  // ─── LOGOUT ───────────────────────────────────────────────
  Future<void> logout() async {
    // ⭐ Disconnect socket before logout
    _disconnectSocket();

    _clearUserScopedProviders();

    await _authService.logout();
    if (!mounted) return;
    state = AuthState.initial;
  }

  // ─── CLEAR ERROR ──────────────────────────────────────────
  void clearError() {
    if (!mounted) return;
    state = state.copyWith(errorMessage: null);
  }

  // ─── UPDATE USER ──────────────────────────────────────────
  void updateUser(UserModel updatedUser) {
    if (!mounted) return;
    state = state.copyWith(user: updatedUser);
  }

  // ─── CONNECT SOCKET (private) ─────────────────────────────
  void _connectSocket() {
    try {
      _ref.read(socketProvider.notifier).connect();
    } catch (e) {
      print('Socket connect error: $e');
    }
  }

  // ─── DISCONNECT SOCKET (private) ──────────────────────────
  void _disconnectSocket() {
    try {
      _ref.read(socketProvider.notifier).disconnect();
    } catch (e) {
      print('Socket disconnect error: $e');
    }
  }

  void _clearUserScopedProviders() {
    _ref.invalidate(feedProvider);
    _ref.invalidate(storyFeedProvider);
    _ref.invalidate(notificationProvider);
    _ref.invalidate(inboxProvider);
    _ref.invalidate(chatProvider);
    _ref.invalidate(profileProvider);
  }

  void _refreshUserScopedProviders() {
    Future.microtask(() {
      _ref.read(feedProvider.notifier).loadFeed();
      _ref.read(storyFeedProvider.notifier).loadStories();
      _ref.read(notificationProvider.notifier).refresh();
      _ref.read(inboxProvider.notifier).loadUnreadCount();
    });
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService, ref);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});
