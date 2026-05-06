// lib/features/reels/presentation/providers/reel_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/reel_model.dart';
import '../../data/repositories/reel_service.dart';

// ─────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────
class ReelFeedState {
  final List<ReelModel> reels;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final int page;
  final String? error;

  const ReelFeedState({
    this.reels = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.page = 1,
    this.error,
  });

  ReelFeedState copyWith({
    List<ReelModel>? reels,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    int? page,
    String? error,
    bool clearError = false,
  }) {
    return ReelFeedState(
      reels: reels ?? this.reels,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────
class ReelFeedNotifier extends StateNotifier<ReelFeedState> {
  final ReelService _reelService;

  ReelFeedNotifier(this._reelService) : super(const ReelFeedState()) {
    loadReels();
  }

  // ─── Load initial ─────────────────────────────────────
  Future<void> loadReels() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final reels = await _reelService.getReelsFeed(page: 1);
      state = state.copyWith(
        reels: reels,
        isLoading: false,
        page: 1,
        hasMore: reels.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── Refresh ──────────────────────────────────────────
  Future<void> refresh() async {
    if (state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final reels = await _reelService.getReelsFeed(page: 1);
      state = state.copyWith(
        reels: reels,
        isRefreshing: false,
        page: 1,
        hasMore: reels.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── Load more (pagination) ───────────────────────────
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.page + 1;
      final more = await _reelService.getReelsFeed(page: nextPage);

      state = state.copyWith(
        reels: [...state.reels, ...more],
        isLoading: false,
        page: nextPage,
        hasMore: more.length >= 10,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ─── Like (optimistic) ────────────────────────────────
  Future<void> likeReel(String reelId) async {
    _updateReel(
      reelId,
      (r) => r.copyWith(
        isLiked: true,
        likesCount: r.likesCount + 1,
      ),
    );
    try {
      await _reelService.likeReel(reelId);
    } catch (_) {
      _updateReel(
        reelId,
        (r) => r.copyWith(
          isLiked: false,
          likesCount: r.likesCount - 1,
        ),
      );
    }
  }

  // ─── Unlike (optimistic) ─────────────────────────────
  Future<void> unlikeReel(String reelId) async {
    _updateReel(
      reelId,
      (r) => r.copyWith(
        isLiked: false,
        likesCount: r.likesCount - 1,
      ),
    );
    try {
      await _reelService.unlikeReel(reelId);
    } catch (_) {
      _updateReel(
        reelId,
        (r) => r.copyWith(
          isLiked: true,
          likesCount: r.likesCount + 1,
        ),
      );
    }
  }

  // ─── Remove deleted reel ─────────────────────────────
  void removeReel(String reelId) {
    state = state.copyWith(
      reels: state.reels.where((r) => r.id != reelId).toList(),
    );
  }

  // ─── Internal helper ─────────────────────────────────
  void _updateReel(
    String reelId,
    ReelModel Function(ReelModel) updater,
  ) {
    state = state.copyWith(
      reels: state.reels.map((r) {
        return r.id == reelId ? updater(r) : r;
      }).toList(),
    );
  }
}

// ─── Provider ─────────────────────────────────────────
final reelFeedProvider =
    StateNotifierProvider<ReelFeedNotifier, ReelFeedState>((ref) {
  final reelService = ref.read(reelServiceProvider);
  return ReelFeedNotifier(reelService);
});
