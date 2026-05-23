// lib/features/notes/pages/note_create_sheet.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:instagram_client/features/auth/presentation/providers/auth_provider.dart';
import 'package:instagram_client/core/network/dio_client.dart';
import 'package:just_audio/just_audio.dart';
import '../controllers/notes_controller.dart';
import '../models/note_model.dart';
import '../widgets/note_bubble.dart';
import '../widgets/audience_selector.dart';

class NoteCreateSheet extends ConsumerStatefulWidget {
  final NoteModel? existingNote; // null = new note

  const NoteCreateSheet({
    super.key,
    this.existingNote,
  });

  static Future<void> show(BuildContext context, {NoteModel? existingNote}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => NoteCreateSheet(existingNote: existingNote),
    );
  }

  @override
  ConsumerState<NoteCreateSheet> createState() => _NoteCreateSheetState();
}

class _NoteCreateSheetState extends ConsumerState<NoteCreateSheet>
    with TickerProviderStateMixin {
  late TextEditingController _textController;
  late FocusNode _focusNode;

  // Pulse & Shake Animation Controllers
  late AnimationController _previewPulseController;
  late Animation<double> _previewScale;

  late AnimationController _shakeController;
  late Animation<double> _shakeTranslation;

  NoteAudience _selectedAudience = NoteAudience.followers;
  bool _isSharing = false;
  String _previewText = '';
  int _lastCharCount = 0;

  // Enhanced note states
  String _noteType = 'text'; // 'text' | 'music' | 'gif'
  
  // Music selected
  String? _musicTrackId;
  String? _musicTrackName;
  String? _musicArtistName;
  String? _musicAlbumArt;
  String? _musicPreviewUrl;
  int? _musicDuration;
  
  // GIF selected
  String? _gifId;
  String? _gifUrl;
  String? _gifPreviewUrl;
  String? _gifTitle;
  int? _gifWidth;
  int? _gifHeight;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _textController = TextEditingController(
      text: widget.existingNote?.text ?? '',
    );
    _previewText = _textController.text;
    _lastCharCount = _previewText.length;
    _selectedAudience = widget.existingNote?.audience ?? NoteAudience.followers;

    if (widget.existingNote != null) {
      _noteType = widget.existingNote!.noteType;
      _musicTrackId = widget.existingNote!.musicTrackId;
      _musicTrackName = widget.existingNote!.musicTrackName;
      _musicArtistName = widget.existingNote!.musicArtistName;
      _musicAlbumArt = widget.existingNote!.musicAlbumArt;
      _musicPreviewUrl = widget.existingNote!.musicPreviewUrl;
      _musicDuration = widget.existingNote!.musicDuration;
      _gifId = widget.existingNote!.gifId;
      _gifUrl = widget.existingNote!.gifUrl;
      _gifPreviewUrl = widget.existingNote!.gifPreviewUrl;
      _gifTitle = widget.existingNote!.gifTitle;
      _gifWidth = widget.existingNote!.gifWidth;
      _gifHeight = widget.existingNote!.gifHeight;
    }

    // 1. Setup Preview Pulse Animation
    _previewPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _previewScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_previewPulseController);

    // 2. Setup Shake Animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shakeTranslation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 5.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 3.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: -2.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -2.0, end: 0.0), weight: 15),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    _textController.addListener(_onTextChanged);

    // Auto-focus input delayed
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _previewPulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newText = _textController.text;
    final currentCount = newText.length;

    if (newText != _previewText) {
      setState(() {
        _previewText = newText;
      });

      // Pulse the preview bubble on every keystroke
      _previewPulseController.forward(from: 0.0);

      // Trigger shake when reaching warning limits
      if (currentCount >= 55 && _lastCharCount < 55) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.vibrate();
      } else if (currentCount == 60 && _lastCharCount < 60) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.vibrate();
      }

      _lastCharCount = currentCount;
    }
  }

  Future<void> _shareNote() async {
    final text = _textController.text.trim();
    final canShare = text.isNotEmpty || _noteType != 'text';
    if (!canShare) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSharing = true;
    });

    try {
      await ref.read(notesProvider.notifier).shareNote(
        text,
        _selectedAudience,
        noteType: _noteType,
        musicTrackId: _musicTrackId,
        musicTrackName: _musicTrackName,
        musicArtistName: _musicArtistName,
        musicAlbumArt: _musicAlbumArt,
        musicPreviewUrl: _musicPreviewUrl,
        musicDuration: _musicDuration,
        gifId: _gifId,
        gifUrl: _gifUrl,
        gifPreviewUrl: _gifPreviewUrl,
        gifTitle: _gifTitle,
        gifWidth: _gifWidth,
        gifHeight: _gifHeight,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('💭 ', style: TextStyle(fontSize: 15)),
                Text(
                  widget.existingNote != null ? 'Note updated successfully' : 'Note shared successfully',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF262626),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share note: $e'),
            backgroundColor: const Color(0xFFED4956),
          ),
        );
      }
    }
  }

  void _deleteNote() {
    HapticFeedback.mediumImpact();
    ref.read(notesProvider.notifier).deleteNote();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final currentUser = ref.watch(currentUserProvider);
    final avatarUrl = currentUser?.profilePicUrl ?? '';
    final username = currentUser?.username ?? 'your_username';

    final hasText = _previewText.isNotEmpty;
    final charCount = _textController.text.length;
    final canShare = hasText || _noteType != 'text';

    return WillPopScope(
      onWillPop: () async => !_isSharing,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.only(bottom: keyboardHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // DRAG HANDLE
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4.5,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            // TITLE ACTION BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 80),
                    child: Text(
                      widget.existingNote != null ? 'Edit note' : 'New note',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: GestureDetector(
                      onTap: _isSharing ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: (canShare && !_isSharing) ? _shareNote : null,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: canShare
                              ? const Color(0xFF0095F6)
                              : (isDark ? Colors.grey[700] : Colors.grey[300]),
                        ),
                        child: Text(_isSharing ? 'Sharing...' : 'Share'),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 0.5, thickness: 0.5),

            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LIVE PREVIEW BUBBLE OVER AVATAR
                    AnimatedBuilder(
                      animation: _previewPulseController,
                      builder: (_, child) => Transform.scale(
                        scale: _previewScale.value,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Speech bubble preview
                          canShare
                              ? NoteBubble(
                                  note: NoteModel(
                                    id: 'preview',
                                    userId: 'me',
                                    username: 'me',
                                    avatarUrl: '',
                                    text: _previewText,
                                    createdAt: DateTime.now(),
                                    audience: _selectedAudience,
                                    isOwn: true,
                                    noteType: _noteType,
                                    musicTrackId: _musicTrackId,
                                    musicTrackName: _musicTrackName,
                                    musicArtistName: _musicArtistName,
                                    musicAlbumArt: _musicAlbumArt,
                                    musicPreviewUrl: _musicPreviewUrl,
                                    musicDuration: _musicDuration,
                                    gifId: _gifId,
                                    gifUrl: _gifUrl,
                                    gifPreviewUrl: _gifPreviewUrl,
                                    gifTitle: _gifTitle,
                                    gifWidth: _gifWidth,
                                    gifHeight: _gifHeight,
                                  ),
                                  isPreview: true,
                                )
                              : _buildPlaceholderBubble(isDark),

                          // Clean attachments button
                          if (_noteType != 'text') ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _noteType = 'text';
                                  _musicTrackId = null;
                                  _musicTrackName = null;
                                  _musicArtistName = null;
                                  _musicAlbumArt = null;
                                  _musicPreviewUrl = null;
                                  _musicDuration = null;
                                  _gifId = null;
                                  _gifUrl = null;
                                  _gifPreviewUrl = null;
                                  _gifTitle = null;
                                  _gifWidth = null;
                                  _gifHeight = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _noteType == 'music' ? 'Remove song' : 'Remove GIF',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.close, size: 12, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),

                          // Your profile avatar
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl.isEmpty ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black38, size: 30) : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0095F6),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Username label
                          Text(
                            username,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // SEGMENTED AUDIENCE SELECTOR
                    AudienceSelector(
                      initialAudience: _selectedAudience,
                      onAudienceChanged: (val) {
                        setState(() {
                          _selectedAudience = val;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // TEXT INPUT RECTANGLE
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeTranslation.value, 0.0),
                            child: child,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLength: 60,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              color: isDark ? Colors.white : Colors.black,
                              fontFamily: 'SF Pro Text',
                            ),
                            decoration: InputDecoration(
                              hintText: 'Share a thought...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey[500] : Colors.grey[400],
                                fontStyle: FontStyle.italic,
                              ),
                              border: InputBorder.none,
                              counterText: '', // Hide native counter
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _shareNote(),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // TOOL BAR & CHARACTER COUNTER ROW
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          // Character limit text
                          AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeTranslation.value * 0.7, 0.0),
                                child: child,
                              );
                            },
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 11.5,
                                fontWeight: charCount > 55 ? FontWeight.w700 : FontWeight.w400,
                                color: charCount > 55
                                    ? (charCount >= 60 ? Colors.red : Colors.orange)
                                    : (isDark ? Colors.grey[500] : Colors.grey[400]),
                              ),
                              child: Text('$charCount/60'),
                            ),
                          ),

                          const Spacer(),

                          // Music Note Tool Button
                          _buildToolIcon(
                            Icons.music_note_outlined,
                            () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _MusicSearchSheet(
                                  onTrackSelected: (track) {
                                    setState(() {
                                      _noteType = 'music';
                                      _musicTrackId = track['id'] ?? '';
                                      _musicTrackName = track['title'] ?? track['name'] ?? 'Track';
                                      _musicArtistName = track['artist'] ?? 'Artist';
                                      _musicAlbumArt = track['albumArt'] ?? track['album_art'] ?? '';
                                      _musicPreviewUrl = track['previewUrl'] ?? track['preview_url'] ?? '';
                                      _musicDuration = track['duration'] != null ? int.tryParse(track['duration'].toString()) : null;
                                      
                                      // Clear conflicting GIF details
                                      _gifId = null;
                                      _gifUrl = null;
                                    });
                                  },
                                ),
                              );
                            },
                            isDark,
                          ),
                          const SizedBox(width: 14),
                          
                          // GIF Badge Button
                          GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => _GifSearchSheet(
                                  onGifSelected: (gif) {
                                    setState(() {
                                      _noteType = 'gif';
                                      _gifId = gif['id'] ?? '';
                                      _gifUrl = gif['url'] ?? '';
                                      _gifPreviewUrl = gif['preview_url'] ?? '';
                                      _gifTitle = gif['title'] ?? '';
                                      _gifWidth = gif['width'] != null ? int.tryParse(gif['width'].toString()) : null;
                                      _gifHeight = gif['height'] != null ? int.tryParse(gif['height'].toString()) : null;
                                      
                                      // Clear conflicting Music details
                                      _musicTrackId = null;
                                      _musicTrackName = null;
                                      _musicPreviewUrl = null;
                                    });
                                  },
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                                  width: 1.2,
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'GIF',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // If editing an existing note, show explicit delete button at the very bottom
                    if (widget.existingNote != null) ...[
                      const SizedBox(height: 18),
                      const Divider(height: 0.5, thickness: 0.5),
                      GestureDetector(
                        onTap: _deleteNote,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          alignment: Alignment.center,
                          child: const Text(
                            'Delete Note',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBubble(bool isDark) {
    final bubbleColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey[100];
    final borderColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFDBDBDB);

    return Container(
      constraints: const BoxConstraints(minWidth: 60, maxWidth: 130),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.all(color: borderColor!, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        'Share a thought...',
        style: TextStyle(
          fontSize: 10.5,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildToolIcon(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        icon,
        size: 22,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }
}

// ─── MUSIC SEARCH BOTTOM SHEET ──────────────────────────────
class _MusicSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<Map<String, dynamic>> onTrackSelected;

  const _MusicSearchSheet({required this.onTrackSelected});

  @override
  ConsumerState<_MusicSearchSheet> createState() => _MusicSearchSheetState();
}

class _MusicSearchSheetState extends ConsumerState<_MusicSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _tracks = [];
  bool _isLoading = false;
  
  AudioPlayer? _previewPlayer;
  String? _playingTrackId;

  @override
  void initState() {
    super.initState();
    _previewPlayer = AudioPlayer();
    // Load trending or standard search mock list initially
    _search('trending');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  void _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final client = ref.read(dioClientProvider);
      final response = await client.get('/music/search', queryParameters: {'query': query});
      if (mounted) {
        setState(() {
          _tracks = response.data['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _togglePreview(Map<String, dynamic> track) async {
    final previewUrl = track['previewUrl'] ?? track['preview_url'];
    final trackId = track['id'];
    if (previewUrl == null || previewUrl.isEmpty) return;

    if (_playingTrackId == trackId) {
      await _previewPlayer!.pause();
      setState(() => _playingTrackId = null);
    } else {
      await _previewPlayer!.stop();
      try {
        await _previewPlayer!.setUrl(previewUrl);
        _previewPlayer!.play();
        setState(() => _playingTrackId = trackId);
        
        _previewPlayer!.playerStateStream.listen((state) {
          if (!mounted) return;
          if (state.processingState == ProcessingState.completed) {
            setState(() => _playingTrackId = null);
          }
        });
      } catch (e) {
        debugPrint("Song preview error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Choose Music',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // Search input bar
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search for music...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.white12 : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          
          // Results list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tracks.isEmpty
                    ? const Center(child: Text('No songs found', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _tracks.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final track = Map<String, dynamic>.from(_tracks[index]);
                          final trackId = track['id'];
                          final isPlaying = _playingTrackId == trackId;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                track['albumArt'] ?? track['album_art'] ?? '',
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.grey,
                                  child: const Icon(Icons.music_note, color: Colors.white),
                                ),
                              ),
                            ),
                            title: Text(
                              track['title'] ?? track['name'] ?? 'Unknown Track',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              track['artist'] ?? 'Unknown Artist',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                    color: const Color(0xFF0095F6),
                                    size: 32,
                                  ),
                                  onPressed: () => _togglePreview(track),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                            onTap: () {
                              _previewPlayer?.stop();
                              widget.onTrackSelected(track);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── GIF SEARCH BOTTOM SHEET ────────────────────────────────
class _GifSearchSheet extends ConsumerStatefulWidget {
  final ValueChanged<Map<String, dynamic>> onGifSelected;

  const _GifSearchSheet({required this.onGifSelected});

  @override
  ConsumerState<_GifSearchSheet> createState() => _GifSearchSheetState();
}

class _GifSearchSheetState extends ConsumerState<_GifSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _gifs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load trending or featured GIFs initially
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) async {
    setState(() => _isLoading = true);

    try {
      final client = ref.read(dioClientProvider);
      final response = await client.get('/gifs/search', queryParameters: {'query': query});
      if (mounted) {
        setState(() {
          _gifs = response.data['data']['gifs'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Text(
            'Choose GIF',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // Search input bar
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Search GIPHY...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.white12 : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          
          // Staggered / Regular Double-column Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _gifs.isEmpty
                    ? const Center(child: Text('No GIFs found', style: TextStyle(color: Colors.grey)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _gifs.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final gif = Map<String, dynamic>.from(_gifs[index]);
                          final previewUrl = gif['preview_url'] ?? gif['url'] ?? '';

                          return GestureDetector(
                            onTap: () {
                              widget.onGifSelected(gif);
                              Navigator.pop(context);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                color: isDark ? Colors.grey[850] : Colors.grey[200],
                                child: Image.network(
                                  previewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.gif, color: Colors.grey, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
