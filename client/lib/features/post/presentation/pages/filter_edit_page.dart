// lib/features/post/presentation/pages/filter_edit_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:colorfilter_generator/addons.dart';
import '../../../../core/theme/app_theme.dart';
import 'finalize_post_page.dart';

class FilterEditPage extends ConsumerStatefulWidget {
  final List<File> images;

  const FilterEditPage({super.key, required this.images});

  @override
  ConsumerState<FilterEditPage> createState() => _FilterEditPageState();
}

class _FilterEditPageState extends ConsumerState<FilterEditPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  int _currentIndex = 0;
  
  // Per-image edit values
  late List<ColorFilterGenerator> _selectedFilters;
  late List<double> _brightnesses;
  late List<double> _contrasts;
  late List<double> _saturations;
  late List<double> _warmths; // Mapped to sepia or rgb scale
  
  String? _selectedTool;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();
    
    final count = widget.images.length;
    _selectedFilters = List.filled(count, presetFiltersList[0]);
    _brightnesses = List.filled(count, 0.0);
    _contrasts = List.filled(count, 0.0);
    _saturations = List.filled(count, 0.0);
    _warmths = List.filled(count, 0.0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  ColorFilterGenerator _getCombinedFilter(int index) {
    final List<List<double>> customFilters = [];
    
    if (_brightnesses[index] != 0.0) customFilters.add(ColorFilterAddons.brightness(_brightnesses[index]));
    if (_contrasts[index] != 0.0) customFilters.add(ColorFilterAddons.contrast(_contrasts[index]));
    if (_saturations[index] != 0.0) customFilters.add(ColorFilterAddons.saturation(_saturations[index]));
    if (_warmths[index] != 0.0) customFilters.add(ColorFilterAddons.sepia(_warmths[index])); // using sepia for warmth effect
    
    if (customFilters.isEmpty && _selectedFilters[index].name == 'No Filter') {
      return presetFiltersList[0];
    }
    
    final combined = ColorFilterGenerator(
      name: 'Combined',
      filters: [
        if (_selectedFilters[index].name != 'No Filter') _selectedFilters[index].matrix,
        ...customFilters,
      ],
    );
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chevron_back, color: AppColors.primary, size: 28),
          onPressed: () => context.pop(),
        ),
        middle: const Text(
          'New Post',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'SF Pro Text'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            final List<List<double>> matrices = [];
            for (int i = 0; i < widget.images.length; i++) {
              matrices.add(_getCombinedFilter(i).matrix);
            }
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => FinalizePostPage(
                  images: widget.images,
                  filterMatrices: matrices,
                ),
              ),
            );
          },
          child: const Text(
            'Next',
            style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600, fontSize: 17),
          ),
        ),
      ),
      body: Column(
        children: [
          // Preview
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 4 / 5, // Instagram 4:5 ratio preferred
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: widget.images.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final currentFilter = _getCombinedFilter(index);
                        return ColorFiltered(
                          colorFilter: ColorFilter.matrix(currentFilter.matrix),
                          child: Image.file(widget.images[index], fit: BoxFit.cover),
                        );
                      },
                    ),
                    if (widget.images.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Slider for Edit Tool
          if (_tabController.index == 1 && _selectedTool != null)
            _buildSlider(isDark),

          // Tabs (Filter / Edit)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? Colors.grey[900]! : Colors.grey[200]!, width: 0.5)),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 140,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildFilterTab(isDark),
                      _buildEditTab(isDark),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: isDark ? Colors.white : Colors.black,
                  labelColor: isDark ? Colors.white : Colors.black,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  onTap: (index) {
                    setState(() {
                      if (index == 0) _selectedTool = null;
                    });
                  },
                  tabs: const [
                    Tab(text: 'FILTER'),
                    Tab(text: 'EDIT'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
  
  Widget _buildSlider(bool isDark) {
    double value = 0;
    double min = -1.0;
    double max = 1.0;
    
    switch (_selectedTool) {
      case 'Brightness':
        value = _brightnesses[_currentIndex];
        break;
      case 'Contrast':
        value = _contrasts[_currentIndex];
        break;
      case 'Saturation':
        value = _saturations[_currentIndex];
        break;
      case 'Warmth':
        value = _warmths[_currentIndex];
        min = 0.0; // sepia looks bad < 0
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            _selectedTool!,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: CupertinoSlider(
              value: value,
              min: min,
              max: max,
              activeColor: isDark ? Colors.white : Colors.black,
              onChanged: (val) {
                setState(() {
                  switch (_selectedTool) {
                    case 'Brightness': _brightnesses[_currentIndex] = val; break;
                    case 'Contrast': _contrasts[_currentIndex] = val; break;
                    case 'Saturation': _saturations[_currentIndex] = val; break;
                    case 'Warmth': _warmths[_currentIndex] = val; break;
                  }
                });
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              (value * 100).toInt().toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(bool isDark) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: presetFiltersList.length,
      itemBuilder: (context, index) {
        final filter = presetFiltersList[index];
        final isSelected = _selectedFilters[_currentIndex].name == filter.name;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedFilters[_currentIndex] = filter),
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 80,
            child: Column(
              children: [
                Text(
                  filter.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                  ),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(filter.matrix),
                    child: Image.file(widget.images[_currentIndex], fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditTab(bool isDark) {
    final List<Map<String, dynamic>> tools = [
      {'name': 'Brightness', 'icon': CupertinoIcons.brightness},
      {'name': 'Contrast', 'icon': CupertinoIcons.circle_lefthalf_fill},
      {'name': 'Saturation', 'icon': CupertinoIcons.drop},
      {'name': 'Warmth', 'icon': CupertinoIcons.thermometer},
    ];

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final toolName = tools[index]['name'];
        final isSelected = _selectedTool == toolName;
        
        // Check if tool has an active value
        bool isActive = false;
        switch (toolName) {
          case 'Brightness': isActive = _brightnesses[_currentIndex] != 0.0; break;
          case 'Contrast': isActive = _contrasts[_currentIndex] != 0.0; break;
          case 'Saturation': isActive = _saturations[_currentIndex] != 0.0; break;
          case 'Warmth': isActive = _warmths[_currentIndex] != 0.0; break;
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTool = toolName;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(right: 24),
            child: Column(
              children: [
                Text(
                  toolName,
                  style: TextStyle(
                    fontSize: 12, 
                    color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),
                Icon(
                  tools[index]['icon'], 
                  size: 30, 
                  color: isSelected || isActive ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                ),
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
