// lib/features/reels/presentation/providers/create_reel_provider.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/repositories/reel_service.dart';

// ─────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────
class CreateReelState {
  final bool isUploading;
  final double uploadProgress; // 0.0 → 1.0
  final String? error;
  final bool success;

  const CreateReelState({
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.success = false,
  });

  CreateReelState copyWith({
    bool? isUploading,
    double? uploadProgress,
    String? error,
    bool? success,
    bool clearError = false,
  }) {
    return CreateReelState(
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: clearError ? null : (error ?? this.error),
      success: success ?? this.success,
    );
  }
}

// ─────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────
class CreateReelNotifier extends StateNotifier<CreateReelState> {
  final ReelService _reelService;

  CreateReelNotifier(this._reelService)
      : super(const CreateReelState());

  Future<void> uploadReel({
    required File videoFile,
    required String caption,
    required String audioName,
  }) async {
    if (state.isUploading) return;

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      clearError: true,
      success: false,
    );

    try {
      await _reelService.createReel(
        videoFile: videoFile,
        caption: caption,
        audioName: audioName,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: progress);
        },
      );

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        success: true,
      );
    } catch (e) {
      String message = 'Failed to upload reel';

      final raw = e.toString().replaceAll('Exception: ', '');
      if (raw.isNotEmpty) message = raw;

      state = state.copyWith(
        isUploading: false,
        error: message,
      );

      rethrow;
    }
  }

  void reset() {
    state = const CreateReelState();
  }
}

// ─── Provider ─────────────────────────────────────────
final createReelProvider =
    StateNotifierProvider<CreateReelNotifier, CreateReelState>((ref) {
  final reelService = ref.read(reelServiceProvider);
  return CreateReelNotifier(reelService);
});