// lib/core/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── THEME STATE ────────────────────────────────────────────
class ThemeState {
  final ThemeMode themeMode;
  final bool isLoading;

  const ThemeState({
    this.themeMode = ThemeMode.light,
    this.isLoading = true,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isLoading,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isDark => themeMode == ThemeMode.dark;
}

// ─── THEME NOTIFIER ─────────────────────────────────────────
class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeKey = 'app_theme_mode';

  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }

  // ─── LOAD SAVED THEME ────────────────────────────────────
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);

      ThemeMode mode = ThemeMode.light; // Default
      if (savedTheme == 'dark') {
        mode = ThemeMode.dark;
      } else if (savedTheme == 'system') {
        mode = ThemeMode.system;
      }

      if (mounted) {
        state = state.copyWith(
          themeMode: mode,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  // ─── TOGGLE DARK MODE ────────────────────────────────────
  Future<void> toggleDarkMode() async {
    final newMode = state.isDark
        ? ThemeMode.light
        : ThemeMode.dark;

    await _saveTheme(newMode);

    if (mounted) {
      state = state.copyWith(themeMode: newMode);
    }
  }

  // ─── SET THEME MODE ──────────────────────────────────────
  Future<void> setThemeMode(ThemeMode mode) async {
    await _saveTheme(mode);
    if (mounted) {
      state = state.copyWith(themeMode: mode);
    }
  }

  // ─── SAVE THEME TO STORAGE ───────────────────────────────
  Future<void> _saveTheme(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeStr = 'light';
      if (mode == ThemeMode.dark) themeStr = 'dark';
      if (mode == ThemeMode.system) themeStr = 'system';
      await prefs.setString(_themeKey, themeStr);
    } catch (e) {
      // Silent fail
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

// Convenience: just the ThemeMode
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

// Convenience: is dark mode?
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isDark;
});
