// lib/core/services/account_manager.dart

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/models/saved_account_model.dart';
import '../constants/app_constants.dart';

// ─── Storage key ──────────────────────────────────────
const String _kSavedAccountsKey = 'saved_accounts_list';

// ─── Provider ─────────────────────────────────────────
final accountManagerProvider = Provider<AccountManager>((ref) {
  return AccountManager();
});

// ─────────────────────────────────────────────────────
// ACCOUNT MANAGER
// ─────────────────────────────────────────────────────
class AccountManager {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ─── Load all saved accounts ──────────────────────────
  Future<List<SavedAccountModel>> getSavedAccounts() async {
    try {
      final raw = await _storage.read(key: _kSavedAccountsKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      return list
          .map(
            (item) => SavedAccountModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Save account (add or update) ────────────────────
  Future<void> saveAccount(SavedAccountModel account) async {
    final accounts = await getSavedAccounts();

    // ─── Check if account already exists ──────────────
    final existingIndex = accounts.indexWhere(
      (a) => a.userId == account.userId,
    );

    if (existingIndex >= 0) {
      // Update existing
      accounts[existingIndex] = account;
    } else {
      // Add new
      accounts.add(account);
    }

    await _persistAccounts(accounts);
  }

  // ─── Set active account ───────────────────────────────
  Future<void> setActiveAccount(String userId) async {
    final accounts = await getSavedAccounts();

    final updated = accounts.map((a) {
      return a.copyWith(isActive: a.userId == userId);
    }).toList();

    await _persistAccounts(updated);

    // ─── Also update main tokens ────────────────────────
    final active = updated.firstWhere(
      (a) => a.userId == userId,
      orElse: () => updated.first,
    );

    await _storage.write(
      key:   AppConstants.accessTokenKey,
      value: active.accessToken,
    );
    await _storage.write(
      key:   AppConstants.refreshTokenKey,
      value: active.refreshToken,
    );
  }

  // ─── Get active account ───────────────────────────────
  Future<SavedAccountModel?> getActiveAccount() async {
    final accounts = await getSavedAccounts();
    try {
      return accounts.firstWhere((a) => a.isActive);
    } catch (_) {
      return accounts.isNotEmpty ? accounts.first : null;
    }
  }

  // ─── Remove account ───────────────────────────────────
  Future<void> removeAccount(String userId) async {
    final accounts = await getSavedAccounts();
    final remaining = accounts.where((a) => a.userId != userId).toList();

    // ─── If we removed the active account, activate first ─
    if (remaining.isNotEmpty) {
      final hadActive = accounts.any(
        (a) => a.userId == userId && a.isActive,
      );
      if (hadActive) {
        remaining[0] = remaining[0].copyWith(isActive: true);
        // Update main tokens to new active
        await _storage.write(
          key:   AppConstants.accessTokenKey,
          value: remaining[0].accessToken,
        );
        await _storage.write(
          key:   AppConstants.refreshTokenKey,
          value: remaining[0].refreshToken,
        );
      }
    } else {
      // No accounts left → clear main tokens
      await _storage.delete(key: AppConstants.accessTokenKey);
      await _storage.delete(key: AppConstants.refreshTokenKey);
    }

    await _persistAccounts(remaining);
  }

  // ─── Update tokens for a saved account ───────────────
  // Called after token refresh so saved tokens stay fresh
  Future<void> updateAccountTokens({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    final accounts = await getSavedAccounts();
    final updated  = accounts.map((a) {
      if (a.userId != userId) return a;
      return a.copyWith(
        accessToken:  accessToken,
        refreshToken: refreshToken,
      );
    }).toList();
    await _persistAccounts(updated);
  }

  // ─── Update profile picture in saved account ──────────
  Future<void> updateAccountAvatar({
    required String userId,
    required String? profilePicture,
  }) async {
    final accounts = await getSavedAccounts();
    final updated  = accounts.map((a) {
      if (a.userId != userId) return a;
      return a.copyWith(profilePicture: profilePicture);
    }).toList();
    await _persistAccounts(updated);
  }

  // ─── Clear all accounts ───────────────────────────────
  Future<void> clearAll() async {
    await _storage.delete(key: _kSavedAccountsKey);
    await _storage.delete(key: AppConstants.accessTokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }

  // ─── Count saved accounts ─────────────────────────────
  Future<int> getAccountCount() async {
    final accounts = await getSavedAccounts();
    return accounts.length;
  }

  // ─── Private: persist list ────────────────────────────
  Future<void> _persistAccounts(List<SavedAccountModel> accounts) async {
    final json = jsonEncode(
      accounts.map((a) => a.toJson()).toList(),
    );
    await _storage.write(key: _kSavedAccountsKey, value: json);
  }
}
