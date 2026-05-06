// lib/features/story/presentation/pages/story_creator_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/repositories/story_service.dart';
import '../providers/story_provider.dart';

// ─── Audience type ────────────────────────────────────
enum StoryAudience { everyone, closeFriends }

class StoryCreatorPage extends ConsumerStatefulWidget {
  const StoryCreatorPage({super.key});

  @override
  ConsumerState<StoryCreatorPage> createState() =>
      _StoryCreatorPageState();
}

class _StoryCreatorPageState extends ConsumerState<StoryCreatorPage>
    with TickerProviderStateMixin {
  // ─── Steps ────────────────────────────────────────────
  int _step = 0; // 0=pick, 1=edit, 2=uploading

  // ─── Selected media ───────────────────────────────────
  File? _mediaFile;
  bool _isVideo = false;
  VideoPlayerController? _videoController;


  // ─── Text overlay ─────────────────────────────────────
  String _textOverlay = '';
  Color  _textColor   = Colors.white;
  double _textSize    = 28;
  bool   _showTextInput = false;
  late final TextEditingController _textController;
  late final FocusNode _textFocus;

  // ─── Audience ─────────────────────────────────────────
  StoryAudience _audience = StoryAudience.everyone;

  // ─── Upload ───────────────────────────────────────────
  double _uploadProgress = 0;
  bool   _isUploading    = false;

  // ─── Picker ───────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _textFocus = FocusNode();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textController.dispose();
    _textFocus.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  // ─── Pick from gallery ────────────────────────────────
  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickMedia();
    if (picked == null) return;
    await _setMedia(File(picked.path), picked.mimeType ?? '');
  }

  // ─── Take photo ───────────────────────────────────────
  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 90,
    );
    if (picked == null) return;
    await _setMedia(File(picked.path), 'image/jpeg');
  }

  // ─── Record video ─────────────────────────────────────
  Future<void> _recordVideo() async {
    final picked = await _picker.pickVideo(
      source:      ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    if (picked == null) return;
    await _setMedia(File(picked.path), 'video/mp4');
  }

  // ─── Set media ────────────────────────────────────────
  Future<void> _setMedia(File file, String mimeType) async {
    final isVideo = mimeType.startsWith('video/') ||
        file.path.toLowerCase().endsWith('.mp4') ||
        file.path.toLowerCase().endsWith('.mov');

    await _videoController?.dispose();
    _videoController = null;

    if (isVideo) {
      final ctrl = kIsWeb 
        ? VideoPlayerController.networkUrl(Uri.parse(file.path))
        : VideoPlayerController.file(file);
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(1);
      ctrl.play();
      setState(() {
        _videoController = ctrl;
        _isVideo = true;
      });
    } else {
      setState(() => _isVideo = false);
    }

    setState(() {
      _mediaFile = file;
      _textOverlay = '';
      _step      = 1;
    });
  }


  Widget _darkField(
    TextEditingController ctrl,
    String label,
    String hint,
  ) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText:   label,
        labelStyle:  const TextStyle(color: Colors.white54),
        hintText:    hint,
        hintStyle:   const TextStyle(color: Colors.white24),
        filled:      true,
        fillColor:   Colors.white12,
        border:      OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:   BorderSide.none,
        ),
      ),
    );
  }

  // ─── Share story ──────────────────────────────────────
  Future<void> _shareStory() async {
    if (_mediaFile == null || _isUploading) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isUploading    = true;
      _uploadProgress = 0;
      _step           = 2;
    });

    try {
      Map<String, dynamic>? pollData;
      Map<String, dynamic>? questionData;

      await ref.read(storyServiceProvider).createStory(
            mediaFile:    _mediaFile!,
            mediaType:    _isVideo ? 'video' : 'image',
            caption:      _textOverlay.isNotEmpty ? _textOverlay : null,
            audience:     _audience == StoryAudience.closeFriends
                ? 'close_friends'
                : 'followers',
            pollData:     pollData,
            questionData: questionData,
            onProgress:   (p) => setState(() => _uploadProgress = p),
          );

      // ─── Refresh story feed ───────────────────────
      ref.invalidate(storyFeedProvider);

      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Story shared! 🎉');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _step        = 1;
        });
        AppSnackbar.error(
          context,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  // ─── Toggle text tool ─────────────────────────────────
  void _toggleTextTool() {
    setState(() => _showTextInput = !_showTextInput);
  }

  // ─── Toggle audience ──────────────────────────────────
  void _toggleAudience() {
    setState(() {
      _audience = _audience == StoryAudience.everyone
          ? StoryAudience.closeFriends
          : StoryAudience.everyone;
    });
    HapticFeedback.selectionClick();
    AppSnackbar.info(
      context,
      _audience == StoryAudience.closeFriends
          ? '👥 Close Friends only'
          : '🌎 Everyone',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: _step == 0
          ? _buildPickerStep()
          : _step == 2
              ? _buildUploadingStep()
              : _buildEditorStep(),
    );
  }

  // ─────────────────────────────────────────────────────
  // STEP 0: PICKER
  // ─────────────────────────────────────────────────────
  Widget _buildPickerStep() {
    return Column(
      children: [
        // ─── App bar ───────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(PhosphorIcons.x(), color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
                const Text(
                  'New Story',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),

        // ─── Options ───────────────────────────────
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width:  90,
                height: 90,
                decoration: BoxDecoration(
                  color:  Colors.white.withValues(alpha: 0.1),
                  shape:  BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.bookOpen(),
                  color: Colors.white,
                  size:  48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Create Your Story',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Share a moment that disappears in 24 hours',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Gallery
              _buildPickerOption(
                icon: PhosphorIcons.image(),
                label: 'Gallery',
                onTap: _pickFromGallery,
              ),
              const SizedBox(height: 14),

              // Camera Photo
              _buildPickerOption(
                icon: PhosphorIcons.camera(),
                label: 'Take Photo',
                onTap: _takePhoto,
                isPrimary: false,
              ),
              const SizedBox(height: 14),

              // Camera Video
              _buildPickerOption(
                icon: PhosphorIcons.videoCamera(),
                label: 'Record Video (15s)',
                onTap: _recordVideo,
                isPrimary: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String   label,
    required VoidCallback onTap,
    bool isPrimary = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:  const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color:  isPrimary
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color:      Colors.white,
                fontSize:   15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────
  // STEP 1: EDITOR
  // ─────────────────────────────────────────────────────
  Widget _buildEditorStep() {
    final size = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Media preview ─────────────────────────────
          Positioned.fill(child: _buildMediaPreview()),

          // ─── Text overlay (if any) ─────────────────────
          if (_textOverlay.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _textOverlay,
                  style: TextStyle(
                    color:      _textColor,
                    fontSize:   _textSize,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),


          // ─── Top bar ───────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildEditorTopBar()),
          ),

          // ─── Bottom bar ────────────────────────────────
          Positioned(
            bottom: 0,
            left:   0,
            right:  0,
            child:  SafeArea(child: _buildEditorBottomBar()),
          ),

          // ─── Text input overlay ────────────────────────
          if (_showTextInput)
            _buildTextInputOverlay(),
        ],
      ),
    );
  }

  // ─── Media preview ────────────────────────────────────
  Widget _buildMediaPreview() {
    if (_mediaFile == null) return Container(color: Colors.black);

    if (_isVideo && _videoController != null &&
        _videoController!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width:  _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child:  VideoPlayer(_videoController!),
        ),
      );
    }

    if (kIsWeb) {
      return Image.network(
        _mediaFile!.path,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Image.file(
      _mediaFile!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }


  // ─── Editor top bar ───────────────────────────────────
  Widget _buildEditorTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Back
          _glassBtn(PhosphorIcons.caretLeft(), () {
            _videoController?.dispose();
            _videoController = null;
            setState(() {
              _step      = 0;
              _mediaFile = null;
              _textOverlay = '';
            });
          }),

          const Spacer(),

          // Text tool
          _glassBtn(PhosphorIcons.textT(), _toggleTextTool),
          const SizedBox(width: 8),


          // Audience
          GestureDetector(
            onTap: _toggleAudience,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color:        _audience == StoryAudience.closeFriends
                    ? Colors.green.withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _audience == StoryAudience.closeFriends
                        ? PhosphorIcons.users()
                        : PhosphorIcons.globe(),
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _audience == StoryAudience.closeFriends
                        ? 'Close Friends'
                        : 'Everyone',
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   12,
                      fontWeight: FontWeight.w600,
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

  // ─── Editor bottom bar ────────────────────────────────
  Widget _buildEditorBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.bottomCenter,
          end:    Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Row(
        children: [
          // Discard
          GestureDetector(
            onTap: () {
              _videoController?.dispose();
              _videoController = null;
              setState(() {
                _step      = 0;
                _mediaFile = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color:        Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Discard',
                style: TextStyle(
                  color:      Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Share button
          GestureDetector(
            onTap: _shareStory,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color:        AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Share to Story',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(PhosphorIcons.arrowRight(), color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Text input overlay ───────────────────────────────
  Widget _buildTextInputOverlay() {
    _textController.text = _textOverlay;

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Column(
          children: [
            // Color picker
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Colors.white,
                  Colors.yellow,
                  Colors.pink,
                  Colors.cyan,
                  Colors.green,
                  Colors.orange,
                ].map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => _textColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _textColor == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Text field
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocus,
                    autofocus: true,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _textSize,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      hintText: 'Type something...',
                      hintStyle: TextStyle(
                        color: Colors.white38,
                        fontSize: 24,
                      ),
                    ),
                    onChanged: (v) => _textOverlay = v,
                  ),
                ),
              ),
            ),

            // Done button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _textFocus.unfocus();
                  setState(() {
                    _textOverlay = _textController.text;
                    _showTextInput = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
              // ─── Uploading step ───────────────────────────────────
  Widget _buildUploadingStep() {
    final pct = (_uploadProgress * 100).toInt();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width:  100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width:  100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value:           _uploadProgress > 0 ? _uploadProgress : null,
                    strokeWidth:     4,
                    color:           AppColors.primary,
                    backgroundColor: Colors.white24,
                  ),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sharing your story...',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please keep the app open',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Helper ───────────────────────────────────────────
  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  40,
        height: 40,
        decoration: BoxDecoration(
          color:  Colors.black.withValues(alpha: 0.45),
          shape:  BoxShape.circle,
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
