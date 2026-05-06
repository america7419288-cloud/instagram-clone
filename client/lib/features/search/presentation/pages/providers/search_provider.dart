// lib/features/search/presentation/providers/search_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/search_service.dart';

// ─── SEARCH STATE ───────────────────────────────────────────
class SearchState {
  final String query;
  final List<Map<String, dynamic>> userResults;
  final List<Map<String, dynamic>> explorePostsGrid;
  final List<String> recentSearches;
  final bool isSearching;       // Actively typing
  final bool isLoadingResults;  // Waiting for API
  final bool isLoadingExplore;
  final bool hasMoreExplore;
  final int explorePage;
  final String? errorMessage;

  const SearchState({
    this.query = '',
    this.userResults = const [],
    this.explorePostsGrid = const [],
    this.recentSearches = const [],
    this.isSearching = false,
    this.isLoadingResults = false,
    this.isLoadingExplore = false,
    this.hasMoreExplore = true,
    this.explorePage = 1,
    this.errorMessage,
  });

  SearchState copyWith({
    String? query,
    List<Map<String, dynamic>>? userResults,
    List<Map<String, dynamic>>? explorePostsGrid,
    List<String>? recentSearches,
    bool? isSearching,
    bool? isLoadingResults,
    bool? isLoadingExplore,
    bool? hasMoreExplore,
    int? explorePage,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      userResults: userResults ?? this.userResults,
      explorePostsGrid: explorePostsGrid ?? this.explorePostsGrid,
      recentSearches: recentSearches ?? this.recentSearches,
      isSearching: isSearching ?? this.isSearching,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      isLoadingExplore: isLoadingExplore ?? this.isLoadingExplore,
      hasMoreExplore: hasMoreExplore ?? this.hasMoreExplore,
      explorePage: explorePage ?? this.explorePage,
      errorMessage: errorMessage,
    );
  }

  bool get showExplore => query.isEmpty;
  bool get showResults => query.isNotEmpty;
  bool get showRecentSearches =>
      query.isEmpty && recentSearches.isNotEmpty;
}

// ─── SEARCH NOTIFIER ────────────────────────────────────────
class SearchNotifier extends Notifier<SearchState> {
  SearchService get _service => ref.read(searchServiceProvider);

  // Debounce timer simulation
  DateTime? _lastSearchTime;

  @override
  SearchState build() {
    // Load initial data
    Future.microtask(() {
      _loadRecentSearches();
      loadExplorePosts();
    });
    return const SearchState();
  }

  // ─── LOAD RECENT SEARCHES FROM LOCAL STORAGE ────────────
  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent =
          prefs.getStringList('recent_searches') ?? [];
      state = state.copyWith(recentSearches: recent);
    } catch (e) {
      // Ignore storage errors
    }
  }

  // ─── SAVE RECENT SEARCH ─────────────────────────────────
  Future<void> _saveRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent =
          List<String>.from(state.recentSearches);

      // Remove if already exists (to move to top)
      recent.remove(query);
      // Add to beginning
      recent.insert(0, query);
      // Keep only last 10
      final trimmed = recent.take(10).toList();

      await prefs.setStringList('recent_searches', trimmed);
      state = state.copyWith(recentSearches: trimmed);
    } catch (e) {
      // Ignore
    }
  }

  // ─── CLEAR RECENT SEARCHES ──────────────────────────────
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches');
      state = state.copyWith(recentSearches: []);
    } catch (e) {
      // Ignore
    }
  }

  // ─── REMOVE ONE RECENT SEARCH ───────────────────────────
  Future<void> removeRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = state.recentSearches
          .where((s) => s != query)
          .toList();
      await prefs.setStringList('recent_searches', updated);
      state = state.copyWith(recentSearches: updated);
    } catch (e) {
      // Ignore
    }
  }

  // ─── ON SEARCH QUERY CHANGE (with debounce) ─────────────
  Future<void> onQueryChanged(String query) async {
    state = state.copyWith(
      query: query,
      isSearching: query.isNotEmpty,
      userResults: query.isEmpty ? [] : state.userResults,
    );

    if (query.trim().isEmpty) {
      state = state.copyWith(
        userResults: [],
        isLoadingResults: false,
      );
      return;
    }

    // Debounce: wait 300ms after user stops typing
    final searchTime = DateTime.now();
    _lastSearchTime = searchTime;

    await Future.delayed(const Duration(milliseconds: 300));

    // If a newer search started, ignore this one
    if (_lastSearchTime != searchTime) return;

    await _performSearch(query.trim());
  }

  // ─── PERFORM SEARCH ─────────────────────────────────────
  Future<void> _performSearch(String query) async {
    state = state.copyWith(
      isLoadingResults: true,
      errorMessage: null,
    );

    try {
      final result = await _service.searchUsers(query: query);
      final users = result['users'] as List<dynamic>;

      state = state.copyWith(
        userResults: users.cast<Map<String, dynamic>>(),
        isLoadingResults: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingResults: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── SUBMIT SEARCH (save to recent) ─────────────────────
  void submitSearch(String query) {
    if (query.trim().isNotEmpty) {
      _saveRecentSearch(query.trim());
    }
  }

  // ─── CLEAR SEARCH ───────────────────────────────────────
  void clearSearch() {
    state = state.copyWith(
      query: '',
      isSearching: false,
      userResults: [],
    );
  }

  // ─── LOAD EXPLORE POSTS ─────────────────────────────────
  Future<void> loadExplorePosts() async {
    if (state.isLoadingExplore) return;

    state = state.copyWith(
      isLoadingExplore: true,
      errorMessage: null,
    );

    try {
      final result = await _service.getExplorePosts(page: 1);
      final posts = result['posts'] as List<dynamic>;

      state = state.copyWith(
        explorePostsGrid: posts.cast<Map<String, dynamic>>(),
        isLoadingExplore: false,
        hasMoreExplore: result['has_next'] as bool? ?? false,
        explorePage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingExplore: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── REFRESH EXPLORE ───────────────────────────────────
  Future<void> refreshExplore() async {
    state = state.copyWith(
      explorePage: 1,
      hasMoreExplore: true,
    );
    await loadExplorePosts();
  }

  // ─── LOAD MORE EXPLORE ───────────────────────────────────
  Future<void> loadMoreExplore() async {
    if (state.isLoadingExplore || !state.hasMoreExplore) return;

    state = state.copyWith(isLoadingExplore: true);

    try {
      final nextPage = state.explorePage + 1;
      final result = await _service.getExplorePosts(
        page: nextPage,
      );
      final newPosts =
          (result['posts'] as List<dynamic>)
              .cast<Map<String, dynamic>>();

      state = state.copyWith(
        explorePostsGrid: [
          ...state.explorePostsGrid,
          ...newPosts,
        ],
        isLoadingExplore: false,
        hasMoreExplore: result['has_next'] as bool? ?? false,
        explorePage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingExplore: false);
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService();
});

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
