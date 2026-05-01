// lib/features/post/presentation/providers/create_post_provider.dart

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_service.dart';
import '../providers/feed_provider.dart';

// Upload step enum
enum UploadStep { idle, uploading, processing, success, error }

// ─── CREATE POST STATE ──────────────────────────────────────
class CreatePostState {
  final List<File> selectedImages; // Images chosen by user
  final String caption;
  final String location;
  final bool commentsDisabled;
  final UploadStep uploadStep;
  final double uploadProgress; // 0.0 to 1.0
  final String? errorMessage;
  final PostModel? createdPost; // After success

  const CreatePostState({
    this.selectedImages = const [],
    this.caption = '',
    this.location = '',
    this.commentsDisabled = false,
    this.uploadStep = UploadStep.idle,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.createdPost,
  });

  CreatePostState copyWith({
    List<File>? selectedImages,
    String? caption,
    String? location,
    bool? commentsDisabled,
    UploadStep? uploadStep,
    double? uploadProgress,
    String? errorMessage,
    PostModel? createdPost,
  }) {
    return CreatePostState(
      selectedImages: selectedImages ?? this.selectedImages,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      uploadStep: uploadStep ?? this.uploadStep,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: errorMessage,
      createdPost: createdPost ?? this.createdPost,
    );
  }

  bool get hasImages => selectedImages.isNotEmpty;
  bool get isUploading =>
      uploadStep == UploadStep.uploading || uploadStep == UploadStep.processing;
  int get progressPercent => (uploadProgress * 100).round();
}

// ─── CREATE POST NOTIFIER ───────────────────────────────────
class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final PostService _postService;
  final Ref _ref;

  CreatePostNotifier(this._postService, this._ref)
    : super(const CreatePostState());

  // ─── SET SELECTED IMAGES ──────────────────────────────────
  void setImages(List<File> images) {
    state = state.copyWith(selectedImages: images);
  }

  // ─── ADD MORE IMAGES ──────────────────────────────────────
  void addImages(List<File> newImages) {
    final combined = [...state.selectedImages, ...newImages];
    // Max 10 images
    final limited = combined.take(10).toList();
    state = state.copyWith(selectedImages: limited);
  }

  // ─── REMOVE IMAGE ─────────────────────────────────────────
  void removeImage(int index) {
    final updated = List<File>.from(state.selectedImages);
    updated.removeAt(index);
    state = state.copyWith(selectedImages: updated);
  }

  // ─── REORDER IMAGES ───────────────────────────────────────
  void reorderImages(int oldIndex, int newIndex) {
    final updated = List<File>.from(state.selectedImages);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(selectedImages: updated);
  }

  // ─── SET CAPTION ──────────────────────────────────────────
  void setCaption(String caption) {
    state = state.copyWith(caption: caption);
  }

  // ─── SET LOCATION ─────────────────────────────────────────
  void setLocation(String location) {
    state = state.copyWith(location: location);
  }

  // ─── TOGGLE COMMENTS ──────────────────────────────────────
  void toggleComments() {
    state = state.copyWith(commentsDisabled: !state.commentsDisabled);
  }

  // ─── RESET STATE ──────────────────────────────────────────
  void reset() {
    state = const CreatePostState();
  }

  // ─── UPLOAD POST ──────────────────────────────────────────
  Future<bool> uploadPost() async {
    if (state.selectedImages.isEmpty) return false;

    state = state.copyWith(
      uploadStep: UploadStep.uploading,
      uploadProgress: 0.0,
      errorMessage: null,
    );

    try {
      final post = await _postService.createPost(
        imageFiles: state.selectedImages,
        caption: state.caption.trim().isEmpty ? null : state.caption.trim(),
        location: state.location.trim().isEmpty ? null : state.location.trim(),
        commentsDisabled: state.commentsDisabled,
        onSendProgress: (sent, total) {
          // Update progress bar
          final progress = sent / total;
          state = state.copyWith(
            uploadProgress: progress,
            uploadStep: progress >= 1.0
                ? UploadStep.processing
                : UploadStep.uploading,
          );
        },
      );

      // Success!
      state = state.copyWith(
        uploadStep: UploadStep.success,
        uploadProgress: 1.0,
        createdPost: post,
      );

      // Add new post to feed (so user sees it immediately)
      _ref.read(feedProvider.notifier).addNewPost(post);

      return true;
    } catch (e) {
      state = state.copyWith(
        uploadStep: UploadStep.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, CreatePostState>(
      (ref) => CreatePostNotifier(ref.watch(postServiceProvider), ref),
    );
