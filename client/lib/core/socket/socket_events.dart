class SocketEvents {
  // Emitters
  static const String joinRoom = 'join-room';
  static const String leaveRoom = 'leave-room';
  static const String sendMessage = 'send-message';
  static const String typing = 'typing';
  static const String stopTyping = 'stop-typing';
  static const String messageRead = 'message-read';
  static const String checkOnline = 'check-online';

  // Listeners
  static const String newMessage = 'new-message';
  static const String userTyping = 'user-typing';
  static const String onlineUsers = 'online-users';
  static const String userOnline = 'user-online';
  static const String userOffline = 'user-offline';
  static const String onlineStatus = 'online-status';
  static const String inboxUpdate = 'inbox-update';
  static const String joinedRoom = 'joined-room';
  static const String messagesRead = 'messages-read';
  static const String messageDeleted = 'message-deleted';
  static const String messageReacted = 'message-reacted';
  static const String error = 'error';
}

class SocketKeys {
  static const String conversationId = 'conversation_id';
  static const String userId = 'user_id';
  static const String message = 'message';
  static const String isTyping = 'is_typing';
  static const String onlineUserIds = 'online_user_ids';
  static const String timestamp = 'timestamp';
  static const String error = 'error';
}
