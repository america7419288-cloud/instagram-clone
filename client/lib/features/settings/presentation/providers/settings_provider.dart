import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/settings_model.dart';
import '../../data/repositories/settings_repository.dart';

final userSettingsProvider = NotifierProvider<UserSettingsNotifier, AsyncValue<UserSettingsModel>>(
  UserSettingsNotifier.new,
);

class UserSettingsNotifier extends Notifier<AsyncValue<UserSettingsModel>> {
  @override
  AsyncValue<UserSettingsModel> build() {
    Future.microtask(loadSettings);
    return const AsyncValue.loading();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> loadSettings() async {
    try {
      state = const AsyncValue.loading();
      final settings = await _repo.getSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePrivacy({
    bool? isPrivateAccount,
    bool? showActivityStatus,
    String? allowStoryReplies,
    String? allowTagging,
    String? allowMentions,
    bool? showSuggestedAccounts,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedPrivacy = current.privacy.copyWith(
      isPrivateAccount: isPrivateAccount,
      showActivityStatus: showActivityStatus,
      allowStoryReplies: allowStoryReplies,
      allowTagging: allowTagging,
      allowMentions: allowMentions,
      showSuggestedAccounts: showSuggestedAccounts,
    );
    final optimistic = UserSettingsModel(
      privacy: updatedPrivacy,
      comments: current.comments,
      likesAndShares: current.likesAndShares,
      notifications: current.notifications,
      timestamp: current.timestamp,
      archive: current.archive,
      saved: current.saved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updatePrivacy(updatedPrivacy.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateComments({
    String? allowComments,
    bool? filterOffensiveComments,
    bool? manualFilter,
    List<String>? filteredWords,
    bool? allowCommentLikes,
    bool? pinComments,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedComments = current.comments.copyWith(
      allowComments: allowComments,
      filterOffensiveComments: filterOffensiveComments,
      manualFilter: manualFilter,
      filteredWords: filteredWords,
      allowCommentLikes: allowCommentLikes,
      pinComments: pinComments,
    );
    final optimistic = UserSettingsModel(
      privacy: current.privacy,
      comments: updatedComments,
      likesAndShares: current.likesAndShares,
      notifications: current.notifications,
      timestamp: current.timestamp,
      archive: current.archive,
      saved: current.saved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updateComments(updatedComments.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateLikesShares({
    bool? hideLikeCount,
    bool? hideOthersLikeCount,
    String? allowSharing,
    bool? allowStorySharing,
    bool? allowReelSharing,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedLikesShares = current.likesAndShares.copyWith(
      hideLikeCount: hideLikeCount,
      hideOthersLikeCount: hideOthersLikeCount,
      allowSharing: allowSharing,
      allowStorySharing: allowStorySharing,
      allowReelSharing: allowReelSharing,
    );
    final optimistic = UserSettingsModel(
      privacy: current.privacy,
      comments: current.comments,
      likesAndShares: updatedLikesShares,
      notifications: current.notifications,
      timestamp: current.timestamp,
      archive: current.archive,
      saved: current.saved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updateLikesShares(updatedLikesShares.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateNotifications({
    bool? pushEnabled,
    String? likes,
    String? comments,
    bool? commentLikes,
    bool? newFollowers,
    bool? followRequests,
    bool? acceptedFollowRequests,
    String? mentions,
    bool? tags,
    bool? directMessages,
    bool? groupRequests,
    bool? liveVideos,
    bool? reels,
    bool? stories,
    bool? emailNotifications,
    bool? smsNotifications,
    bool? pauseAll,
    String? pauseUntil,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedNotifications = current.notifications.copyWith(
      pushEnabled: pushEnabled,
      likes: likes,
      comments: comments,
      commentLikes: commentLikes,
      newFollowers: newFollowers,
      followRequests: followRequests,
      acceptedFollowRequests: acceptedFollowRequests,
      mentions: mentions,
      tags: tags,
      directMessages: directMessages,
      groupRequests: groupRequests,
      liveVideos: liveVideos,
      reels: reels,
      stories: stories,
      emailNotifications: emailNotifications,
      smsNotifications: smsNotifications,
      pauseAll: pauseAll,
      pauseUntil: pauseUntil,
    );
    final optimistic = UserSettingsModel(
      privacy: current.privacy,
      comments: current.comments,
      likesAndShares: current.likesAndShares,
      notifications: updatedNotifications,
      timestamp: current.timestamp,
      archive: current.archive,
      saved: current.saved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updateNotifications(updatedNotifications.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateTimestamp({
    bool? showTimestamp,
    String? format,
    bool? use24HourFormat,
    bool? showSeenTimestamp,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedTimestamp = current.timestamp.copyWith(
      showTimestamp: showTimestamp,
      format: format,
      use24HourFormat: use24HourFormat,
      showSeenTimestamp: showSeenTimestamp,
    );
    final optimistic = UserSettingsModel(
      privacy: current.privacy,
      comments: current.comments,
      likesAndShares: current.likesAndShares,
      notifications: current.notifications,
      timestamp: updatedTimestamp,
      archive: current.archive,
      saved: current.saved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updateTimestamp(updatedTimestamp.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateArchiveSettings({
    bool? autoArchiveStories,
    bool? autoArchivePosts,
    bool? showArchiveInProfile,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedArchive = current.archive.copyWith(
      autoArchiveStories: autoArchiveStories,
      autoArchivePosts: autoArchivePosts,
      showArchiveInProfile: showArchiveInProfile,
    );
    final optimistic = UserSettingsModel(
      privacy: current.privacy,
      comments: current.comments,
      likesAndShares: current.likesAndShares,
      notifications: current.notifications,
      timestamp: current.timestamp,
      archive: updatedArchive,
      saved: current.saved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updateArchiveSettings(updatedArchive.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSavedSettings({
    String? defaultCollection,
    bool? showSavedCount,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedSaved = current.saved.copyWith(
      defaultCollection: defaultCollection,
      showSavedCount: showSavedCount,
    );
    final optimistic = UserSettingsModel(
      privacy: current.privacy,
      comments: current.comments,
      likesAndShares: current.likesAndShares,
      notifications: current.notifications,
      timestamp: current.timestamp,
      archive: current.archive,
      saved: updatedSaved,
    );
    state = AsyncValue.data(optimistic);

    try {
      final updated = await _repo.updateSavedSettings(updatedSaved.toJson());
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(e, st);
    }
  }
}
