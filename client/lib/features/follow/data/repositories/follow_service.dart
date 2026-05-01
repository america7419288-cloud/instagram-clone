// lib/features/follow/data/repositories/follow_service.dart

import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';

class FollowService {
  final DioClient _dioClient = DioClient();

  // ─── FOLLOW USER ─────────────────────────────────────────
  Future<Map<String, dynamic>> followUser(String userId) async {
    try {
      final response = await _dioClient.post(
        '/users/$userId/follow',
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UNFOLLOW USER ───────────────────────────────────────
  Future<void> unfollowUser(String userId) async {
    try {
      await _dioClient.delete('/users/$userId/follow');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── CANCEL FOLLOW REQUEST ───────────────────────────────
  Future<void> cancelFollowRequest(String userId) async {
    try {
      await _dioClient.delete('/users/$userId/follow/cancel');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ACCEPT FOLLOW REQUEST ───────────────────────────────
  Future<void> acceptFollowRequest(String userId) async {
    try {
      await _dioClient.post('/users/$userId/follow/accept');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── REJECT FOLLOW REQUEST ───────────────────────────────
  Future<void> rejectFollowRequest(String userId) async {
    try {
      await _dioClient.post('/users/$userId/follow/reject');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── REMOVE FOLLOWER ─────────────────────────────────────
  Future<void> removeFollower(String userId) async {
    try {
      await _dioClient.delete('/users/$userId/follower');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET FOLLOWERS ───────────────────────────────────────
  Future<Map<String, dynamic>> getFollowers({
    required String userId,
    int page = 1,
    int limit = 20,
    String? query,
  }) async {
    try {
      final response = await _dioClient.get(
        '/users/$userId/followers',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      );

      return {
        'users': response.data['data'] as List<dynamic>,
        'pagination': response.data['pagination'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET FOLLOWING ───────────────────────────────────────
  Future<Map<String, dynamic>> getFollowing({
    required String userId,
    int page = 1,
    int limit = 20,
    String? query,
  }) async {
    try {
      final response = await _dioClient.get(
        '/users/$userId/following',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (query != null && query.isNotEmpty) 'q': query,
        },
      );

      return {
        'users': response.data['data'] as List<dynamic>,
        'pagination': response.data['pagination'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET FOLLOW REQUESTS ─────────────────────────────────
  Future<Map<String, dynamic>> getFollowRequests({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.get(
        '/users/follow-requests',
        queryParameters: {'page': page, 'limit': limit},
      );

      return {
        'requests': response.data['data'] as List<dynamic>,
        'pagination': response.data['pagination'],
      };
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET FOLLOW STATUS ───────────────────────────────────
  Future<Map<String, dynamic>> getFollowStatus(
    String userId,
  ) async {
    try {
      final response = await _dioClient.get(
        '/users/$userId/follow-status',
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET SUGGESTIONS ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getSuggestions({
    int limit = 10,
  }) async {
    try {
      final response = await _dioClient.get(
        '/users/suggestions',
        queryParameters: {'limit': limit},
      );
      return List<Map<String, dynamic>>.from(
        response.data['data']['users'] ?? [],
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}