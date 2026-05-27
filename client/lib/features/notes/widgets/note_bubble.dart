// lib/features/notes/widgets/note_bubble.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/note_model.dart';

class NoteBubble extends StatefulWidget {
  final NoteModel note;
  final bool isLarge;        // larger size for view sheet
  final bool isPreview;      // live preview (creation sheet)
  final bool animateEntry;   // pop-in animation on mount
  final VoidCallback? onTap;

  const NoteBubble({
    super.key,
    required this.note,
    this.isLarge = false,
    this.isPreview = false,
    this.animateEntry = false,
    this.onTap,
  });

  @override
  State<NoteBubble> createState() => _NoteBubbleState();
}

class _NoteBubbleState extends State<NoteBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Music audio preview player
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    if (widget.animateEntry) {
      _entryController.forward();
    } else {
      _entryController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant NoteBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateEntry && !oldWidget.animateEntry) {
      _entryController.forward(from: 0.0);
    }
    
    // If note changed or preview url changed, reset audio player
    if (oldWidget.note.musicPreviewUrl != widget.note.musicPreviewUrl) {
      _audioPlayer?.dispose();
      _audioPlayer = null;
      _isPlaying = false;
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    final previewUrl = widget.note.musicPreviewUrl;
    if (previewUrl == null || previewUrl.isEmpty) return;

    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      try {
        await _audioPlayer!.setUrl(previewUrl);
        _audioPlayer!.playerStateStream.listen((state) {
          if (!mounted) return;
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _audioPlayer!.seek(Duration.zero);
              _audioPlayer!.pause();
            }
          });
        });
      } catch (e) {
        debugPrint("Audio Player Error: $e");
        return;
      }
    }

    if (_isPlaying) {
      await _audioPlayer!.pause();
    } else {
      await _audioPlayer!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDashed = !widget.isPreview && widget.note.timeRemaining.inHours < 4;

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Opacity(
          opacity: (_opacityAnimation.value * widget.note.opacityLevel).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.bottomLeft, // Tail sits bottom-left
            child: child,
          ),
        );
      },
      child: InstagramNoteBubble(
        text: widget.note.text,
        noteType: widget.note.noteType,
        musicAlbumArt: widget.note.musicAlbumArt,
        musicTrackName: widget.note.musicTrackName,
        musicArtistName: widget.note.musicArtistName,
        gifUrl: widget.note.gifUrl,
        isOwn: widget.note.isOwn,
        isEmojiOnly: widget.note.isEmojiOnly,
        isLarge: widget.isLarge,
        isPlaying: _isPlaying,
        onMusicPlayTap: _togglePlay,
        onTap: widget.onTap,
        isDashed: isDashed,
        isExpiringSoon: widget.note.isExpiringSoon,
      ),
    );
  }
}

// ─── INSTAGRAM NOTE BUBBLE (iOS Thought Bubble Style) ──────────────────────

class InstagramNoteBubble extends StatelessWidget {
  final String text;
  final String noteType;
  final String? musicAlbumArt;
  final String? musicTrackName;
  final String? musicArtistName;
  final String? gifUrl;
  final bool isOwn;
  final bool isEmojiOnly;
  final bool isLarge;
  final bool isPlaying;
  final VoidCallback? onMusicPlayTap;
  final VoidCallback? onTap;
  final bool isDashed;
  final bool isExpiringSoon;

  const InstagramNoteBubble({
    super.key,
    required this.text,
    this.noteType = 'text',
    this.musicAlbumArt,
    this.musicTrackName,
    this.musicArtistName,
    this.gifUrl,
    this.isOwn = false,
    this.isEmojiOnly = false,
    this.isLarge = false,
    this.isPlaying = false,
    this.onMusicPlayTap,
    this.onTap,
    this.isDashed = false,
    this.isExpiringSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final double fontSize = isEmojiOnly
        ? (isLarge ? 28.0 : 20.0)
        : (isLarge ? 14.0 : 10.5);

    final double hPad = isEmojiOnly
        ? (isLarge ? 14.0 : 10.0)
        : (isLarge ? 12.0 : 8.0);
        
    final double vPad = isEmojiOnly
        ? (isLarge ? 12.0 : 8.0)
        : (isLarge ? 10.0 : 6.0);

    final double maxWidth = isLarge ? 220.0 : (noteType == 'text' ? 88.0 : 100.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. MAIN BUBBLE
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF262626), // Dark gray background as requested
              borderRadius: BorderRadius.circular(20), // Pill-shaped/oval
              border: Border.all(
                color: isDashed 
                    ? Colors.white.withOpacity(0.3) 
                    : const Color(0xFF3A3A3C),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            constraints: BoxConstraints(
              minWidth: 54,
              maxWidth: maxWidth,
            ),
            child: _buildBubbleContent(isDark, fontSize),
          ),

          // 2. THOUGHT BUBBLE "TAIL" (cascading circles)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 3),
                // Circle 1: slightly larger
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF262626),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 2),
                // Circle 2: smaller
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF262626),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(bool isDark, double fontSize) {
    // ─── 1. MUSIC SHARE TYPE ────────────────────────────────
    if (noteType == 'music') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Album art with overlay play/pause
          GestureDetector(
            onTap: onMusicPlayTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    musicAlbumArt ?? '',
                    width: isLarge ? 48 : 32,
                    height: isLarge ? 48 : 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: isLarge ? 48 : 32,
                      height: isLarge ? 32 : 32,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: isLarge ? 48 : 32,
                  height: isLarge ? 48 : 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: isLarge ? 22 : 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            musicTrackName ?? 'Track',
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            musicArtistName ?? 'Artist',
            style: const TextStyle(
              fontSize: 7,
              color: Colors.grey,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: Colors.white70,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
              maxLines: isLarge ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    // ─── 2. GIF SHARE TYPE ──────────────────────────────────
    if (noteType == 'gif' && gifUrl != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              gifUrl!,
              width: isLarge ? 96 : 52,
              height: isLarge ? 96 : 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: isLarge ? 96 : 52,
                height: isLarge ? 96 : 52,
                color: Colors.grey[800],
                child: const Icon(Icons.gif, color: Colors.grey, size: 24),
              ),
            ),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
              maxLines: isLarge ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    // ─── 3. STANDARD TEXT TYPE ──────────────────────────────
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            color: Colors.white,
            height: 1.3,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
          maxLines: isEmojiOnly ? 1 : (isLarge ? 3 : 2),
          overflow: TextOverflow.ellipsis,
        ),
        if (isOwn && isExpiringSoon) ...[
          const SizedBox(height: 2),
          Text(
            'Expiring soon',
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w300,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }
}

