// lib/features/post/data/repositories/post_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/post_model.dart';

class PostService {
  final DioClient _dioClient = DioClient();

  // ─── GET FEED ────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeed({
    int page = 1,
    int limit = 12,
  }) async {
    try {
      final response = await _dioClient.get(
        AppConstants.feedEndpoint,
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = response.data;

      // Handle empty feed
      if (data['data'] is Map &&
          data['data']['is_empty_feed'] == true) {
        return {
          'posts': <PostModel>[],
          'pagination': data['data']['pagination'],
          'is_empty_feed': true,
        };
      }

      final posts = (data['data'] as List<dynamic>? ?? [])
          .map((p) => PostModel.fromJson(p))
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

  // ─── CREATE POST ─────────────────────────────────────────
  // Upload multiple images + caption to backend
  Future<PostModel> createPost({
    required List<File> imageFiles,
    String? caption,
    String? location,
    bool commentsDisabled = false,
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      // Build form data with multiple files
      final formData = FormData();

      // Add each image file
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        final fileName = 'image_$i.jpg';

        formData.files.add(
          MapEntry(
            'media', // Must match backend field name
            await MultipartFile.fromFile(
              file.path,
              filename: fileName,
              contentType: MediaType('image', 'jpeg'),
            ),
          ),
        );
      }

      // Add text fields
      if (caption != null && caption.isNotEmpty) {
        formData.fields.add(MapEntry('caption', caption));
      }
      if (location != null && location.isNotEmpty) {
        formData.fields.add(MapEntry('location', location));
      }
      formData.fields.add(
        MapEntry('comments_disabled', commentsDisabled.toString()),
      );

      // Upload with progress tracking
      final response = await _dioClient.uploadFile(
        AppConstants.postsEndpoint,
        formData,
        onSendProgress: onSendProgress,
      );

      final data = response.data['data'];
      final postMap = (data is Map && data.containsKey('post')) ? data['post'] : data;
      return PostModel.fromJson(postMap);
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
      await _dioClient.post(
        '${AppConstants.postsEndpoint}/$postId/save',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UNSAVE POST ─────────────────────────────────────────
  Future<void> unsavePost(String postId) async {
    try {
      await _dioClient.delete(
        '${AppConstants.postsEndpoint}/$postId/save',
      );
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
      final data = response.data['data'];
      final postMap = (data is Map && data.containsKey('post')) ? data['post'] : data;
      return PostModel.fromJson(postMap);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── UPDATE POST ─────────────────────────────────────────
  Future<PostModel> updatePost({
    required String postId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dioClient.patch(
        '${AppConstants.postsEndpoint}/$postId',
        data: data,
      );
      final responseData = response.data['data'];
      final postMap = (responseData is Map && responseData.containsKey('post')) 
          ? responseData['post'] 
          : responseData;
      return PostModel.fromJson(postMap);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── DELETE POST ─────────────────────────────────────────
  Future<void> deletePost(String postId) async {
    try {
      await _dioClient.delete(
        '${AppConstants.postsEndpoint}/$postId',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }



  // ─── RECORD ALGORITHM INTERACTION ───────────────────────
  Future<void> recordInteraction({
    required String contentId,
    required String contentType,
    required String action,
    String? authorId,
    int dwellTime = 0,
    String source = 'feed',
    List<String> contentCategories = const [],
    List<String> contentHashtags = const [],
    String? sessionId,
  }) async {
    try {
      await _dioClient.post(
        '/algorithms/interact',
        data: {
          'contentId': contentId,
          'contentType': contentType,
          'action': action,
          'authorId': authorId,
          'dwellTime': dwellTime,
          'source': source,
          'contentCategories': contentCategories,
          'contentHashtags': contentHashtags,
          'sessionId': sessionId,
        },
      );
    } catch (e) {
      // Fail silently to never interrupt user interaction
      print('Interaction logging failed: $e');
    }
  }

  // ─── ERROR HANDLER ───────────────────────────────────────
  Exception _handleError(DioException e) {
    final message =
        e.response?.data?['message'] ?? 'Something went wrong';
    return Exception(message);
  }
}
