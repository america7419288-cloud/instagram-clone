import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/community.dart';
import '../models/community_channel.dart';
import '../models/community_member.dart';
import '../models/community_post.dart';
import '../models/community_rule.dart';

class CommunityRepository {
  final Dio _dio;

  CommunityRepository(this._dio);

  // ─── 1. CREATE COMMUNITY ─────────────────────────────────────
  Future<Community> createCommunity({
    required String name,
    required String handle,
    String? description,
    String? category,
    String? privacy,
    List<String>? tags,
  }) async {
    final response = await _dio.post(
      '/communities',
      data: {
        'name': name,
        'handle': handle,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (privacy != null) 'privacy': privacy,
        if (tags != null) 'tags': tags,
      },
    );
    return Community.fromJson(response.data['data']['community']);
  }

  // ─── 2. GET MY COMMUNITIES (JOINED) ─────────────────────────
  Future<List<Community>> getMyCommunities() async {
    final response = await _dio.get('/communities/my');
    final list = response.data['data']['communities'] as List;
    return list.map((json) => Community.fromJson(json)).toList();
  }

  // ─── 3. DISCOVER COMMUNITIES ─────────────────────────────────
  Future<List<Community>> discoverCommunities({
    String? category,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/communities/discover',
      queryParameters: {
        if (category != null) 'category': category,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data']['communities'] as List;
    return list.map((json) => Community.fromJson(json)).toList();
  }

  // ─── 4. SEARCH COMMUNITIES ───────────────────────────────────
  Future<List<Community>> searchCommunities({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/communities/search',
      queryParameters: {
        'q': query,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data']['communities'] as List;
    return list.map((json) => Community.fromJson(json)).toList();
  }

  // ─── 5. GET COMMUNITY DETAILS ────────────────────────────────
  Future<Map<String, dynamic>> getCommunityDetails(String communityId) async {
    final response = await _dio.get('/communities/$communityId');
    final data = response.data['data'];
    return {
      'community': Community.fromJson(data['community']),
      'isMember': data['is_member'] ?? false,
      'role': data['role'],
    };
  }

  // ─── 6. UPDATE / DELETE COMMUNITY ────────────────────────────
  Future<Community> updateCommunity(
    String communityId, {
    String? name,
    String? description,
    String? category,
    String? privacy,
    Map<String, dynamic>? settings,
  }) async {
    final response = await _dio.put(
      '/communities/$communityId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (privacy != null) 'privacy': privacy,
        if (settings != null) 'settings': settings,
      },
    );
    return Community.fromJson(response.data['data']['community']);
  }

  Future<void> deleteCommunity(String communityId) async {
    await _dio.delete('/communities/$communityId');
  }

  // ─── 7. JOIN / LEAVE COMMUNITY ───────────────────────────────
  Future<Map<String, dynamic>> joinCommunity(
    String communityId, {
    String? message,
  }) async {
    final response = await _dio.post(
      '/communities/$communityId/join',
      data: {
        if (message != null) 'message': message,
      },
    );
    return response.data['data'];
  }

  Future<void> leaveCommunity(String communityId) async {
    await _dio.delete('/communities/$communityId/leave');
  }

  // ─── 8. AVATAR / COVER PHOTO UPLOADS ─────────────────────────
  Future<String> updateAvatar(String communityId, String imagePath) async {
    final formData = FormData();
    formData.files.add(MapEntry(
      'avatar',
      await MultipartFile.fromFile(imagePath),
    ));

    final response = await _dio.put(
      '/communities/$communityId/avatar',
      data: formData,
    );
    return response.data['data']['avatar_url'];
  }

  Future<String> updateCover(String communityId, String imagePath) async {
    final formData = FormData();
    formData.files.add(MapEntry(
      'cover',
      await MultipartFile.fromFile(imagePath),
    ));

    final response = await _dio.put(
      '/communities/$communityId/cover',
      data: formData,
    );
    return response.data['data']['cover_url'];
  }

  // ─── 9. MEMBERS & MODERATION ─────────────────────────────────
  Future<List<CommunityMember>> getMembers(String communityId) async {
    final response = await _dio.get('/communities/$communityId/members');
    final list = response.data['data']['members'] as List;
    return list.map((json) => CommunityMember.fromJson(json)).toList();
  }

  Future<void> updateMemberRole(String communityId, String userId, String role) async {
    await _dio.put(
      '/communities/$communityId/members/$userId/role',
      data: {'role': role},
    );
  }

  Future<void> banMember(
    String communityId,
    String userId, {
    String? reason,
    int? duration,
  }) async {
    await _dio.post(
      '/communities/$communityId/members/$userId/ban',
      data: {
        if (reason != null) 'reason': reason,
        if (duration != null) 'duration': duration,
      },
    );
  }

  Future<void> unbanMember(String communityId, String userId) async {
    await _dio.delete('/communities/$communityId/members/$userId/ban');
  }

  // ─── 10. JOIN REQUESTS (PRIVATE) ─────────────────────────────
  Future<List<Map<String, dynamic>>> getJoinRequests(String communityId) async {
    final response = await _dio.get('/communities/$communityId/requests');
    final list = response.data['data']['requests'] as List;
    return list.map((json) => Map<String, dynamic>.from(json)).toList();
  }

  Future<void> approveRequest(String communityId, String userId) async {
    await _dio.post('/communities/$communityId/requests/$userId/approve');
  }

  Future<void> rejectRequest(String communityId, String userId) async {
    await _dio.post('/communities/$communityId/requests/$userId/reject');
  }

  // ─── 11. CHANNELS ────────────────────────────────────────────
  Future<List<CommunityChannel>> getChannels(String communityId) async {
    final response = await _dio.get('/communities/$communityId/channels');
    final list = response.data['data']['channels'] as List;
    return list.map((json) => CommunityChannel.fromJson(json)).toList();
  }

  Future<CommunityChannel> createChannel(
    String communityId, {
    required String name,
    String? description,
    required String type,
    List<String>? allowedRoles,
  }) async {
    final response = await _dio.post(
      '/communities/$communityId/channels',
      data: {
        'name': name,
        'type': type,
        if (description != null) 'description': description,
        if (allowedRoles != null) 'allowed_roles': allowedRoles,
      },
    );
    return CommunityChannel.fromJson(response.data['data']['channel']);
  }

  Future<CommunityChannel> updateChannel(
    String communityId,
    String channelId, {
    String? name,
    String? description,
    List<String>? allowedRoles,
  }) async {
    final response = await _dio.put(
      '/communities/$communityId/channels/$channelId',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (allowedRoles != null) 'allowed_roles': allowedRoles,
      },
    );
    return CommunityChannel.fromJson(response.data['data']['channel']);
  }

  Future<void> deleteChannel(String communityId, String channelId) async {
    await _dio.delete('/communities/$communityId/channels/$channelId');
  }

  // ─── 12. POSTS ───────────────────────────────────────────────
  Future<List<CommunityPost>> getCommunityPosts(
    String communityId, {
    String? channelId,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get(
      '/communities/$communityId/posts',
      queryParameters: {
        if (channelId != null) 'channel_id': channelId,
        'page': page,
        'limit': limit,
      },
    );
    final list = response.data['data']['posts'] as List;
    return list.map((json) => CommunityPost.fromJson(json)).toList();
  }

  Future<CommunityPost> createPost(
    String communityId, {
    required String channelId,
    String? content,
    String type = 'text',
    Map<String, dynamic>? poll,
    Map<String, dynamic>? event,
    List<String>? mediaPaths,
  }) async {
    dynamic data;
    if (mediaPaths != null && mediaPaths.isNotEmpty) {
      final formData = FormData.fromMap({
        'channel_id': channelId,
        if (content != null) 'content': content,
        'type': type,
        if (poll != null) 'poll': poll,
        if (event != null) 'event': event,
      });

      for (final path in mediaPaths) {
        formData.files.add(MapEntry(
          'media',
          await MultipartFile.fromFile(path),
        ));
      }
      data = formData;
    } else {
      data = {
        'channel_id': channelId,
        if (content != null) 'content': content,
        'type': type,
        if (poll != null) 'poll': poll,
        if (event != null) 'event': event,
      };
    }

    final response = await _dio.post(
      '/communities/$communityId/posts',
      data: data,
    );
    return CommunityPost.fromJson(response.data['data']['post']);
  }

  Future<void> deletePost(String communityId, String postId) async {
    await _dio.delete('/communities/$communityId/posts/$postId');
  }

  Future<void> likePost(String communityId, String postId) async {
    await _dio.post('/communities/$communityId/posts/$postId/like');
  }

  Future<void> pinPost(String communityId, String postId, {required bool pin}) async {
    await _dio.put(
      '/communities/$communityId/posts/$postId/pin',
      data: {'pin': pin},
    );
  }

  // ─── 13. RULES ───────────────────────────────────────────────
  Future<List<CommunityRule>> getRules(String communityId) async {
    final response = await _dio.get('/communities/$communityId/rules');
    final list = response.data['data']['rules'] as List;
    return list.map((json) => CommunityRule.fromJson(json)).toList();
  }

  Future<CommunityRule> addRule(
    String communityId, {
    required String title,
    String? description,
  }) async {
    final response = await _dio.post(
      '/communities/$communityId/rules',
      data: {
        'title': title,
        if (description != null) 'description': description,
      },
    );
    return CommunityRule.fromJson(response.data['data']['rule']);
  }

  Future<CommunityRule> updateRule(
    String communityId,
    String ruleId, {
    String? title,
    String? description,
    int? order,
  }) async {
    final response = await _dio.put(
      '/communities/$communityId/rules/$ruleId',
      data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (order != null) 'order': order,
      },
    );
    return CommunityRule.fromJson(response.data['data']['rule']);
  }

  Future<void> deleteRule(String communityId, String ruleId) async {
    await _dio.delete('/communities/$communityId/rules/$ruleId');
  }

  // ─── 14. INVITE LINK ─────────────────────────────────────────
  Future<String> getInviteLink(String communityId) async {
    final response = await _dio.get('/communities/$communityId/invite');
    return response.data['data']['invite_code'];
  }

  Future<String> joinViaInviteLink(String inviteCode) async {
    final response = await _dio.post('/communities/join/$inviteCode');
    return response.data['data']['community_id'];
  }

  Future<Map<String, dynamic>> votePoll(String communityId, String postId, int optionIndex) async {
    final response = await _dio.post(
      '/communities/$communityId/posts/$postId/poll/vote',
      data: {'optionIndex': optionIndex},
    );
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> rsvpEvent(String communityId, String postId) async {
    final response = await _dio.post(
      '/communities/$communityId/posts/$postId/event/rsvp',
    );
    return Map<String, dynamic>.from(response.data['data']);
  }
}
