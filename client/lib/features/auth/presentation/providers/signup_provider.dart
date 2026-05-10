// lib/features/auth/presentation/providers/signup_provider.dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_service.dart';
import '../providers/auth_provider.dart';

// ─────────────────────────────────────────────────────
// SIGNUP STATE
// ─────────────────────────────────────────────────────
class SignupState {
  final String email;
  final String phone;
  final String fullName;
  final DateTime? birthday;
  final String password;
  final String username;
  final File? profileImage;
  final bool isLoading;
  final String? error;

  const SignupState({
    this.email        = '',
    this.phone        = '',
    this.fullName     = '',
    this.birthday,
    this.password     = '',
    this.username     = '',
    this.profileImage,
    this.isLoading    = false,
    this.error,
  });

  SignupState copyWith({
    String?   email,
    String?   phone,
    String?   fullName,
    DateTime? birthday,
    String?   password,
    String?   username,
    File?     profileImage,
    bool?     isLoading,
    String?   error,
    bool      clearError = false,
  }) {
    return SignupState(
      email:        email         ?? this.email,
      phone:        phone         ?? this.phone,
      fullName:     fullName      ?? this.fullName,
      birthday:     birthday      ?? this.birthday,
      password:     password      ?? this.password,
      username:     username      ?? this.username,
      profileImage: profileImage  ?? this.profileImage,
      isLoading:    isLoading     ?? this.isLoading,
      error:        clearError ? null : (error ?? this.error),
    );
  }
}

// ─────────────────────────────────────────────────────
// SIGNUP NOTIFIER
// ─────────────────────────────────────────────────────
class SignupNotifier extends Notifier<SignupState> {
  @override
  SignupState build() {
    return const SignupState();
  }

  AuthService get _authService => ref.read(authServiceProvider);

  void updateData({
    String? email,
    String? phone,
    String? fullName,
    DateTime? birthday,
    String? password,
    String? username,
    File? profileImage,
  }) {
    state = state.copyWith(
      email: email,
      phone: phone,
      fullName: fullName,
      birthday: birthday,
      password: password,
      username: username,
      profileImage: profileImage,
    );
  }

  void setEmail(String v)    => state = state.copyWith(email: v.trim());
  void setPhone(String v)    => state = state.copyWith(phone: v.trim());
  void setFullName(String v) => state = state.copyWith(fullName: v.trim());
  void setBirthday(DateTime v) => state = state.copyWith(birthday: v);
  void setPassword(String v) => state = state.copyWith(password: v);
  void setUsername(String v) => state = state.copyWith(username: v.trim());
  void setProfileImage(File? f) => state = state.copyWith(profileImage: f);
  void clearError()          => state = state.copyWith(clearError: true);

  // ─── CHECK EMAIL ─────────────────────────────────────
  Future<bool> checkEmail(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authService.checkEmail(email);
      final available = result['available'] as bool? ?? false;
      state = state.copyWith(isLoading: false);
      return available;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── CHECK USERNAME ──────────────────────────────────
  Future<bool> checkUsername(String username) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authService.checkUsername(username);
      final available = result['available'] as bool? ?? false;
      state = state.copyWith(isLoading: false);
      return available;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── REGISTER ────────────────────────────────────────
  Future<bool> register() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await ref.read(authProvider.notifier).register(
        username: state.username,
        email:    state.email,
        password: state.password,
        fullName: state.fullName,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() => state = const SignupState();
}

// ─────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────
final signupProvider =
    NotifierProvider<SignupNotifier, SignupState>(SignupNotifier.new);
