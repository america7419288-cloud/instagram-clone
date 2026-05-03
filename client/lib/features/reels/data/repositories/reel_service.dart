// lib/features/reels/data/repositories/reel_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/reel_model.dart';

// ─── Provider ─────────────────────────────────────────
final reelServiceProvider = Provider<ReelService>((ref) {
  return ReelService(ref);
});

class ReelService {
  final Ref _ref;

  ReelService(this._ref);

  DioClient get _client => _ref.read(dioClientProvider);

  // ─── Get reels feed ───────────────────────────────────
  Future<List<ReelModel>> getReelsFeed({int page = 1}) async {
    final response = await _client.get(
      AppConstants.reelsFeedUrl,
      queryParameters: {
        'page': page,
        'limit': AppConstants.reelsPageSize,
      },
    );

    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map((r) => ReelModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      response.data['message'] ?? 'Failed to load reels',
    );
  }

  // ─── Get user reels ───────────────────────────────────
  Future<List<ReelModel>> getUserReels({
    required String username,
    int page = 1,
  }) async {
    final response = await _client.get(
      '${AppConstants.reelsUrl}/user/$username',
      queryParameters: {'page': page, 'limit': 12},
    );

    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      return data
          .map((r) => ReelModel.fromJson(r as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
      response.data['message'] ?? 'Failed to load user reels',
    );
  }

  // ─── Like reel ────────────────────────────────────────
  Future<void> likeReel(String reelId) async {
    await _client.post(
      '${AppConstants.reelsUrl}/$reelId/like',
    );
  }

  // ─── Unlike reel ──────────────────────────────────────
  Future<void> unlikeReel(String reelId) async {
    await _client.delete(
      '${AppConstants.reelsUrl}/$reelId/like',
    );
  }

  // ─── Delete reel ──────────────────────────────────────
  Future<void> deleteReel(String reelId) async {
    await _client.delete(
      '${AppConstants.reelsUrl}/$reelId',
    );
  }
}