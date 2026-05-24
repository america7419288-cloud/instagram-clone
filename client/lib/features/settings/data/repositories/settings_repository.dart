import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../models/settings_model.dart';
import '../models/saved_collection_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref);
});

class SettingsRepository {
  final Ref _ref;

  SettingsRepository(this._ref);

  DioClient get _client => _ref.read(dioClientProvider);

  // ─── SETTINGS GENERAL ───────────────────────────────────

  Future<UserSettingsModel> getSettings() async {
    final response = await _client.get('/settings');
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to load settings');
  }

  Future<UserSettingsModel> updatePrivacy(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/privacy', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update privacy settings');
  }

  Future<UserSettingsModel> updateComments(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/comments', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update comments settings');
  }

  Future<UserSettingsModel> updateLikesShares(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/likes-shares', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update likes & shares settings');
  }

  Future<UserSettingsModel> updateNotifications(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/notifications', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update notifications settings');
  }

  Future<UserSettingsModel> updateTimestamp(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/timestamp', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update timestamp settings');
  }

  Future<UserSettingsModel> updateArchiveSettings(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/archive-settings', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update archive settings');
  }

  Future<UserSettingsModel> updateSavedSettings(Map<String, dynamic> body) async {
    final response = await _client.put('/settings/saved-settings', data: body);
    if (response.data['success'] == true) {
      final data = response.data['data']['settings'];
      return UserSettingsModel.fromJson(data as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update saved settings');
  }

  // ─── SAVED POSTS & COLLECTIONS ──────────────────────────

  Future<List<dynamic>> getSavedPosts({String? collectionId, int page = 1, int limit = 24}) async {
    final response = await _client.get(
      '/settings/saved',
      queryParameters: {
        if (collectionId != null) 'collectionId': collectionId,
        'page': page,
        'limit': limit,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['posts'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load saved posts');
  }

  Future<void> savePost(String postId, {String? collectionId}) async {
    await _client.post(
      '/settings/saved/$postId',
      data: {
        if (collectionId != null) 'collectionId': collectionId,
      },
    );
  }

  Future<void> unsavePost(String postId) async {
    await _client.delete('/settings/saved/$postId');
  }

  Future<List<SavedCollectionModel>> getCollections() async {
    final response = await _client.get('/settings/saved/collections');
    if (response.data['success'] == true) {
      final list = response.data['data']['collections'] as List<dynamic>;
      return list.map((c) => SavedCollectionModel.fromJson(c as Map<String, dynamic>)).toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load collections');
  }

  Future<SavedCollectionModel> createCollection(String name) async {
    final response = await _client.post(
      '/settings/saved/collections',
      data: {'name': name},
    );
    if (response.data['success'] == true) {
      return SavedCollectionModel.fromJson(response.data['data']['collection'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to create collection');
  }

  Future<SavedCollectionModel> updateCollection(String id, {String? name, String? coverPostId}) async {
    final response = await _client.put(
      '/settings/saved/collections/$id',
      data: {
        if (name != null) 'name': name,
        if (coverPostId != null) 'coverPostId': coverPostId,
      },
    );
    if (response.data['success'] == true) {
      return SavedCollectionModel.fromJson(response.data['data']['collection'] as Map<String, dynamic>);
    }
    throw Exception(response.data['message'] ?? 'Failed to update collection');
  }

  Future<void> deleteCollection(String id) async {
    await _client.delete('/settings/saved/collections/$id');
  }

  Future<void> addToCollection(String collectionId, String postId) async {
    await _client.post('/settings/saved/collections/$collectionId/posts/$postId');
  }

  Future<void> removeFromCollection(String collectionId, String postId) async {
    await _client.delete('/settings/saved/collections/$collectionId/posts/$postId');
  }

  // ─── CLOSE FRIENDS ─────────────────────────────────────

  Future<List<dynamic>> getCloseFriends({int page = 1, int limit = 30, String? search}) async {
    final response = await _client.get(
      '/settings/close-friends',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null) 'search': search,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['closeFriends'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load close friends');
  }

  Future<void> addCloseFriend(String userId) async {
    await _client.post('/settings/close-friends/$userId');
  }

  Future<void> removeCloseFriend(String userId) async {
    await _client.delete('/settings/close-friends/$userId');
  }

  Future<bool> isCloseFriend(String userId) async {
    final response = await _client.get('/settings/close-friends/check/$userId');
    if (response.data['success'] == true) {
      return response.data['data']['isCloseFriend'] == true;
    }
    return false;
  }

  // ─── MUTED ACCOUNTS ────────────────────────────────────

  Future<List<dynamic>> getMutedAccounts({int page = 1, int limit = 30}) async {
    final response = await _client.get(
      '/settings/muted',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['mutedAccounts'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load muted accounts');
  }

  Future<void> muteAccount(String userId, {bool mutePosts = true, bool muteStories = false}) async {
    await _client.post(
      '/settings/muted/$userId',
      data: {
        'mutePosts': mutePosts,
        'muteStories': muteStories,
      },
    );
  }

  Future<void> updateMuteSettings(String userId, {bool? mutePosts, bool? muteStories}) async {
    await _client.put(
      '/settings/muted/$userId',
      data: {
        if (mutePosts != null) 'mutePosts': mutePosts,
        if (muteStories != null) 'muteStories': muteStories,
      },
    );
  }

  Future<void> unmuteAccount(String userId) async {
    await _client.delete('/settings/muted/$userId');
  }

  // ─── BLOCKED ACCOUNTS ──────────────────────────────────

  Future<List<dynamic>> getBlockedAccounts({int page = 1, int limit = 30}) async {
    final response = await _client.get(
      '/settings/blocked',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['blockedAccounts'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load blocked accounts');
  }

  Future<void> blockAccount(String userId) async {
    await _client.post('/settings/blocked/$userId');
  }

  Future<void> unblockAccount(String userId) async {
    await _client.delete('/settings/blocked/$userId');
  }

  Future<bool> isBlocked(String userId) async {
    final response = await _client.get('/settings/blocked/check/$userId');
    if (response.data['success'] == true) {
      return response.data['data']['isBlocked'] == true;
    }
    return false;
  }

  // ─── ARCHIVE ──────────────────────────────────────────

  Future<List<dynamic>> getArchive({String? type, int page = 1, int limit = 24}) async {
    final response = await _client.get(
      '/settings/archive',
      queryParameters: {
        if (type != null) 'type': type,
        'page': page,
        'limit': limit,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['archived'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load archive');
  }

  Future<List<dynamic>> getArchivedStories({int page = 1, int limit = 24}) async {
    final response = await _client.get(
      '/settings/archive/stories',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['stories'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load archived stories');
  }

  Future<List<dynamic>> getArchivedPosts({int page = 1, int limit = 24}) async {
    final response = await _client.get(
      '/settings/archive/posts',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    if (response.data['success'] == true) {
      return response.data['data']['posts'] as List<dynamic>;
    }
    throw Exception(response.data['message'] ?? 'Failed to load archived posts');
  }

  Future<void> archiveContent(String type, String contentId) async {
    await _client.post('/settings/archive/$type/$contentId');
  }

  Future<void> unarchiveContent(String type, String contentId) async {
    await _client.delete('/settings/archive/$type/$contentId');
  }

  Future<void> clearArchive({String? type}) async {
    final queryStr = type != null ? '?type=$type' : '';
    await _client.delete('/settings/archive$queryStr');
  }
}
