class Conversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isOnline;
  final String? lastActive;

  const Conversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.isOnline = false,
    this.lastActive,
  });

  static Conversation mock() {
    return const Conversation(
      id: 'conv1',
      otherUserId: 'other',
      otherUserName: 'johndoe',
      otherUserAvatar: 'https://i.pravatar.cc/150?img=1',
      isOnline: true,
      lastActive: 'Active now',
    );
  }
}
