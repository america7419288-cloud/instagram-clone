// lib/features/messages/data/repositories/message_service.dart

import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class MessageService {
  final DioClient _dioClient = DioClient();

  // ─── CREATE OR GET DM ────────────────────────────────────
  Future<ConversationModel> createOrGetConversation(
    String targetUserId,
  ) async {
    try {
      final response = await _dioClient.post(
        '/conversations/',
        data: {'user_id': targetUserId},
      );
      return ConversationModel.fromJson(
        response.data['data']['conversation'],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET INBOX ───────────────────────────────────────────
  Future<List<ConversationModel>> getInbox({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.get(
        '/conversations/',
        queryParameters: {'page': page, 'limit': limit},
      );

      // Backend returns: { success: true, message: '...', data: [...], pagination: {...} }
      final List<dynamic> data = response.data['data'] as List<dynamic>? ?? [];
      
      return data
          .map((c) => ConversationModel.fromJson(
                c as Map<String, dynamic>,
              ))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET MESSAGES ────────────────────────────────────────
  Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _dioClient.get(
        '/conversations/$conversationId/messages',
        queryParameters: {'page': page, 'limit': limit},
      );

      // Backend returns: { success: true, data: [...], pagination: {...} }
      final List<dynamic> messagesData = response.data['data'] as List<dynamic>? ?? [];
      final messages = messagesData
          .map((m) => MessageModel.fromJson(
                m as Map<String, dynamic>,
              ))
          .toList();

      return {
        'messages': messages,
        'pagination': response.data['pagination'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── SEND MESSAGE ────────────────────────────────────────
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String content,
    String messageType = 'text',
    String? replyToMessageId,
  }) async {
    try {
      final response = await _dioClient.post(
        '/conversations/$conversationId/messages',
        data: {
          'content': content,
          'message_type': messageType,
          if (replyToMessageId != null)
            'reply_to_message_id': replyToMessageId,
        },
      );
      return MessageModel.fromJson(
        response.data['data']['message'],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UNSEND MESSAGE ──────────────────────────────────────
  Future<void> deleteMessage(String messageId) async {
    try {
      await _dioClient.delete('/messages/$messageId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── MARK AS READ ────────────────────────────────────────
  Future<void> markAsRead(String conversationId) async {
    try {
      await _dioClient.put(
        '/conversations/$conversationId/read',
      );
    } on DioException catch (_) {
      // Silent fail - not critical
    }
  }

  // ─── GET UNREAD COUNT ────────────────────────────────────
  Future<int> getUnreadCount() async {
    try {
      final response = await _dioClient.get(
        '/conversations/unread-count',
      );
      return response.data['data']['unread_count'] as int? ?? 0;
    } on DioException catch (_) {
      return 0;
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}

