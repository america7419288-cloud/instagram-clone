import 'package:dio/dio.dart';
import '../../features/chat/data/models/message.dart';
import '../../features/chat/data/models/conversation.dart';

class ChatApi {
  final Dio _dio;

  ChatApi(this._dio);

  Future<List<Conversation>> getConversations() async {
    final response = await _dio.get('/conversations');
    return (response.data['data'] as List)
        .map((json) => Conversation.fromJson(json))
        .where((c) => c.id.isNotEmpty)  // guard against empty IDs from failed prior calls
        .toList();
  }

  Future<List<Message>> getMessages(String conversationId, {int? limit, String? before}) async {
    final response = await _dio.get(
      '/conversations/$conversationId/messages',
      queryParameters: {
        if (limit != null) 'limit': limit,
        if (before != null) 'before': before,
      },
    );
    return (response.data['data'] as List)
        .map((json) => Message.fromJson(json))
        .toList();
  }

  Future<Message> sendMessage(
    String conversationId,
    String content, {
    String? tempId,
    String messageType = 'text',
    String? mediaPath,
    String? postId,
    String? replyToId,
  }) async {
    dynamic data;
    if (mediaPath != null) {
      final formData = FormData.fromMap({
        'content': content,
        'message_type': messageType,
        if (tempId != null) 'temp_id': tempId,
        if (postId != null) 'shared_post_id': postId,
        if (replyToId != null) 'reply_to_message_id': replyToId,
      });

      formData.files.add(MapEntry(
        'media',
        await MultipartFile.fromFile(mediaPath),
      ));
      data = formData;
    } else {
      data = {
        'content': content,
        'message_type': messageType,
        if (tempId != null) 'temp_id': tempId,
        if (postId != null) 'shared_post_id': postId,
        if (replyToId != null) 'reply_to_message_id': replyToId,
      };
    }

    final response = await _dio.post(
      '/conversations/$conversationId/messages',
      data: data,
    );
    return Message.fromJson(response.data['data']['message']);
  }

  Future<void> markAsRead(String conversationId) async {
    await _dio.put('/conversations/$conversationId/read');
  }

  Future<Conversation> createConversation(String participantId) async {
    final response = await _dio.post(
      '/conversations',
      data: {'user_id': participantId},
    );
    return Conversation.fromJson(response.data['data']['conversation']);
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _dio.delete('/conversations/$conversationId/messages/$messageId');
  }

  Future<void> addReaction(String conversationId, String messageId, String emoji) async {
    await _dio.post(
      '/conversations/$conversationId/messages/$messageId/react',
      data: {'emoji': emoji},
    );
  }

  Future<Message> editMessage(String conversationId, String messageId, String content) async {
    final response = await _dio.put(
      '/conversations/$conversationId/messages/$messageId',
      data: {'content': content},
    );
    return Message.fromJson(response.data['data']['message']);
  }

  Future<Conversation> createGroupConversation({
    required String name,
    required List<String> participantIds,
    String? avatarUrl,
  }) async {
    final response = await _dio.post(
      '/conversations/group',
      data: {
        'name': name,
        'participant_ids': participantIds,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
    );
    return Conversation.fromJson(response.data['data']['conversation']);
  }

  Future<void> setDisappearingMessages(String conversationId, int? durationSeconds) async {
    await _dio.put(
      '/conversations/$conversationId/disappearing',
      data: {'duration': durationSeconds},
    );
  }

  Future<List<Message>> searchMessages(String conversationId, String query) async {
    final response = await _dio.get(
      '/conversations/$conversationId/search',
      queryParameters: {'query': query},
    );
    return (response.data['data']['results'] as List)
        .map((json) => Message.fromJson(json))
        .toList();
  }
}
