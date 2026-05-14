// lib/features/reels/data/repositories/reel_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
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

  // ─── Get single reel ──────────────────────────────────
  Future<ReelModel> getReelById(String reelId) async {
    final response = await _client.get('${AppConstants.reelsUrl}/$reelId');

    if (response.data['success'] == true) {
      return ReelModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(
      response.data['message'] ?? 'Failed to load reel',
    );
  }

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

  // ─── Create reel ──────────────────────────────────────
  Future<ReelModel> createReel({
    required File videoFile,
    required String caption,
    required String audioName,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = videoFile.path.split('/').last;
    final ext = fileName.toLowerCase().split('.').last;

    // ─── Detect mime type ──────────────────────────────
    String mimeType;
    switch (ext) {
      case 'mp4':
        mimeType = 'video/mp4';
        break;
      case 'mov':
        mimeType = 'video/quicktime';
        break;
      case 'avi':
        mimeType = 'video/x-msvideo';
        break;
      case 'webm':
        mimeType = 'video/webm';
        break;
      case '3gp':
        mimeType = 'video/3gpp';
        break;
      default:
        mimeType = 'video/mp4';
    }

    final fileBytes = await videoFile.readAsBytes();

    final formData = FormData();

    // ─── Video file ────────────────────────────────────
    formData.files.add(
      MapEntry(
        'video',
        MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      ),
    );

    // ─── Text fields ───────────────────────────────────
    if (caption.isNotEmpty) {
      formData.fields.add(MapEntry('caption', caption));
    }
    if (audioName.isNotEmpty) {
      formData.fields.add(MapEntry('audioName', audioName));
    }

    final response = await _client.dio.post(
      AppConstants.reelsUrl,
      data: formData,
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    if (response.data['success'] == true) {
      return ReelModel.fromJson(
        response.data['data'] as Map<String, dynamic>,
      );
    }
    throw Exception(
      response.data['message'] ?? 'Failed to create reel',
    );
  }

  // ─── Like reel ────────────────────────────────────────
  Future<void> likeReel(String reelId) async {
    await _client.post('${AppConstants.reelsUrl}/$reelId/like');
  }

  // ─── Unlike reel ──────────────────────────────────────
  Future<void> unlikeReel(String reelId) async {
    await _client.delete('${AppConstants.reelsUrl}/$reelId/like');
  }

  // ─── Delete reel ──────────────────────────────────────
  Future<void> deleteReel(String reelId) async {
    await _client.delete('${AppConstants.reelsUrl}/$reelId');
  }

  // ─── Save reel ────────────────────────────────────────
  Future<void> saveReel(String reelId) async {
    await _client.post('${AppConstants.reelsUrl}/$reelId/save');
  }

  // ─── Unsave reel ──────────────────────────────────────
  Future<void> unsaveReel(String reelId) async {
    await _client.delete('${AppConstants.reelsUrl}/$reelId/save');
  }
}

