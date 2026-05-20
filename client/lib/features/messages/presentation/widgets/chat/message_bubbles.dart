import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'chat_ui_constants.dart';

class TextBubble extends StatelessWidget {
  final String text;
  final bool isSent;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const TextBubble({
    super.key,
    required this.text,
    required this.isSent,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: isSent
          ? (isFirstInGroup
                ? const Radius.circular(18)
                : const Radius.circular(6))
          : const Radius.circular(18),
      bottomLeft: isSent
          ? const Radius.circular(18)
          : (isLastInGroup
                ? const Radius.circular(6)
                : const Radius.circular(18)),
      bottomRight: isSent
          ? (isLastInGroup
                ? const Radius.circular(6)
                : const Radius.circular(18))
          : const Radius.circular(18),
    );

    // Emoji-only check (1-3 emojis)
    if (_isEmojiOnly(text)) {
      final emojiCount = text.trim().characters.length;
      final double fontSize = emojiCount == 1
          ? 52
          : (emojiCount == 2 ? 44 : 36);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: fontSize, decoration: TextDecoration.none),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
        minWidth: 42,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: isSent
            ? ChatUIConstants.bubbleSent
            : (isDark
                  ? ChatUIConstants.bubbleReceivedDark
                  : ChatUIConstants.bubbleReceivedLight),
        borderRadius: borderRadius,
        border: isSent
            ? null
            : Border.all(
                color: isDark
                    ? const Color(0xFF303030)
                    : const Color(0xFFE9E9E9),
                width: 0.4,
              ),
      ),
      child: Text(text, style: ChatUIConstants.messageStyle(isSent, isDark)),
    );
  }

  bool _isEmojiOnly(String text) {
    if (text.isEmpty) return false;
    final trimmed = text.trim();
    // Simplified emoji detection
    final regex = RegExp(
      r'^(\u00a9|\u00ae|[\u2000-\u3300]|\ud83c[\ud000-\udfff]|\ud83d[\ud000-\udfff]|\ud83e[\ud000-\udfff])+$',
    );
    if (!regex.hasMatch(trimmed)) return false;
    return trimmed.characters.length <= 3;
  }
}

class ImageBubble extends StatelessWidget {
  final String imageUrl;
  final bool isSent;

  const ImageBubble({super.key, required this.imageUrl, required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 245,
        maxHeight: 310,
        minWidth: 80,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isSent
            ? ChatUIConstants.bubbleSent
            : (CupertinoTheme.of(context).brightness == Brightness.dark
                  ? ChatUIConstants.bubbleReceivedDark
                  : ChatUIConstants.bubbleReceivedLight),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const Center(child: CupertinoActivityIndicator()),
          errorWidget: (context, url, error) => const Center(
            child: Icon(
              LucideIcons.imageOff,
              size: 32,
              color: ChatUIConstants.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}

class VideoBubble extends StatelessWidget {
  final String thumbnailUrl;
  final String duration;
  final bool isSent;

  const VideoBubble({
    super.key,
    required this.thumbnailUrl,
    required this.duration,
    required this.isSent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 280,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: thumbnailUrl, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.transparent,
                    CupertinoColors.black.withOpacity(0.38),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.play,
                  size: 21,
                  color: CupertinoColors.white,
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 10,
              child: Text(
                duration,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  shadows: [
                    Shadow(color: CupertinoColors.black, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AudioBubble extends StatefulWidget {
  final String audioUrl;
  final bool isSent;

  const AudioBubble({
    super.key,
    required this.audioUrl,
    required this.isSent,
  });

  @override
  State<AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<AudioBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (widget.audioUrl.isEmpty) return;
    try {
      final duration = await _audioPlayer.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("Error initializing audio player: $e");
    }

    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _audioPlayer.seek(Duration.zero);
            _audioPlayer.pause();
          }
        });
      }
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });

    _positionSubscription = _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_isInitialized && widget.audioUrl.isNotEmpty) {
      await _initAudio();
    }
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    final displayDuration = _formatDuration(_isPlaying ? _position : (_duration == Duration.zero ? const Duration(seconds: 3) : _duration));

    return Container(
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
          GestureDetector(
            onTap: _togglePlay,
            child: _buildPlayButton(isDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWaveform(isDark, progress),
                const SizedBox(width: 2),
                Text(
                  displayDuration,
                  style: TextStyle(
                    fontFamily: ChatUIConstants.fontFamily,
                    fontSize: 11,
                    color: widget.isSent
                        ? CupertinoColors.white.withOpacity(0.65)
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
    );
  }

  Widget _buildPlayButton(bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isSent
            ? CupertinoColors.white.withOpacity(0.22)
            : (isDark
                ? CupertinoColors.white.withOpacity(0.1)
                : CupertinoColors.black.withOpacity(0.07)),
      ),
      child: Icon(
        _isPlaying ? LucideIcons.pause : LucideIcons.play,
        size: 17,
        color: widget.isSent
            ? CupertinoColors.white
            : (isDark
                ? ChatUIConstants.textPrimaryDark
                : ChatUIConstants.textPrimaryLight),
      ),
    );
  }

  Widget _buildWaveform(bool isDark, double progress) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(40, (index) {
          final barProgress = index / 40.0;
          final isPlayed = barProgress <= progress;
          final height = (3.0 + (index % 7) * 2.5).clamp(3.0, 22.0);

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
                      ? CupertinoColors.white.withOpacity(0.35)
                      : (isDark
                          ? CupertinoColors.white.withOpacity(0.2)
                          : const Color(0xFFCCCCCC))),
            ),
          );
        }),
      ),
    );
  }
}
