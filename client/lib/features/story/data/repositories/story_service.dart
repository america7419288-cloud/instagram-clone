// lib/features/story/data/repositories/story_service.dart

import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/story_model.dart';

class StoryService {
  final DioClient _dioClient = DioClient();

  // ─── GET STORY FEED ──────────────────────────────────────
  // Returns stories grouped by user
  Future<List<StoryUserGroup>> getStoryFeed() async {
    try {
      final response = await _dioClient.get('/stories/feed');
      final data = response.data['data'];
      final usersJson = data['users'] as List<dynamic>? ?? [];

      return usersJson
          .map((u) => StoryUserGroup.fromJson(
                u as Map<String, dynamic>,
              ))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── GET MY STORIES ──────────────────────────────────────
  Future<List<StoryModel>> getMyStories() async {
    try {
      final response = await _dioClient.get('/stories/my');
      final storiesJson =
          response.data['data']['stories'] as List<dynamic>? ?? [];

      return storiesJson
          .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── MARK STORY AS VIEWED ────────────────────────────────
  Future<void> viewStory(String storyId) async {
    try {
      await _dioClient.post('/stories/$storyId/view');
    } on DioException catch (e) {
      // Don't throw - view tracking failure is non-critical
      print('View tracking error: ${e.message}');
    }
  }

  // ─── DELETE STORY ────────────────────────────────────────
  Future<void> deleteStory(String storyId) async {
    try {
      await _dioClient.delete('/stories/$storyId');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── CREATE STORY ────────────────────────────────────────
  Future<StoryModel> createStory({
    required File imageFile,
    String? caption,
    String audience = 'followers',
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'story.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        'audience': audience,
      });

      final response = await _dioClient.uploadFile(
        '/stories/',
        formData,
      );

      return StoryModel.fromJson(
        response.data['data']['story'],
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