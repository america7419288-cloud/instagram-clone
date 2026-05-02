// lib/features/story/presentation/providers/story_create_provider.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/story_service.dart';
import '../providers/story_provider.dart';

// ─── TEXT OVERLAY MODEL ─────────────────────────────────────
// Represents a text overlay on the story image
class StoryTextOverlay {
  final String id;
  final String text;
  final Color color;
  final double fontSize;
  final Offset position; // 0.0 to 1.0 relative position

  const StoryTextOverlay({
    required this.id,
    required this.text,
    required this.color,
    required this.fontSize,
    required this.position,
  });

  StoryTextOverlay copyWith({
    String? text,
    Color? color,
    double? fontSize,
    Offset? position,
  }) {
    return StoryTextOverlay(
      id: id,
      text: text ?? this.text,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      position: position ?? this.position,
    );
  }
}

// ─── STORY CREATE STATE ─────────────────────────────────────
class StoryCreateState {
  final File? selectedImage;
  final List<StoryTextOverlay> textOverlays;
  final String audience; // 'followers' or 'close_friends'
  final bool isUploading;
  final double uploadProgress;
  final String? errorMessage;
  final bool isSuccess;

  const StoryCreateState({
    this.selectedImage,
    this.textOverlays = const [],
    this.audience = 'followers',
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.isSuccess = false,
  });

  StoryCreateState copyWith({
    File? selectedImage,
    List<StoryTextOverlay>? textOverlays,
    String? audience,
    bool? isUploading,
    double? uploadProgress,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return StoryCreateState(
      selectedImage: selectedImage ?? this.selectedImage,
      textOverlays: textOverlays ?? this.textOverlays,
      audience: audience ?? this.audience,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  bool get hasImage => selectedImage != null;
  bool get hasTextOverlays => textOverlays.isNotEmpty;
  bool get isCloseFriends => audience == 'close_friends';
}

// ─── STORY CREATE NOTIFIER ───────────────────────────────────
class StoryCreateNotifier extends StateNotifier<StoryCreateState> {
  final StoryService _storyService;
  final Ref _ref;

  StoryCreateNotifier(this._storyService, this._ref)
      : super(const StoryCreateState());

  // ─── SET IMAGE ────────────────────────────────────────────
  void setImage(File image) {
    if (!mounted) return;
    state = state.copyWith(
      selectedImage: image,
      errorMessage: null,
    );
  }

  // ─── ADD TEXT OVERLAY ─────────────────────────────────────
  void addTextOverlay({
    required String text,
    required Color color,
    required double fontSize,
    required Offset position,
  }) {
    if (!mounted || text.trim().isEmpty) return;

    final overlay = StoryTextOverlay(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      color: color,
      fontSize: fontSize,
      position: position,
    );

    state = state.copyWith(
      textOverlays: [...state.textOverlays, overlay],
    );
  }

  // ─── REMOVE TEXT OVERLAY ──────────────────────────────────
  void removeTextOverlay(String id) {
    if (!mounted) return;
    state = state.copyWith(
      textOverlays: state.textOverlays
          .where((t) => t.id != id)
          .toList(),
    );
  }

  // ─── UPDATE TEXT OVERLAY POSITION ────────────────────────
  void updateTextPosition(String id, Offset newPosition) {
    if (!mounted) return;
    state = state.copyWith(
      textOverlays: state.textOverlays.map((t) {
        if (t.id == id) return t.copyWith(position: newPosition);
        return t;
      }).toList(),
    );
  }

  // ─── TOGGLE AUDIENCE ──────────────────────────────────────
  void toggleAudience() {
    if (!mounted) return;
    state = state.copyWith(
      audience: state.isCloseFriends ? 'followers' : 'close_friends',
    );
  }

  // ─── UPLOAD STORY ─────────────────────────────────────────
  Future<bool> uploadStory({String? caption}) async {
    if (!mounted || state.selectedImage == null) return false;

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      errorMessage: null,
    );

    try {
      // Build caption from text overlays if no explicit caption
      final storyCaption = caption?.isNotEmpty == true
          ? caption
          : state.textOverlays.isNotEmpty
              ? state.textOverlays.map((t) => t.text).join(' • ')
              : null;

      // Simulate progress (real progress from Cloudinary)
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return false;
        state = state.copyWith(
          uploadProgress: i / 10 * 0.7, // Up to 70% for upload
        );
      }

      // Upload to backend
      final story = await _storyService.createStory(
        imageFile: state.selectedImage!,
        caption: storyCaption,
        audience: state.audience,
      );

      if (!mounted) return false;

      // Complete progress
      state = state.copyWith(uploadProgress: 1.0);

      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return false;

      // Update story feed provider
      _ref.read(storyFeedProvider.notifier).addStoryToMyGroup(story);

      state = state.copyWith(
        isUploading: false,
        isSuccess: true,
      );

      return true;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        isUploading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  // ─── RESET ────────────────────────────────────────────────
  void reset() {
    if (!mounted) return;
    state = const StoryCreateState();
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final storyCreateProvider = StateNotifierProvider<
    StoryCreateNotifier, StoryCreateState>((ref) {
  return StoryCreateNotifier(
    ref.watch(storyServiceProvider),
    ref,
  );
});

