// lib/features/post/data/repositories/post_tag_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/post_tag_model.dart';

final postTagServiceProvider = Provider<PostTagService>((ref) {
  return PostTagService(ref);
});

class PostTagService {
  final Ref _ref;
  PostTagService(this._ref);

  DioClient get _client => _ref.read(dioClientProvider);

  // ─── Add tags to post ─────────────────────────────────
  Future<void> addTags({
    required String postId,
    required List<PostTagModel> tags,
  }) async {
    final response = await _client.post(
      '${AppConstants.postsUrl}/$postId/tags',
      data: {
        'tags': tags.map((t) => t.toJson()).toList(),
      },
    );
    if (response.data['success'] != true) {
      throw Exception(
        response.data['message'] ?? 'Failed to add tags',
      );
    }
  }

  // ─── Get tags for post ────────────────────────────────
  Future<List<PostTagModel>> getPostTags(String postId) async {
    final response = await _client.get(
      '${AppConstants.postsUrl}/$postId/tags',
    );
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map((t) => PostTagModel.fromJson(t as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      response.data['message'] ?? 'Failed to load tags',
    );
  }

  // ─── Remove tag ───────────────────────────────────────
  Future<void> removeTag({
    required String postId,
    required String userId,
  }) async {
    await _client.delete(
      '${AppConstants.postsUrl}/$postId/tags/$userId',
    );
  }

  // ─── Accept tag ───────────────────────────────────────
  Future<void> acceptTag(String postId) async {
    await _client.patch(
      '${AppConstants.postsUrl}/$postId/tags/accept',
    );
  }

  // ─── Get tagged posts for user ────────────────────────
  Future<List<dynamic>> getTaggedPosts({
    required String username,
    int page = 1,
  }) async {
    final response = await _client.get(
      '${AppConstants.usersUrl}/$username/tagged-posts',
      queryParameters: {'page': page, 'limit': 20},
    );
    if (response.data['success'] == true) {
      return response.data['data'] ?? [];
    }
    throw Exception(
      response.data['message'] ?? 'Failed to load tagged posts',
    );
  }
}
