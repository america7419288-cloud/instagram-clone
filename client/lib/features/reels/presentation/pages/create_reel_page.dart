// lib/features/reels/presentation/pages/create_reel_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/create_reel_provider.dart';
import '../providers/reel_provider.dart';

class CreateReelPage extends ConsumerStatefulWidget {
  const CreateReelPage({super.key});

  @override
  ConsumerState<CreateReelPage> createState() => _CreateReelPageState();
}

class _CreateReelPageState extends ConsumerState<CreateReelPage>
    with TickerProviderStateMixin {
  // ─── Steps ────────────────────────────────────────────
  // Step 0 = pick video
  // Step 1 = preview + details
  int _step = 0;

  // ─── Selected video ───────────────────────────────────
  File? _videoFile;
  VideoPlayerController? _previewController;
  int _durationSeconds = 0;
  bool _isMuted = false;

  // ─── Form fields ──────────────────────────────────────
  final TextEditingController _captionController =
      TextEditingController();
  final TextEditingController _audioNameController =
      TextEditingController();
  final FocusNode _captionFocus = FocusNode();

  // ─── Picker ───────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();

  // ─── Max duration ─────────────────────────────────────
  static const int _maxSeconds = 90;

  @override
  void initState() {
    super.initState();
    // Go fullscreen
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _previewController?.dispose();
    _captionController.dispose();
    _audioNameController.dispose();
    _captionFocus.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────
  // PICK VIDEO FROM GALLERY
  // ─────────────────────────────────────────────────────
  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: _maxSeconds),
      );
      if (picked == null) return;
      await _setVideo(File(picked.path));
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not open gallery: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────
  // RECORD FROM CAMERA
  // ─────────────────────────────────────────────────────
  Future<void> _recordFromCamera() async {
    try {
      final XFile? recorded = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: _maxSeconds),
        preferredCameraDevice: CameraDevice.rear,
      );
      if (recorded == null) return;
      await _setVideo(File(recorded.path));
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, 'Could not open camera: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────
  // SET VIDEO (validate + initialize preview)
  // ─────────────────────────────────────────────────────
  Future<void> _setVideo(File file) async {
    // ─── Validate duration ────────────────────────────
    final tempController = VideoPlayerController.file(file);
    await tempController.initialize();
    final duration = tempController.value.duration.inSeconds;
    await tempController.dispose();

    if (duration > _maxSeconds) {
      if (mounted) {
        AppSnackbar.error(
          context,
          'Video is ${duration}s. Reels must be $_maxSeconds seconds or less.',
        );
      }
      return;
    }

    if (duration < 1) {
      if (mounted) {
        AppSnackbar.error(context, 'Video is too short.');
      }
      return;
    }

    // ─── Initialize preview controller ───────────────
    await _previewController?.dispose();

    final controller = VideoPlayerController.file(file);
    await controller.initialize();
    controller.setLooping(true);
    controller.setVolume(_isMuted ? 0.0 : 1.0);
    controller.play();

    if (!mounted) return;

    setState(() {
      _videoFile = file;
      _previewController = controller;
      _durationSeconds = duration;
      _step = 1; // move to details step
    });
  }

  // ─────────────────────────────────────────────────────
  // TOGGLE MUTE
  // ─────────────────────────────────────────────────────
  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _previewController?.setVolume(_isMuted ? 0.0 : 1.0);
    HapticFeedback.selectionClick();
  }

  // ─────────────────────────────────────────────────────
  // UPLOAD REEL
  // ─────────────────────────────────────────────────────
  Future<void> _uploadReel() async {
    if (_videoFile == null) return;
    _captionFocus.unfocus();
    HapticFeedback.lightImpact();

    try {
      await ref.read(createReelProvider.notifier).uploadReel(
            videoFile: _videoFile!,
            caption: _captionController.text.trim(),
            audioName: _audioNameController.text.trim().isEmpty
                ? 'Original audio'
                : _audioNameController.text.trim(),
          );

      // ─── Refresh reel feed ────────────────────────
      ref.read(reelFeedProvider.notifier).refresh();

      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Reel shared successfully! 🎉');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────
  // BACK (step 1 → step 0, or close)
  // ─────────────────────────────────────────────────────
  void _handleBack() {
    if (_step == 1) {
      _previewController?.dispose();
      _previewController = null;
      setState(() {
        _step = 0;
        _videoFile = null;
        _durationSeconds = 0;
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createReelProvider);

    return WillPopScope(
      onWillPop: () async {
        if (createState.isUploading) return false;
        _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _step == 0
            ? _buildPickerStep()
            : _buildDetailsStep(createState),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // STEP 0: PICK VIDEO
  // ─────────────────────────────────────────────────────
  Widget _buildPickerStep() {
    return SafeArea(
      child: Column(
        children: [
          // ─── App bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
                const Text(
                  'New Reel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // ─── Pick options ──────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Create a Reel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share a video up to $_maxSeconds seconds',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),

                // ─── Gallery button ──────────────────
                _PickerOptionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from gallery',
                  onTap: _pickFromGallery,
                ),
                const SizedBox(height: 16),

                // ─── Camera button ───────────────────
                _PickerOptionButton(
                  icon: Icons.videocam_outlined,
                  label: 'Record with camera',
                  onTap: _recordFromCamera,
                  isPrimary: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // STEP 1: PREVIEW + DETAILS
  // ─────────────────────────────────────────────────────
  Widget _buildDetailsStep(CreateReelState createState) {
    return Stack(
      children: [
        // ─── Video preview (full screen background) ───
        _buildVideoPreview(),

        // ─── Uploading overlay ────────────────────────
        if (createState.isUploading) _buildUploadingOverlay(createState),

        // ─── UI layer ─────────────────────────────────
        if (!createState.isUploading)
          _buildDetailsUI(createState),
      ],
    );
  }

  // ─── Full screen video preview ────────────────────────
  Widget _buildVideoPreview() {
    if (_previewController == null ||
        !_previewController!.value.isInitialized) {
      return Container(color: Colors.black);
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _previewController!.value.size.width,
          height: _previewController!.value.size.height,
          child: VideoPlayer(_previewController!),
        ),
      ),
    );
  }

  // ─── Details UI layer ─────────────────────────────────
  Widget _buildDetailsUI(CreateReelState createState) {
    return SafeArea(
      child: Column(
        children: [
          // ─── Top bar ───────────────────────────────
          _buildTopBar(),

          const Spacer(),

          // ─── Bottom panel ──────────────────────────
          _buildBottomPanel(),
        ],
      ),
    );
  }

  // ─── Top bar (back + mute + share) ────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Back button
          _GlassIconButton(
            icon: Icons.arrow_back,
            onTap: _handleBack,
          ),
          const Spacer(),

          // Duration badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_durationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Mute button
          _GlassIconButton(
            icon: _isMuted ? Icons.volume_off : Icons.volume_up,
            onTap: _toggleMute,
          ),
        ],
      ),
    );
  }

  // ─── Bottom panel (gradient + fields + share) ─────────
  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.92),
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Caption field ────────────────────────
          _buildField(
            controller: _captionController,
            focusNode: _captionFocus,
            hint: 'Write a caption...',
            icon: Icons.edit_outlined,
            maxLines: 3,
            maxLength: 2200,
          ),

          const SizedBox(height: 12),

          // ─── Audio name field ─────────────────────
          _buildField(
            controller: _audioNameController,
            hint: 'Audio name (optional)',
            icon: Icons.music_note_outlined,
            maxLines: 1,
          ),

          const SizedBox(height: 20),

          // ─── Share button ─────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _uploadReel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Share Reel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Text field ───────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: maxLines,
              minLines: 1,
              maxLength: maxLength,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                filled: false,
                isDense: true,
                counterStyle: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Uploading overlay ────────────────────────────────
  Widget _buildUploadingOverlay(CreateReelState createState) {
    final progress = createState.uploadProgress;
    final percent = (progress * 100).toInt();

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Circular progress ────────────────────
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 4,
                      color: AppColors.primary,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Uploading reel...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              progress < 1.0
                  ? 'Please keep the app open'
                  : 'Processing...',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────
  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────
// PICKER OPTION BUTTON
// ─────────────────────────────────────────────────────
class _PickerOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _PickerOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.5,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// GLASS ICON BUTTON (for top bar)
// ─────────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
