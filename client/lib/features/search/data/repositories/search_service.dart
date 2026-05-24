// lib/features/search/data/repositories/search_service.dart

import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class SearchService {
  final DioClient _dioClient = DioClient();

  // ─── SEARCH USERS ────────────────────────────────────────
  Future<Map<String, dynamic>> searchUsers({
    required String query,
    int page = 1,
    int limit = 20,
    String? excludeConversationId,
  }) async {
    try {
      final response = await _dioClient.get(
        '/users/search',
        queryParameters: {
          'q': query,
          'page': page,
          'limit': limit,
          if (excludeConversationId != null) 'exclude_conversation_id': excludeConversationId,
        },
      );

      return {
        'users': response.data['data']['users'] as List<dynamic>,
        'pagination': response.data['data']['pagination'],
        'query': query,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET EXPLORE POSTS ───────────────────────────────────
  Future<Map<String, dynamic>> getExplorePosts({
    int page = 1,
    int limit = 24,
  }) async {
    try {
      final response = await _dioClient.get(
        '/posts/explore',
        queryParameters: {'page': page, 'limit': limit},
      );

      return {
        'posts': response.data['data']['posts'] as List<dynamic>,
        'page': page,
        'has_next': response.data['data']['has_next'] ?? false,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET HASHTAG POSTS ───────────────────────────────────
  Future<Map<String, dynamic>> getHashtagPosts({
    required String tag,
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final response = await _dioClient.get(
        '/posts/hashtag/$tag',
        queryParameters: {'page': page, 'limit': limit},
      );

      return {
        'posts': response.data['data']['posts'] as List<dynamic>,
        'hashtag': response.data['data']['hashtag'],
        'post_count': response.data['data']['post_count'] ?? 0,
        'has_next': response.data['data']['has_next'] ?? false,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET SUGGESTIONS ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSuggestions() async {
    try {
      final response = await _dioClient.get('/users/suggestions');
      return List<Map<String, dynamic>>.from(
        response.data['data']['users'] ?? [],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}
