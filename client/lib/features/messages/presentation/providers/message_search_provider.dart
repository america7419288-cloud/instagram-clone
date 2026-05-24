// lib/features/messages/presentation/providers/message_search_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user_model.dart';
import '../../../search/data/repositories/search_service.dart';

class MessageSearchState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  MessageSearchState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  MessageSearchState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
  }) {
    return MessageSearchState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MessageSearchNotifier extends Notifier<MessageSearchState> {
  SearchService get _searchService => ref.read(searchServiceProvider);

  @override
  MessageSearchState build() {
    Future.microtask(() => loadSuggestions());
    return MessageSearchState();
  }

  Future<void> loadSuggestions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _searchService.getSuggestions();
      final users = list.map((u) => UserModel.fromJson(u)).toList();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      loadSuggestions();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _searchService.searchUsers(query: query);
      final usersData = result['users'] as List<dynamic>;
      final users = usersData.map((u) => UserModel.fromJson(u)).toList();

      state = state.copyWith(
        users: users,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void clear() {
    state = MessageSearchState();
    loadSuggestions();
  }
}

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

final messageSearchProvider =
    NotifierProvider<MessageSearchNotifier, MessageSearchState>(
  MessageSearchNotifier.new,
);

