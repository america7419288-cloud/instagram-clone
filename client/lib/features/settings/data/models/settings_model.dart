class UserSettingsModel {
  final PrivacySettings privacy;
  final CommentSettings comments;
  final LikesSharesSettings likesAndShares;
  final NotificationSettings notifications;
  final TimestampSettings timestamp;
  final ArchiveSettings archive;
  final SavedSettings saved;

  const UserSettingsModel({
    required this.privacy,
    required this.comments,
    required this.likesAndShares,
    required this.notifications,
    required this.timestamp,
    required this.archive,
    required this.saved,
  });

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      privacy: PrivacySettings.fromJson(json['privacy'] ?? {}),
      comments: CommentSettings.fromJson(json['comments'] ?? {}),
      likesAndShares: LikesSharesSettings.fromJson(json['likesAndShares'] ?? json['likes_and_shares'] ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] ?? {}),
      timestamp: TimestampSettings.fromJson(json['timestamp'] ?? {}),
      archive: ArchiveSettings.fromJson(json['archive'] ?? {}),
      saved: SavedSettings.fromJson(json['saved'] ?? {}),
    );
  }

  factory UserSettingsModel.defaults() {
    return const UserSettingsModel(
      privacy: PrivacySettings(),
      comments: CommentSettings(),
      likesAndShares: LikesSharesSettings(),
      notifications: NotificationSettings(),
      timestamp: TimestampSettings(),
      archive: ArchiveSettings(),
      saved: SavedSettings(),
    );
  }
}

class PrivacySettings {
  final bool isPrivateAccount;
  final bool showActivityStatus;
  final String allowStoryReplies;
  final String allowTagging;
  final String allowMentions;
  final bool showSuggestedAccounts;

  const PrivacySettings({
    this.isPrivateAccount = false,
    this.showActivityStatus = true,
    this.allowStoryReplies = 'everyone',
    this.allowTagging = 'everyone',
    this.allowMentions = 'everyone',
    this.showSuggestedAccounts = true,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      isPrivateAccount: json['isPrivateAccount'] ?? false,
      showActivityStatus: json['showActivityStatus'] ?? true,
      allowStoryReplies: json['allowStoryReplies'] ?? 'everyone',
      allowTagging: json['allowTagging'] ?? 'everyone',
      allowMentions: json['allowMentions'] ?? 'everyone',
      showSuggestedAccounts: json['showSuggestedAccounts'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'isPrivateAccount': isPrivateAccount,
    'showActivityStatus': showActivityStatus,
    'allowStoryReplies': allowStoryReplies,
    'allowTagging': allowTagging,
    'allowMentions': allowMentions,
    'showSuggestedAccounts': showSuggestedAccounts,
  };

  PrivacySettings copyWith({
    bool? isPrivateAccount,
    bool? showActivityStatus,
    String? allowStoryReplies,
    String? allowTagging,
    String? allowMentions,
    bool? showSuggestedAccounts,
  }) {
    return PrivacySettings(
      isPrivateAccount: isPrivateAccount ?? this.isPrivateAccount,
      showActivityStatus: showActivityStatus ?? this.showActivityStatus,
      allowStoryReplies: allowStoryReplies ?? this.allowStoryReplies,
      allowTagging: allowTagging ?? this.allowTagging,
      allowMentions: allowMentions ?? this.allowMentions,
      showSuggestedAccounts: showSuggestedAccounts ?? this.showSuggestedAccounts,
    );
  }
}

class CommentSettings {
  final String allowComments;
  final bool filterOffensiveComments;
  final bool manualFilter;
  final List<String> filteredWords;
  final bool allowCommentLikes;
  final bool pinComments;

  const CommentSettings({
    this.allowComments = 'everyone',
    this.filterOffensiveComments = true,
    this.manualFilter = false,
    this.filteredWords = const [],
    this.allowCommentLikes = true,
    this.pinComments = true,
  });

  factory CommentSettings.fromJson(Map<String, dynamic> json) {
    return CommentSettings(
      allowComments: json['allowComments'] ?? 'everyone',
      filterOffensiveComments: json['filterOffensiveComments'] ?? true,
      manualFilter: json['manualFilter'] ?? false,
      filteredWords: List<String>.from(json['filteredWords'] ?? []),
      allowCommentLikes: json['allowCommentLikes'] ?? true,
      pinComments: json['pinComments'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'allowComments': allowComments,
    'filterOffensiveComments': filterOffensiveComments,
    'manualFilter': manualFilter,
    'filteredWords': filteredWords,
    'allowCommentLikes': allowCommentLikes,
    'pinComments': pinComments,
  };

  CommentSettings copyWith({
    String? allowComments,
    bool? filterOffensiveComments,
    bool? manualFilter,
    List<String>? filteredWords,
    bool? allowCommentLikes,
    bool? pinComments,
  }) {
    return CommentSettings(
      allowComments: allowComments ?? this.allowComments,
      filterOffensiveComments: filterOffensiveComments ?? this.filterOffensiveComments,
      manualFilter: manualFilter ?? this.manualFilter,
      filteredWords: filteredWords ?? this.filteredWords,
      allowCommentLikes: allowCommentLikes ?? this.allowCommentLikes,
      pinComments: pinComments ?? this.pinComments,
    );
  }
}

class LikesSharesSettings {
  final bool hideLikeCount;
  final bool hideOthersLikeCount;
  final String allowSharing;
  final bool allowStorySharing;
  final bool allowReelSharing;

  const LikesSharesSettings({
    this.hideLikeCount = false,
    this.hideOthersLikeCount = false,
    this.allowSharing = 'everyone',
    this.allowStorySharing = true,
    this.allowReelSharing = true,
  });

  factory LikesSharesSettings.fromJson(Map<String, dynamic> json) {
    return LikesSharesSettings(
      hideLikeCount: json['hideLikeCount'] ?? false,
      hideOthersLikeCount: json['hideOthersLikeCount'] ?? false,
      allowSharing: json['allowSharing'] ?? 'everyone',
      allowStorySharing: json['allowStorySharing'] ?? true,
      allowReelSharing: json['allowReelSharing'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'hideLikeCount': hideLikeCount,
    'hideOthersLikeCount': hideOthersLikeCount,
    'allowSharing': allowSharing,
    'allowStorySharing': allowStorySharing,
    'allowReelSharing': allowReelSharing,
  };

  LikesSharesSettings copyWith({
    bool? hideLikeCount,
    bool? hideOthersLikeCount,
    String? allowSharing,
    bool? allowStorySharing,
    bool? allowReelSharing,
  }) {
    return LikesSharesSettings(
      hideLikeCount: hideLikeCount ?? this.hideLikeCount,
      hideOthersLikeCount: hideOthersLikeCount ?? this.hideOthersLikeCount,
      allowSharing: allowSharing ?? this.allowSharing,
      allowStorySharing: allowStorySharing ?? this.allowStorySharing,
      allowReelSharing: allowReelSharing ?? this.allowReelSharing,
    );
  }
}

class NotificationSettings {
  final bool pushEnabled;
  final String likes;
  final String comments;
  final bool commentLikes;
  final bool newFollowers;
  final bool followRequests;
  final bool acceptedFollowRequests;
  final String mentions;
  final bool tags;
  final bool directMessages;
  final bool groupRequests;
  final bool liveVideos;
  final bool reels;
  final bool stories;
  final bool emailNotifications;
  final bool smsNotifications;
  final bool pauseAll;
  final String? pauseUntil;

  const NotificationSettings({
    this.pushEnabled = true,
    this.likes = 'everyone',
    this.comments = 'everyone',
    this.commentLikes = true,
    this.newFollowers = true,
    this.followRequests = true,
    this.acceptedFollowRequests = true,
    this.mentions = 'everyone',
    this.tags = true,
    this.directMessages = true,
    this.groupRequests = true,
    this.liveVideos = true,
    this.reels = true,
    this.stories = true,
    this.emailNotifications = true,
    this.smsNotifications = false,
    this.pauseAll = false,
    this.pauseUntil,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['pushEnabled'] ?? true,
      likes: json['likes'] ?? 'everyone',
      comments: json['comments'] ?? 'everyone',
      commentLikes: json['commentLikes'] ?? true,
      newFollowers: json['newFollowers'] ?? true,
      followRequests: json['followRequests'] ?? true,
      acceptedFollowRequests: json['acceptedFollowRequests'] ?? true,
      mentions: json['mentions'] ?? 'everyone',
      tags: json['tags'] ?? true,
      directMessages: json['directMessages'] ?? true,
      groupRequests: json['groupRequests'] ?? true,
      liveVideos: json['liveVideos'] ?? true,
      reels: json['reels'] ?? true,
      stories: json['stories'] ?? true,
      emailNotifications: json['emailNotifications'] ?? true,
      smsNotifications: json['smsNotifications'] ?? false,
      pauseAll: json['pauseAll'] ?? false,
      pauseUntil: json['pauseUntil'],
    );
  }

  Map<String, dynamic> toJson() => {
    'pushEnabled': pushEnabled,
    'likes': likes,
    'comments': comments,
    'commentLikes': commentLikes,
    'newFollowers': newFollowers,
    'followRequests': followRequests,
    'acceptedFollowRequests': acceptedFollowRequests,
    'mentions': mentions,
    'tags': tags,
    'directMessages': directMessages,
    'groupRequests': groupRequests,
    'liveVideos': liveVideos,
    'reels': reels,
    'stories': stories,
    'emailNotifications': emailNotifications,
    'smsNotifications': smsNotifications,
    'pauseAll': pauseAll,
    'pauseUntil': pauseUntil,
  };

  NotificationSettings copyWith({
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
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      commentLikes: commentLikes ?? this.commentLikes,
      newFollowers: newFollowers ?? this.newFollowers,
      followRequests: followRequests ?? this.followRequests,
      acceptedFollowRequests: acceptedFollowRequests ?? this.acceptedFollowRequests,
      mentions: mentions ?? this.mentions,
      tags: tags ?? this.tags,
      directMessages: directMessages ?? this.directMessages,
      groupRequests: groupRequests ?? this.groupRequests,
      liveVideos: liveVideos ?? this.liveVideos,
      reels: reels ?? this.reels,
      stories: stories ?? this.stories,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      pauseAll: pauseAll ?? this.pauseAll,
      pauseUntil: pauseUntil ?? this.pauseUntil,
    );
  }
}

class TimestampSettings {
  final bool showTimestamp;
  final String format;
  final bool use24HourFormat;
  final bool showSeenTimestamp;

  const TimestampSettings({
    this.showTimestamp = true,
    this.format = 'relative',
    this.use24HourFormat = false,
    this.showSeenTimestamp = true,
  });

  factory TimestampSettings.fromJson(Map<String, dynamic> json) {
    return TimestampSettings(
      showTimestamp: json['showTimestamp'] ?? true,
      format: json['format'] ?? 'relative',
      use24HourFormat: json['use24HourFormat'] ?? false,
      showSeenTimestamp: json['showSeenTimestamp'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'showTimestamp': showTimestamp,
    'format': format,
    'use24HourFormat': use24HourFormat,
    'showSeenTimestamp': showSeenTimestamp,
  };

  TimestampSettings copyWith({
    bool? showTimestamp,
    String? format,
    bool? use24HourFormat,
    bool? showSeenTimestamp,
  }) {
    return TimestampSettings(
      showTimestamp: showTimestamp ?? this.showTimestamp,
      format: format ?? this.format,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      showSeenTimestamp: showSeenTimestamp ?? this.showSeenTimestamp,
    );
  }
}

class ArchiveSettings {
  final bool autoArchiveStories;
  final bool autoArchivePosts;
  final bool showArchiveInProfile;

  const ArchiveSettings({
    this.autoArchiveStories = true,
    this.autoArchivePosts = false,
    this.showArchiveInProfile = false,
  });

  factory ArchiveSettings.fromJson(Map<String, dynamic> json) {
    return ArchiveSettings(
      autoArchiveStories: json['autoArchiveStories'] ?? true,
      autoArchivePosts: json['autoArchivePosts'] ?? false,
      showArchiveInProfile: json['showArchiveInProfile'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'autoArchiveStories': autoArchiveStories,
    'autoArchivePosts': autoArchivePosts,
    'showArchiveInProfile': showArchiveInProfile,
  };

  ArchiveSettings copyWith({
    bool? autoArchiveStories,
    bool? autoArchivePosts,
    bool? showArchiveInProfile,
  }) {
    return ArchiveSettings(
      autoArchiveStories: autoArchiveStories ?? this.autoArchiveStories,
      autoArchivePosts: autoArchivePosts ?? this.autoArchivePosts,
      showArchiveInProfile: showArchiveInProfile ?? this.showArchiveInProfile,
    );
  }
}

class SavedSettings {
  final String defaultCollection;
  final bool showSavedCount;

  const SavedSettings({
    this.defaultCollection = 'All Posts',
    this.showSavedCount = false,
  });

  factory SavedSettings.fromJson(Map<String, dynamic> json) {
    return SavedSettings(
      defaultCollection: json['defaultCollection'] ?? 'All Posts',
      showSavedCount: json['showSavedCount'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'defaultCollection': defaultCollection,
    'showSavedCount': showSavedCount,
  };

  SavedSettings copyWith({
    String? defaultCollection,
    bool? showSavedCount,
  }) {
    return SavedSettings(
      defaultCollection: defaultCollection ?? this.defaultCollection,
      showSavedCount: showSavedCount ?? this.showSavedCount,
    );
  }
}
