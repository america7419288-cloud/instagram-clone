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

  List<_Tool> get _tools => _toolSets[_currentPage];

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
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.images.length,
            onPageChanged: (i) =>
                setState(() { _currentPage = i; _activeTool = null; }),
            itemBuilder: (_, i) => ColorFiltered(
              colorFilter: _buildFilter(i),
              child: InteractiveViewer(
                transformationController: _txCtrls[i],
                minScale: 1.0,
                maxScale: 4.0,
                child: Image.file(widget.images[i], fit: BoxFit.cover),
              ),
            ),
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
        ],
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
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: isSel ? 68 : 62,
                        height: isSel ? 68 : 62,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: ColorFiltered(
                            colorFilter: i == 0
                                ? const ColorFilter.mode(
                                    Colors.transparent, BlendMode.dst)
                                : ColorFilter.matrix(filter.matrix),
                            child: Image.file(
                              widget.images[_currentPage],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        filter.name,
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white60,
                          fontSize: 10,
                          fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                          fontFamily: 'SF-Pro',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Intensity slider
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: _showIntensitySlider ? 52 : 0,
          color: Colors.black,
          child: _showIntensitySlider
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text('0',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontFamily: 'SF-Pro')),
                      Expanded(
                        child: CupertinoSlider(
                          value: _filterIntensity[_currentPage],
                          min: 0,
                          max: 100,
                          activeColor: Colors.white,
                          thumbColor: Colors.white,
                          onChanged: (v) => setState(
                              () => _filterIntensity[_currentPage] = v),
                        ),
                      ),
                      const Text('100',
                          style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                              fontFamily: 'SF-Pro')),
                    ],
                  ),
                )
              : null,
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
    final screenW = MediaQuery.of(context).size.width;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      color: Colors.black,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CupertinoSlider(
                value: tool.value,
                min: tool.min,
                max: tool.max,
                divisions: ((tool.max - tool.min).round()),
                activeColor: const Color(0xFF0095F6),
                thumbColor: Colors.white,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => tool.value = v);
                },
              ),
              if (tool.hasZeroCenter)
                Positioned(
                  left: screenW / 2 - 20,
                  child: Container(
                      width: 1.5, height: 12, color: Colors.white30),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${tool.min.round()}',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'SF-Pro')),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tool.value > 0
                        ? '+${tool.value.round()}'
                        : '${tool.value.round()}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF-Pro'),
                  ),
                ),
                Text('+${tool.max.round()}',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'SF-Pro')),
              ],
            ),
          ),
          if (tool.isChanged)
            CupertinoButton(
              padding: const EdgeInsets.only(top: 4),
              onPressed: () => setState(() => tool.value = 0),
              child: const Text('Reset',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontFamily: 'SF-Pro')),
            ),
        ],
      ),
    );
  }
}
