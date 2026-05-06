// lib/features/post/presentation/providers/create_post_provider.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart'; // Required for StateNotifier in Riverpod 3.x
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/models/post_model.dart';
import '../providers/feed_provider.dart';

// Upload step enum
enum UploadStep { idle, uploading, processing, success, error }

// ─── State ────────────────────────────────────────────
class CreatePostState {
  final List<File> selectedImages;
  final String caption;
  final String location;
  final bool commentsDisabled;
  final UploadStep uploadStep;
  final double uploadProgress; // 0.0 → 1.0
  final String? errorMessage;
  final bool success;
  final PostModel? createdPost;

  const CreatePostState({
    this.selectedImages = const [],
    this.caption = '',
    this.location = '',
    this.commentsDisabled = false,
    this.uploadStep = UploadStep.idle,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.success = false,
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
    bool? success,
    PostModel? createdPost,
    bool clearError = false,
  }) {
    return CreatePostState(
      selectedImages: selectedImages ?? this.selectedImages,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      uploadStep: uploadStep ?? this.uploadStep,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      success: success ?? this.success,
      createdPost: createdPost ?? this.createdPost,
    );
  }

  bool get hasImages => selectedImages.isNotEmpty;
  int get progressPercent => (uploadProgress * 100).round();
  String? get error => errorMessage;
  bool get isUploading => uploadStep == UploadStep.uploading || uploadStep == UploadStep.processing;
  bool get isLoading => isUploading;
}

// ─── Notifier ─────────────────────────────────────────
class CreatePostNotifier extends StateNotifier<CreatePostState> {
  final DioClient _dioClient;
  final Ref _ref;

  CreatePostNotifier(this._dioClient, this._ref)
      : super(const CreatePostState());

  // Helper methods for CreatePostPage
  void setImages(List<File> images) {
    state = state.copyWith(selectedImages: images);
  }

  void addImages(List<File> newImages) {
    final combined = [...state.selectedImages, ...newImages];
    final limited = combined.take(10).toList();
    state = state.copyWith(selectedImages: limited);
  }

  void removeImage(int index) {
    final updated = List<File>.from(state.selectedImages);
    updated.removeAt(index);
    state = state.copyWith(selectedImages: updated);
  }

  void setCaption(String caption) {
    state = state.copyWith(caption: caption);
  }

  void setLocation(String location) {
    state = state.copyWith(location: location);
  }

  void toggleComments() {
    state = state.copyWith(commentsDisabled: !state.commentsDisabled);
  }

  void reorderImages(int oldIndex, int newIndex) {
    final updated = List<File>.from(state.selectedImages);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(selectedImages: updated);
  }

  Future<bool> uploadPost({
    List<XFile>? files,
    String? caption,
    String? location,
    List<List<double>>? filterMatrices,
  }) async {
    final uploadFiles = files != null 
        ? files.map((f) => File(f.path)).toList() 
        : state.selectedImages;

    if (uploadFiles.isEmpty) {
      throw Exception('Please select at least one photo or video');
    }

    state = state.copyWith(
      uploadStep: UploadStep.uploading,
      uploadProgress: 0.0,
      clearError: true,
      success: false,
    );

    try {
      final formData = FormData();

      // Add caption and location
      final finalCaption = caption ?? state.caption;
      final finalLocation = location ?? state.location;

      if (finalCaption.isNotEmpty) {
        formData.fields.add(MapEntry('caption', finalCaption));
      }
      if (finalLocation.isNotEmpty) {
        formData.fields.add(MapEntry('location', finalLocation));
      }
      formData.fields.add(MapEntry('comments_disabled', state.commentsDisabled.toString()));

      // Add each file and its corresponding filter
      for (int i = 0; i < uploadFiles.length; i++) {
        final file = uploadFiles[i];
        final fileName = file.path.split('/').last;
        final fileBytes = await file.readAsBytes();

        final ext = fileName.toLowerCase().split('.').last;
        String mimeType = _getMimeType(ext);

        formData.files.add(
          MapEntry(
            'media',
            MultipartFile.fromBytes(
              fileBytes,
              filename: fileName,
              contentType: DioMediaType.parse(mimeType),
            ),
          ),
        );
        
        if (filterMatrices != null && i < filterMatrices.length) {
          formData.fields.add(MapEntry('filters[$i]', filterMatrices[i].join(',')));
        }
      }

      final response = await _dioClient.dio.post(
        AppConstants.postsUrl,
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            state = state.copyWith(
              uploadProgress: progress,
              uploadStep: progress >= 1.0 ? UploadStep.processing : UploadStep.uploading,
            );
          }
        },
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        final postMap = (data is Map && data.containsKey('post')) ? data['post'] : data;
        
        if (postMap == null) {
          throw Exception('Server returned success but no post data');
        }

        final post = PostModel.fromJson(postMap as Map<String, dynamic>);
        
        state = state.copyWith(
          uploadStep: UploadStep.success,
          uploadProgress: 1.0,
          success: true,
          createdPost: post,
        );

        // Add to feed
        _ref.read(feedProvider.notifier).addNewPost(post);
        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to create post');
      }
    } catch (e) {
      String errorMessage = 'Failed to create post';

      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          errorMessage = data['message'].toString();
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          errorMessage = 'Upload timed out. Please try with a shorter video or better connection.';
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }

      state = state.copyWith(
        uploadStep: UploadStep.error,
        errorMessage: errorMessage,
      );

      return false;
    }
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'avi': return 'video/x-msvideo';
      case 'webm': return 'video/webm';
      case '3gp': return 'video/3gpp';
      default: return 'application/octet-stream';
    }
  }

  void reset() {
    state = const CreatePostState();
  }
}

// ─── Provider ─────────────────────────────────────────
final createPostProvider =
    StateNotifierProvider<CreatePostNotifier, CreatePostState>((ref) {
  final dioClient = ref.read(dioClientProvider);
  return CreatePostNotifier(dioClient, ref);
});
