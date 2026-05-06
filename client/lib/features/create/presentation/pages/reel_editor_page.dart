// lib/features/create/presentation/pages/reel_editor_page.dart
//
// Bridge: launches a pre-seeded version of the reel creation flow.
// Since CreateReelPage has no constructor param for pre-selected file,
// we use a lightweight wrapper that calls _setVideo immediately via initState.

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../reels/presentation/providers/create_reel_provider.dart';
import '../../../reels/presentation/providers/reel_provider.dart';

/// A lightweight single-screen Reel editor that starts directly in
/// the preview+details step with the given [file].
class ReelEditorPage extends ConsumerStatefulWidget {
  final File file;

  const ReelEditorPage({super.key, required this.file});

  @override
  ConsumerState<ReelEditorPage> createState() => _ReelEditorPageState();
}

class _ReelEditorPageState extends ConsumerState<ReelEditorPage> {
  VideoPlayerController? _controller;
  int _durationSeconds = 0;
  bool _isMuted = false;

  final _captionCtrl   = TextEditingController();
  final _audioCtrl     = TextEditingController();
  final _captionFocus  = FocusNode();

  static const int _maxSeconds = 90;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initVideo();
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.file(widget.file);
    await ctrl.initialize();

    final secs = ctrl.value.duration.inSeconds;
    if (secs > _maxSeconds) {
      await ctrl.dispose();
      if (mounted) {
        AppSnackbar.error(
          context,
          'Video is ${secs}s — Reels must be $_maxSeconds seconds or less.',
        );
        Navigator.of(context).pop();
      }
      return;
    }

    ctrl.setLooping(true);
    ctrl.setVolume(_isMuted ? 0.0 : 1.0);
    ctrl.play();

    if (!mounted) return;
    setState(() {
      _controller      = ctrl;
      _durationSeconds = secs;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _captionCtrl.dispose();
    _audioCtrl.dispose();
    _captionFocus.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    HapticFeedback.selectionClick();
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Future<void> _upload() async {
    _captionFocus.unfocus();
    HapticFeedback.lightImpact();
    try {
      await ref.read(createReelProvider.notifier).uploadReel(
            videoFile:  widget.file,
            caption:    _captionCtrl.text.trim(),
            audioName:  _audioCtrl.text.trim().isEmpty
                ? 'Original audio'
                : _audioCtrl.text.trim(),
          );
      ref.read(reelFeedProvider.notifier).refresh();
      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Reel shared successfully! 🎉');
        context.pop();
        context.pop(); // also pop MediaPickerPage
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createReelProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final shouldPop = await showCupertinoDialog<bool>(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Discard Reel?'),
              content: const Text('If you go back now, you will lose your edits.'),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Editing'),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          if (shouldPop == true && mounted) {
            Navigator.pop(context); // Actually pop
          }
        },
        child: Stack(
          children: [
            // ── Video background ──────────────────────────
            if (_controller != null && _controller!.value.isInitialized)
              SizedBox.expand(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width:  _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child:  VideoPlayer(_controller!),
                        ),
                      ),
                      if (!_controller!.value.isPlaying)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(Icons.play_arrow, size: 80, color: Colors.white70),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: VideoProgressIndicator(
                          _controller!,
                          allowScrubbing: true,
                          padding: EdgeInsets.zero,
                          colors: const VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white24,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(child: CupertinoActivityIndicator(color: Colors.white)),
              ),

            // ── Upload overlay ────────────────────────────
            if (createState.isUploading)
              _buildUploadingOverlay(createState),

            // ── UI layer ─────────────────────────────────
            if (!createState.isUploading)
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    const Spacer(),
                    _buildBottomPanel(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _GlassBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  _fmt(_durationSeconds),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          _GlassBtn(
            icon: _isMuted ? Icons.volume_off : Icons.volume_up,
            onTap: _toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.bottomCenter,
          end:    Alignment.topCenter,
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
          _glassField(ctrl: _captionCtrl, focus: _captionFocus,
              hint: 'Write a caption...', icon: Icons.edit_outlined, maxLines: 3, maxLength: 2200),
          const SizedBox(height: 12),
          _glassField(ctrl: _audioCtrl,
              hint: 'Audio name (optional)', icon: Icons.music_note_outlined),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: IgColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Share Reel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassField({
    required TextEditingController ctrl,
    FocusNode? focus,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 12 : 0),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller:  ctrl,
              focusNode:   focus,
              maxLines:    maxLines,
              minLines:    1,
              maxLength:   maxLength,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              decoration: InputDecoration(
                hintText:     hint,
                hintStyle:    const TextStyle(color: Colors.white54, fontSize: 14),
                border:       InputBorder.none,
                filled:       false,
                isDense:      true,
                counterStyle: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingOverlay(CreateReelState s) {
    final pct = (s.uploadProgress * 100).toInt();
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100, height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: s.uploadProgress > 0 ? s.uploadProgress : null,
                    strokeWidth: 4,
                    color: IgColors.primary,
                    backgroundColor: Colors.white24,
                  ),
                  Text('$pct%',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Uploading reel...',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(s.uploadProgress < 1.0 ? 'Please keep the app open' : 'Processing...',
              style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
