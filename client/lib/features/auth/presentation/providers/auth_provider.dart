// lib/features/auth/presentation/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/account_manager.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/socket/socket_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../data/models/saved_account_model.dart';
import '../../data/repositories/auth_service.dart';

// Import other providers to refresh/invalidate them on auth changes
import '../../../messages/presentation/providers/message_provider.dart';
import 'package:instagram_clinet/features/notifications/presentation/providers/notification_provider.dart';
import '../../../post/presentation/providers/feed_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../story/presentation/providers/story_provider.dart';

// ─────────────────────────────────────────────────────
// AUTH STATE
// ─────────────────────────────────────────────────────
class AuthState {
  final bool      isAuthenticated;
  final bool      isLoading;
  final UserModel? user;
  final String?   error;
  final List<SavedAccountModel> savedAccounts;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading       = true,
    this.user,
    this.error,
    this.savedAccounts   = const [],
  });

  AuthState copyWith({
    bool?      isAuthenticated,
    bool?      isLoading,
    UserModel? user,
    String?    error,
    bool       clearError = false,
    List<SavedAccountModel>? savedAccounts,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading:       isLoading       ?? this.isLoading,
      user:            user            ?? this.user,
      error:           clearError ? null : (error ?? this.error),
      savedAccounts:   savedAccounts   ?? this.savedAccounts,
    );
  }

  String? get errorMessage => error;
}

// ─────────────────────────────────────────────────────
// AUTH NOTIFIER
// ─────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService      _authService;
  final AccountManager   _accountManager;
  final Ref              _ref;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  AuthNotifier(this._authService, this._accountManager, this._ref)
      : super(const AuthState()) {
    _init();
  }

  // ─── Initialize: check stored token ──────────────────
  Future<void> _init() async {
    try {
      final token = await _storage.read(
        key: AppConstants.accessTokenKey,
      );

      // ─── Load saved accounts ──────────────────────────
      final accounts = await _accountManager.getSavedAccounts();

      if (token == null) {
        state = state.copyWith(
          isLoading:     false,
          savedAccounts: accounts,
        );
        return;
      }

      final user = await _authService.getMe();
      state = state.copyWith(
        isAuthenticated: true,
        isLoading:       false,
        user:            user,
        savedAccounts:   accounts,
      );

      _connectSocket(token);
      
      // ─── Register FCM token on app init ────────────────
      _registerPushToken();
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── Login ────────────────────────────────────────────
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      _disconnectSocket();
      _clearUserScopedProviders();

      final result = await _authService.login(
        identifier: identifier,
        password:   password,
      );

      final accessToken  = result.accessToken;
      final refreshToken = result.refreshToken;
      final user         = result.user;

      // ─── Save tokens (main) ───────────────────────────
      await _storage.write(
        key:   AppConstants.accessTokenKey,
        value: accessToken,
      );
      await _storage.write(
        key:   AppConstants.refreshTokenKey,
        value: refreshToken,
      );

      // ─── Save to account manager ──────────────────────
      final savedAccount = SavedAccountModel(
        userId:         user.id,
        username:       user.username,
        email:          user.email,
        fullName:       user.fullName,
        profilePicture: user.profilePicture,
        accessToken:    accessToken,
        refreshToken:   refreshToken,
        isActive:       true,
      );

      // Mark all others as inactive
      final currentAccounts = await _accountManager.getSavedAccounts();
      for (final acc in currentAccounts) {
        if (acc.userId != user.id) {
          await _accountManager.saveAccount(
            acc.copyWith(isActive: false),
          );
        }
      }

      await _accountManager.saveAccount(savedAccount);
      final updatedAccounts = await _accountManager.getSavedAccounts();

      state = state.copyWith(
        isAuthenticated: true,
        isLoading:       false,
        user:            user,
        savedAccounts:   updatedAccounts,
      );

      _connectSocket(accessToken);
      _refreshUserScopedProviders();
      
      // ─── Register FCM token after login ────────────────
      _registerPushToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  // ─── Register ─────────────────────────────────────────
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      _disconnectSocket();
      _clearUserScopedProviders();

      final result = await _authService.register(
        username: username,
        email:    email,
        password: password,
        fullName: fullName,
      );

      final accessToken  = result.accessToken;
      final refreshToken = result.refreshToken;
      final user         = result.user;

      await _storage.write(
        key:   AppConstants.accessTokenKey,
        value: accessToken,
      );
      await _storage.write(
        key:   AppConstants.refreshTokenKey,
        value: refreshToken,
      );

      final savedAccount = SavedAccountModel(
        userId:         user.id,
        username:       user.username,
        email:          user.email,
        fullName:       user.fullName,
        profilePicture: user.profilePicture,
        accessToken:    accessToken,
        refreshToken:   refreshToken,
        isActive:       true,
      );
      await _accountManager.saveAccount(savedAccount);
      final updatedAccounts = await _accountManager.getSavedAccounts();

      state = state.copyWith(
        isAuthenticated: true,
        isLoading:       false,
        user:            user,
        savedAccounts:   updatedAccounts,
      );

      _connectSocket(accessToken);
      _refreshUserScopedProviders();

      // ─── Register FCM token after register ─────────────
      _registerPushToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  // ─── Switch Account ───────────────────────────────────
  Future<void> switchAccount(String userId) async {
    if (state.user?.id == userId) return; // already active

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // ─── Disconnect current socket ────────────────────
      _disconnectSocket();
      _clearUserScopedProviders();

      // ─── Set new active account ───────────────────────
      await _accountManager.setActiveAccount(userId);

      // ─── Load new account data ────────────────────────
      final user = await _authService.getMe();

      // ─── Update saved account with fresh data ─────────
      final active = await _accountManager.getActiveAccount();
      if (active != null && user != null) {
        await _accountManager.saveAccount(
          active.copyWith(
            fullName:       user.fullName,
            profilePicture: user.profilePicture,
          ),
        );
      }

      final updatedAccounts = await _accountManager.getSavedAccounts();

      state = state.copyWith(
        isAuthenticated: true,
        isLoading:       false,
        user:            user,
        savedAccounts:   updatedAccounts,
      );

      // ─── Connect socket for new account ───────────────
      final token = await _storage.read(
        key: AppConstants.accessTokenKey,
      );
      if (token != null) {
        _connectSocket(token);
        _refreshUserScopedProviders();
        
        // ─── Register FCM token for new account ───────────
        _registerPushToken();
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:     e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── Logout (current account) ─────────────────────────
  Future<void> logout() async {
    try {
      // ─── Clear FCM token on logout ─────────────────────
      await _clearPushToken();
      await _authService.logout();
    } catch (_) {}

    _disconnectSocket();
    _clearUserScopedProviders();

    final currentUserId = state.user?.id;
    if (currentUserId != null) {
      await _accountManager.removeAccount(currentUserId);
    }

    final remaining = await _accountManager.getSavedAccounts();

    if (remaining.isNotEmpty) {
      // ─── Switch to first remaining account ────────────
      final nextAccount = remaining.first;
      await _accountManager.setActiveAccount(nextAccount.userId);

      try {
        final user = await _authService.getMe();
        final token = await _storage.read(
          key: AppConstants.accessTokenKey,
        );
        final updatedAccounts = await _accountManager.getSavedAccounts();

        state = state.copyWith(
          isAuthenticated: true,
          isLoading:       false,
          user:            user,
          savedAccounts:   updatedAccounts,
        );

        if (token != null) {
          _connectSocket(token);
          _refreshUserScopedProviders();
          _registerPushToken();
        }
        return;
      } catch (_) {}
    }

    // ─── No remaining accounts → fully logged out ──────
    await _accountManager.clearAll();

    state = const AuthState(
      isAuthenticated: false,
      isLoading:       false,
      savedAccounts:   [],
    );
  }

  // ─── Logout all accounts ──────────────────────────────
  Future<void> logoutAll() async {
    try {
      await _clearPushToken();
      await _authService.logout();
    } catch (_) {}

    _disconnectSocket();
    _clearUserScopedProviders();
    await _accountManager.clearAll();

    state = const AuthState(
      isAuthenticated: false,
      isLoading:       false,
      savedAccounts:   [],
    );
  }

  // ─── Remove a specific saved account ─────────────────
  Future<void> removeAccount(String userId) async {
    if (state.user?.id == userId) {
      // Removing active account → same as logout
      await logout();
      return;
    }

    await _accountManager.removeAccount(userId);
    final updatedAccounts = await _accountManager.getSavedAccounts();
    state = state.copyWith(savedAccounts: updatedAccounts);
  }

  // ─── Refresh user data ────────────────────────────────
  Future<void> refreshUser() async {
    try {
      final user = await _authService.getMe();
      if (user == null) return;
      
      state = state.copyWith(user: user);

      // ─── Update avatar in saved accounts ──────────────
      if (state.user != null) {
        await _accountManager.updateAccountAvatar(
          userId:         state.user!.id,
          profilePicture: user.profilePicture,
        );
      }

      final updatedAccounts = await _accountManager.getSavedAccounts();
      state = state.copyWith(savedAccounts: updatedAccounts);
    } catch (_) {}
  }

  // ─── Clear error state ────────────────────────────────
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ─── Update profile (called after edit profile) ───────
  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  // ─── Socket helpers ───────────────────────────────────
  void _connectSocket(String token) {
    try {
      _ref.read(socketProvider.notifier).connect();
    } catch (_) {}
  }

  void _disconnectSocket() {
    try {
      _ref.read(socketProvider.notifier).disconnect();
    } catch (_) {}
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

  // ─── PUSH NOTIFICATION HELPERS ────────────────────────────
  void _registerPushToken() async {
    try {
      final pushService = _ref.read(pushNotificationServiceProvider);
      await pushService.getAndSendToken();
    } catch (e) {
      debugPrint('⚠️ Could not register push token: $e');
    }
  }

  Future<void> _clearPushToken() async {
    try {
      final pushService = _ref.read(pushNotificationServiceProvider);
      await pushService.clearToken();
    } catch (e) {
      debugPrint('⚠️ Could not clear push token: $e');
    }
  }
}

// ─── Provider ─────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService      = ref.read(authServiceProvider);
  final accountManager   = ref.read(accountManagerProvider);
  return AuthNotifier(authService, accountManager, ref);
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
