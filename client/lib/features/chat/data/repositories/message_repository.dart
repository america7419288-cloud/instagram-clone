import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../../core/api/chat_api.dart';
import '../../../../core/socket/socket_service.dart';
import '../../../../core/storage/chat_local_db.dart';
import '../models/message.dart';
import '../models/conversation.dart';

class MessageRepository {
  final ChatApi _api;
  final SocketService _socket;
  final ChatLocalDb _localDb;
  final _uuid = const Uuid();

  MessageRepository({
    required ChatApi api,
    required SocketService socket,
    required ChatLocalDb localDb,
  }) : _api = api,
       _socket = socket,
       _localDb = localDb;

  // Stream of socket events related to messages
  Stream<Map<String, dynamic>> get onMessageEvent => _socket.messageStream;

  Future<List<Conversation>> getConversations() async {
    try {
      final conversations = await _api.getConversations();
      await _localDb.saveConversations(conversations);
      return conversations;
    } catch (e) {
      // Fallback to local cache
      return _localDb.getConversations();
    }
  }

  Future<List<Message>> getMessages(
    String conversationId, {
    String? before,
  }) async {
    try {
      final cachedMessages = _localDb.getMessages(conversationId);
      final messages = await _api.getMessages(conversationId, before: before);
      if (before == null && messages.isEmpty && cachedMessages.isNotEmpty) {
        return cachedMessages;
      }

      if (before == null) {
        await _localDb.replaceMessages(conversationId, messages);
      } else {
        await _localDb.saveMessages(messages);
      }
      return messages;
    } catch (e) {
      return _localDb.getMessages(conversationId);
    }
  }

  List<Message> getCachedMessages(String conversationId) {
    return _localDb.getMessages(conversationId);
  }

  Future<void> saveMessage(Message message) async {
    await _localDb.saveMessage(message);
  }

  Future<Message> sendMessage(
    String conversationId,
    String content,
    String senderId, {
    String messageType = 'text',
    String? mediaPath,
    String? postId,
    String? replyToId,
    String? tempId,
    String? sharedUsername,
    String? sharedCaption,
    String? sharedThumbnailUrl,
  }) async {
    final effectiveTempId = tempId ?? _uuid.v4();
    final optimisticMessage = Message(
      id: effectiveTempId,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: DateTime.now(),
      isSending: true,
      tempId: effectiveTempId,
      replyToId: replyToId,
      messageType: messageType,
      localPath: mediaPath, // for local preview while uploading
      postId: messageType == 'post' ? postId : null,
      reelId: messageType == 'reel' ? postId : null,
      storyId: messageType == 'story' ? postId : null,
      sharedUsername: sharedUsername,
      sharedCaption: sharedCaption,
      sharedThumbnailUrl: sharedThumbnailUrl,
    );

    // Save to local DB immediately for UI update
    await _localDb.saveMessage(optimisticMessage);

    try {
      final message = await _api.sendMessage(
        conversationId,
        content,
        tempId: effectiveTempId,
        messageType: messageType,
        mediaPath: mediaPath,
        postId: postId,
        replyToId: replyToId,
      );

      // Remove optimistic and save real
      await _localDb.deleteMessage(effectiveTempId);
      await _localDb.saveMessage(message);

      return message;
    } catch (e) {
      final errorMessage = optimisticMessage.copyWith(
        isSending: false,
        hasError: true,
      );
      await _localDb.saveMessage(errorMessage);
      rethrow;
    }
  }

  void joinConversation(String conversationId) =>
      _socket.joinRoom(conversationId);
  void leaveConversation(String conversationId) =>
      _socket.leaveRoom(conversationId);
  void setTyping(String conversationId, bool isTyping) =>
      _socket.setTyping(conversationId, isTyping);

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _api.deleteMessage(conversationId, messageId);
    await _localDb.deleteMessage(messageId);
  }

  Future<void> deleteLocalMessage(String messageId) async {
    await _localDb.deleteMessage(messageId);
  }

  Future<void> addReaction(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    await _api.addReaction(conversationId, messageId, emoji);
    final message = _localDb.getMessage(messageId);
    if (message != null) {
      final updatedReactions = Map<String, int>.from(message.reactions ?? {});
      updatedReactions[emoji] = (updatedReactions[emoji] ?? 0) + 1;
      await _localDb.saveMessage(message.copyWith(reactions: updatedReactions));
    }
  }

  Future<void> markAsRead(String conversationId) async {
    await _api.markAsRead(conversationId);
    final conv = _localDb.getConversation(conversationId);
    if (conv != null) {
      await _localDb.saveConversation(conv.copyWith(unreadCount: 0));
    }
  }

  Future<Conversation> createConversation(String participantId) async {
    final conversation = await _api.createConversation(participantId);
    await _localDb.saveConversation(conversation);
    return conversation;
  }

  Future<Message> editMessage(String conversationId, String messageId, String content) async {
    final message = await _api.editMessage(conversationId, messageId, content);
    await _localDb.saveMessage(message);
    return message;
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  }) async {
    final conversation = await _api.createGroupConversation(
      name: name,
      participantIds: participantIds,
      avatarUrl: avatarUrl,
    );
    await _localDb.saveConversation(conversation);
    return conversation;
  }

  Future<void> setDisappearingMessages(String conversationId, int? durationSeconds) async {
    await _api.setDisappearingMessages(conversationId, durationSeconds);
    final conv = _localDb.getConversation(conversationId);
    if (conv != null) {
      await _localDb.saveConversation(conv.copyWith(disappearingDuration: durationSeconds));
    }
  }

  Future<List<Message>> searchMessages(String conversationId, String query) async {
    return await _api.searchMessages(conversationId, query);
  }

  Future<void> clearLocalCache() async {
    await _localDb.clearAll();
  }
}
