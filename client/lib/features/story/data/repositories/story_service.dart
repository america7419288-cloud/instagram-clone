// lib/features/story/data/repositories/story_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/story_model.dart';
import '../models/story_advanced_model.dart';

final storyServiceProvider = Provider<StoryService>((ref) {
  return StoryService(ref);
});

class StoryService {
  final Ref _ref;
  StoryService(this._ref);

  DioClient get _client => _ref.read(dioClientProvider);

  // ─── Get story feed ───────────────────────────────────
  Future<List<StoryFeedModel>> getStoryFeed() async {
    final response = await _client.get(AppConstants.storyFeedUrl);
    if (response.data['success'] == true) {
      final data = response.data['data'];
      final usersJson = data['users'] as List<dynamic>? ?? [];
      return usersJson
          .map((s) => StoryFeedModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load stories');
  }

  Future<List<StoryModel>> getMyStories() async {
    final response = await _client.get('${AppConstants.storiesUrl}/my');
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data']['stories'] ?? [];
      return data
          .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load stories');
  }

  Future<List<StoryModel>> getUserStories(String userId) async {
    final response =
        await _client.get('${AppConstants.storiesUrl}/user/$userId');
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data']['stories'] ?? [];
      return data
          .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load stories');
  }

  Future<void> viewStory(String storyId) async {
    await _client.post('${AppConstants.storiesUrl}/$storyId/view');
  }

  Future<void> deleteStory(String storyId) async {
    await _client.delete('${AppConstants.storiesUrl}/$storyId');
  }

  // ─── Create story ─────────────────────────────────────
  Future<void> createStory({
    required File mediaFile,
    required String mediaType,
    String? caption,
    String audience = 'followers',
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? questionData,
    Map<String, dynamic>? musicData,
    void Function(double)? onProgress,
  }) async {
    final fileName = mediaFile.path.split('/').last;
    final ext      = fileName.toLowerCase().split('.').last;

    String mimeType;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      case 'mp4':
        mimeType = 'video/mp4';
        break;
      case 'mov':
        mimeType = 'video/quicktime';
        break;
      default:
        mimeType = 'image/jpeg';
    }

    final bytes    = await mediaFile.readAsBytes();
    final formData = FormData();

    formData.files.add(
      MapEntry(
        'media',
        MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      ),
    );

    if (caption != null && caption.isNotEmpty) {
      formData.fields.add(MapEntry('caption', caption));
    }
    formData.fields.add(MapEntry('audience', audience));

    if (pollData != null) {
      formData.fields
          .add(MapEntry('pollQuestion', pollData['question'] ?? 'Vote'));
      formData.fields
          .add(MapEntry('optionA', pollData['optionA'] ?? 'Yes'));
      formData.fields
          .add(MapEntry('optionB', pollData['optionB'] ?? 'No'));
      
      // Positioning
      formData.fields.add(MapEntry('stickerX', pollData['x']?.toString() ?? '0.5'));
      formData.fields.add(MapEntry('stickerY', pollData['y']?.toString() ?? '0.5'));
      formData.fields.add(MapEntry('stickerWidth', pollData['width']?.toString() ?? '0'));
      formData.fields.add(MapEntry('stickerHeight', pollData['height']?.toString() ?? '0'));
      formData.fields.add(MapEntry('stickerRotation', pollData['rotation']?.toString() ?? '0'));
    }

    if (questionData != null) {
      formData.fields.add(
        MapEntry('questionText', questionData['text'] ?? 'Ask me anything'),
      );
      // Positioning
      formData.fields.add(MapEntry('stickerX', questionData['x']?.toString() ?? '0.5'));
      formData.fields.add(MapEntry('stickerY', questionData['y']?.toString() ?? '0.5'));
      formData.fields.add(MapEntry('stickerWidth', questionData['width']?.toString() ?? '0'));
      formData.fields.add(MapEntry('stickerHeight', questionData['height']?.toString() ?? '0'));
      formData.fields.add(MapEntry('stickerRotation', questionData['rotation']?.toString() ?? '0'));
    }

    if (musicData != null) {
      formData.fields.add(MapEntry('musicId', musicData['id'] ?? ''));
      formData.fields.add(MapEntry('musicTitle', musicData['title'] ?? ''));
      formData.fields.add(MapEntry('musicArtist', musicData['artist'] ?? ''));
      formData.fields.add(MapEntry('musicThumbnail', musicData['thumbnail'] ?? ''));
      formData.fields.add(MapEntry('musicStartTime', musicData['startTime']?.toString() ?? '0'));
      formData.fields.add(MapEntry('musicDuration', musicData['duration']?.toString() ?? '15'));
    }

    await _client.dio.post(
      AppConstants.storiesUrl,
      data: formData,
      options: Options(
        sendTimeout:    const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );
  }

  // ─── Music search ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> searchMusic(String query) async {
    final response = await _client.get('/api/v1/music/search', queryParameters: {'query': query});
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception(response.data['message'] ?? 'Failed to search music');
  }

  // ─── Poll vote ────────────────────────────────────────
  Future<StoryPollModel> votePoll({
    required String storyId,
    required String option,
  }) async {
    final response = await _client.post(
      '${AppConstants.storiesUrl}/$storyId/poll/vote',
      data: {'option': option},
    );
    if (response.data['success'] == true) {
      return StoryPollModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(response.data['message'] ?? 'Failed to vote');
  }

  // ─── Poll results ─────────────────────────────────────
  Future<StoryPollModel> getPollResults(String storyId) async {
    final response = await _client.get(
      '${AppConstants.storiesUrl}/$storyId/poll/results',
    );
    if (response.data['success'] == true) {
      return StoryPollModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(response.data['message'] ?? 'Failed to get results');
  }

  // ─── Answer question ──────────────────────────────────
  Future<void> answerQuestion({
    required String storyId,
    required String answer,
  }) async {
    await _client.post(
      '${AppConstants.storiesUrl}/$storyId/question/answer',
      data: {'answer': answer},
    );
  }

  // ─── React to story ───────────────────────────────────
  Future<void> reactToStory({
    required String storyId,
    required String emoji,
  }) async {
    await _client.post(
      '${AppConstants.storiesUrl}/$storyId/react',
      data: {'emoji': emoji},
    );
  }

  // ─── Remove reaction ──────────────────────────────────
  Future<void> removeReaction(String storyId) async {
    await _client.delete('${AppConstants.storiesUrl}/$storyId/react');
  }

  // ─── Reply to story ───────────────────────────────────
  Future<String> replyToStory({
    required String storyId,
    required String message,
  }) async {
    final response = await _client.post(
      '${AppConstants.storiesUrl}/$storyId/reply',
      data: {'message': message},
    );
    if (response.data['success'] == true) {
      return response.data['data']['conversationId']?.toString() ?? '';
    }
    throw Exception(response.data['message'] ?? 'Failed to send reply');
  }

  // ─── Get highlights ───────────────────────────────────
  Future<List<HighlightModel>> getUserHighlights(String username) async {
    final response = await _client.get(
      '${AppConstants.usersUrl}/$username/highlights',
    );
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map(
            (h) => HighlightModel.fromJson(h as Map<String, dynamic>),
          )
          .toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load highlights');
  }

  // ─── Get highlight detail ─────────────────────────────
  Future<HighlightModel> getHighlight(String highlightId) async {
    final response = await _client.get(
      '${AppConstants.highlightsUrl}/$highlightId',
    );
    if (response.data['success'] == true) {
      return HighlightModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(response.data['message'] ?? 'Failed to load highlight');
  }

  // ─── Create highlight ─────────────────────────────────
  Future<HighlightModel> createHighlight({
    required String title,
    List<String> storyIds = const [],
  }) async {
    final response = await _client.post(
      AppConstants.highlightsUrl,
      data: {'title': title, 'storyIds': storyIds},
    );
    if (response.data['success'] == true) {
      return HighlightModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create highlight',
    );
  }

  // ─── Delete highlight ─────────────────────────────────
  Future<void> deleteHighlight(String highlightId) async {
    await _client.delete('${AppConstants.highlightsUrl}/$highlightId');
  }

  // ─── Get story archive ────────────────────────────────
  Future<List<StoryModel>> getStoryArchive() async {
    final response =
        await _client.get('${AppConstants.storiesUrl}/archive');
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map((s) => StoryModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load archive');
  }
}
