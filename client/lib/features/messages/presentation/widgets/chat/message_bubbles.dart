import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
              LucideIcons.image_off,
              size: 36,
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
                  size: 24,
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
        size: 19,
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

class SharedPostBubble extends StatelessWidget {
  final String? sharedUsername;
  final String? sharedCaption;
  final String? sharedThumbnailUrl;
  final String messageType; // 'post', 'reel', 'story'
  final bool isSent;
  final VoidCallback? onTap;

  const SharedPostBubble({
    super.key,
    required this.sharedUsername,
    required this.sharedCaption,
    required this.sharedThumbnailUrl,
    required this.messageType,
    required this.isSent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final isReel = messageType == 'reel';
    final isStory = messageType == 'story';

    // Premium card styling
    final cardBgColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF2F2F7);

    final borderColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);

    final textColor = isDark
        ? ChatUIConstants.textPrimaryDark
        : ChatUIConstants.textPrimaryLight;

    final subTextColor = isDark
        ? ChatUIConstants.textSecondaryDark
        : ChatUIConstants.textSecondaryLight;

    // Header label
    String typeLabel = 'Instagram Post';
    IconData typeIcon = LucideIcons.image;
    if (isReel) {
      typeLabel = 'Instagram Reel';
      typeIcon = LucideIcons.film;
    } else if (isStory) {
      typeLabel = 'Instagram Story';
      typeIcon = LucideIcons.clock;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
          minWidth: 180,
        ),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Bar: Profile avatar and Username
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Beautiful gradient avatar placeholder
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF99D1C),
                          Color(0xFFE1306C),
                          Color(0xFF833AB4),
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.user,
                        size: 12,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Username & Type Metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sharedUsername ?? 'instagram_user',
                          style: TextStyle(
                            fontFamily: ChatUIConstants.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontFamily: ChatUIConstants.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: subTextColor,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    typeIcon,
                    size: 14,
                    color: subTextColor,
                  ),
                ],
              ),
            ),

            // 2. Media Preview Card
            AspectRatio(
              aspectRatio: isReel ? 0.8 : 1.0, // vertical layout for reels, square for posts/stories
              child: Container(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFEFEFF4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (sharedThumbnailUrl != null && sharedThumbnailUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: sharedThumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                        errorWidget: (context, url, error) => Center(
                          child: Icon(
                            isReel ? LucideIcons.film : LucideIcons.image,
                            size: 32,
                            color: subTextColor.withOpacity(0.5),
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Icon(
                          isReel ? LucideIcons.film : LucideIcons.image,
                          size: 36,
                          color: subTextColor.withOpacity(0.5),
                        ),
                      ),

                    // Play overlay for Reels
                    if (isReel)
                      Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: CupertinoColors.black.withOpacity(0.45),
                            border: Border.all(
                              color: CupertinoColors.white.withOpacity(0.15),
                              width: 0.5,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.play,
                              size: 18,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 3. Caption / Subtitle area
            if (sharedCaption != null && sharedCaption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: ChatUIConstants.fontFamily,
                      fontSize: 12,
                      color: textColor,
                    ),
                    children: [
                      TextSpan(
                        text: '${sharedUsername ?? 'instagram_user'} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: sharedCaption,
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: textColor.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        isReel ? 'Watch this Reel' : (isStory ? 'View Story' : 'View Post'),
                        style: TextStyle(
                          fontFamily: ChatUIConstants.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor.withOpacity(0.8),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Icon(
                      LucideIcons.chevron_right,
                      size: 14,
                      color: subTextColor,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
