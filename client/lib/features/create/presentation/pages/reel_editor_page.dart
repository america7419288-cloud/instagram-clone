// lib/features/create/presentation/pages/reel_editor_page.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../reels/presentation/providers/create_reel_provider.dart';
import '../../../reels/presentation/providers/reel_provider.dart';

class ReelEditorPage extends ConsumerStatefulWidget {
  final File file;
  const ReelEditorPage({super.key, required this.file});

  @override
  ConsumerState<ReelEditorPage> createState() => _ReelEditorPageState();
}

class _ReelEditorPageState extends ConsumerState<ReelEditorPage> {
  VideoPlayerController? _ctrl;
  int _durationSeconds = 0;
  bool _isMuted = false;

  final _captionCtrl = TextEditingController();
  final _audioCtrl = TextEditingController();
  final _captionFocus = FocusNode();

  // Speed cycle
  final _speeds = [0.5, 1.0, 1.5, 2.0];
  int _speedIdx = 1;

  static const int _maxSeconds = 90;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _initVideo();
  }

  Future<void> _initVideo() async {
    final c = VideoPlayerController.file(widget.file);
    await c.initialize();
    final secs = c.value.duration.inSeconds;
    if (secs > _maxSeconds) {
      await c.dispose();
      if (mounted) {
        AppSnackbar.error(context,
            'Video is ${secs}s — Reels must be $_maxSeconds seconds or less.');
        Navigator.pop(context);
      }
      return;
    }
    c.setLooping(true);
    c.setVolume(_isMuted ? 0.0 : 1.0);
    c.play();
    if (!mounted) return;
    setState(() { _ctrl = c; _durationSeconds = secs; });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _captionCtrl.dispose();
    _audioCtrl.dispose();
    _captionFocus.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _ctrl?.setVolume(_isMuted ? 0.0 : 1.0);
    HapticFeedback.selectionClick();
  }

  void _togglePlay() {
    if (_ctrl == null) return;
    setState(() {
      _ctrl!.value.isPlaying ? _ctrl!.pause() : _ctrl!.play();
    });
    HapticFeedback.selectionClick();
  }

  void _cycleSpeed() {
    HapticFeedback.selectionClick();
    setState(() => _speedIdx = (_speedIdx + 1) % _speeds.length);
    _ctrl?.setPlaybackSpeed(_speeds[_speedIdx]);
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
            videoFile: widget.file,
            caption: _captionCtrl.text.trim(),
            audioName: _audioCtrl.text.trim().isEmpty
                ? 'Original audio'
                : _audioCtrl.text.trim(),
          );
      ref.read(reelFeedProvider.notifier).refresh();
      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Reel shared! 🎉');
        context.pop();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<bool> _confirmDiscard() async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Discard Reel?'),
        content: const Text(
            'If you go back now, you will lose your edits.'),
        actions: [
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Editing')),
          CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard')),
        ],
      ),
    );
    return result == true;
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createReelProvider);
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmDiscard() && mounted) Navigator.pop(context);
          },
          child: Stack(
            children: [
              // ── Video ──────────────────────────────────
              _buildVideoLayer(),

              // ── Top gradient ───────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: safeTop + 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Nav bar ────────────────────────────────
              if (!state.isUploading)
                _buildNavBar(safeTop),

              // ── Right tools column ─────────────────────
              if (!state.isUploading)
                _buildRightTools(safeTop),

              // ── Bottom section ─────────────────────────
              if (!state.isUploading)
                _buildBottomSection(safeBot),

              // ── Uploading overlay ──────────────────────
              if (state.isUploading)
                _buildUploadOverlay(state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    if (_ctrl == null || !_ctrl!.value.isInitialized) {
      return const Center(
          child: CupertinoActivityIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _ctrl!.value.size.width,
            height: _ctrl!.value.size.height,
            child: VideoPlayer(_ctrl!),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(double safeTop) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: safeTop + 52,
        padding: EdgeInsets.only(top: safeTop, left: 4, right: 4),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () async {
                if (await _confirmDiscard() && mounted) Navigator.pop(context);
              },
              child: const Icon(LucideIcons.chevron_left,
                  color: Colors.white, size: 28),
            ),
            const Spacer(),
            const Text('New reel',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF-Pro')),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _upload,
              child: const Text('Next',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'SF-Pro')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightTools(double safeTop) {
    final tools = [
      {'icon': LucideIcons.music, 'label': 'Audio'},
      {'icon': LucideIcons.type, 'label': 'Text'},
      {'icon': LucideIcons.smile, 'label': 'Sticker'},
      {'icon': LucideIcons.pencil, 'label': 'Draw'},
      {'icon': LucideIcons.scissors, 'label': 'Trim'},
      {'icon': LucideIcons.zap, 'label': 'Effects'},
      {'icon': _isMuted ? LucideIcons.volume_x : LucideIcons.volume_2,
       'label': _isMuted ? 'Unmute' : 'Mute',
       'action': _toggleMute},
    ];

    return Positioned(
      right: 12,
      top: safeTop + 60,
      bottom: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: tools.map((t) {
          return _ReelToolBtn(
            icon: t['icon'] as IconData,
            label: t['label'] as String,
            onTap: (t['action'] as VoidCallback?) ?? () {},
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomSection(double safeBot) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.88),
              Colors.black.withOpacity(0.5),
              Colors.transparent,
            ],
            stops: const [0.0, 0.65, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 24, 16, safeBot + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duration badge
            Text(
              '${_fmt(_durationSeconds)}  •  1 clip',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'SF-Pro'),
            ),
            const SizedBox(height: 10),
            // Timeline bar
            _buildTimeline(),
            const SizedBox(height: 14),
            // Bottom action row
            _buildActionRow(),
            const SizedBox(height: 16),
            // Caption field
            _buildCaptionField(),
            const SizedBox(height: 10),
            // Share button
            _buildShareBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFF58529), width: 2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: List.generate(
              6,
              (_) => Expanded(
                    child: Container(color: Colors.grey[800]),
                  )),
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _BottomActionBtn(
          icon: LucideIcons.circle_plus,
          label: 'Add clip',
          onTap: () {},
        ),
        _BottomActionBtn(
          icon: LucideIcons.gauge,
          label: '${_speeds[_speedIdx]}×',
          onTap: _cycleSpeed,
          isText: true,
        ),
        _BottomActionBtn(
          icon: LucideIcons.timer,
          label: 'Timer',
          onTap: () {},
        ),
        _BottomActionBtn(
          icon: LucideIcons.list,
          label: 'Align',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildCaptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.white.withOpacity(0.18), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Icon(LucideIcons.pencil, color: Colors.white60, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _captionCtrl,
              focusNode: _captionFocus,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontFamily: 'SF-Pro'),
              decoration: const InputDecoration(
                hintText: 'Write a caption…',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareBtn() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _upload,
        child: Container(
          decoration: BoxDecoration(
            color: IgColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.circle_play,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Share Reel',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'SF-Pro')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOverlay(CreateReelState s) {
    final pct = (s.uploadProgress * 100).toInt();
    return Container(
      color: Colors.black.withOpacity(0.75),
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Uploading reel…',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF-Pro')),
            const SizedBox(height: 8),
            Text(
              s.uploadProgress < 1.0 ? 'Please keep the app open' : 'Processing…',
              style: const TextStyle(
                  color: Colors.white60, fontSize: 13, fontFamily: 'SF-Pro'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Right tool button ─────────────────────────────────────
class _ReelToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReelToolBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'SF-Pro',
                    shadows: [
                      Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4)
                    ])),
          ],
        ),
      ),
    );
  }
}

// ── Bottom action button ──────────────────────────────────
class _BottomActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isText;
  const _BottomActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.isText = false});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isText
                ? Center(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'SF-Pro')))
                : Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 4),
          Text(isText ? '' : label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'SF-Pro')),
        ],
      ),
    );
  }
}
