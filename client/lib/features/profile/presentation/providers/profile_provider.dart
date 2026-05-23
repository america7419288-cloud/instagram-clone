import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/repositories/profile_service.dart';

// ─── PROFILE STATE ──────────────────────────────────────────
class ProfileState {
  final ProfileModel? profile;
  final List<ProfilePostModel> posts;
  final bool isLoading;
  final bool isLoadingPosts;
  final bool isLoadingMore;
  final bool hasMorePosts;
  final int currentPage;
  final String? errorMessage;
  final bool isSaving; // For edit profile

  const ProfileState({
    this.profile,
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingPosts = false,
    this.isLoadingMore = false,
    this.hasMorePosts = true,
    this.currentPage = 1,
    this.errorMessage,
    this.isSaving = false,
  });

  ProfileState copyWith({
    ProfileModel? profile,
    List<ProfilePostModel>? posts,
    bool? isLoading,
    bool? isLoadingPosts,
    bool? isLoadingMore,
    bool? hasMorePosts,
    int? currentPage,
    String? errorMessage,
    bool? isSaving,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingPosts: isLoadingPosts ?? this.isLoadingPosts,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMorePosts: hasMorePosts ?? this.hasMorePosts,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: errorMessage,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

// ─── PROFILE NOTIFIER ────────────────────────────────────────
class ProfileNotifier extends Notifier<ProfileState> {
  late ProfileService _service;
  late String username;

  @override
  ProfileState build() {
    _service = ref.watch(profileServiceProvider);
    
    // Initial load
    Future.microtask(() => loadProfile());

    return const ProfileState();
  }

  // ─── LOAD PROFILE ────────────────────────────────────────
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final profile = await _service.getUserProfile(username);
      
      state = state.copyWith(profile: profile, isLoading: false);

      // Load posts if not private or own profile
      if (!profile.isPrivate ||
          profile.isOwnProfile ||
          (profile.isFollowing ?? false)) {
        await loadPosts(profile.id);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LOAD POSTS ──────────────────────────────────────────
  Future<void> loadPosts(String userId) async {
    state = state.copyWith(isLoadingPosts: true, currentPage: 1);

    try {
      final result = await _service.getUserPosts(userId: userId, page: 1);
      
      final posts = result['posts'] as List<ProfilePostModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        posts: posts,
        isLoadingPosts: false,
        hasMorePosts: pagination?['hasNextPage'] ?? false,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(isLoadingPosts: false);
    }
  }

  // ─── LOAD MORE POSTS ─────────────────────────────────────
  Future<void> loadMorePosts() async {
    if (state.isLoadingMore ||
        !state.hasMorePosts ||
        state.profile == null)
      return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final result = await _service.getUserPosts(
        userId: state.profile!.id,
        page: nextPage,
      );
      
      final newPosts = result['posts'] as List<ProfilePostModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        posts: [...state.posts, ...newPosts],
        isLoadingMore: false,
        hasMorePosts: pagination?['hasNextPage'] ?? false,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ─── REFRESH PROFILE ─────────────────────────────────────
  Future<void> refresh() async {
    await loadProfile();
  }

  // ─── UPDATE PROFILE ──────────────────────────────────────
  Future<bool> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? website,
    String? gender,
    bool? isPrivate,
  }) async {
    state = state.copyWith(isSaving: true, errorMessage: null);

    try {
      final updatedProfile = await _service.updateProfile(
        fullName: fullName,
        username: username,
        bio: bio,
        website: website,
        gender: gender,
        isPrivate: isPrivate,
      );
      
      state = state.copyWith(profile: updatedProfile, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── UPDATE PROFILE PICTURE ──────────────────────────────
  Future<bool> updateProfilePicture(XFile imageFile) async {
    state = state.copyWith(isSaving: true);

    try {
      final newUrl = await _service.updateProfilePicture(imageFile);
      
      state = state.copyWith(
        profile: state.profile?.copyWith(profilePicUrl: newUrl),
        isSaving: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── UPDATE FOLLOWER COUNT (after follow/unfollow) ───────
  void updateFollowerCount(int delta) {
    if (state.profile == null) return;
    state = state.copyWith(
      profile: state.profile!.copyWith(
        followersCount: state.profile!.followersCount + delta,
      ),
    );
  }

  // ─── REMOVE POST FROM STATE ──────────────────────────────
  void removePost(String postId) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
      profile: state.profile?.copyWith(
        postCount: (state.profile!.postCount - 1).clamp(0, 1 << 31),
      ),
    );
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Per-username profile provider (family)
final profileProvider =
    NotifierProvider.family<ProfileNotifier, ProfileState, String>(
  (username) => ProfileNotifier()..username = username,
);


