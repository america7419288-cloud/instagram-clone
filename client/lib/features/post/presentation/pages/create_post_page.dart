// lib/features/post/presentation/pages/create_post_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/create_post_provider.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _captionFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  // Max characters for caption
  static const int _maxCaptionLength = 2200;

  @override
  void initState() {
    super.initState();
    _captionController.addListener(_onCaptionChanged);
  }

  @override
  void dispose() {
    _captionController.removeListener(_onCaptionChanged);
    _captionController.dispose();
    _locationController.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  void _onCaptionChanged() {
    ref.read(createPostProvider.notifier).setCaption(_captionController.text);
  }

  // ─── PICK FROM GALLERY ───────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 100,
      );

      if (pickedFiles.isEmpty) return;

      final currentCount = ref.read(createPostProvider).selectedImages.length;
      final int remaining = 10 - currentCount;

      if (remaining <= 0) {
        _showMaxImagesSnackbar();
        return;
      }

      // Limit to remaining slots
      final toAdd = pickedFiles.take(remaining).toList();
      final files = toAdd.map((x) => File(x.path)).toList();

      ref.read(createPostProvider.notifier).addImages(files);
    } catch (e) {
      _showErrorSnackbar('Failed to pick images: $e');
    }
  }

  // ─── PICK FROM CAMERA ────────────────────────────────────
  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 100,
      );

      if (photo == null) return;

      final currentCount = ref.read(createPostProvider).selectedImages.length;
      if (currentCount >= 10) {
        _showMaxImagesSnackbar();
        return;
      }

      ref.read(createPostProvider.notifier).addImages([File(photo.path)]);
    } catch (e) {
      _showErrorSnackbar('Failed to open camera: $e');
    }
  }

  // ─── CROP IMAGE ──────────────────────────────────────────
  Future<void> _cropImage(int index) async {
    try {
      final file = ref.read(createPostProvider).selectedImages[index];

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        maxWidth: 4096,
        maxHeight: 4096,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset4x5(),
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.original,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset4x5(),
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (croppedFile != null) {
        final images = List<File>.from(
          ref.read(createPostProvider).selectedImages,
        );
        images[index] = File(croppedFile.path);
        ref.read(createPostProvider.notifier).setImages(images);
      }
    } catch (e) {
      _showErrorSnackbar('Failed to crop image: $e');
    }
  }

  // ─── SHOW SOURCE PICKER ───────────────────────────────────
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Add Photos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.background,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.textPrimary,
                  ),
                ),
                title: const Text('Photo Library'),
                subtitle: const Text('Choose from your gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),

              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.background,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.textPrimary,
                  ),
                ),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── UPLOAD POST ─────────────────────────────────────────
  Future<void> _uploadPost() async {
    FocusScope.of(context).unfocus();

    final success = await ref.read(createPostProvider.notifier).uploadPost();

    if (success && mounted) {
      // Show success message
      AppSnackbar.success(context, 'Post shared successfully!');

      // Reset create post state
      ref.read(createPostProvider.notifier).reset();

      // Navigate to home feed
      if (mounted) context.go(AppRoutes.home);
    }
  }

  // ─── CONFIRM DISCARD ─────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    final hasContent =
        ref.read(createPostProvider).hasImages ||
        _captionController.text.isNotEmpty;

    if (!hasContent) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard Post?'),
        content: const Text('If you go back now, your post will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
            child: const Text(
              'Discard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showMaxImagesSnackbar() {
    AppSnackbar.warning(context, 'Maximum 10 images per post');
  }

  void _showErrorSnackbar(String message) {
    AppSnackbar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createPostProvider);

    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Scaffold(
        backgroundColor: AppColors.white,

        // ─── APP BAR ──────────────────────────────────────
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () async {
              if (await _confirmDiscard()) {
                if (mounted) {
                  ref.read(createPostProvider.notifier).reset();
                  context.pop();
                }
              }
            },
            icon: const Icon(Icons.close, color: AppColors.textPrimary),
          ),
          title: const Text(
            'New Post',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            // Share button
            TextButton(
              onPressed: createState.hasImages && !createState.isUploading
                  ? _uploadPost
                  : null,
              child: Text(
                'Share',
                style: TextStyle(
                  color: createState.hasImages && !createState.isUploading
                      ? AppColors.primary
                      : AppColors.border,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),

        // ─── BODY ─────────────────────────────────────────
        body: createState.isUploading
            ? _buildUploadingState(createState)
            : createState.uploadStep == UploadStep.error
            ? _buildErrorState(createState)
            : _buildCreateForm(createState),
      ),
    );
  }

  // ─── MAIN CREATE FORM ─────────────────────────────────────
  Widget _buildCreateForm(CreatePostState createState) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image section
          if (!createState.hasImages)
            _buildImagePicker()
          else
            _buildImagePreview(createState),

          const Divider(height: 1, color: AppColors.border),

          // Caption input
          _buildCaptionInput(createState),

          const Divider(height: 1, color: AppColors.border),

          // Location input
          _buildLocationInput(),

          const Divider(height: 1, color: AppColors.border),

          // Advanced settings
          _buildAdvancedSettings(createState),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── IMAGE PICKER (empty state) ───────────────────────────
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _showImageSourcePicker,
      child: Container(
        width: double.infinity,
        height: 300,
        color: AppColors.background,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.border.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to select from gallery or camera',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFromGallery,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.photo_library, size: 20),
              label: const Text(
                'Select Photos',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickFromCamera,
              icon: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.textSecondary,
              ),
              label: const Text(
                'Take Photo',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── IMAGE PREVIEW (with images selected) ─────────────────
  Widget _buildImagePreview(CreatePostState createState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main image preview (first image large)
        Stack(
          children: [
            // Main image
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.black,
              child: Image.file(
                createState.selectedImages[0],
                fit: BoxFit.contain,
              ),
            ),

            // Add more button (top right)
            if (createState.selectedImages.length < 10)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: _showImageSourcePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${createState.selectedImages.length}/10',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Thumbnails row (reorderable)
        if (createState.selectedImages.length > 1)
          SizedBox(
            height: 80,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: createState.selectedImages.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                ref
                    .read(createPostProvider.notifier)
                    .reorderImages(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                return _ThumbnailItem(
                  key: ValueKey(createState.selectedImages[index].path),
                  file: createState.selectedImages[index],
                  index: index,
                  isFirst: index == 0,
                  onRemove: () =>
                      ref.read(createPostProvider.notifier).removeImage(index),
                  onCrop: () => _cropImage(index),
                );
              },
            ),
          ),

        // Image count indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${createState.selectedImages.length} photo${createState.selectedImages.length > 1 ? 's' : ''} selected',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              Text(
                'Hold & drag to reorder',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── CAPTION INPUT ────────────────────────────────────────
  Widget _buildCaptionInput(CreatePostState createState) {
    final charCount = _captionController.text.length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          const Text(
            'Caption',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          // Text field
          TextField(
            controller: _captionController,
            focusNode: _captionFocus,
            maxLines: 6,
            minLines: 3,
            maxLength: _maxCaptionLength,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Write a caption... #hashtag @mention',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
              border: InputBorder.none,
              counterText: '', // Hide default counter
              contentPadding: EdgeInsets.zero,
            ),
          ),

          // Character counter
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '$charCount / $_maxCaptionLength',
                style: TextStyle(
                  color: charCount > _maxCaptionLength * 0.9
                      ? AppColors.secondary
                      : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── LOCATION INPUT ───────────────────────────────────────
  Widget _buildLocationInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _locationController,
        style: const TextStyle(fontSize: 15),
        onChanged: (value) {
          ref.read(createPostProvider.notifier).setLocation(value);
        },
        decoration: const InputDecoration(
          hintText: 'Add location',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          prefixIcon: Icon(
            Icons.location_on_outlined,
            color: AppColors.textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ─── ADVANCED SETTINGS ────────────────────────────────────
  Widget _buildAdvancedSettings(CreatePostState createState) {
    return Column(
      children: [
        // Turn off commenting
        SwitchListTile(
          value: createState.commentsDisabled,
          onChanged: (_) {
            ref.read(createPostProvider.notifier).toggleComments();
          },
          title: const Text(
            'Turn off commenting',
            style: TextStyle(fontSize: 15),
          ),
          subtitle: const Text(
            'People will not be able to comment on this post',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          activeColor: AppColors.primary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
        ),
      ],
    );
  }

  // ─── UPLOADING STATE ─────────────────────────────────────
  Widget _buildUploadingState(CreatePostState createState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated upload icon
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: createState.uploadProgress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${createState.progressPercent}%',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            Text(
              createState.uploadStep == UploadStep.processing
                  ? 'Processing your post...'
                  : 'Uploading ${createState.selectedImages.length} photo${createState.selectedImages.length > 1 ? 's' : ''}...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              "Please don't close the app",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),

            const SizedBox(height: 24),

            // Preview thumbnails during upload
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: createState.selectedImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(createState.selectedImages[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ERROR STATE ──────────────────────────────────────────
  Widget _buildErrorState(CreatePostState createState) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 72,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Failed',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              createState.errorMessage ??
                  'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _uploadPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref.read(createPostProvider.notifier).reset();
                context.pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── THUMBNAIL ITEM (reorderable) ───────────────────────────
class _ThumbnailItem extends StatelessWidget {
  final File file;
  final int index;
  final bool isFirst;
  final VoidCallback onRemove;
  final VoidCallback onCrop;

  const _ThumbnailItem({
    super.key,
    required this.file,
    required this.index,
    required this.isFirst,
    required this.onRemove,
    required this.onCrop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
      child: Stack(
        children: [
          // Thumbnail image
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                border: isFirst
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
            ),
          ),

          // "Cover" label on first image
          if (isFirst)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: const Text(
                  'COVER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Remove button (top right)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),

          // Crop button (bottom right)
          Positioned(
            bottom: isFirst ? 18 : 2,
            right: 2,
            child: GestureDetector(
              onTap: onCrop,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.crop, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CropAspectRatioPreset4x5 implements CropAspectRatioPresetData {
  @override
  String get name => '4x5';

  @override
  (int, int)? get data => (4, 5);
}
