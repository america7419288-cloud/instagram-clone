// lib/features/story/presentation/pages/story_create_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/story_create_provider.dart';

class StoryCreatePage extends ConsumerStatefulWidget {
  const StoryCreatePage({super.key});

  @override
  ConsumerState<StoryCreatePage> createState() => _StoryCreatePageState();
}

class _StoryCreatePageState extends ConsumerState<StoryCreatePage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();

  // Text overlay state
  bool _isAddingText = false;
  final TextEditingController _textController = TextEditingController();
  Color _selectedTextColor = Colors.white;
  double _selectedFontSize = 32.0;
  String? _activeTextId; // Which text is being dragged

  // Available text colors
  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.pink,
    Colors.orange,
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // ─── PICK FROM GALLERY ────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2160,
        maxHeight: 3840,
        imageQuality: 100,
      );

      if (picked != null && mounted) {
        ref.read(storyCreateProvider.notifier).setImage(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Error: $e');
      }
    }
  }

  // ─── PICK FROM CAMERA ─────────────────────────────────────
  Future<void> _pickFromCamera() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2160,
        maxHeight: 3840,
        imageQuality: 100,
      );

      if (picked != null && mounted) {
        ref.read(storyCreateProvider.notifier).setImage(File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Error: $e');
      }
    }
  }

  // ─── SHOW IMAGE SOURCE PICKER ─────────────────────────────
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add to Your Story',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.white10,
                child: Icon(Icons.photo_library_outlined, color: Colors.white),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.white10,
                child: Icon(Icons.camera_alt_outlined, color: Colors.white),
              ),
              title: const Text(
                'Take a Photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── SHOW TEXT INPUT ──────────────────────────────────────
  void _showTextInput(BuildContext context) {
    setState(() {
      _isAddingText = true;
      _textController.clear();
    });

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text preview
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _textController.text.isEmpty
                        ? 'Type something...'
                        : _textController.text,
                    style: TextStyle(
                      color: _selectedTextColor,
                      fontSize: _selectedFontSize,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Text input
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _textController,
                    autofocus: true,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Add text to your story...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ),

                const SizedBox(height: 12),

                // Color picker row
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _textColors.length,
                    itemBuilder: (_, i) {
                      final color = _textColors[i];
                      final isSelected = color == _selectedTextColor;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            _selectedTextColor = color;
                          });
                          setState(() {
                            _selectedTextColor = color;
                          });
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              width: isSelected ? 3 : 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Font size slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Text(
                        'A',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      Expanded(
                        child: Slider(
                          value: _selectedFontSize,
                          min: 16,
                          max: 60,
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedFontSize = value;
                            });
                            setState(() {
                              _selectedFontSize = value;
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'A',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _isAddingText = false);
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _textController.text.trim().isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                setState(() => _isAddingText = false);

                                // Add text overlay at center
                                ref
                                    .read(storyCreateProvider.notifier)
                                    .addTextOverlay(
                                      text: _textController.text,
                                      color: _selectedTextColor,
                                      fontSize: _selectedFontSize,
                                      position: const Offset(
                                        0.5,
                                        0.5,
                                      ), // Center
                                    );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Add Text'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── UPLOAD STORY ─────────────────────────────────────────
  Future<void> _uploadStory() async {
    final success = await ref.read(storyCreateProvider.notifier).uploadStory();

    if (success && mounted) {
      AppSnackbar.success(context, 'Story posted!');

      // Reset state
      ref.read(storyCreateProvider.notifier).reset();

      // Navigate to home
      if (mounted) context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(storyCreateProvider);

    return Scaffold(
      backgroundColor: Colors.black,

      body: createState.isUploading
          ? _buildUploadingState(createState)
          : createState.hasImage
          ? _buildImageEditor(createState)
          : _buildImagePicker(),
    );
  }

  // ─── IMAGE PICKER (no image selected) ────────────────────
  Widget _buildImagePicker() {
    return Stack(
      children: [
        // Dark background
        Container(
          color: const Color(0xFF1A1A1A),
          width: double.infinity,
          height: double.infinity,
        ),

        // Close button
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),

        // Center content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Camera icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 2),
                ),
                child: const Icon(
                  Icons.add_a_photo_outlined,
                  color: Colors.white,
                  size: 48,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Create Your Story',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Share a photo or video with your followers',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Gallery button
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),

              const SizedBox(height: 16),

              // Camera button
              OutlinedButton.icon(
                onPressed: _pickFromCamera,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text(
                  'Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── IMAGE EDITOR (image selected) ───────────────────────
  Widget _buildImageEditor(StoryCreateState createState) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── BACKGROUND IMAGE ──────────────────────────────
        Image.file(
          createState.selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),

        // Dark gradient overlay (top + bottom)
        _buildGradientOverlays(),

        // ─── TEXT OVERLAYS ────────────────────────────────
        ...createState.textOverlays.map(
          (overlay) => _buildDraggableText(overlay),
        ),

        // ─── TOP CONTROLS ─────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // Close button
                    IconButton(
                      onPressed: () => _confirmClose(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    const Spacer(),

                    // Text tool
                    _TopToolButton(
                      icon: Icons.text_fields,
                      label: 'Text',
                      onTap: () => _showTextInput(context),
                    ),

                    const SizedBox(width: 8),

                    // Change image
                    _TopToolButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: _showImageSourcePicker,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── BOTTOM CONTROLS ──────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close Friends toggle
                  _buildAudienceSelector(createState),

                  const SizedBox(height: 16),

                  // Share button
                  Row(
                    children: [
                      // Discard button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _confirmClose(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Discard',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Share button
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: _uploadStory,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              gradient: AppColors.instagramGradient,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Share to Story',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Error message
        if (createState.errorMessage != null)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                createState.errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // ─── GRADIENT OVERLAYS ────────────────────────────────────
  Widget _buildGradientOverlays() {
    return Column(
      children: [
        // Top gradient
        Container(
          height: 150,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        // Bottom gradient
        Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  // ─── DRAGGABLE TEXT OVERLAY ───────────────────────────────
  Widget _buildDraggableText(StoryTextOverlay overlay) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final x = overlay.position.dx * constraints.maxWidth;
        final y = overlay.position.dy * constraints.maxHeight;

        return Positioned(
          left: x - 100, // Center the text widget
          top: y - overlay.fontSize / 2,
          child: GestureDetector(
            // Double tap to remove
            onDoubleTap: () {
              ref
                  .read(storyCreateProvider.notifier)
                  .removeTextOverlay(overlay.id);
            },
            // Drag to reposition
            onPanUpdate: (details) {
              final newX =
                  (overlay.position.dx * constraints.maxWidth +
                      details.delta.dx) /
                  constraints.maxWidth;
              final newY =
                  (overlay.position.dy * constraints.maxHeight +
                      details.delta.dy) /
                  constraints.maxHeight;

              ref
                  .read(storyCreateProvider.notifier)
                  .updateTextPosition(
                    overlay.id,
                    Offset(newX.clamp(0.0, 1.0), newY.clamp(0.0, 1.0)),
                  );
            },
            child: SizedBox(
              width: 200,
              child: Text(
                overlay.text,
                style: TextStyle(
                  color: overlay.color,
                  fontSize: overlay.fontSize,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 6,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── AUDIENCE SELECTOR ───────────────────────────────────
  Widget _buildAudienceSelector(StoryCreateState createState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            createState.isCloseFriends ? Icons.star : Icons.public,
            color: createState.isCloseFriends ? Colors.green : Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            createState.isCloseFriends ? 'Close Friends' : 'Your Followers',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                ref.read(storyCreateProvider.notifier).toggleAudience(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: createState.isCloseFriends
                    ? Colors.green
                    : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                createState.isCloseFriends ? 'On' : 'Change',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UPLOADING STATE ─────────────────────────────────────
  Widget _buildUploadingState(StoryCreateState createState) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Story thumbnail
            if (createState.selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  createState.selectedImage!,
                  width: 120,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),

            const SizedBox(height: 32),

            // Animated progress indicator
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: createState.uploadProgress,
                    strokeWidth: 5,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                  Text(
                    '${(createState.uploadProgress * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Sharing your story...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Don't close the app",
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ─── CONFIRM CLOSE ────────────────────────────────────────
  Future<void> _confirmClose(BuildContext context) async {
    final createState = ref.read(storyCreateProvider);

    if (!createState.hasImage) {
      ref.read(storyCreateProvider.notifier).reset();
      context.pop();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard Story?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'If you go back, your story will be discarded.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Keep Editing',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ref.read(storyCreateProvider.notifier).reset();
      context.pop();
    }
  }
}

// ─── TOP TOOL BUTTON ─────────────────────────────────────────
class _TopToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
