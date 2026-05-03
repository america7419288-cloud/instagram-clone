// lib/features/profile/presentation/providers/profile_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileService _service;
  final String username;
  Timer? _refreshTimer;

  ProfileNotifier(this._service, this.username) : super(const ProfileState()) {
    loadProfile();
    
    // ─── PERIODIC REFRESH ─────────────────────────────────────
    // Refresh profile every 60 seconds to keep stats updated
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && !state.isLoading) {
        refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ─── LOAD PROFILE ────────────────────────────────────────
  Future<void> loadProfile() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final profile = await _service.getUserProfile(username);
      if (!mounted) return;

      state = state.copyWith(profile: profile, isLoading: false);

      // Load posts if not private or own profile
      if (!profile.isPrivate ||
          profile.isOwnProfile ||
          (profile.isFollowing ?? false)) {
        await loadPosts(profile.id);
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ─── LOAD POSTS ──────────────────────────────────────────
  Future<void> loadPosts(String userId) async {
    if (!mounted) return;
    state = state.copyWith(isLoadingPosts: true, currentPage: 1);

    try {
      final result = await _service.getUserPosts(userId: userId, page: 1);
      if (!mounted) return;

      final posts = result['posts'] as List<ProfilePostModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        posts: posts,
        isLoadingPosts: false,
        hasMorePosts: pagination?['hasNextPage'] ?? false,
        currentPage: 1,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingPosts: false);
    }
  }

  // ─── LOAD MORE POSTS ─────────────────────────────────────
  Future<void> loadMorePosts() async {
    if (!mounted ||
        state.isLoadingMore ||
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
      if (!mounted) return;

      final newPosts = result['posts'] as List<ProfilePostModel>;
      final pagination = result['pagination'];

      state = state.copyWith(
        posts: [...state.posts, ...newPosts],
        isLoadingMore: false,
        hasMorePosts: pagination?['hasNextPage'] ?? false,
        currentPage: nextPage,
      );
    } catch (e) {
      if (!mounted) return;
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
    if (!mounted) return false;
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
      if (!mounted) return false;

      state = state.copyWith(profile: updatedProfile, isSaving: false);
      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── UPDATE PROFILE PICTURE ──────────────────────────────
  Future<bool> updateProfilePicture(File imageFile) async {
    if (!mounted) return false;
    state = state.copyWith(isSaving: true);

    try {
      final newUrl = await _service.updateProfilePicture(imageFile);
      if (!mounted) return false;

      state = state.copyWith(
        profile: state.profile?.copyWith(profilePicUrl: newUrl),
        isSaving: false,
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
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
}

// ─── PROVIDERS ──────────────────────────────────────────────
final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

// Per-username profile provider (family)
final profileProvider =
    StateNotifierProvider.family<ProfileNotifier, ProfileState, String>(
      (ref, username) =>
          ProfileNotifier(ref.watch(profileServiceProvider), username),
    );
