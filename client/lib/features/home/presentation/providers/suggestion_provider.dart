import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class SuggestionNotifier extends Notifier<SuggestionState> {
  late FollowService _service;

  @override
  SuggestionState build() {
    _service = FollowService(); // Or get from provider if available
    
    // Initial load
    Future.microtask(() => loadSuggestions());
    
    return const SuggestionState();
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

final suggestionProvider = NotifierProvider<SuggestionNotifier, SuggestionState>(() {
  return SuggestionNotifier();
});

