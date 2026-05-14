// lib/features/follow/presentation/providers/follow_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../follow_service.dart';

// ─── FOLLOW STATUS ENUM ─────────────────────────────────────
enum FollowStatus {
  notFollowing, // Can follow
  following, // Already following
  requested, // Pending request
  loading, // API call in progress
}

// ─── FOLLOW STATE (per user) ────────────────────────────────
class FollowState {
  final FollowStatus status;
  final int followersCount;
  final int followingCount;
  final bool isOwnProfile;
  final bool isBlocked;
  final bool hasBlockedMe;

  const FollowState({
    this.status = FollowStatus.notFollowing,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isOwnProfile = false,
    this.isBlocked = false,
    this.hasBlockedMe = false,
  });

  FollowState copyWith({
    FollowStatus? status,
    int? followersCount,
    int? followingCount,
    bool? isOwnProfile,
    bool? isBlocked,
    bool? hasBlockedMe,
  }) {
    return FollowState(
      status: status ?? this.status,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      isBlocked: isBlocked ?? this.isBlocked,
      hasBlockedMe: hasBlockedMe ?? this.hasBlockedMe,
    );
  }

  bool get isFollowing => status == FollowStatus.following;
  bool get isPending => status == FollowStatus.requested;
  bool get isNotFollowing => status == FollowStatus.notFollowing;
  bool get isLoading => status == FollowStatus.loading;
}

// ─── FOLLOW NOTIFIER (per user) ─────────────────────────────
class FollowNotifier extends Notifier<FollowState> {
  FollowService get _service => ref.read(followServiceProvider);
  late String targetUserId;

  @override
  FollowState build() {
    Future.microtask(_loadFollowStatus);
    return const FollowState();
  }

  Future<void> _loadFollowStatus() async {
    try {
      final data = await _service.getFollowStatus(targetUserId);
      final followStatusStr = data['follow_status'] as String?;
      final isOwnProfile = data['is_own_profile'] as bool? ?? false;
      final counts = data['counts'] as Map<String, dynamic>? ?? {};

      FollowStatus status;
      switch (followStatusStr) {
        case 'following':
        case 'accepted':
          status = FollowStatus.following;
          break;
        case 'requested':
        case 'pending':
          status = FollowStatus.requested;
          break;
        default:
          status = FollowStatus.notFollowing;
      }

      state = state.copyWith(
        status: status,
        followersCount:
            data['followers_count'] as int? ?? counts['followers'] as int? ?? 0,
        followingCount:
            data['following_count'] as int? ?? counts['following'] as int? ?? 0,
        isOwnProfile: isOwnProfile,
        isBlocked: data['is_blocked_by_me'] as bool? ?? false,
        hasBlockedMe: data['has_blocked_me'] as bool? ?? false,
      );
    } catch (e) {
      // Keep default state on error
    }
  }

  // ─── TOGGLE FOLLOW ────────────────────────────────────────
  Future<void> toggleFollow() async {
    final previousStatus = state.status;

    // Optimistic update
    if (state.isFollowing) {
      // Unfollow
      state = state.copyWith(
        status: FollowStatus.loading,
        followersCount: state.followersCount - 1,
      );
      try {
        await _service.unfollowUser(targetUserId);
        state = state.copyWith(status: FollowStatus.notFollowing);
      } catch (e) {
        // Revert
        state = state.copyWith(
          status: previousStatus,
          followersCount: state.followersCount + 1,
        );
        rethrow;
      }
    } else if (state.isPending) {
      // Cancel request
      state = state.copyWith(status: FollowStatus.loading);
      try {
        await _service.cancelFollowRequest(targetUserId);
        state = state.copyWith(status: FollowStatus.notFollowing);
      } catch (e) {
        state = state.copyWith(status: previousStatus);
        rethrow;
      }
    } else {
      // Follow
      state = state.copyWith(status: FollowStatus.loading);
      try {
        final data = await _service.followUser(targetUserId);
        final newStatus = data['follow_status'] as String?;
        final isFollowing = newStatus == 'following' || newStatus == 'accepted';

        state = state.copyWith(
          status: isFollowing ? FollowStatus.following : FollowStatus.requested,
          followersCount: isFollowing
              ? (data['followers_count'] as int? ?? state.followersCount + 1)
              : state.followersCount,
        );
      } catch (e) {
        state = state.copyWith(status: previousStatus);
        rethrow;
      }
    }
  }

  // ─── BLOCK USER ───────────────────────────────────────────
  Future<void> blockUser() async {
    state = state.copyWith(status: FollowStatus.loading);
    try {
      await _service.blockUser(targetUserId);
      state = state.copyWith(
        status: FollowStatus.notFollowing,
        isBlocked: true,
        // When blocking, followers count might decrease if they were following
        followersCount: state.followersCount > 0 ? state.followersCount - 1 : 0,
      );
    } catch (e) {
      state = state.copyWith(status: FollowStatus.notFollowing);
      rethrow;
    }
  }

  // ─── UNBLOCK USER ─────────────────────────────────────────
  Future<void> unblockUser() async {
    state = state.copyWith(status: FollowStatus.loading);
    try {
      await _service.unblockUser(targetUserId);
      state = state.copyWith(
        status: FollowStatus.notFollowing,
        isBlocked: false,
      );
    } catch (e) {
      state = state.copyWith(status: FollowStatus.notFollowing);
      rethrow;
    }
  }
}

// ─── FOLLOW REQUESTS STATE ──────────────────────────────────
class FollowRequestsState {
  final List<Map<String, dynamic>> requests;
  final bool isLoading;
  final String? errorMessage;
  final int pendingCount;

  const FollowRequestsState({
    this.requests = const [],
    this.isLoading = false,
    this.errorMessage,
    this.pendingCount = 0,
  });

  FollowRequestsState copyWith({
    List<Map<String, dynamic>>? requests,
    bool? isLoading,
    String? errorMessage,
    int? pendingCount,
  }) {
    return FollowRequestsState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      pendingCount: pendingCount ?? this.pendingCount,
    );
  }
}

// ─── FOLLOW REQUESTS NOTIFIER ────────────────────────────────
class FollowRequestsNotifier extends Notifier<FollowRequestsState> {
  FollowService get _service => ref.read(followServiceProvider);

  @override
  FollowRequestsState build() {
    Future.microtask(loadRequests);
    return const FollowRequestsState();
  }

  Future<void> loadRequests() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final result = await _service.getFollowRequests();
      final requests = result['requests'] as List<dynamic>;

      state = state.copyWith(
        requests: requests.cast<Map<String, dynamic>>().toList(),
        isLoading: false,
        pendingCount: requests.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> acceptRequest(String requesterId) async {
    try {
      await _service.acceptFollowRequest(requesterId);
      // Remove from list
      state = state.copyWith(
        requests: state.requests
            .where((r) => r['requester']?['id'] != requesterId)
            .toList(),
        pendingCount: state.pendingCount > 0 ? state.pendingCount - 1 : 0,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRequest(String requesterId) async {
    try {
      await _service.rejectFollowRequest(requesterId);
      state = state.copyWith(
        requests: state.requests
            .where((r) => r['requester']?['id'] != requesterId)
            .toList(),
        pendingCount: state.pendingCount > 0 ? state.pendingCount - 1 : 0,
      );
    } catch (e) {
      rethrow;
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final followServiceProvider = Provider<FollowService>((ref) {
  return FollowService();
});

// Per-user follow provider (family)
final followProvider =
    NotifierProvider.family<FollowNotifier, FollowState, String>(
  (targetUserId) => FollowNotifier()..targetUserId = targetUserId,
);

// Follow requests provider
final followRequestsProvider =
    NotifierProvider<FollowRequestsNotifier, FollowRequestsState>(
  FollowRequestsNotifier.new,
);

// Pending requests count (for badge)
final pendingRequestsCountProvider = Provider<int>((ref) {
  return ref.watch(followRequestsProvider).pendingCount;
});
