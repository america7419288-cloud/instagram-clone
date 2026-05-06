// lib/features/create/presentation/pages/story_editor_page.dart
//
// Bridge: launches the story editor pre-loaded with [file],
// bypassing StoryCreatorPage's picker step.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../story/data/repositories/story_service.dart';
import '../../../story/presentation/providers/story_provider.dart';
import '../../../story/presentation/pages/story_creator_page.dart';

class StoryEditorPage extends ConsumerStatefulWidget {
  final File file;

  const StoryEditorPage({super.key, required this.file});

  @override
  ConsumerState<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends ConsumerState<StoryEditorPage>
    with TickerProviderStateMixin {
  bool _isVideo = false;
  VideoPlayerController? _videoController;

  String _textOverlay  = '';
  Color  _textColor    = Colors.white;
  bool   _showTextInput = false;
  Offset _textOffset   = Offset.zero;
  double _colorHue     = 0.0;
  
  late final TextEditingController _textCtrl;
  late final FocusNode _textFocus;

  StoryAudience _audience = StoryAudience.everyone;

  double _uploadProgress = 0;
  bool   _isUploading    = false;

  @override
  void initState() {
    super.initState();
    _textCtrl  = TextEditingController();
    _textFocus = FocusNode();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initMedia();
  }

  Future<void> _initMedia() async {
    final path = widget.file.path.toLowerCase();
    final isVid = path.endsWith('.mp4') || path.endsWith('.mov') ||
        path.endsWith('.avi') || path.endsWith('.mkv');

    if (isVid) {
      final ctrl = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(widget.file.path))
          : VideoPlayerController.file(widget.file);
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(1);
      ctrl.play();
      if (!mounted) return;
      setState(() {
        _videoController = ctrl;
        _isVideo = true;
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textCtrl.dispose();
    _textFocus.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _share() async {
    if (_isUploading) return;
    HapticFeedback.lightImpact();
    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      await ref.read(storyServiceProvider).createStory(
        mediaFile:    widget.file,
        mediaType:    _isVideo ? 'video' : 'image',
        caption:      _textOverlay.isNotEmpty ? _textOverlay : null,
        audience:     _audience == StoryAudience.closeFriends
            ? 'close_friends' : 'followers',
        onProgress:   (p) => setState(() => _uploadProgress = p),
      );
      ref.invalidate(storyFeedProvider);
      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Story shared! 🎉');
        context.pop();
        context.pop(); // also pop MediaPickerPage
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _toggleAudience() {
    setState(() {
      _audience = _audience == StoryAudience.everyone
          ? StoryAudience.closeFriends
          : StoryAudience.everyone;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) return _buildUploading();

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: _buildMedia()),
            if (_textOverlay.isNotEmpty && !_showTextInput) _buildTextOverlay(),
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(child: _buildTopBar()),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SafeArea(child: _buildBottomBar()),
            ),
            if (_showTextInput) _buildTextEditor(),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (_isVideo && _videoController != null && _videoController!.value.isInitialized) {
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
      return Image.network(widget.file.path, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity);
    }
    return Image.file(widget.file, fit: BoxFit.cover,
        width: double.infinity, height: double.infinity);
  }

  Widget _buildTextOverlay() {
    return Positioned.fill(
      child: Transform.translate(
        offset: _textOffset,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _textOffset += details.delta;
            });
          },
          child: Container(
            color: Colors.transparent, // ensure the gesture detector takes up space
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _textOverlay,
                  style: TextStyle(
                    color: _textColor, fontSize: 28, fontWeight: FontWeight.w700,
                    shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _glassBtn(PhosphorIcons.caretLeft(), () => Navigator.pop(context)),
          const Spacer(),
          _glassBtn(PhosphorIcons.textT(), () => setState(() => _showTextInput = true)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _toggleAudience,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _audience == StoryAudience.closeFriends
                    ? Colors.green.withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                     _audience == StoryAudience.closeFriends
                         ? PhosphorIcons.users()
                         : PhosphorIcons.globe(),
                     color: Colors.white, size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _audience == StoryAudience.closeFriends ? 'Close Friends' : 'Everyone',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('Discard',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _share,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Share to Story',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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

  Widget _buildTextEditor() {
    _textCtrl.text = _textOverlay;
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    onPanUpdate: (details) {
                      final percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      setState(() {
                        _colorHue = percent * 360.0;
                        _textColor = HSVColor.fromAHSV(1.0, _colorHue, 1.0, 1.0).toColor();
                        // White color fallback at the very left edge
                        if (percent < 0.05) _textColor = Colors.white;
                        // Black color fallback at the very right edge
                        if (percent > 0.95) _textColor = Colors.black;
                      });
                    },
                    onTapDown: (details) {
                      final percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                      setState(() {
                        _colorHue = percent * 360.0;
                        _textColor = HSVColor.fromAHSV(1.0, _colorHue, 1.0, 1.0).toColor();
                        if (percent < 0.05) _textColor = Colors.white;
                        if (percent > 0.95) _textColor = Colors.black;
                      });
                    },
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white, width: 2),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.red,
                            Colors.orange,
                            Colors.yellow,
                            Colors.green,
                            Colors.blue,
                            Colors.indigo,
                            Colors.purple,
                            Colors.black,
                          ],
                          stops: [0.0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0],
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: (_colorHue / 360.0) * constraints.maxWidth - 12,
                            top: -4,
                            child: Container(
                              width: 24,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _textColor,
                                border: Border.all(color: Colors.white, width: 3),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _textFocus,
                    autofocus: true,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor, fontSize: 28, fontWeight: FontWeight.w700,
                      shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Type something...',
                      hintStyle: TextStyle(color: Colors.white38, fontSize: 24),
                    ),
                    onChanged: (v) => _textOverlay = v,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  _textFocus.unfocus();
                  setState(() {
                    _textOverlay   = _textCtrl.text;
                    _showTextInput = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploading() {
    final pct = (_uploadProgress * 100).toInt();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100, height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    strokeWidth: 4, color: AppColors.primary, backgroundColor: Colors.white24,
                  ),
                  Text('$pct%',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Sharing your story...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
