import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../models/ad_model.dart';
import '../models/campaign_model.dart';
import '../models/advertiser_model.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService(ref);
});

class AdService {
  final Ref _ref;
  AdService(this._ref);

  DioClient get _client => _ref.read(dioClientProvider);

  // ── PUBLIC AD SERVING & EVENT LOGGING ─────────────────
  Future<List<AdModel>> getFeedAds({int count = 2}) async {
    try {
      final response = await _client.get('/ads/feed', queryParameters: {'count': count});
      if (response.data['success'] == true) {
        final List<dynamic> list = response.data['data']['ads'] ?? [];
        return list.map((a) => AdModel.fromJson(a)).toList();
      }
      return [];
    } catch (_) {
      return []; // Return empty gracefully so it never breaks feeds
    }
  }

  Future<List<AdModel>> getStoryAds() async {
    try {
      final response = await _client.get('/ads/stories');
      if (response.data['success'] == true) {
        final List<dynamic> list = response.data['data']['ads'] ?? [];
        return list.map((a) => AdModel.fromJson(a)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<AdModel>> getReelAds() async {
    try {
      final response = await _client.get('/ads/reels');
      if (response.data['success'] == true) {
        final List<dynamic> list = response.data['data']['ads'] ?? [];
        return list.map((a) => AdModel.fromJson(a)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> trackAdEvent({
    required String adId,
    required String campaignId,
    required String advertiserId,
    required String action,
    required String placement,
  }) async {
    try {
      await _client.post('/ads/track', data: {
        'adId': adId,
        'campaignId': campaignId,
        'advertiserId': advertiserId,
        'action': action,
        'placement': placement,
      });
    } catch (_) {
      // Ignore tracking network errors so UX is smooth
    }
  }

  // ── ADVERTISER PROFILE ──────────────────────────────
  Future<AdvertiserModel> registerAdvertiser({
    required String businessName,
    required String businessEmail,
    required String businessCategory,
    String? businessWebsite,
    File? logo,
  }) async {
    final formData = FormData();
    formData.fields.addAll([
      MapEntry('businessName', businessName),
      MapEntry('businessEmail', businessEmail),
      MapEntry('businessCategory', businessCategory),
      if (businessWebsite != null) MapEntry('businessWebsite', businessWebsite),
    ]);

    if (logo != null) {
      final path = logo.path;
      final fileName = path.split('/').last;
      final bytes = await logo.readAsBytes();
      formData.files.add(
        MapEntry(
          'logo',
          MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    final response = await _client.dio.post('/ads/advertiser', data: formData);
    if (response.data['success'] == true) {
      return AdvertiserModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to register advertiser');
  }

  Future<AdvertiserModel> getMyAdvertiser() async {
    final response = await _client.get('/ads/advertiser/me');
    if (response.data['success'] == true) {
      return AdvertiserModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to load advertiser profile');
  }

  Future<AdvertiserModel> updateAdvertiser({
    required String businessName,
    required String businessEmail,
    required String businessCategory,
    String? businessWebsite,
    File? logo,
  }) async {
    final formData = FormData();
    formData.fields.addAll([
      MapEntry('businessName', businessName),
      MapEntry('businessEmail', businessEmail),
      MapEntry('businessCategory', businessCategory),
      if (businessWebsite != null) MapEntry('businessWebsite', businessWebsite),
    ]);

    if (logo != null) {
      final path = logo.path;
      final fileName = path.split('/').last;
      final bytes = await logo.readAsBytes();
      formData.files.add(
        MapEntry(
          'logo',
          MultipartFile.fromBytes(
            bytes,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    final response = await _client.dio.put('/ads/advertiser', data: formData);
    if (response.data['success'] == true) {
      return AdvertiserModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to update advertiser profile');
  }

  // ── CAMPAIGNS ───────────────────────────────────────
  Future<List<CampaignModel>> getMyCampaigns() async {
    final response = await _client.get('/ads/campaigns');
    if (response.data['success'] == true) {
      final List<dynamic> list = response.data['data']['campaigns'] ?? [];
      return list.map((c) => CampaignModel.fromJson(c)).toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load campaigns');
  }

  Future<CampaignModel> createCampaign({
    required String name,
    required String objective,
    required String budgetType,
    required int budgetAmount, // cents
    required String bidStrategy,
    int? bidAmount,
    required DateTime startDate,
    DateTime? endDate,
    required List<int> activeDays,
    required int activeHoursStart,
    required int activeHoursEnd,
    required Map<String, dynamic> targeting,
    required Map<String, bool> placements,
  }) async {
    final response = await _client.post('/ads/campaigns', data: {
      'name': name,
      'objective': objective,
      'budget': {
        'type': budgetType,
        'amount': budgetAmount,
      },
      'bidStrategy': bidStrategy,
      'bidAmount': bidAmount,
      'schedule': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'activeDays': activeDays,
        'activeHoursStart': activeHoursStart,
        'activeHoursEnd': activeHoursEnd,
      },
      'targeting': targeting,
      'placements': placements,
    });

    if (response.data['success'] == true) {
      return CampaignModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to create campaign');
  }

  Future<CampaignModel> getCampaign(String id) async {
    final response = await _client.get('/ads/campaigns/$id');
    if (response.data['success'] == true) {
      return CampaignModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to load campaign');
  }

  Future<void> pauseCampaign(String id) async {
    await _client.post('/ads/campaigns/$id/pause');
  }

  Future<void> resumeCampaign(String id) async {
    await _client.post('/ads/campaigns/$id/resume');
  }

  Future<void> deleteCampaign(String id) async {
    await _client.delete('/ads/campaigns/$id');
  }

  // ── AD CREATIVES ────────────────────────────────────
  Future<List<AdModel>> getCreatives(String campaignId) async {
    final response = await _client.get('/ads/campaigns/$campaignId/creatives');
    if (response.data['success'] == true) {
      final List<dynamic> list = response.data['data'] ?? [];
      return list.map((c) => AdModel.fromJson(c)).toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load creatives');
  }

  Future<AdModel> createCreative({
    required String campaignId,
    required String type,
    String? advertiserName,
    String? advertiserAvatarUrl,
    required String primaryText,
    String? headline,
    String? description,
    required String ctaType,
    required String ctaUrl,
    String storySwipeUpText = 'See more',
    String storyOverlayColor = '#000000',
    File? image,
    File? video,
    File? thumbnail,
    List<File> carouselImages = const [],
    String? carouselCardsJson,
  }) async {
    final formData = FormData();
    formData.fields.addAll([
      MapEntry('type', type),
      if (advertiserName != null) MapEntry('advertiserName', advertiserName),
      if (advertiserAvatarUrl != null) MapEntry('advertiserAvatarUrl', advertiserAvatarUrl),
      MapEntry('primaryText', primaryText),
      if (headline != null) MapEntry('headline', headline),
      if (description != null) MapEntry('description', description),
      MapEntry('ctaType', ctaType),
      MapEntry('ctaUrl', ctaUrl),
      MapEntry('storySwipeUpText', storySwipeUpText),
      MapEntry('storyOverlayColor', storyOverlayColor),
      if (carouselCardsJson != null) MapEntry('carouselCards', carouselCardsJson),
    ]);

    if (image != null) {
      final bytes = await image.readAsBytes();
      formData.files.add(
        MapEntry(
          'image',
          MultipartFile.fromBytes(
            bytes,
            filename: image.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    if (video != null) {
      final bytes = await video.readAsBytes();
      formData.files.add(
        MapEntry(
          'video',
          MultipartFile.fromBytes(
            bytes,
            filename: video.path.split('/').last,
            contentType: MediaType('video', 'mp4'),
          ),
        ),
      );
    }

    if (thumbnail != null) {
      final bytes = await thumbnail.readAsBytes();
      formData.files.add(
        MapEntry(
          'thumbnail',
          MultipartFile.fromBytes(
            bytes,
            filename: thumbnail.path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    for (int i = 0; i < carouselImages.length; i++) {
      final bytes = await carouselImages[i].readAsBytes();
      formData.files.add(
        MapEntry(
          'carouselImages',
          MultipartFile.fromBytes(
            bytes,
            filename: carouselImages[i].path.split('/').last,
            contentType: MediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    final response = await _client.dio.post(
      '/ads/campaigns/$campaignId/creatives',
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    if (response.data['success'] == true) {
      return AdModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to upload ad creative');
  }

  Future<void> deleteCreative(String id) async {
    await _client.delete('/ads/creatives/$id');
  }

  // ── ANALYTICS snap query ────────────────────────────
  Future<Map<String, dynamic>> getCampaignAnalytics(String id, {int days = 7}) async {
    final response = await _client.get('/ads/campaigns/$id/analytics', queryParameters: {'days': days});
    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Failed to load analytics');
  }

  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final response = await _client.get('/ads/analytics/overview');
    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Failed to load analytics overview');
  }

  // ── ADMIN ───────────────────────────────────────────
  Future<List<CampaignModel>> getAllCampaigns({String? status}) async {
    final response = await _client.get(
      '/ads/admin/campaigns',
      queryParameters: status != null ? {'status': status} : null,
    );
    if (response.data['success'] == true) {
      final List<dynamic> list = response.data['data']['campaigns'] ?? [];
      return list.map((c) => CampaignModel.fromJson(c)).toList();
    }
    throw Exception(response.data['message'] ?? 'Failed to load campaigns list');
  }

  Future<void> approveCampaign(String id) async {
    await _client.post('/ads/admin/campaigns/$id/approve');
  }

  Future<void> rejectCampaign(String id, String reason) async {
    await _client.post('/ads/admin/campaigns/$id/reject', data: {'reason': reason});
  }

  Future<Map<String, dynamic>> getAdminAnalytics({int days = 30}) async {
    final response = await _client.get('/ads/admin/analytics', queryParameters: {'days': days});
    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Failed to load platform analytics');
  }
}
