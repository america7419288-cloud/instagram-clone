// lib/features/post/data/repositories/post_service.dart

import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/post_model.dart';

class PostService {
  final DioClient _dioClient = DioClient();

  // ─── GET FEED ────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeed({int page = 1, int limit = 12}) async {
    try {
      final response = await _dioClient.get(
        AppConstants.feedEndpoint,
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = response.data as Map<String, dynamic>;
      final responseData = data['data'];

      if (responseData is Map<String, dynamic> &&
          responseData['is_empty_feed'] == true) {
        return {
          'posts': <PostModel>[],
          'pagination': responseData['pagination'],
          'is_empty_feed': true,
        };
      }

      final posts = (responseData as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PostModel.fromJson)
          .toList();

      return {
        'posts': posts,
        'pagination': data['pagination'],
        'is_empty_feed': false,
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── LIKE POST ───────────────────────────────────────────
  Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      final response = await _dioClient.post(
        '${AppConstants.postsEndpoint}/$postId/like',
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UNLIKE POST ─────────────────────────────────────────
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    try {
      final response = await _dioClient.delete(
        '${AppConstants.postsEndpoint}/$postId/like',
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── SAVE POST ───────────────────────────────────────────
  Future<void> savePost(String postId) async {
    try {
      await _dioClient.post('${AppConstants.postsEndpoint}/$postId/save');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UNSAVE POST ─────────────────────────────────────────
  Future<void> unsavePost(String postId) async {
    try {
      await _dioClient.delete('${AppConstants.postsEndpoint}/$postId/save');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET SINGLE POST ─────────────────────────────────────
  Future<PostModel> getPost(String postId) async {
    try {
      final response = await _dioClient.get(
        '${AppConstants.postsEndpoint}/$postId',
      );
      return PostModel.fromJson(response.data['data']['post']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message = e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}
