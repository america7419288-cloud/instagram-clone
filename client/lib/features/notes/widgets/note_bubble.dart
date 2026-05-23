// lib/features/notes/widgets/note_bubble.dart

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/note_model.dart';
import 'note_bubble_painter.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFDBDBDB);

    final isEmoji = widget.note.isEmojiOnly;
    final double fontSize = isEmoji
        ? (widget.isLarge ? 28.0 : 20.0)
        : (widget.isLarge ? 14.0 : 10.5);

    final double hPad = isEmoji
        ? (widget.isLarge ? 14.0 : 10.0)
        : (widget.isLarge ? 12.0 : 8.0);
        
    final double vPad = isEmoji
        ? (widget.isLarge ? 12.0 : 8.0)
        : (widget.isLarge ? 10.0 : 6.0);

    final double maxWidth = widget.isLarge ? 220.0 : (widget.note.noteType == 'text' ? 88.0 : 100.0);
    final double tailHeight = widget.isLarge ? 7.0 : 6.0;
    final double tailWidth = widget.isLarge ? 9.0 : 8.0;

    // Dashed border: 20-23h (opacity 0.65) and 23-24h (opacity 0.4)
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
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 54,
              maxWidth: maxWidth,
            ),
            child: CustomPaint(
              painter: NoteBubblePainter(
                backgroundColor: bgColor,
                borderColor: borderColor,
                isDashed: isDashed,
                tailHeight: tailHeight,
                tailWidth: tailWidth,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  hPad,
                  vPad,
                  hPad,
                  vPad + tailHeight, // Bottom padding adds tailHeight to avoid text overlaps
                ),
                child: _buildBubbleContent(isDark, fontSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(bool isDark, double fontSize) {
    // ─── 1. MUSIC SHARE TYPE ────────────────────────────────
    if (widget.note.noteType == 'music') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Album art with overlay play/pause
          GestureDetector(
            onTap: _togglePlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.note.musicAlbumArt ?? '',
                    width: widget.isLarge ? 48 : 32,
                    height: widget.isLarge ? 48 : 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: widget.isLarge ? 48 : 32,
                      height: widget.isLarge ? 32 : 32,
                      color: Colors.grey[isDark ? 800 : 300],
                      child: Icon(
                        Icons.music_note,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 16,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: widget.isLarge ? 48 : 32,
                  height: widget.isLarge ? 48 : 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: widget.isLarge ? 22 : 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.note.musicTrackName ?? 'Track',
            style: TextStyle(
              fontSize: widget.isLarge ? 11 : 8.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            widget.note.musicArtistName ?? 'Artist',
            style: TextStyle(
              fontSize: widget.isLarge ? 9.5 : 7,
              color: Colors.grey,
              decoration: TextDecoration.none,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.note.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.note.text,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: isDark ? Colors.white70 : Colors.black87,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
              maxLines: widget.isLarge ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    // ─── 2. GIF SHARE TYPE ──────────────────────────────────
    if (widget.note.noteType == 'gif' && widget.note.gifUrl != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              widget.note.gifUrl!,
              width: widget.isLarge ? 96 : 52,
              height: widget.isLarge ? 96 : 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: widget.isLarge ? 96 : 52,
                height: widget.isLarge ? 96 : 52,
                color: Colors.grey[isDark ? 800 : 300],
                child: const Icon(Icons.gif, color: Colors.grey, size: 24),
              ),
            ),
          ),
          if (widget.note.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.note.text,
              style: TextStyle(
                fontSize: fontSize * 0.9,
                color: isDark ? Colors.white : Colors.black,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
              maxLines: widget.isLarge ? 2 : 1,
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
          widget.note.text,
          style: TextStyle(
            fontSize: fontSize,
            color: isDark ? Colors.white : Colors.black,
            height: 1.3,
            fontWeight: FontWeight.w400,
            fontFamily: 'SF Pro Display',
            decoration: TextDecoration.none,
          ),
          textAlign: TextAlign.center,
          maxLines: widget.note.isEmojiOnly ? 1 : (widget.isLarge ? 3 : 2),
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.note.isOwn && !widget.isPreview && widget.note.isExpiringSoon) ...[
          const SizedBox(height: 2),
          Text(
            'Expiring soon',
            style: TextStyle(
              fontSize: 8,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
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

