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

class _StoryEditorPageState extends ConsumerState<StoryEditorPage> with TickerProviderStateMixin {
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

  // Interaction
  bool _isDragging = false;
  bool _isOverDeleteZone = false;
  PlacedElement? _activeElement;

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

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _textFocus = FocusNode();
    _initMedia();
  }

  Future<void> _initMedia() async {
    final path = widget.file.path.toLowerCase();
    final isVid = path.endsWith('.mp4') || path.endsWith('.mov') ||
        path.endsWith('.avi') || path.endsWith('.mkv');

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
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────

  void _share() async {
    if (_isUploading) return;
    HapticFeedback.lightImpact();
    setState(() { _isUploading = true; _uploadProgress = 0; });

    try {
      await ref.read(storyServiceProvider).createStory(
        mediaFile: widget.file,
        mediaType: _isVideo ? 'video' : 'image',
        caption: _elements.where((e) => e.type == ElementType.text).isNotEmpty 
            ? _elements.firstWhere((e) => e.type == ElementType.text).content.toString() 
            : null,
        audience: _audience == StoryAudience.closeFriends ? 'close_friends' : 'followers',
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
        AppSnackbar.error(context, e.toString().replaceAll('Exception: ', ''));
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

  void _addText() {
    setState(() {
      _isTextMode = true;
      _textCtrl.clear();
      _textFocus.requestFocus();
    });
  }

  void _confirmText() {
    if (_textCtrl.text.trim().isEmpty) {
      setState(() { _isTextMode = false; });
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
          position: Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2),
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
          if (_isDrawingMode) _buildDrawingModeUI(safeAreaTop, safeAreaBottom),

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
          child: _isVideo && _videoController != null && _videoController!.value.isInitialized
              ? VideoPlayer(_videoController!)
              : Image.file(widget.file, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildDrawingLayer() {
    return Positioned.fill(
      child: CustomPaint(
        painter: DrawingPainter(strokes: _strokes, currentPoints: _currentStrokePoints, currentColor: _selectedColor, currentSize: _strokeSize),
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
          });
          HapticFeedback.selectionClick();
        },
        onScaleUpdate: (details) {
          setState(() {
            e.position += details.focalPointDelta;
            e.scale *= details.scale;
            e.rotation += details.rotation;
            
            // Delete zone detection (simple threshold)
            _isOverDeleteZone = e.position.dy > MediaQuery.of(context).size.height - 150;
          });
        },
        onScaleEnd: (details) {
          if (_isOverDeleteZone) {
            setState(() { _elements.remove(e); });
            HapticFeedback.mediumImpact();
          }
          setState(() {
            _activeElement = null;
            _isDragging = false;
            _isOverDeleteZone = false;
          });
        },
        onDoubleTap: () {
          setState(() {
            _editingElement = e;
            _textCtrl.text = e.content;
            _isTextMode = true;
            _textFocus.requestFocus();
          });
        },
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(e.scale)
            ..rotateZ(e.rotation),
          child: _buildElementWidget(e),
        ),
      ),
    );
  }

  Widget _buildElementWidget(PlacedElement e) {
    if (e.type == ElementType.text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          e.content,
          textAlign: e.alignment,
          style: TextStyle(
            color: e.color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: e.fontFamily,
            shadows: [Shadow(blurRadius: 8, color: Colors.black.withOpacity(0.5))],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMusicWidget() {
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _pickMusic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_selectedMusic!['thumbnail'] != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      _selectedMusic!['thumbnail'],
                      width: 32,
                      height: 32,
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
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _selectedMusic!['artist'] ?? 'Artist',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
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
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                ),
              ),
            ),
            const Spacer(),
            Container(
              height: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.45), Colors.transparent],
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
      left: 12, right: 12,
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
      top: 0, bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RightTool(icon: LucideIcons.pencil, label: 'Draw', onTap: () => setState(() => _isDrawingMode = true)),
            _RightTool(icon: LucideIcons.type, label: 'Text', onTap: _addText),
            _RightTool(icon: LucideIcons.smile, label: 'Sticker', onTap: () {}),
            _RightTool(icon: LucideIcons.music, label: 'Music', onTap: _pickMusic),
            _RightTool(
              icon: _showSparkles ? LucideIcons.sparkle : LucideIcons.sparkles, 
              label: 'Effects', 
              onTap: () => setState(() => _showSparkles = !_showSparkles),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(double safeAreaBottom) {
    return Positioned(
      bottom: safeAreaBottom + 12,
      left: 16, right: 16,
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _addText,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Aa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _share,
            child: Row(
              children: [
                const Text('Your story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.chevron_right, color: Colors.black, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawingModeUI(double safeAreaTop, double safeAreaBottom) {
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
          left: 12, right: 12,
          child: Row(
            children: [
              _StoryIconButton(
                icon: LucideIcons.undo_2,
                onTap: _strokes.isEmpty ? null : () => setState(() => _strokes.removeLast()),
              ),
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onPressed: () => setState(() => _isDrawingMode = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        // Tools (right)
        Positioned(
          right: 12,
          top: 0, bottom: 0,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DrawToolBtn(icon: LucideIcons.pencil, isSelected: !_isEraser && !_isNeon, onTap: () => setState(() { _isEraser = false; _isNeon = false; })),
                _DrawToolBtn(icon: LucideIcons.zap, isSelected: _isNeon, onTap: () => setState(() { _isEraser = false; _isNeon = true; })),
                _DrawToolBtn(icon: LucideIcons.eraser, isSelected: _isEraser, onTap: () => setState(() { _isEraser = true; _isNeon = false; })),
              ],
            ),
          ),
        ),
        // Stroke Slider (left)
        _buildStrokeSizeSlider(),
        // Colors (bottom)
        Positioned(
          bottom: safeAreaBottom + 8,
          left: 0, right: 0,
          child: _buildColorPicker(),
        ),
      ],
    );
  }

  Widget _buildStrokeSizeSlider() {
    return Positioned(
      left: 16,
      top: 0, bottom: 0,
      child: Center(
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            setState(() {
              _strokeSize = (_strokeSize - details.delta.dy * 0.3).clamp(2.0, 40.0);
            });
            HapticFeedback.selectionClick();
          },
          child: Container(
            width: 32,
            height: 180,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(16)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 4, height: 140, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                Positioned(
                  bottom: ((_strokeSize - 2) / 38) * 140 + 10,
                  child: Container(
                    width: _strokeSize.clamp(8, 28),
                    height: _strokeSize.clamp(8, 28),
                    decoration: BoxDecoration(color: _selectedColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    final colors = [Colors.white, Colors.black, Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.pink];
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: colors.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => setState(() => _selectedColor = colors[i]),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: _selectedColor == colors[i] ? 36 : 28,
            height: _selectedColor == colors[i] ? 36 : 28,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(color: _selectedColor == colors[i] ? Colors.white : Colors.white24, width: _selectedColor == colors[i] ? 3 : 1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextModeUI(double safeAreaTop) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CupertinoTextField(
                controller: _textCtrl,
                focusNode: _textFocus,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                decoration: null,
                maxLines: null,
              ),
            ),
          ),
          Positioned(
            top: safeAreaTop + 8,
            right: 12,
            child: CupertinoButton(
              onPressed: _confirmText,
              child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteZone(double safeAreaBottom) {
    return Positioned(
      bottom: safeAreaBottom + 80,
      left: 0, right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _isOverDeleteZone ? 72 : 56,
          height: _isOverDeleteZone ? 72 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isOverDeleteZone ? Colors.red : Colors.black45,
            border: Border.all(color: Colors.white24, width: 2),
          ),
          child: Icon(_isOverDeleteZone ? LucideIcons.trash_2 : LucideIcons.trash, color: Colors.white, size: _isOverDeleteZone ? 28 : 22),
        ),
      ),
    );
  }

  Widget _buildUploadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: _uploadProgress > 0 ? _uploadProgress : null, color: Colors.white),
            const SizedBox(height: 24),
            Text('Sharing to story... ${(_uploadProgress * 100).toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
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
        width: 40, height: 40,
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
        child: iconPath != null 
          ? Center(
              child: SvgPicture.asset(
                iconPath!, 
                width: 20, height: 20, 
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            )
          : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RightTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RightTool({required this.icon, required this.label, required this.onTap});

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
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
          ],
        ),
      ),
    );
  }
}

class _DrawToolBtn extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _DrawToolBtn({required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          width: isSelected ? 46 : 38,
          height: isSelected ? 46 : 38,
          decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.black45, shape: BoxShape.circle),
          child: Icon(icon, color: isSelected ? Colors.black : Colors.white, size: isSelected ? 22 : 18),
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

  DrawingPainter({required this.strokes, required this.currentPoints, required this.currentColor, required this.currentSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      paint.color = stroke.color;
      paint.strokeWidth = stroke.size;
      
      if (stroke.isNeon) {
        final neonPaint = Paint()
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..color = stroke.color.withOpacity(0.5)
          ..strokeWidth = stroke.size + 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
        _drawStroke(canvas, stroke.points, neonPaint);
      }
      
      _drawStroke(canvas, stroke.points, paint);
    }

    if (currentPoints.isNotEmpty) {
      paint.color = currentColor;
      paint.strokeWidth = currentSize;
      _drawStroke(canvas, currentPoints, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
