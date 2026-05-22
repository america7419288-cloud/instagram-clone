// lib/features/story/presentation/providers/story_create_provider.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/story_model.dart';
import '../../data/repositories/story_service.dart';
import '../providers/story_provider.dart';

// ─── TEXT OVERLAY MODEL ─────────────────────────────────────
class StoryTextOverlay {
  final String id;
  final String text;
  final Color color;
  final double fontSize;
  final Offset position;

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
  final String audience;
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
class StoryCreateNotifier extends Notifier<StoryCreateState> {
  late final StoryService _storyService;

  @override
  StoryCreateState build() {
    _storyService = ref.watch(storyServiceProvider);
    return const StoryCreateState();
  }

  void setImage(File image) {
    state = state.copyWith(selectedImage: image, errorMessage: null);
  }

  void addTextOverlay({
    required String text,
    required Color color,
    required double fontSize,
    required Offset position,
  }) {
    if (text.trim().isEmpty) return;
    final overlay = StoryTextOverlay(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      color: color,
      fontSize: fontSize,
      position: position,
    );
    state = state.copyWith(textOverlays: [...state.textOverlays, overlay]);
  }

  void removeTextOverlay(String id) {
    state = state.copyWith(
      textOverlays: state.textOverlays.where((t) => t.id != id).toList(),
    );
  }

  void updateTextPosition(String id, Offset newPosition) {
    state = state.copyWith(
      textOverlays: state.textOverlays.map((t) {
        if (t.id == id) return t.copyWith(position: newPosition);
        return t;
      }).toList(),
    );
  }

  void toggleAudience() {
    state = state.copyWith(
      audience: state.isCloseFriends ? 'followers' : 'close_friends',
    );
  }

  Future<bool> uploadStory({String? caption}) async {
    if (state.selectedImage == null) return false;

    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      errorMessage: null,
    );

    try {
      final storyCaption = caption?.isNotEmpty == true
          ? caption
          : state.textOverlays.isNotEmpty
              ? state.textOverlays.map((t) => t.text).join(' • ')
              : null;

      // Real upload to backend
      await _storyService.createStory(
        mediaFile: state.selectedImage!,
        mediaType: 'image',
        caption: storyCaption,
        audience: state.audience,
        onProgress: (p) {
          state = state.copyWith(uploadProgress: p);
        },
      );

      state = state.copyWith(uploadProgress: 1.0, isUploading: false, isSuccess: true);

      // Refresh story feed
      ref.invalidate(storyFeedProvider);

      return true;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const StoryCreateState();
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final storyCreateProvider = NotifierProvider<StoryCreateNotifier, StoryCreateState>(
  StoryCreateNotifier.new,
);
