// lib/features/post/data/repositories/comment_service.dart

import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/comment_model.dart';

class CommentService {
  final DioClient _dioClient = DioClient();

  // ─── GET COMMENTS FOR A POST ─────────────────────────────
  Future<Map<String, dynamic>> getComments({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.get(
        '/posts/$postId/comments',
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = response.data;
      final comments = (data['data'] as List<dynamic>? ?? [])
          .map((c) => CommentModel.fromJson(c))
          .toList();

      return {
        'comments': comments,
        'pagination': data['pagination'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ADD COMMENT ─────────────────────────────────────────
  Future<CommentModel> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await _dioClient.post(
        '/posts/$postId/comments',
        data: {'content': content},
      );

      return CommentModel.fromJson(
        response.data['data']['comment'],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── REPLY TO COMMENT ────────────────────────────────────
  Future<CommentModel> replyToComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final response = await _dioClient.post(
        '/comments/$commentId/reply',
        data: {'content': content},
      );

      return CommentModel.fromJson(
        response.data['data']['reply'],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET REPLIES ─────────────────────────────────────────
  Future<List<CommentModel>> getReplies({
    required String commentId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        '/comments/$commentId/replies',
        queryParameters: {'page': page, 'limit': limit},
      );

      return (response.data['data'] as List<dynamic>? ?? [])
          .map((c) => CommentModel.fromJson(c))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── LIKE COMMENT ────────────────────────────────────────
  Future<void> likeComment(String commentId) async {
    try {
      await _dioClient.post('/comments/$commentId/like');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UNLIKE COMMENT ──────────────────────────────────────
  Future<void> unlikeComment(String commentId) async {
    try {
      await _dioClient.delete('/comments/$commentId/like');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── DELETE COMMENT ──────────────────────────────────────
  Future<void> deleteComment(String commentId) async {
    try {
      await _dioClient.delete('/comments/$commentId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET POST LIKERS ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPostLikers({
    required String postId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.get(
        '/posts/$postId/likes',
        queryParameters: {'page': page, 'limit': limit},
      );

      return List<Map<String, dynamic>>.from(
        response.data['data'] ?? [],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message = e.response?.data?['message']
        ?? 'Something went wrong';
    return Exception(message);
  }
}