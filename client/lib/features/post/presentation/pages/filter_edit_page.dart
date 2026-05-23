// lib/features/post/presentation/pages/filter_edit_page.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:colorfilter_generator/addons.dart';
import 'package:video_player/video_player.dart';
import 'finalize_post_page.dart';

// ── Edit tool model ────────────────────────────────────────
class _Tool {
  final String name;
  final IconData icon;
  final double min;
  final double max;
  double value;

  _Tool({
    required this.name,
    required this.icon,
    this.min = -100,
    this.max = 100,
    this.value = 0,
  });

  bool get isChanged => value != 0;
  bool get hasZeroCenter => min < 0;
}

// ── Filter & Edit Page ─────────────────────────────────────
class FilterEditPage extends StatefulWidget {
  final List<File> images;
  const FilterEditPage({super.key, required this.images});

  @override
  State<FilterEditPage> createState() => _FilterEditPageState();
}

class _FilterEditPageState extends State<FilterEditPage>
    with SingleTickerProviderStateMixin {
  // Tab
  int _tab = 0; // 0=Filter 1=Edit
  late AnimationController _tabAnim;

  // Image carousel
  late PageController _pageCtrl;
  int _currentPage = 0;

  // Per-image filter selection
  late List<int> _filterIndex; // index into presetFiltersList
  late List<double> _filterIntensity;
  bool _showIntensitySlider = false;
  int? _lastTappedFilterIndex;

  // Per-image edit tools (one set per image)
  late List<List<_Tool>> _toolSets;
  _Tool? _activeTool;

  // Transform controllers
  late List<TransformationController> _txCtrls;

  bool _isComparing = false;

  List<_Tool> get _tools => _toolSets[_currentPage];

  bool _isVideo(File f) {
    final ext = f.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'm4v'].contains(ext);
  }

  @override
  void initState() {
    super.initState();
    _tabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _pageCtrl = PageController();
    final n = widget.images.length;
    _filterIndex = List.filled(n, 0);
    _filterIntensity = List.filled(n, 100);
    _txCtrls = List.generate(n, (_) => TransformationController());
    _toolSets = List.generate(n, (_) => _buildTools());
  }

  List<_Tool> _buildTools() => [
        _Tool(name: 'Brightness', icon: LucideIcons.sun),
        _Tool(name: 'Contrast', icon: LucideIcons.circle),
        _Tool(name: 'Warmth', icon: LucideIcons.thermometer),
        _Tool(name: 'Saturation', icon: LucideIcons.droplets),
        _Tool(name: 'Fade', icon: LucideIcons.blend),
        _Tool(name: 'Highlights', icon: LucideIcons.sparkle),
        _Tool(name: 'Shadows', icon: LucideIcons.moon, min: -100, max: 100),
        _Tool(name: 'Vignette', icon: LucideIcons.aperture, min: 0, max: 100),
        _Tool(name: 'Sharpen', icon: LucideIcons.zap, min: 0, max: 100),
      ];

  @override
  void dispose() {
    _tabAnim.dispose();
    _pageCtrl.dispose();
    for (final c in _txCtrls) c.dispose();
    super.dispose();
  }

  ColorFilter _buildFilter(int imgIdx) {
    final preset = presetFiltersList[_filterIndex[imgIdx]];
    final intensity = _filterIntensity[imgIdx] / 100.0;
    final tools = _toolSets[imgIdx];

    final filters = <List<double>>[];
    if (preset.matrix.isNotEmpty && _filterIndex[imgIdx] != 0) {
      // Blend preset with intensity
      if (intensity < 1.0) {
        filters.add(_blendMatrix(preset.matrix, intensity));
      } else {
        filters.add(preset.matrix);
      }
    }

    final bright = tools[0].value / 100;
    final contrast = tools[1].value / 100;
    final warmth = tools[2].value / 200;
    final sat = tools[3].value / 100;

    if (bright != 0) filters.add(ColorFilterAddons.brightness(bright));
    if (contrast != 0) filters.add(ColorFilterAddons.contrast(contrast));
    if (sat != 0) filters.add(ColorFilterAddons.saturation(sat));
    if (warmth != 0) filters.add(ColorFilterAddons.sepia(warmth));

    if (filters.isEmpty) return const ColorFilter.mode(Colors.transparent, BlendMode.dst);

    final gen = ColorFilterGenerator(name: 'combined', filters: filters);
    return ColorFilter.matrix(gen.matrix);
  }

  List<double> _blendMatrix(List<double> m, double t) {
    // identity matrix
    const id = [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    return List.generate(m.length, (i) => id[i] + (m[i] - id[i]) * t);
  }

  void _goNext() {
    final matrices = <List<double>>[];
    for (int i = 0; i < widget.images.length; i++) {
      final f = _buildFilter(i);
      // Extract matrix from ColorFilter — pass raw preset matrix
      matrices.add(presetFiltersList[_filterIndex[i]].matrix);
    }
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => FinalizePostPage(
          images: widget.images,
          filterMatrices: matrices,
          transformations: _txCtrls.map((c) => c.value).toList(),
        ),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            _buildNavBar(safeTop),
            _buildPreview(screenW),
            _buildTabBar(screenW),
            Expanded(child: _tab == 0 ? _buildFilterTab() : _buildEditTab()),
          ],
        ),
      ),
    );
  }

  // ── NAV BAR ────────────────────────────────────────────
  Widget _buildNavBar(double safeTop) {
    return Container(
      height: safeTop + 44,
      color: Colors.black,
      padding: EdgeInsets.only(top: safeTop, left: 4, right: 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: () => Navigator.pop(context),
            child: const Icon(LucideIcons.chevron_left,
                color: Colors.white, size: 28),
          ),
          const Spacer(),
          const Text('Edit',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF-Pro')),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: _goNext,
            child: const Text('Next',
                style: TextStyle(
                    color: Color(0xFF0095F6),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF-Pro')),
          ),
        ],
      ),
    );
  }

  // ── PREVIEW ────────────────────────────────────────────
  Widget _buildPreview(double screenW) {
    return SizedBox(
      width: screenW,
      height: screenW,
      child: GestureDetector(
        onLongPressStart: (_) {
          HapticFeedback.mediumImpact();
          setState(() => _isComparing = true);
        },
        onLongPressEnd: (_) {
          HapticFeedback.lightImpact();
          setState(() => _isComparing = false);
        },
        onLongPressCancel: () {
          setState(() => _isComparing = false);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageCtrl,
              physics: _isComparing ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: (i) =>
                  setState(() { _currentPage = i; _activeTool = null; }),
              itemBuilder: (_, i) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Original un-filtered / un-adjusted image
                    InteractiveViewer(
                      transformationController: _txCtrls[i],
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: _isVideo(widget.images[i])
                          ? _VideoPreviewItem(file: widget.images[i])
                          : Image.file(widget.images[i], fit: BoxFit.cover),
                    ),
                    // Filtered and Adjusted Image with fading
                    AnimatedOpacity(
                      opacity: _isComparing ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      child: IgnorePointer(
                        ignoring: _isComparing,
                        child: ColorFiltered(
                          colorFilter: _buildFilter(i),
                          child: InteractiveViewer(
                            transformationController: _txCtrls[i],
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: _isVideo(widget.images[i])
                                ? _VideoPreviewItem(file: widget.images[i])
                                : Image.file(widget.images[i], fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Page count badge
            if (widget.images.length > 1)
              Positioned(
                top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${widget.images.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF-Pro'),
                  ),
                ),
              ),
            // Page dots
            if (widget.images.length > 1)
              Positioned(
                bottom: 10, left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: active ? 6 : 5,
                      height: active ? 6 : 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? Colors.white : Colors.white54,
                      ),
                    );
                  }),
                ),
              ),
            // Comparing ORIGINAL overlay badge
            if (_isComparing)
              Positioned(
                top: 16,
                left: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.eye, color: Colors.white, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            'ORIGINAL PREVIEW',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              fontFamily: 'SF-Pro',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── TAB BAR ────────────────────────────────────────────
  Widget _buildTabBar(double screenW) {
    return Container(
      height: 44,
      color: Colors.black,
      child: Stack(
        children: [
          // Top separator
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(height: 0.33, color: Colors.white24),
          ),
          // Tabs
          Row(
            children: ['Filter', 'Edit'].asMap().entries.map((e) {
              final active = _tab == e.key;
              return Expanded(
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() {
                    _tab = e.key;
                    _activeTool = null;
                    _showIntensitySlider = false;
                  }),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white38,
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      fontFamily: 'SF-Pro',
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // Sliding underline
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            bottom: 0,
            left: _tab == 0 ? 0 : screenW / 2,
            child: Container(width: screenW / 2, height: 1.5, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── FILTER TAB ─────────────────────────────────────────
  Widget _buildFilterTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: presetFiltersList.length,
            itemBuilder: (_, i) {
              final filter = presetFiltersList[i];
              final isSel = _filterIndex[_currentPage] == i;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isSel) {
                    setState(() =>
                        _showIntensitySlider = !_showIntensitySlider);
                  } else {
                    setState(() {
                      _filterIndex[_currentPage] = i;
                      _showIntensitySlider = false;
                    });
                  }
                },
                child: AnimatedScale(
                  scale: isSel ? 1.04 : 0.96,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Container(
                    margin: const EdgeInsets.only(right: 14, top: 4, bottom: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? const Color(0xFF0095F6) : Colors.white12,
                              width: 2.0,
                            ),
                            boxShadow: isSel ? [
                              BoxShadow(
                                color: const Color(0xFF0095F6).withOpacity(0.3),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ] : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: ColorFiltered(
                                colorFilter: i == 0
                                    ? const ColorFilter.mode(
                                        Colors.transparent, BlendMode.dst)
                                    : ColorFilter.matrix(filter.matrix),
                                child: _isVideo(widget.images[_currentPage])
                                    ? _VideoPreviewItem(
                                        file: widget.images[_currentPage],
                                        isThumb: true,
                                      )
                                    : Image.file(
                                        widget.images[_currentPage],
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSel) ...[
                              const Icon(LucideIcons.check,
                                  color: Color(0xFF0095F6), size: 10),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              filter.name,
                              style: TextStyle(
                                color: isSel ? const Color(0xFF0095F6) : Colors.white60,
                                fontSize: 10.5,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                fontFamily: 'SF-Pro',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Intensity slider with PremiumSlider
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _showIntensitySlider
              ? Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  color: Colors.black,
                  child: Column(
                    children: [
                      _PremiumSlider(
                        value: _filterIntensity[_currentPage],
                        min: 0,
                        max: 100,
                        onChanged: (v) => setState(() {
                          _filterIntensity[_currentPage] = v;
                        }),
                        onReset: () => setState(() {
                          _filterIntensity[_currentPage] = 100.0;
                        }),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Original (0)',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 11,
                                    fontFamily: 'SF-Pro')),
                            Text('Double tap to reset (100)',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: 'SF-Pro')),
                            Text('Full (100)',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 11,
                                    fontFamily: 'SF-Pro')),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── EDIT TAB ───────────────────────────────────────────
  Widget _buildEditTab() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 40),
      itemCount: _tools.length,
      itemBuilder: (_, i) {
        final tool = _tools[i];
        final isActive = _activeTool == tool;
        return Column(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() =>
                    _activeTool = isActive ? null : tool);
              },
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(tool.icon,
                        color: isActive || tool.isChanged
                            ? Colors.white
                            : Colors.white.withOpacity(0.55),
                        size: 22),
                    const SizedBox(width: 16),
                    Text(tool.name,
                        style: TextStyle(
                            color: isActive ? Colors.white : Colors.white.withOpacity(0.85),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'SF-Pro')),
                    const Spacer(),
                    if (tool.isChanged)
                      Text(
                        tool.value > 0
                            ? '+${tool.value.round()}'
                            : '${tool.value.round()}',
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 13,
                            fontFamily: 'SF-Pro'),
                      ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.chevron_right,
                        color: Colors.white24, size: 16),
                  ],
                ),
              ),
            ),
            // Inline slider
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: isActive
                  ? _buildInlineSlider(tool)
                  : const SizedBox.shrink(),
            ),
            Container(
              height: 0.33,
              margin: const EdgeInsets.only(left: 58),
              color: Colors.white12,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInlineSlider(_Tool tool) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      color: Colors.black,
      child: Column(
        children: [
          const SizedBox(height: 10),
          _PremiumSlider(
            value: tool.value,
            min: tool.min,
            max: tool.max,
            onChanged: (v) {
              setState(() => tool.value = v);
            },
            onReset: () {
              setState(() => tool.value = 0.0);
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${tool.min.round()}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontFamily: 'SF-Pro')),
                Text('Double tap slider to reset',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'SF-Pro')),
                Text('+${tool.max.round()}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        fontFamily: 'SF-Pro')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PREMIUM HAPTIC SLIDER WITH TOOLTIP & ACCURATE PHYSICS ───────
class _PremiumSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;

  const _PremiumSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onReset,
  });

  @override
  State<_PremiumSlider> createState() => _PremiumSliderState();
}

class _PremiumSliderState extends State<_PremiumSlider> {
  bool _isDragging = false;

  void _handleDrag(DragUpdateDetails details, double trackWidth) {
    final localX = details.localPosition.dx;
    final pct = (localX / trackWidth).clamp(0.0, 1.0);
    final newValue = widget.min + pct * (widget.max - widget.min);
    widget.onChanged(newValue);
  }

  void _handleTap(TapUpDetails details, double trackWidth) {
    final localX = details.localPosition.dx;
    final pct = (localX / trackWidth).clamp(0.0, 1.0);
    final newValue = widget.min + pct * (widget.max - widget.min);
    widget.onChanged(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.max - widget.min;
    final normalizedValue = ((widget.value - widget.min) / range).clamp(0.0, 1.0);
    final isCentered = widget.min < 0 && widget.max > 0;
    final zeroPos = isCentered ? (-widget.min / range).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        if (widget.onReset != null) {
          widget.onReset!();
        } else {
          widget.onChanged(0.0);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Value Tooltip above the slider
              Positioned(
                top: -34,
                left: (normalizedValue * width - 20).clamp(0.0, width - 40),
                child: AnimatedScale(
                  scale: _isDragging ? 1.1 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0095F6),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Text(
                      widget.value > 0
                          ? '+${widget.value.round()}'
                          : '${widget.value.round()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'SF-Pro',
                      ),
                    ),
                  ),
                ),
              ),
              // Track & gestures
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {
                  setState(() => _isDragging = true);
                  HapticFeedback.selectionClick();
                },
                onHorizontalDragUpdate: (details) => _handleDrag(details, width),
                onHorizontalDragEnd: (_) {
                  setState(() => _isDragging = false);
                  HapticFeedback.lightImpact();
                },
                onTapUp: (details) => _handleTap(details, width),
                child: SizedBox(
                  height: 30,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Inactive track background
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Centered tick mark if zero center
                      if (isCentered)
                        Positioned(
                          left: zeroPos * width - 1,
                          child: Container(
                            width: 2,
                            height: 10,
                            color: Colors.white.withOpacity(0.45),
                          ),
                        ),
                      // Active track filling with gradient
                      Positioned(
                        left: isCentered
                            ? (normalizedValue < zeroPos ? normalizedValue * width : zeroPos * width)
                            : 0,
                        right: isCentered
                            ? (normalizedValue < zeroPos ? (1.0 - zeroPos) * width : (1.0 - normalizedValue) * width)
                            : (1.0 - normalizedValue) * width,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00C6FF), Color(0xFF0095F6)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Sliding Thumb
                      Positioned(
                        left: normalizedValue * width - 10,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 50),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                            border: Border.all(
                              color: const Color(0xFF0095F6).withOpacity(_isDragging ? 0.8 : 0.0),
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Video Preview Item ─────────────────────────────────────

class _VideoPreviewItem extends StatefulWidget {
  final File file;
  final bool isThumb;
  const _VideoPreviewItem({required this.file, this.isThumb = false});

  @override
  State<_VideoPreviewItem> createState() => _VideoPreviewItemState();
}

class _VideoPreviewItemState extends State<_VideoPreviewItem> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(widget.file);
    _ctrl!.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        if (!widget.isThumb) {
          _ctrl!.setLooping(true);
          _ctrl!.play();
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CupertinoActivityIndicator(color: Colors.white),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _ctrl!.value.size.width,
          height: _ctrl!.value.size.height,
          child: VideoPlayer(_ctrl!),
        ),
      ),
    );
  }
}

