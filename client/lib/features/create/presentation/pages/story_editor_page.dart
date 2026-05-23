// lib/features/create/presentation/pages/story_editor_page.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/widgets/app_snackbar.dart';
import '../../../story/presentation/pages/story_creator_page.dart';
import '../../../story/data/repositories/story_service.dart';
import '../../../story/presentation/providers/story_provider.dart';
import '../../../story/presentation/widgets/music_picker.dart';

// ── Models ────────────────────────────────────────────────

enum ElementType { text, sticker }

class PlacedElement {
  final String id;
  final ElementType type;
  dynamic content;
  Offset position;
  double scale;
  double rotation;

  // Text specific
  TextAlign alignment;
  TextStyleType styleType;
  Color color;
  String fontFamily;

  PlacedElement({
    required this.id,
    required this.type,
    required this.content,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.alignment = TextAlign.center,
    this.styleType = TextStyleType.classic,
    this.color = Colors.white,
    this.fontFamily = 'SFPro',
  });
}

enum TextStyleType { classic, highlight, neon, outline }

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double size;
  final bool isEraser;
  final bool isNeon;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.size,
    this.isEraser = false,
    this.isNeon = false,
  });
}

// ── Story Editor Page ──────────────────────────────────────

class StoryEditorPage extends ConsumerStatefulWidget {
  final File file;
  const StoryEditorPage({super.key, required this.file});

  @override
  ConsumerState<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends ConsumerState<StoryEditorPage>
    with TickerProviderStateMixin {
  // Media
  bool _isVideo = false;
  VideoPlayerController? _videoController;

  // Layers
  final List<PlacedElement> _elements = [];
  final List<DrawingStroke> _strokes = [];
  List<Offset> _currentStrokePoints = [];

  // Modes
  bool _isDrawingMode = false;
  bool _isTextMode = false;
  PlacedElement? _editingElement;

  // Drawing state
  Color _selectedColor = Colors.white;
  double _strokeSize = 10.0;
  bool _isEraser = false;
  bool _isNeon = false;

  // Text style
  TextStyleType _selectedStyle = TextStyleType.classic;

  // Interaction
  bool _isDragging = false;
  bool _isOverDeleteZone = false;
  PlacedElement? _activeElement;

  // Gesture Lock Tracking
  double _startScale = 1.0;
  double _startRotation = 0.0;
  Offset _startPosition = Offset.zero;


  // Upload
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  StoryAudience _audience = StoryAudience.everyone;

  // Music
  Map<String, dynamic>? _selectedMusic;

  // Effects
  bool _showSparkles = false;

  // Text Editing
  late TextEditingController _textCtrl;
  late FocusNode _textFocus;

  // Animations
  late AnimationController _deleteZoneCtrl;
  late Animation<double> _deleteZoneScale;
  late AnimationController _deleteZoneGlowCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _textFocus = FocusNode();

    _deleteZoneCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _deleteZoneScale = Tween<double>(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: _deleteZoneCtrl, curve: Curves.easeOutBack));

    _deleteZoneGlowCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);

    _initMedia();
  }

  Future<void> _initMedia() async {
    final p = widget.file.path.toLowerCase();
    final isVid = p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.avi') ||
        p.endsWith('.mkv');

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
    _deleteZoneCtrl.dispose();
    _deleteZoneGlowCtrl.dispose();
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────

  void _share() async {
    if (_isUploading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      await ref.read(storyServiceProvider).createStory(
            mediaFile: widget.file,
            mediaType: _isVideo ? 'video' : 'image',
            caption: _elements
                    .where((e) => e.type == ElementType.text)
                    .isNotEmpty
                ? _elements
                    .firstWhere((e) => e.type == ElementType.text)
                    .content
                    .toString()
                : null,
            audience: _audience == StoryAudience.closeFriends
                ? 'close_friends'
                : 'followers',
            musicData: _selectedMusic,
            onProgress: (p) => setState(() => _uploadProgress = p),
          );
      ref.invalidate(storyFeedProvider);
      if (mounted) {
        HapticFeedback.mediumImpact();
        AppSnackbar.success(context, 'Story shared! 🎉');
        context.pop();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        AppSnackbar.error(
            context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _pickMusic() async {
    final song = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MusicPicker(),
    );

    if (song != null) {
      setState(() {
        _selectedMusic = song;
      });
    }
  }

  void _showStickerPicker() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StickerPickerSheet(
        onStickerSelected: (sticker) {
          setState(() {
            _elements.add(PlacedElement(
              id: DateTime.now().toString(),
              type: ElementType.sticker,
              content: sticker,
              position: Offset(
                MediaQuery.of(context).size.width / 2 - 100,
                MediaQuery.of(context).size.height / 2 - 40,
              ),
              scale: 1.0,
              rotation: 0.0,
            ));
          });
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }


  void _addText() {
    setState(() {
      _isTextMode = true;
      _textCtrl.clear();
      _textFocus.requestFocus();
    });
  }

  void _confirmText() {
    if (_textCtrl.text.trim().isEmpty) {
      setState(() {
        _isTextMode = false;
      });
      return;
    }

    if (_editingElement != null) {
      setState(() {
        _editingElement!.content = _textCtrl.text;
        _editingElement = null;
        _isTextMode = false;
      });
    } else {
      setState(() {
        _elements.add(PlacedElement(
          id: DateTime.now().toString(),
          type: ElementType.text,
          content: _textCtrl.text,
          position: Offset(
            MediaQuery.of(context).size.width / 2 - 60,
            MediaQuery.of(context).size.height / 2 - 30,
          ),
          styleType: _selectedStyle,
          color: _selectedColor,
        ));
        _isTextMode = false;
      });
    }
    _textFocus.unfocus();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Background
          _buildBackground(),

          // 2. Drawing Layer
          _buildDrawingLayer(),

          // 3. Placed Elements
          ..._elements.map((e) => _buildPlacedElement(e)),

          // 3.5 Effects Layer
          if (_showSparkles)
            Positioned.fill(
              child: IgnorePointer(
                child: Lottie.asset(
                  AppAssets.sparkle,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          // Music Widget
          if (_selectedMusic != null) _buildMusicWidget(),

          // 4. Overlays
          if (!_isDrawingMode && !_isTextMode) ...[
            _buildGradients(),
            _buildTopControls(safeAreaTop),
            _buildRightTools(),
            _buildBottomToolbar(safeAreaBottom),
          ],

          // 5. Drawing Mode UI
          if (_isDrawingMode)
            _buildDrawingModeUI(safeAreaTop, safeAreaBottom),

          // 6. Text Mode UI
          if (_isTextMode) _buildTextModeUI(safeAreaTop),

          // 7. Delete Zone
          if (_isDragging) _buildDeleteZone(safeAreaBottom),

          // 8. Uploading Overlay
          if (_isUploading) _buildUploadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Center(
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: _isVideo &&
                  _videoController != null &&
                  _videoController!.value.isInitialized
              ? VideoPlayer(_videoController!)
              : Image.file(widget.file, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildDrawingLayer() {
    return Positioned.fill(
      child: CustomPaint(
        painter: DrawingPainter(
          strokes: _strokes,
          currentPoints: _currentStrokePoints,
          currentColor: _selectedColor,
          currentSize: _strokeSize,
          isNeonActive: _isNeon,
        ),
      ),
    );
  }

  Widget _buildPlacedElement(PlacedElement e) {
    return Positioned(
      left: e.position.dx,
      top: e.position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          setState(() {
            _activeElement = e;
            _isDragging = true;
            _startScale = e.scale;
            _startRotation = e.rotation;
            _startPosition = e.position;
          });
          HapticFeedback.selectionClick();
        },
        onScaleUpdate: (details) {
          final screenH = MediaQuery.of(context).size.height;
          setState(() {
            // Smooth, robust focal point translation
            e.position += details.focalPointDelta;
            
            // Scaled/rotated relative to locks to prevent cumulative multiplication explosion
            if (details.scale != 1.0) {
              e.scale = (_startScale * details.scale).clamp(0.4, 4.0);
            }
            if (details.rotation != 0.0) {
              e.rotation = _startRotation + details.rotation;
            }

            // Delete zone detection with distance-based scale
            final distToBottom = screenH - e.position.dy;
            _isOverDeleteZone = distToBottom < 160;
            if (_isOverDeleteZone) {
              _deleteZoneCtrl.forward();
            } else {
              _deleteZoneCtrl.reverse();
            }
          });
        },
        onScaleEnd: (details) {
          if (_isOverDeleteZone) {
            setState(() {
              _elements.remove(e);
            });
            HapticFeedback.mediumImpact();
          }
          _deleteZoneCtrl.reverse();
          setState(() {
            _activeElement = null;
            _isDragging = false;
            _isOverDeleteZone = false;
          });
        },
        onDoubleTap: () {
          if (e.type == ElementType.text) {
            setState(() {
              _editingElement = e;
              _textCtrl.text = e.content;
              _isTextMode = true;
              _textFocus.requestFocus();
            });
          }
        },
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            // ignore: deprecated_member_use
            ..scale(e.scale)
            ..rotateZ(e.rotation),
          child: _buildElementWidget(e),
        ),
      ),
    );
  }

  Widget _buildElementWidget(PlacedElement e) {
    if (e.type == ElementType.text) {
      return _buildStyledText(e);
    }
    if (e.type == ElementType.sticker) {
      return _buildSticker(e);
    }
    return const SizedBox.shrink();
  }

  Widget _buildSticker(PlacedElement e) {
    final data = e.content as Map<String, dynamic>;
    final type = data['type'] as String;

    if (type == 'emoji') {
      return Text(
        data['emoji'] as String,
        style: const TextStyle(fontSize: 64),
      );
    }

    // Mention Sticker
    if (type == 'mention') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white30, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '@',
                  style: TextStyle(
                    color: Color(0xFF0095F6),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SF-Pro',
                  ),
                ),
                const SizedBox(width: 4),
                IntrinsicWidth(
                  child: TextField(
                    controller: TextEditingController(text: (data['text'] ?? 'username').toString().replaceAll('@', '')),
                    onChanged: (val) {
                      data['text'] = '@$val';
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF-Pro',
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Location Sticker
    if (type == 'location') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white70, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.map_pin, color: Color(0xFFED4956), size: 16),
                const SizedBox(width: 6),
                IntrinsicWidth(
                  child: TextField(
                    controller: TextEditingController(text: (data['text'] ?? 'Paris, France').toString().replaceAll('📍 ', '')),
                    onChanged: (val) {
                      data['text'] = '📍 $val';
                    },
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'SF-Pro',
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Poll Sticker
    if (type == 'poll') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: data['question'] ?? 'Ask a question...'),
                  onChanged: (val) => data['question'] = val,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'SF-Pro'),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: const Text('YES', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.black26),
                    Expanded(
                      child: Container(
                        height: 40,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: const Text('NO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Question Sticker
    if (type == 'question') {
      return Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF56040),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              alignment: Alignment.center,
              child: const Text('Ask me a question', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Text(
                'Type something...',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStyledText(PlacedElement e) {
    final text = e.content as String;

    switch (e.styleType) {
      case TextStyleType.classic:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            textAlign: e.alignment,
            style: TextStyle(
              color: e.color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                    blurRadius: 8, color: Colors.black.withOpacity(0.6))
              ],
            ),
          ),
        );
      case TextStyleType.highlight:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: e.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            textAlign: e.alignment,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case TextStyleType.neon:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            textAlign: e.alignment,
            style: TextStyle(
              color: e.color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                    color: e.color.withOpacity(0.9),
                    blurRadius: 16,
                    offset: Offset.zero),
                Shadow(
                    color: e.color.withOpacity(0.6),
                    blurRadius: 32,
                    offset: Offset.zero),
              ],
            ),
          ),
        );
      case TextStyleType.outline:
        return Stack(
          children: [
            // Stroke
            Text(
              text,
              textAlign: e.alignment,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = Colors.black,
              ),
            ),
            // Fill
            Text(
              text,
              textAlign: e.alignment,
              style: TextStyle(
                color: e.color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildMusicWidget() {
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _pickMusic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.music,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    if (_selectedMusic!['thumbnail'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _selectedMusic!['thumbnail'],
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedMusic!['title'] ?? 'Music',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _selectedMusic!['artist'] ?? 'Artist',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradients() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Column(
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControls(double safeAreaTop) {
    return Positioned(
      top: safeAreaTop + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          _StoryIconButton(
            iconPath: AppAssets.close,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          _StoryIconButton(
            iconPath: AppAssets.save,
            onTap: () {
              AppSnackbar.success(context, 'Story saved to device');
            },
          ),
          const SizedBox(width: 12),
          _StoryIconButton(
            icon: LucideIcons.settings,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildRightTools() {
    return Positioned(
      right: 12,
      top: 0,
      bottom: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StoryRightTool(
                      icon: LucideIcons.pencil,
                      label: 'Draw',
                      onTap: () =>
                          setState(() => _isDrawingMode = true)),
                  _StoryRightTool(
                      icon: LucideIcons.type,
                      label: 'Text',
                      onTap: _addText),
                  _StoryRightTool(
                      icon: LucideIcons.smile,
                      label: 'Sticker',
                      onTap: _showStickerPicker),
                  _StoryRightTool(
                      icon: LucideIcons.music,
                      label: 'Music',
                      onTap: _pickMusic),
                  _StoryRightTool(
                    icon: _showSparkles
                        ? LucideIcons.sparkle
                        : LucideIcons.sparkles,
                    label: 'Effects',
                    onTap: () =>
                        setState(() => _showSparkles = !_showSparkles),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(double safeAreaBottom) {
    return Positioned(
      bottom: safeAreaBottom + 12,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Aa Button
          GestureDetector(
            onTap: _addText,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1.5),
                  ),
                  child: const Text(
                    'Aa',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Share button
          GestureDetector(
            onTap: _share,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFD1D1D).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Text(
                    'Your story',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(LucideIcons.chevron_right, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingModeUI(
      double safeAreaTop, double safeAreaBottom) {
    return Stack(
      children: [
        // Capture layer
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (details) {
              setState(() {
                _currentStrokePoints = [details.localPosition];
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentStrokePoints.add(details.localPosition);
              });
            },
            onPanEnd: (details) {
              setState(() {
                _strokes.add(DrawingStroke(
                  points: List.from(_currentStrokePoints),
                  color: _isEraser ? Colors.black : _selectedColor,
                  size: _strokeSize,
                  isEraser: _isEraser,
                  isNeon: _isNeon,
                ));
                _currentStrokePoints = [];
              });
            },
          ),
        ),
        // Top Bar
        Positioned(
          top: safeAreaTop + 8,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _StoryIconButton(
                icon: LucideIcons.undo_2,
                onTap: _strokes.isEmpty
                    ? null
                    : () => setState(() => _strokes.removeLast()),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isDrawingMode = false),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter:
                        ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Drawing tool buttons (right)
        Positioned(
          right: 12,
          top: 0,
          bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DrawToolBtn(
                    icon: LucideIcons.pencil,
                    label: 'Pen',
                    isSelected: !_isEraser && !_isNeon,
                    onTap: () => setState(() {
                          _isEraser = false;
                          _isNeon = false;
                        })),
                _DrawToolBtn(
                    icon: LucideIcons.zap,
                    label: 'Neon',
                    isSelected: _isNeon,
                    onTap: () => setState(() {
                          _isEraser = false;
                          _isNeon = true;
                        })),
                _DrawToolBtn(
                    icon: LucideIcons.eraser,
                    label: 'Erase',
                    isSelected: _isEraser,
                    onTap: () => setState(() {
                          _isEraser = true;
                          _isNeon = false;
                        })),
              ],
            ),
          ),
        ),
        // Stroke Slider (left)
        _buildStrokeSizeSlider(),
        // Colors (bottom)
        Positioned(
          bottom: safeAreaBottom + 8,
          left: 0,
          right: 0,
          child: _buildColorPicker(),
        ),
      ],
    );
  }

  Widget _buildStrokeSizeSlider() {
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _strokeSize =
                  (_strokeSize - details.delta.dy * 0.3).clamp(2.0, 40.0);
            });
            HapticFeedback.selectionClick();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 36,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1), width: 1),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Positioned(
                      bottom:
                          ((_strokeSize - 2) / 38) * 130 + 10,
                      child: Container(
                        width: _strokeSize.clamp(8.0, 26.0),
                        height: _strokeSize.clamp(8.0, 26.0),
                        decoration: BoxDecoration(
                          color: _selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _selectedColor.withOpacity(0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      Colors.white,
      Colors.black,
      const Color(0xFFFF3B30),
      const Color(0xFFFF9500),
      const Color(0xFFFFCC00),
      const Color(0xFF34C759),
      const Color(0xFF007AFF),
      const Color(0xFFAF52DE),
      const Color(0xFFFF2D55),
      const Color(0xFF00C7BE),
    ];
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: colors.length,
        itemBuilder: (context, i) {
          final isActive = _selectedColor == colors[i];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedColor = colors[i]);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: isActive ? 38 : 30,
              height: isActive ? 38 : 30,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? Colors.white : Colors.white38,
                  width: isActive ? 3 : 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                            color: colors[i].withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextModeUI(double safeAreaTop) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Stack(
        children: [
          // Text Style Selector
          Positioned(
            top: safeAreaTop + 12,
            left: 0,
            right: 0,
            child: _TextStyleSelector(
              selected: _selectedStyle,
              onSelect: (s) => setState(() => _selectedStyle = s),
            ),
          ),
          // Text Input
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CupertinoTextField(
                controller: _textCtrl,
                focusNode: _textFocus,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                decoration: null,
                maxLines: null,
              ),
            ),
          ),
          // Done
          Positioned(
            top: safeAreaTop + 56,
            right: 16,
            child: GestureDetector(
              onTap: _confirmText,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          // Color picker at bottom
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 0,
            right: 0,
            child: _buildColorPicker(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteZone(double safeAreaBottom) {
    return Positioned(
      bottom: safeAreaBottom + 60,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _deleteZoneCtrl,
          builder: (context, child) {
            return Transform.scale(
              scale: _deleteZoneScale.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _isOverDeleteZone ? 76 : 60,
            height: _isOverDeleteZone ? 76 : 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _isOverDeleteZone
                  ? const RadialGradient(
                      colors: [Color(0xFFFF3B30), Color(0xFFFF6B35)],
                    )
                  : null,
              color: _isOverDeleteZone ? null : Colors.black54,
              border: Border.all(
                color: _isOverDeleteZone
                    ? Colors.white
                    : Colors.white30,
                width: 2,
              ),
              boxShadow: _isOverDeleteZone
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              _isOverDeleteZone
                  ? LucideIcons.trash_2
                  : LucideIcons.trash,
              color: Colors.white,
              size: _isOverDeleteZone ? 30 : 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.88),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    color: const Color(0xFF833AB4),
                    backgroundColor: Colors.white12,
                    strokeWidth: 4,
                  ),
                  Text(
                    '${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Sharing your story...',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'Keep the app open',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Text Style Selector ────────────────────────────────────
class _TextStyleSelector extends StatelessWidget {
  final TextStyleType selected;
  final ValueChanged<TextStyleType> onSelect;

  const _TextStyleSelector(
      {required this.selected, required this.onSelect});

  static const _labels = ['Classic', 'Highlight', 'Neon', 'Outline'];
  static const _types = TextStyleType.values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _labels.length,
        itemBuilder: (context, i) {
          final isActive = selected == _types[i];
          return GestureDetector(
            onTap: () {
              onSelect(_types[i]);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white12,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: isActive ? Colors.white : Colors.white24,
                    width: 1.5),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────

class _StoryIconButton extends StatelessWidget {
  final String? iconPath;
  final IconData? icon;
  final VoidCallback? onTap;
  const _StoryIconButton({this.iconPath, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle),
        child: iconPath != null
            ? Center(
                child: SvgPicture.asset(
                  iconPath!,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                      Colors.white, BlendMode.srcIn),
                ),
              )
            : Icon(icon,
                color: onTap != null ? Colors.white : Colors.white38,
                size: 20),
      ),
    );
  }
}

class _StoryRightTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _StoryRightTool(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _DrawToolBtn(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isSelected ? 48 : 40,
          height: isSelected ? 48 : 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.black45,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.black : Colors.white,
            size: isSelected ? 22 : 18,
          ),
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────

class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentSize;
  final bool isNeonActive;

  DrawingPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentSize,
    this.isNeonActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    for (final stroke in strokes) {
      paint.color = stroke.color;
      paint.strokeWidth = stroke.size;

      if (stroke.isNeon) {
        // Double-path neon: translucent glow under solid core
        final glowPaint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..color = stroke.color.withOpacity(0.35)
          ..strokeWidth = stroke.size + 14
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 12);
        _drawStroke(canvas, stroke.points, glowPaint);

        // Inner glow
        final innerGlowPaint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..color = stroke.color.withOpacity(0.65)
          ..strokeWidth = stroke.size + 4
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 4);
        _drawStroke(canvas, stroke.points, innerGlowPaint);
      }

      _drawStroke(canvas, stroke.points, paint);
    }

    if (currentPoints.isNotEmpty) {
      paint.color = currentColor;
      paint.strokeWidth = currentSize;

      if (isNeonActive) {
        final glowPaint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..color = currentColor.withOpacity(0.35)
          ..strokeWidth = currentSize + 14
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 12);
        _drawStroke(canvas, currentPoints, glowPaint);
      }

      _drawStroke(canvas, currentPoints, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(
          points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

// ── Sticker Picker Sheet ────────────────────────────────────

class _StickerPickerSheet extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onStickerSelected;
  const _StickerPickerSheet({required this.onStickerSelected});

  @override
  State<_StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<_StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0 = Features, 1 = Emoji
  late AnimationController _animCtrl;
  late Animation<double> _slideAnim;

  static const _emojis = [
    '😂', '❤️', '🔥', '✨', '😍', '🎉', '💯', '🙌',
    '😎', '🥳', '💪', '🤩', '😢', '😡', '🥺', '🤔',
    '💀', '🫶', '⭐', '🌈', '🍕', '🎵', '🚀', '🌊',
    '🦋', '🌸', '💎', '👑', '🎯', '🤝', '👏', '🫡',
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _pick(Map<String, dynamic> sticker) {
    Navigator.pop(context);
    widget.onStickerSelected(sticker);
  }

  @override
  Widget build(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (1 - _slideAnim.value) * 300),
        child: Opacity(
            opacity: _slideAnim.value.clamp(0.0, 1.0), child: child),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title + tab pills
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Text(
                        'Add to Story',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _tabPill('Features', 0),
                      const SizedBox(width: 8),
                      _tabPill('Emoji', 1),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                // Content area
                Expanded(
                  child: _tab == 0
                      ? _buildFeaturesGrid(safeBot)
                      : _buildEmojiGrid(safeBot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabPill(String label, int idx) {
    final isActive = _tab == idx;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tab = idx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : Colors.white70,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesGrid(double safeBot) {
    final features = [
      {
        'icon': LucideIcons.map_pin,
        'label': 'Location',
        'key': 'location',
        'color': const Color(0xFF4FC3F7)
      },
      {
        'icon': LucideIcons.at_sign,
        'label': 'Mention',
        'key': 'mention',
        'color': const Color(0xFFCE93D8)
      },
      {
        'icon': LucideIcons.chart_column,
        'label': 'Poll',
        'key': 'poll',
        'color': const Color(0xFF80CBC4)
      },
      {
        'icon': LucideIcons.circle_question_mark,
        'label': 'Question',
        'key': 'question',
        'color': const Color(0xFFF48FB1)
      },
      {
        'icon': LucideIcons.clock,
        'label': 'Countdown',
        'key': 'countdown',
        'color': const Color(0xFFFFCC80)
      },
      {
        'icon': LucideIcons.music,
        'label': 'Music',
        'key': 'music',
        'color': const Color(0xFF80DEEA)
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, safeBot + 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: features.length,
      itemBuilder: (_, i) {
        final f = features[i];
        final color = f['color'] as Color;
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            _pick({'type': 'feature', 'content': f['key'] as String});
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: color.withOpacity(0.35), width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(f['icon'] as IconData, color: color, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      f['label'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiGrid(double safeBot) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, safeBot + 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: _emojis.length,
      itemBuilder: (_, i) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _pick({'type': 'emoji', 'content': _emojis[i]});
          },
          child: Center(
            child: Text(
              _emojis[i],
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }
}
