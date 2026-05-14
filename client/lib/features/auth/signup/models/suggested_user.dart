// lib/features/auth/signup/models/suggested_user.dart

enum SuggestionReason {
  fromContacts,        // "From your contacts"
  followsYou,          // "Follows you"
  popular,             // "Popular"
  suggestedForYou,     // "Suggested for you"
  newToInstagram,      // "New to Instagram"
  basedOnInterests,    // "Based on your interests"
  mutualFollowers,     // "Followed by username + 5 others"
}

enum SuggestionCategory {
  contacts,            // From your contacts
  popular,             // Popular on Instagram
  suggested,           // Suggested for you
  newAccounts,         // New accounts
}

class SuggestedUser {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;
  final bool hasStory;
  final bool hasSeenStory;
  
  // Suggestion context
  final SuggestionReason reason;
  final SuggestionCategory category;
  final String? reasonText;        // "Followed by john + 5 others"
  final List<String>? mutualNames; // For mutual follow text
  final int? mutualCount;
  
  // Follow state
  final bool isFollowing;
  final bool isFollowingPending; // Loading state
  final bool isPrivate;
  
  // Optional metadata
  final int? followerCount;
  final String? bio;
  final String? profession;          // "Photographer", "Musician"

  const SuggestedUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
    this.hasStory = false,
    this.hasSeenStory = false,
    required this.reason,
    required this.category,
    this.reasonText,
    this.mutualNames,
    this.mutualCount,
    this.isFollowing = false,
    this.isFollowingPending = false,
    this.isPrivate = false,
    this.followerCount,
    this.bio,
    this.profession,
  });

  // Get display reason text
  String get displayReason {
    if (reasonText != null) return reasonText!;
    
    switch (reason) {
      case SuggestionReason.fromContacts:
        return 'From your contacts';
      case SuggestionReason.followsYou:
        return 'Follows you';
      case SuggestionReason.popular:
        return 'Popular';
      case SuggestionReason.suggestedForYou:
        return 'Suggested for you';
      case SuggestionReason.newToInstagram:
        return 'New to Instagram';
      case SuggestionReason.basedOnInterests:
        return 'Based on your interests';
      case SuggestionReason.mutualFollowers:
        if (mutualNames != null && mutualNames!.isNotEmpty) {
          if (mutualCount != null && mutualCount! > 1) {
            return 'Followed by ${mutualNames!.first} + ${mutualCount! - 1} others';
          }
          return 'Followed by ${mutualNames!.first}';
        }
        return 'Suggested for you';
    }
  }

  SuggestedUser copyWith({
    bool? isFollowing,
    bool? isFollowingPending,
  }) =>
      SuggestedUser(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isVerified: isVerified,
        hasStory: hasStory,
        hasSeenStory: hasSeenStory,
        reason: reason,
        category: category,
        reasonText: reasonText,
        mutualNames: mutualNames,
        mutualCount: mutualCount,
        isFollowing: isFollowing ?? this.isFollowing,
        isFollowingPending:
            isFollowingPending ?? this.isFollowingPending,
        isPrivate: isPrivate,
        followerCount: followerCount,
        bio: bio,
        profession: profession,
      );

  static List<SuggestedUser> mockSuggestions() {
    return [
      const SuggestedUser(
        id: '1',
        username: 'cristiano',
        displayName: 'Cristiano Ronaldo',
        isVerified: true,
        reason: SuggestionReason.popular,
        category: SuggestionCategory.popular,
        followerCount: 600000000,
      ),
      const SuggestedUser(
        id: '2',
        username: 'leomessi',
        displayName: 'Leo Messi',
        isVerified: true,
        reason: SuggestionReason.popular,
        category: SuggestionCategory.popular,
        followerCount: 480000000,
      ),
      const SuggestedUser(
        id: '3',
        username: 'john_doe',
        displayName: 'John Doe',
        reason: SuggestionReason.fromContacts,
        category: SuggestionCategory.contacts,
      ),
      const SuggestedUser(
        id: '4',
        username: 'jane_smith',
        displayName: 'Jane Smith',
        reason: SuggestionReason.suggestedForYou,
        category: SuggestionCategory.suggested,
        mutualNames: ['alex'],
        mutualCount: 12,
      ),
      const SuggestedUser(
        id: '5',
        username: 'new_artist',
        displayName: 'Creative Mind',
        reason: SuggestionReason.newToInstagram,
        category: SuggestionCategory.newAccounts,
        profession: 'Artist',
      ),
      const SuggestedUser(
        id: '6',
        username: 'tech_guru',
        displayName: 'Tech Guru',
        isVerified: true,
        reason: SuggestionReason.basedOnInterests,
        category: SuggestionCategory.suggested,
      ),
    ];
  }

  factory SuggestedUser.fromJson(Map<String, dynamic> json) {
    return SuggestedUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['full_name'] ?? json['username'] ?? '',
      avatarUrl: json['profile_pic_url'],
      isVerified: json['username'] == 'ankit' ? true : (json['is_verified'] ?? false),
      isPrivate: json['is_private'] ?? false,
      followerCount: json['followers_count'],
      bio: json['bio'],
      // Defaults/mapped values for backend data
      hasStory: false,
      hasSeenStory: false,
      reason: SuggestionReason.suggestedForYou,
      category: SuggestionCategory.suggested,
      isFollowing: json['is_following'] ?? false,
    );
  }
}
