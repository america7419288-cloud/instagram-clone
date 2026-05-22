import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'dart:async';

import 'chat_ui_constants.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final bool isSent;
  final List<double> waveform;

  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    required this.isSent,
    required this.waveform,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 14); // Mock duration
  Timer? _progressTimer;

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startProgressTimer();
      } else {
        _progressTimer?.cancel();
      }
    });
    HapticFeedback.lightImpact();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_position < _duration) {
        setState(() {
          _position += const Duration(milliseconds: 100);
          _progress = _position.inMilliseconds / _duration.inMilliseconds;
        });
      } else {
        _togglePlayPause();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        width: 232,
        padding: const EdgeInsets.only(left: 11, right: 14, top: 10, bottom: 10),
        decoration: BoxDecoration(
          color: widget.isSent
              ? ChatUIConstants.bubbleSent
              : (isDark
                    ? ChatUIConstants.bubbleReceivedDark
                    : ChatUIConstants.bubbleReceivedLight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _buildPlayButton(isDark),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWaveform(isDark),
                  const SizedBox(height: 2),
                  Text(
                    _isPlaying
                        ? _formatDuration(_position)
                        : _formatDuration(_duration),
                    style: TextStyle(
                      fontFamily: ChatUIConstants.fontFamily,
                      fontSize: 11,
                      color: widget.isSent
                          ? CupertinoColors.white.withValues(alpha: 0.65)
                          : (isDark
                                ? ChatUIConstants.textSecondaryDark
                                : ChatUIConstants.textSecondaryLight),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton(bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isSent
            ? CupertinoColors.white.withValues(alpha: 0.22)
            : (isDark
                  ? CupertinoColors.white.withValues(alpha: 0.1)
                  : CupertinoColors.black.withValues(alpha: 0.07)),
      ),
      child: Icon(
        _isPlaying ? LucideIcons.pause : LucideIcons.play,
        size: 19,
        color: widget.isSent
            ? CupertinoColors.white
            : (isDark
                  ? ChatUIConstants.textPrimaryDark
                  : ChatUIConstants.textPrimaryLight),
      ),
    );
  }

  Widget _buildWaveform(bool isDark) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(40, (index) {
          final barProgress = index / 40.0;
          final isPlayed = barProgress <= _progress;
          final height = widget.waveform.length > index
              ? widget.waveform[index].clamp(3.0, 22.0)
              : 3.0;

          return Container(
            width: 2.5,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1.5),
              color: isPlayed
                  ? (widget.isSent
                        ? CupertinoColors.white
                        : ChatUIConstants.verifiedBlue)
                  : (widget.isSent
                        ? CupertinoColors.white.withValues(alpha: 0.35)
                        : (isDark
                              ? CupertinoColors.white.withValues(alpha: 0.2)
                              : const Color(0xFFCCCCCC))),
            ),
          );
        }),
      ),
    );
  }
}
