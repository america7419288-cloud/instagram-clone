// lib/features/menu/models/menu_context.dart

enum MenuContentType {
  post,
  reel,
  story,
  comment,
  profile,
  message,
}

enum MenuRelationship {
  owner,         // Your own content
  following,     // Following the user
  notFollowing,  // Not following
  blocked,
  closeFriend,
}

class MenuContext {
  final String contentId;
  final MenuContentType contentType;
  final MenuRelationship relationship;
  final String? authorUsername;
  final String? authorId;
  final String? authorAvatarUrl;
  
  // State flags
  final bool isSaved;
  final bool isPinned;
  final bool isMuted;
  final bool hasLikeCount;
  final bool commentsEnabled;
  final bool isVerified;
  final bool isCloseFriendsOnly;
  
  // Permissions
  final bool canEdit;
  final bool canDelete;
  final bool canRemix;
  final bool canDownload;

  const MenuContext({
    required this.contentId,
    required this.contentType,
    required this.relationship,
    this.authorUsername,
    this.authorId,
    this.authorAvatarUrl,
    this.isSaved = false,
    this.isPinned = false,
    this.isMuted = false,
    this.hasLikeCount = true,
    this.commentsEnabled = true,
    this.isVerified = false,
    this.isCloseFriendsOnly = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canRemix = true,
    this.canDownload = false,
  });

  bool get isOwner => relationship == MenuRelationship.owner;
  bool get isFollowing =>
      relationship == MenuRelationship.following ||
      relationship == MenuRelationship.closeFriend;
}
