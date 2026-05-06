// lib/features/create/presentation/pages/media_picker_page.dart

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../core/design/design_tokens.dart';
import 'post_editor_page.dart';
import 'reel_editor_page.dart';
import 'story_editor_page.dart';

// ─── Create type ──────────────────────────────────────
enum CreateType { post, reel, story }

class MediaPickerPage extends StatefulWidget {
  final CreateType createType;

  const MediaPickerPage({super.key, required this.createType});

  @override
  State<MediaPickerPage> createState() => _MediaPickerPageState();
}

class _MediaPickerPageState extends State<MediaPickerPage>
    with SingleTickerProviderStateMixin {
  // ─── Tab controller (Recents / Photos / Videos) ───────
  late TabController _tabController;

  // ─── Media assets ─────────────────────────────────────
  List<AssetEntity> _assets      = [];
  AssetEntity?      _selected;
  Uint8List?        _selectedThumb;
  bool              _isLoading   = true;
  bool              _isMultiple  = false; // multi-select for posts

  // ─── Multiple selection (posts only) ──────────────────
  final List<AssetEntity> _multiSelected = [];

  // ─── Pagination ───────────────────────────────────────
  int  _currentPage = 0;
  bool _hasMore     = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 80;

  // ─── Camera ───────────────────────────────────────────
  final ImagePicker _picker = ImagePicker();

  // ─── Tabs ─────────────────────────────────────────────
  static const List<String> _tabs = ['Recents', 'Photo', 'Video'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadAssets();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final type = [RequestType.common, RequestType.image, RequestType.video]
        [_tabController.index];
    _loadAssets(type: type);
  }

  Future<void> _loadAssets({RequestType type = RequestType.common, bool loadMore = false}) async {
    if (_isLoadingMore) return;
    
    if (loadMore) {
      if (!_hasMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMore = true;
        _assets.clear();
      });
    }

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      setState(() => _isLoading = false);
      if (mounted) _showPermissionDenied();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type:         type,
      onlyAll:      true,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        videoOption: FilterOption(
          durationConstraint: DurationConstraint(
            max: widget.createType == CreateType.reel
                ? const Duration(minutes: 2)
                : const Duration(hours: 1),
          ),
          sizeConstraint: const SizeConstraint(ignoreSize: true),
        ),
      ),
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    final assetCount = await albums.first.assetCountAsync;
    final start = _currentPage * _pageSize;
    final end   = start + _pageSize;

    final newAssets = await albums.first.getAssetListRange(start: start, end: end);
    if (!mounted) return;

    setState(() {
      _assets.addAll(newAssets);
      _isLoading = false;
      _isLoadingMore = false;
      _currentPage++;
      if (newAssets.length < _pageSize || _assets.length >= assetCount) {
        _hasMore = false;
      }
    });

    if (!loadMore && _assets.isNotEmpty) _selectAsset(_assets.first);
  }

  // ─── Select preview ───────────────────────────────────
  Future<void> _selectAsset(AssetEntity asset) async {
    setState(() => _selected = asset);
    final thumb = await asset.thumbnailDataWithSize(
      const ThumbnailSize(800, 800),
    );
    if (mounted) setState(() => _selectedThumb = thumb);
  }

  // ─── Toggle multi-select ──────────────────────────────
  void _toggleMultiSelect(AssetEntity asset) {
    if (!_isMultiple) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_multiSelected.contains(asset)) {
        _multiSelected.remove(asset);
      } else if (_multiSelected.length < 10) {
        _multiSelected.add(asset);
      }
    });
  }

  // ─── Navigate to editor ───────────────────────────────
  Future<void> _navigateToEditor() async {
    if (_selected == null && _multiSelected.isEmpty) return;
    HapticFeedback.lightImpact();

    final assets = _isMultiple && _multiSelected.isNotEmpty
        ? _multiSelected
        : [_selected!];

    final files = <File>[];
    for (final a in assets) {
      final file = await a.file;
      if (file != null) files.add(file);
    }

    if (files.isEmpty || !mounted) return;

    switch (widget.createType) {
      case CreateType.post:
        Navigator.push(context, _buildIosRoute(PostEditorPage(files: files)));
        break;
      case CreateType.reel:
        Navigator.push(context, _buildIosRoute(ReelEditorPage(file: files.first)));
        break;
      case CreateType.story:
        Navigator.push(context, _buildIosRoute(StoryEditorPage(file: files.first)));
        break;
    }
  }

  // ─── Open camera ──────────────────────────────────────
  Future<void> _openCamera() async {
    HapticFeedback.lightImpact();
    final isVideo = widget.createType == CreateType.reel;

    XFile? picked;
    if (isVideo) {
      picked = await _picker.pickVideo(
        source:      ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
    } else {
      picked = await _picker.pickImage(
        source:       ImageSource.camera,
        imageQuality: 90,
      );
    }

    if (picked == null || !mounted) return;
    final file = File(picked.path);

    switch (widget.createType) {
      case CreateType.post:
        Navigator.push(context, _buildIosRoute(PostEditorPage(files: [file])));
        break;
      case CreateType.reel:
        Navigator.push(context, _buildIosRoute(ReelEditorPage(file: file)));
        break;
      case CreateType.story:
        Navigator.push(context, _buildIosRoute(StoryEditorPage(file: file)));
        break;
    }
  }

  void _showPermissionDenied() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title:   const Text('Permission Required'),
        content: const Text('Please allow access to your photos in Settings.'),
        actions: [
          CupertinoDialogAction(
            child:     const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child:           const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              PhotoManager.openSetting();
            },
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (widget.createType) {
      case CreateType.post:  return 'New Post';
      case CreateType.reel:  return 'New Reel';
      case CreateType.story: return 'New Story';
    }
  }

  // ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = IgColors.bg_(isDark);
    final text   = IgColors.text_(isDark);
    final sub    = IgColors.textSub_(isDark);
    final div    = IgColors.divider_(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark, text, sub),
            _buildPreview(isDark),
            _buildToolbar(isDark, text, sub, div),
            _buildTabBar(isDark, text, div),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGrid(isDark, RequestType.common),
                  _buildGrid(isDark, RequestType.image),
                  _buildGrid(isDark, RequestType.video),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TOP BAR ──────────────────────────────────────────
  Widget _buildTopBar(bool isDark, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical:   Spacing.sm,
      ),
      child: Row(
        children: [
          _IgIconBtn(
            icon:   PhosphorIcons.x(),
            onTap:  () => Navigator.pop(context),
            isDark: isDark,
          ),
          const Spacer(),
          Text(_title, style: IgText.h3.copyWith(color: text)),
          const Spacer(),
          GestureDetector(
            onTap: _navigateToEditor,
            child: Text(
              'Next',
              style: IgText.labelLg.copyWith(
                color: _selected != null || _multiSelected.isNotEmpty
                    ? IgColors.primary
                    : sub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── PREVIEW ──────────────────────────────────────────
  Widget _buildPreview(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final height = width * 1.25; // 4:5 aspect ratio

    if (_selectedThumb == null) {
      return Container(
        width:  width,
        height: height,
        color:  isDark ? IgColors.darkBgAlt : IgColors.bgAlt,
        child: Center(
          child: PhosphorIcon(
            PhosphorIcons.image(),
            size:  48,
            color: IgColors.textSub_(isDark),
          ),
        ),
      );
    }

    return SizedBox(
      width:  width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_selectedThumb!, fit: BoxFit.cover),
          if (_selected?.type == AssetType.video)
            Positioned(
              bottom: Spacing.sm,
              left:   Spacing.sm,
              child:  _VideoDuration(asset: _selected!),
            ),
        ],
      ),
    );
  }

  // ─── TOOLBAR ──────────────────────────────────────────
  Widget _buildToolbar(bool isDark, Color text, Color sub, Color div) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical:   Spacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: div, width: 0.5)),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Recents', style: IgText.label.copyWith(color: text)),
              const SizedBox(width: Spacing.xs),
              PhosphorIcon(PhosphorIcons.caretDown(), size: 14, color: text),
            ],
          ),
          const Spacer(),
          if (widget.createType == CreateType.post) ...[
            _ToolbarChip(
              icon:   PhosphorIcons.squaresFour(),
              label:  'Select',
              active: _isMultiple,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isMultiple = !_isMultiple;
                  _multiSelected.clear();
                });
              },
            ),
            const SizedBox(width: Spacing.sm),
          ],
          _ToolbarChip(
            icon:   PhosphorIcons.camera(),
            label:  'Camera',
            isDark: isDark,
            onTap:  _openCamera,
          ),
        ],
      ),
    );
  }

  // ─── TAB BAR ──────────────────────────────────────────
  Widget _buildTabBar(bool isDark, Color text, Color div) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: div, width: 0.5)),
      ),
      child: TabBar(
        controller:          _tabController,
        indicatorColor:      text,
        indicatorWeight:     1.5,
        labelColor:          text,
        unselectedLabelColor: IgColors.textSub_(isDark),
        labelStyle:          IgText.label,
        unselectedLabelStyle: IgText.label,
        tabs:                _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  // ─── ASSET GRID ──────────────────────────────────────
  Widget _buildGrid(bool isDark, RequestType type) {
    if (_isLoading && _assets.isEmpty) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 1.5, crossAxisSpacing: 1.5,
        ),
        itemCount: 24,
        itemBuilder: (_, idx) => Container(color: IgColors.shimBase_(isDark)),
      );
    }

    final filtered = type == RequestType.common
        ? _assets
        : _assets.where((a) {
            return type == RequestType.image
                ? a.type == AssetType.image
                : a.type == AssetType.video;
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              PhosphorIcons.imageSquare(),
              size:  48,
              color: IgColors.textSub_(isDark),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'No media found',
              style: IgText.bodySm.copyWith(color: IgColors.textSub_(isDark)),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingMore && _hasMore &&
            scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          _loadAssets(
            type: type == RequestType.common
                ? RequestType.common
                : (type == RequestType.image ? RequestType.image : RequestType.video),
            loadMore: true,
          );
        }
        return false;
      },
      child: GridView.builder(
        padding:      EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 1.5, crossAxisSpacing: 1.5,
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final asset     = filtered[index];
          final isSelected = _selected == asset;
          final multiIdx  = _multiSelected.indexOf(asset);
          final inMulti   = multiIdx >= 0;

          return GestureDetector(
            onTap: () {
              if (_isMultiple) {
                _toggleMultiSelect(asset);
              } else {
                _selectAsset(asset);
              }
            },
            child: _AssetThumbnail(
              asset:      asset,
              isSelected: isSelected && !_isMultiple,
              multiIndex: inMulti ? multiIdx + 1 : null,
              isDark:     isDark,
              isMultiple: _isMultiple,
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// ASSET THUMBNAIL TILE
// ─────────────────────────────────────────────────────
class _AssetThumbnail extends StatefulWidget {
  final AssetEntity asset;
  final bool        isSelected;
  final int?        multiIndex;
  final bool        isDark;
  final bool        isMultiple;

  const _AssetThumbnail({
    required this.asset,
    required this.isSelected,
    required this.isDark,
    required this.isMultiple,
    this.multiIndex,
  });

  @override
  State<_AssetThumbnail> createState() => _AssetThumbnailState();
}

class _AssetThumbnailState extends State<_AssetThumbnail> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(300, 300),
    );
    if (mounted) setState(() => _thumb = data);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ─── Image ─────────────────────────────────────
        _thumb != null
            ? Image.memory(_thumb!, fit: BoxFit.cover)
            : Container(color: IgColors.shimBase_(widget.isDark)),

        // ─── Selected dim overlay ───────────────────────
        if (widget.isSelected)
          Container(color: Colors.black.withValues(alpha: 0.3)),

        // ─── Video duration badge ───────────────────────
        if (widget.asset.type == AssetType.video)
          Positioned(
            bottom: 4, left: 4,
            child: _VideoDuration(asset: widget.asset),
          ),

        // ─── Multi-select badge / empty circle ─────────
        if (widget.isMultiple)
          Positioned(
            top: 6, right: 6,
            child: widget.multiIndex != null
                ? Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                      color: IgColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.multiIndex}',
                        style: IgText.micro.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                      color: Colors.transparent,
                    ),
                  ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────
// VIDEO DURATION BADGE
// ─────────────────────────────────────────────────────
class _VideoDuration extends StatelessWidget {
  final AssetEntity asset;
  const _VideoDuration({required this.asset});

  @override
  Widget build(BuildContext context) {
    final dur = asset.videoDuration;
    final mm  = dur.inMinutes.toString();
    final ss  = (dur.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color:        Colors.black.withValues(alpha: 0.6),
        borderRadius: Radii.xsAll,
      ),
      child: Text(
        '$mm:$ss',
        style: IgText.micro.copyWith(color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// TOOLBAR CHIP
// ─────────────────────────────────────────────────────
class _ToolbarChip extends StatelessWidget {
  final PhosphorIconData icon;
  final String           label;
  final bool             isDark;
  final VoidCallback     onTap;
  final bool             active;

  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical:   Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? IgColors.text_(isDark)
              : IgColors.inputBg_(isDark),
          borderRadius: Radii.fullAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              icon,
              size:  14,
              color: active ? IgColors.bg_(isDark) : IgColors.text_(isDark),
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              label,
              style: IgText.labelSm.copyWith(
                color: active ? IgColors.bg_(isDark) : IgColors.text_(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// ICON BUTTON
// ─────────────────────────────────────────────────────
class _IgIconBtn extends StatelessWidget {
  final PhosphorIconData icon;
  final VoidCallback     onTap;
  final bool             isDark;

  const _IgIconBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xs),
        child: PhosphorIcon(
          icon,
          size:  24,
          color: IgColors.icon_(isDark),
        ),
      ),
    );
  }
}

// ─── iOS-style page route ─────────────────────────────
PageRoute _buildIosRoute(Widget page) =>
    CupertinoPageRoute(builder: (_) => page);
