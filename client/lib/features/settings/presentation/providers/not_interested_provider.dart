// lib/features/settings/presentation/providers/not_interested_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotInterestedState {
  final List<Map<String, dynamic>> items;
  const NotInterestedState({this.items = const []});
}

class NotInterestedNotifier extends Notifier<NotInterestedState> {
  static const _key = 'not_interested_items';

  @override
  NotInterestedState build() {
    _loadItems();
    return const NotInterestedState();
  }

  Future<void> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      final parsed = list
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .toList();
      state = NotInterestedState(items: parsed);
    } catch (e) {
      // Ignore
    }
  }

  Future<void> addPost(Map<String, dynamic> post) async {
    final updated = List<Map<String, dynamic>>.from(state.items);
    // Remove duplicate if exists
    updated.removeWhere((item) => item['id'] == post['id']);
    updated.insert(0, post);

    state = NotInterestedState(items: updated);
    _saveToPrefs(updated);
  }

  Future<void> removePost(String postId) async {
    final updated = state.items.where((item) => item['id'] != postId).toList();
    state = NotInterestedState(items: updated);
    _saveToPrefs(updated);
  }

  Future<void> _saveToPrefs(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stringList = list.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList(_key, stringList);
    } catch (e) {
      // Ignore
    }
  }
}

final notInterestedProvider =
    NotifierProvider<NotInterestedNotifier, NotInterestedState>(
  NotInterestedNotifier.new,
);
