// lib/features/home/presentation/providers/suggestion_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../shared/models/user_model.dart';
import '../../../follow/data/repositories/follow_service.dart';

class SuggestionState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  const SuggestionState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  SuggestionState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return SuggestionState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SuggestionNotifier extends StateNotifier<SuggestionState> {
  final FollowService _service;

  SuggestionNotifier(this._service) : super(const SuggestionState()) {
    loadSuggestions();
  }

  Future<void> loadSuggestions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final List<Map<String, dynamic>> data = await _service.getSuggestions();
      final users = data.map((u) => UserModel.fromJson(u)).toList();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false, 
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void removeSuggestion(String userId) {
    state = state.copyWith(
      users: state.users.where((u) => u.id != userId).toList(),
    );
  }
}

final suggestionProvider = StateNotifierProvider<SuggestionNotifier, SuggestionState>((ref) {
  final service = FollowService();
  return SuggestionNotifier(service);
});
