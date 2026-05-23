// lib/features/create/presentation/pages/reel_editor_page.dart

import 'dart:io';
import 'dart:ui';
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

class _ReelEditorPageState extends ConsumerState<ReelEditorPage>
    with TickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  int _durationSeconds = 0;
  bool _isMuted = false;
  bool _showTrimOverlay = false;
  double _trimStartSec = 0.0;
  double _trimEndSec = 30.0;
  Map<String, dynamic>? _selectedMusic;

  final _captionCtrl = TextEditingController();
  final _audioCtrl = TextEditingController();
  final _captionFocus = FocusNode();

  // Speed pills: [0.3x, 0.5x, 1x, 2x, 3x]
  final _speeds = [0.3, 0.5, 1.0, 2.0, 3.0];
  final _speedLabels = ['0.3×', '0.5×', '1×', '2×', '3×'];
  int _speedIdx = 2; // 1x default

  static const int _maxSeconds = 90;

  late AnimationController _speedPillCtrl;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _speedPillCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _speedPillCtrl.forward();

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
    setState(() {
      _ctrl = c;
      _durationSeconds = secs;
      _trimEndSec = secs.toDouble().clamp(1.0, 90.0);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _captionCtrl.dispose();
    _audioCtrl.dispose();
    _captionFocus.dispose();
    _speedPillCtrl.dispose();
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

  void _setSpeed(int idx) {
    HapticFeedback.selectionClick();
    setState(() => _speedIdx = idx);
    _ctrl?.setPlaybackSpeed(_speeds[idx]);
    _speedPillCtrl.reset();
    _speedPillCtrl.forward();
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
        content:
            const Text('If you go back now, you will lose your edits.'),
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

  void _pickMusic() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MusicPickerSheet(
        onSelected: (song) {
          setState(() {
            _selectedMusic = song;
            _audioCtrl.text =
                song['title'] as String? ?? 'Original audio';
          });
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  void _showTrimStudio() {
    HapticFeedback.mediumImpact();
    setState(() => _showTrimOverlay = !_showTrimOverlay);
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
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: safeTop + 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Nav bar ────────────────────────────────
              if (!state.isUploading) _buildNavBar(safeTop),

              // ── Right tools column ─────────────────────
              if (!state.isUploading) _buildRightTools(safeTop),

              // ── Bottom section ─────────────────────────
              if (!state.isUploading) _buildBottomSection(safeBot),

              // ── Trim overlay ───────────────────────────
              if (_showTrimOverlay && !state.isUploading)
                _buildTrimOverlay(safeBot),

              // ── Uploading overlay ──────────────────────
              if (state.isUploading) _buildUploadOverlay(state),
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
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: safeTop + 56,
        padding: EdgeInsets.only(top: safeTop, left: 4, right: 4),
        child: Row(
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: () async {
                if (await _confirmDiscard() && mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Icon(LucideIcons.chevron_left,
                  color: Colors.white, size: 28),
            ),
            const Spacer(),
            const Text(
              'New Reel',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: _upload,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFD1D1D).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: const Text(
                  'Share',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
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

  Widget _buildRightTools(double safeTop) {
    final tools = [
      {'icon': LucideIcons.music, 'label': 'Audio', 'action': _pickMusic},
      {'icon': LucideIcons.type, 'label': 'Text'},
      {'icon': LucideIcons.smile, 'label': 'Sticker'},
      {'icon': LucideIcons.pencil, 'label': 'Draw'},
      {'icon': LucideIcons.scissors, 'label': 'Trim', 'action': _showTrimStudio},
      {'icon': LucideIcons.zap, 'label': 'Effects'},
      {
        'icon': _isMuted ? LucideIcons.volume_x : LucideIcons.volume_2,
        'label': _isMuted ? 'Unmute' : 'Mute',
        'action': _toggleMute,
      },
    ];

    return Positioned(
      right: 12,
      top: safeTop + 64,
      bottom: 220,
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
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 20, 16, safeBot + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Duration badge
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: Text(
                    '${_fmt(_durationSeconds)}  ·  1 clip',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Timeline bar
            _buildTimeline(),
            const SizedBox(height: 14),
            // Speed pills
            _buildSpeedPills(),
            const SizedBox(height: 14),
            // Caption field
            _buildCaptionField(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Stack(
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFF58529),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF58529).withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: List.generate(
                8,
                (_) => Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Left trim handle
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: _TrimHandle(isLeft: true),
        ),
        // Right trim handle
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _TrimHandle(isLeft: false),
        ),
        // Playhead
        Positioned(
          left: 40,
          top: 0,
          bottom: 0,
          child: Container(
            width: 2.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                    color: Colors.white.withOpacity(0.5), blurRadius: 4)
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedPills() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Stack(
            children: [
              // Sliding backdrop
              AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  -1.0 + (_speedIdx / (_speeds.length - 1)) * 2.0,
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / _speeds.length,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                ),
              ),
              // Pills
              Row(
                children: List.generate(_speeds.length, (i) {
                  final isActive = _speedIdx == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _setSpeed(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white70,
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          child: Text(_speedLabels[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.white.withOpacity(0.14), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Icon(LucideIcons.pencil,
                    color: Colors.white60, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _captionCtrl,
                  focusNode: _captionFocus,
                  maxLines: 3,
                  minLines: 1,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Write a caption…',
                    hintStyle:
                        TextStyle(color: Colors.white38, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrimOverlay(double safeBot) {
    final maxSec =
        _durationSeconds.toDouble().clamp(1.0, 90.0);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.95),
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 20, 16, safeBot + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.scissors,
                    color: Color(0xFFF58529), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Trim Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showTrimOverlay = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF58529),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _trimTimeChip('Start', _trimStartSec),
                Text(
                  '${(_trimEndSec - _trimStartSec).toStringAsFixed(1)}s',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
                _trimTimeChip('End', _trimEndSec),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                activeTrackColor: const Color(0xFFF58529),
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor:
                    const Color(0xFFF58529).withOpacity(0.2),
                rangeThumbShape:
                    const RoundRangeSliderThumbShape(
                        enabledThumbRadius: 10),
                rangeTrackShape:
                    const RoundedRectRangeSliderTrackShape(),
                rangeValueIndicatorShape:
                    const PaddleRangeSliderValueIndicatorShape(),
                showValueIndicator: ShowValueIndicator.always,
              ),
              child: RangeSlider(
                values: RangeValues(_trimStartSec, _trimEndSec),
                min: 0.0,
                max: maxSec,
                labels: RangeLabels(
                  '${_trimStartSec.toStringAsFixed(1)}s',
                  '${_trimEndSec.toStringAsFixed(1)}s',
                ),
                onChanged: (vals) {
                  if (vals.end - vals.start < 1.0) return;
                  HapticFeedback.selectionClick();
                  setState(() {
                    _trimStartSec = vals.start;
                    _trimEndSec = vals.end;
                  });
                  _ctrl?.seekTo(Duration(
                      milliseconds:
                          (_trimStartSec * 1000).toInt()));
                },
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0:00',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                Text(_fmt(_durationSeconds),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trimTimeChip(String label, double secs) {
    final m = secs ~/ 60;
    final s = (secs % 60).toStringAsFixed(1);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: const Color(0xFFF58529).withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
          Text(
            '$m:$s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadOverlay(CreateReelState s) {
    final pct = (s.uploadProgress * 100).toInt();
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: s.uploadProgress > 0 ? s.uploadProgress : null,
                    strokeWidth: 5,
                    color: IgColors.primary,
                    backgroundColor: Colors.white12,
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Uploading Reel…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.uploadProgress < 1.0
                  ? 'Please keep the app open'
                  : 'Almost done…',
              style:
                  const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trim Handle ───────────────────────────────────────────
class _TrimHandle extends StatelessWidget {
  final bool isLeft;
  const _TrimHandle({required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      decoration: BoxDecoration(
        color: const Color(0xFFF58529),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isLeft ? 6 : 0),
          bottomLeft: Radius.circular(isLeft ? 6 : 0),
          topRight: Radius.circular(isLeft ? 0 : 6),
          bottomRight: Radius.circular(isLeft ? 0 : 6),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              width: 2.5,
              height: 2.5,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right tool button ─────────────────────────────────────
class _ReelToolBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ReelToolBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  State<_ReelToolBtn> createState() => _ReelToolBtnState();
}

class _ReelToolBtnState extends State<_ReelToolBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.83)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, child) =>
              Transform.scale(scale: _scale.value, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: BackdropFilter(
                  filter:
                      ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.38),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                          width: 1),
                    ),
                    child: Icon(widget.icon,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    Shadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 4)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Music Picker Sheet ────────────────────────────────────

class _MusicPickerSheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onSelected;
  const _MusicPickerSheet({required this.onSelected});

  @override
  State<_MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<_MusicPickerSheet> {
  int _selectedIdx = -1;

  static const _tracks = [
    {'title': 'Blinding Lights', 'artist': 'The Weeknd', 'duration': '3:20'},
    {'title': 'As It Was', 'artist': 'Harry Styles', 'duration': '2:37'},
    {'title': 'Stay', 'artist': 'The Kid LAROI', 'duration': '2:21'},
    {'title': 'Ghost', 'artist': 'Justin Bieber', 'duration': '2:33'},
    {'title': 'Easy On Me', 'artist': 'Adele', 'duration': '3:44'},
    {'title': 'Bad Habits', 'artist': 'Ed Sheeran', 'duration': '3:51'},
    {'title': 'Industry Baby', 'artist': 'Lil Nas X', 'duration': '3:32'},
    {'title': 'Levitating', 'artist': 'Dua Lipa', 'duration': '3:23'},
  ];

  @override
  Widget build(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.62,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.82),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF833AB4),
                          Color(0xFFFD1D1D),
                        ]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.music,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(LucideIcons.x,
                          color: Colors.white54, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),
              // Track list
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(bottom: safeBot + 16, top: 8),
                  itemCount: _tracks.length,
                  itemBuilder: (_, i) {
                    final track = _tracks[i];
                    final isSel = _selectedIdx == i;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIdx = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withOpacity(0.07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: isSel
                              ? Border.all(
                                  color: const Color(0xFF833AB4)
                                      .withOpacity(0.4))
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Play/Pause disc
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: isSel
                                      ? const [
                                          Color(0xFF833AB4),
                                          Color(0xFFFD1D1D),
                                        ]
                                      : [Colors.white12, Colors.white12],
                                ),
                              ),
                              child: Icon(
                                isSel
                                    ? LucideIcons.pause
                                    : LucideIcons.play,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Title + artist
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    track['title']!,
                                    style: TextStyle(
                                      color: isSel
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.85),
                                      fontSize: 14,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    track['artist']!,
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Duration
                            Text(
                              track['duration']!,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            // Use button
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isSel
                                  ? GestureDetector(
                                      key: const ValueKey('use_btn'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        widget.onSelected(
                                            Map<String, dynamic>.from(
                                                track));
                                      },
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF833AB4),
                                              Color(0xFFFD1D1D),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Text(
                                          'Use',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox(
                                      key: ValueKey('no_btn'),
                                      width: 44),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
