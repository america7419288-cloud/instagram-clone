// lib/features/story/presentation/pages/story_creator_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/story_advanced_model.dart';
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

  // ─── Sticker ─────────────────────────────────────────
  StoryStickerData? _sticker;

  // ─── Text overlay ─────────────────────────────────────
  String _textOverlay = '';
  Color  _textColor   = Colors.white;
  double _textSize    = 28;
  bool   _showTextInput = false;

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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  }

  @override
  void dispose() {
    _videoController?.dispose();
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
      final ctrl = VideoPlayerController.file(file);
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
      _sticker   = null;
      _textOverlay = '';
      _step      = 1;
    });
  }

  // ─── Add sticker ──────────────────────────────────────
  void _addPollSticker() {
    _showPollDialog();
  }

  void _addQuestionSticker() {
    _showQuestionDialog();
  }

  void _addEmojiSticker(String emoji) {
    setState(() {
      _sticker = StoryStickerData(
        type:  StoryStickerType.emoji,
        emoji: emoji,
        dx:    0.5,
        dy:    0.5,
      );
    });
  }

  // ─── Poll dialog ──────────────────────────────────────
  void _showPollDialog() {
    final questionCtrl = TextEditingController(text: 'Vote');
    final optionACtrl  = TextEditingController(text: 'Yes');
    final optionBCtrl  = TextEditingController(text: 'No');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Add Poll',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _darkField(questionCtrl, 'Poll question', 'e.g. What do you prefer?'),
            const SizedBox(height: 12),
            _darkField(optionACtrl, 'Option A', 'Yes'),
            const SizedBox(height: 8),
            _darkField(optionBCtrl, 'Option B', 'No'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sticker = StoryStickerData(
                  type:         StoryStickerType.poll,
                  pollQuestion: questionCtrl.text,
                  optionA:      optionACtrl.text,
                  optionB:      optionBCtrl.text,
                  dx:           0.5,
                  dy:           0.55,
                );
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Add Poll'),
          ),
        ],
      ),
    );
  }

  // ─── Question dialog ──────────────────────────────────
  void _showQuestionDialog() {
    final ctrl = TextEditingController(text: 'Ask me anything');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text(
          'Add Question',
          style: TextStyle(color: Colors.white),
        ),
        content: _darkField(ctrl, 'Question prompt', 'Ask me anything'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _sticker = StoryStickerData(
                  type:         StoryStickerType.question,
                  questionText: ctrl.text,
                  dx:           0.5,
                  dy:           0.55,
                );
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Add Question'),
          ),
        ],
      ),
    );
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

      if (_sticker?.type == StoryStickerType.poll) {
        pollData = {
          'question': _sticker!.pollQuestion,
          'optionA':  _sticker!.optionA,
          'optionB':  _sticker!.optionB,
          'x':        _sticker!.dx,
          'y':        _sticker!.dy,
          'width':    0.0, // Can be added if measured
          'height':   0.0,
          'rotation': 0.0,
        };
      } else if (_sticker?.type == StoryStickerType.question) {
        questionData = {
          'text':     _sticker!.questionText,
          'x':        _sticker!.dx,
          'y':        _sticker!.dy,
          'width':    0.0,
          'height':   0.0,
          'rotation': 0.0,
        };
      }

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
                  icon: const Icon(Icons.close, color: Colors.white),
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
                  color:  Colors.white.withOpacity(0.1),
                  shape:  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_stories,
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
                icon:   Icons.photo_library_outlined,
                label:  'Gallery',
                onTap:  _pickFromGallery,
              ),
              const SizedBox(height: 14),

              // Camera Photo
              _buildPickerOption(
                icon:      Icons.photo_camera_outlined,
                label:     'Take Photo',
                onTap:     _takePhoto,
                isPrimary: false,
              ),
              const SizedBox(height: 14),

              // Camera Video
              _buildPickerOption(
                icon:      Icons.videocam_outlined,
                label:     'Record Video (15s)',
                onTap:     _recordVideo,
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
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.2)),
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

          // ─── Sticker overlay ───────────────────────────
          if (_sticker != null) _buildStickerPreview(size),

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

    return Image.file(
      _mediaFile!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  // ─── Sticker preview (positioned) ────────────────────
  Widget _buildStickerPreview(Size size) {
    if (_sticker == null) return const SizedBox.shrink();

    final left   = _sticker!.dx * size.width - 90;
    final top    = _sticker!.dy * size.height - 40;

    return Positioned(
      left: left.clamp(0, size.width - 180),
      top:  top.clamp(80, size.height - 180),
      child: GestureDetector(
        onPanUpdate: (d) {
          final newDx = (_sticker!.dx + d.delta.dx / size.width)
              .clamp(0.1, 0.9);
          final newDy = (_sticker!.dy + d.delta.dy / size.height)
              .clamp(0.1, 0.9);
          setState(() => _sticker = _sticker!.copyWith(dx: newDx, dy: newDy));
        },
        child: _buildStickerWidget(_sticker!),
      ),
    );
  }

  Widget _buildStickerWidget(StoryStickerData sticker) {
    switch (sticker.type) {
      case StoryStickerType.poll:
        return _PollStickerPreview(
          question: sticker.pollQuestion ?? 'Vote',
          optionA:  sticker.optionA  ?? 'Yes',
          optionB:  sticker.optionB  ?? 'No',
          onRemove: () => setState(() => _sticker = null),
        );
      case StoryStickerType.question:
        return _QuestionStickerPreview(
          question: sticker.questionText ?? 'Ask me anything',
          onRemove: () => setState(() => _sticker = null),
        );
      case StoryStickerType.emoji:
        return GestureDetector(
          onLongPress: () => setState(() => _sticker = null),
          child: Text(
            sticker.emoji ?? '❤️',
            style: const TextStyle(fontSize: 48),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Editor top bar ───────────────────────────────────
  Widget _buildEditorTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Back
          _glassBtn(Icons.arrow_back, () {
            _videoController?.dispose();
            _videoController = null;
            setState(() {
              _step      = 0;
              _mediaFile = null;
              _sticker   = null;
              _textOverlay = '';
            });
          }),

          const Spacer(),

          // Text tool
          _glassBtn(Icons.text_fields, _toggleTextTool),
          const SizedBox(width: 8),

          // Stickers
          _glassBtn(
            Icons.emoji_emotions_outlined,
            _showStickerPanel,
          ),
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
                    ? Colors.green.withOpacity(0.85)
                    : Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _audience == StoryAudience.closeFriends
                        ? Icons.people
                        : Icons.public,
                    color: Colors.white,
                    size:  14,
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
            Colors.black.withOpacity(0.85),
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
                color:        Colors.white.withOpacity(0.15),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Share to Story',
                    style: TextStyle(
                      color:      Colors.white,
                      fontSize:   15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
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
    final ctrl = TextEditingController(text: _textOverlay);

    return Container(
      color: Colors.black.withOpacity(0.75),
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
                ]
                    .map(
                      (c) => GestureDetector(
                        onTap: () => setState(() => _textColor = c),
                        child: Container(
                          width:  28,
                          height: 28,
                          decoration: BoxDecoration(
                            color:  c,
                            shape:  BoxShape.circle,
                            border: Border.all(
                              color: _textColor == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            // Text field
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller:     ctrl,
                    autofocus:      true,
                    maxLines:       null,
                    textAlign:      TextAlign.center,
                    style:          TextStyle(
                      color:      _textColor,
                      fontSize:   _textSize,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                    decoration: const InputDecoration(
                      border:  InputBorder.none,
                      filled:  false,
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
                  setState(() {
                    _textOverlay  = ctrl.text;
                    _showTextInput = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize:     const Size(double.infinity, 48),
                  shape:           RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize:   16,
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

  // ─── Sticker panel ────────────────────────────────────
  void _showStickerPanel() {
    showModalBottomSheet(
      context:           context,
      backgroundColor:   const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width:  36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color:        Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Text(
                'Add Sticker',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              // Poll + Question
              Row(
                children: [
                  Expanded(
                    child: _StickerOptionTile(
                      icon:    Icons.bar_chart,
                      label:   'Poll',
                      color:   Colors.purple,
                      onTap:   () {
                        Navigator.pop(context);
                        _addPollSticker();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StickerOptionTile(
                      icon:    Icons.help_outline,
                      label:   'Question',
                      color:   Colors.blue,
                      onTap:   () {
                        Navigator.pop(context);
                        _addQuestionSticker();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Emoji row
              const Text(
                'Quick Emoji',
                style: TextStyle(
                  color:   Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😮', '😂', '😢', '😡', '🔥', '👏']
                    .map(
                      (e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _addEmojiSticker(e);
                        },
                        child: Text(
                          e,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
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
          color:  Colors.black.withOpacity(0.45),
          shape:  BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// POLL STICKER PREVIEW (on editor canvas)
// ─────────────────────────────────────────────────────
class _PollStickerPreview extends StatelessWidget {
  final String      question;
  final String      optionA;
  final String      optionB;
  final VoidCallback onRemove;

  const _PollStickerPreview({
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        width:   180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              question,
              style: const TextStyle(
                color:      Colors.black,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PollOption(label: optionA, color: Colors.blue),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PollOption(label: optionB, color: Colors.pink),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Long press to remove',
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final String label;
  final Color  color;
  const _PollOption({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color:      color,
          fontSize:   12,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// QUESTION STICKER PREVIEW (on editor canvas)
// ─────────────────────────────────────────────────────
class _QuestionStickerPreview extends StatelessWidget {
  final String      question;
  final VoidCallback onRemove;

  const _QuestionStickerPreview({
    required this.question,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onRemove,
      child: Container(
        width:   180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline, color: Colors.blue, size: 20),
            const SizedBox(height: 6),
            Text(
              question,
              style: const TextStyle(
                color:      Colors.black,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Type an answer...',
                style: TextStyle(color: Colors.grey, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Long press to remove',
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// STICKER OPTION TILE
// ─────────────────────────────────────────────────────
class _StickerOptionTile extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final Color       color;
  final VoidCallback onTap;

  const _StickerOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}