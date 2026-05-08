import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/design/design_tokens.dart';
import 'post_editor_page.dart';
import 'reel_editor_page.dart';
import 'story_editor_page.dart';

enum CreateType { post, reel, story }

class MediaPickerPage extends StatefulWidget {
  final CreateType createType;
  const MediaPickerPage({super.key, required this.createType});

  @override
  State<MediaPickerPage> createState() => _MediaPickerPageState();
}

class _MediaPickerPageState extends State<MediaPickerPage>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────
  late CreateType _createType;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isMultiple = false;

  // ── Assets ─────────────────────────────────────────────
  List<AssetEntity> _assets = [];
  AssetEntity? _selected;
  Uint8List? _selectedThumb;
  final List<AssetEntity> _multiSelected = [];

  // ── Albums ─────────────────────────────────────────────
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;

  // ── Pagination ─────────────────────────────────────────
  int _page = 0;
  bool _hasMore = true;
  static const int _pageSize = 80;

  // ── Transform ──────────────────────────────────────────
  late TransformationController _tx;
  final ImagePicker _picker = ImagePicker();

  // ── Filter tabs ────────────────────────────────────────
  int _filterTab = 0; // 0=All 1=Photo 2=Video

  @override
  void initState() {
    super.initState();
    _createType = widget.createType;
    _tx = TransformationController();
    _loadAssets();
  }

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  RequestType get _requestType =>
      [RequestType.common, RequestType.image, RequestType.video][_filterTab];

  Future<void> _loadAssets({bool loadMore = false}) async {
    if (_isLoadingMore) return;
    if (loadMore && !_hasMore) return;

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _assets.clear();
        _page = 0;
        _hasMore = true;
      });
    }

    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.isAuth) {
      setState(() { _isLoading = false; _isLoadingMore = false; });
      if (mounted) _showPermDenied();
      return;
    }

    _albums = await PhotoManager.getAssetPathList(
      type: _requestType,
      filterOption: FilterOptionGroup(
        videoOption: FilterOption(
          durationConstraint: DurationConstraint(
            max: _createType == CreateType.reel
                ? const Duration(minutes: 2)
                : const Duration(hours: 1),
          ),
          sizeConstraint: const SizeConstraint(ignoreSize: true),
        ),
      ),
    );

    if (_albums.isEmpty) {
      setState(() { _isLoading = false; _isLoadingMore = false; });
      return;
    }

    _selectedAlbum ??= _albums.first;
    final count = await _selectedAlbum!.assetCountAsync;
    final start = _page * _pageSize;
    final batch = await _selectedAlbum!.getAssetListRange(
        start: start, end: start + _pageSize);

    if (!mounted) return;
    setState(() {
      if (loadMore) {
        _assets.addAll(batch);
      } else {
        _assets = batch;
      }
      _page++;
      _hasMore = batch.length == _pageSize && _assets.length < count;
      _isLoading = false;
      _isLoadingMore = false;
    });

    if (!loadMore && _assets.isNotEmpty) _selectAsset(_assets.first);
  }

  Future<void> _selectAsset(AssetEntity asset) async {
    _tx.value = Matrix4.identity();
    setState(() { _selected = asset; _selectedThumb = null; });
    final thumb = await asset.thumbnailDataWithSize(const ThumbnailSize(900, 900));
    if (mounted) setState(() => _selectedThumb = thumb);
  }

  void _toggleMulti(AssetEntity asset) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_multiSelected.contains(asset)) {
        _multiSelected.remove(asset);
      } else if (_multiSelected.length < 10) {
        _multiSelected.add(asset);
      }
    });
  }

  Future<void> _goNext() async {
    final assets = _isMultiple && _multiSelected.isNotEmpty
        ? _multiSelected
        : (_selected != null ? [_selected!] : []);
    if (assets.isEmpty) return;
    HapticFeedback.lightImpact();
    final files = <File>[];
    for (final a in assets) {
      final f = await a.file;
      if (f != null) files.add(f);
    }
    if (files.isEmpty || !mounted) return;
    switch (_createType) {
      case CreateType.post:
        Navigator.push(context, _iosRoute(PostEditorPage(files: files)));
      case CreateType.reel:
        Navigator.push(context, _iosRoute(ReelEditorPage(file: files.first)));
      case CreateType.story:
        Navigator.push(context, _iosRoute(StoryEditorPage(file: files.first)));
    }
  }

  Future<void> _openCamera() async {
    HapticFeedback.lightImpact();
    XFile? picked;
    if (_createType == CreateType.reel) {
      picked = await _picker.pickVideo(
          source: ImageSource.camera, maxDuration: const Duration(minutes: 2));
    } else {
      picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    }
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    switch (_createType) {
      case CreateType.post:
        Navigator.push(context, _iosRoute(PostEditorPage(files: [file])));
      case CreateType.reel:
        Navigator.push(context, _iosRoute(ReelEditorPage(file: file)));
      case CreateType.story:
        Navigator.push(context, _iosRoute(StoryEditorPage(file: file)));
    }
  }

  void _showAlbumSheet() {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _AlbumSheet(
        albums: _albums,
        selected: _selectedAlbum,
        onSelect: (album) {
          setState(() {
            _selectedAlbum = album;
            _assets.clear();
            _page = 0;
            _hasMore = true;
          });
          _loadAssets();
        },
      ),
    );
  }

  void _showPermDenied() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Photos Access Required'),
        content: const Text('Allow access to your photos in Settings.'),
        actions: [
          CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () { Navigator.pop(context); PhotoManager.openSetting(); },
              child: const Text('Settings')),
        ],
      ),
    );
  }

  // ── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;
    final previewH = screenW; // 1:1 square preview

    final hasSelection = _selected != null || _multiSelected.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ── Navigation Bar ────────────────────────────
            _NavBar(
              safeTop: safeTop,
              albumName: _selectedAlbum?.name ?? 'Recents',
              onClose: () => Navigator.pop(context),
              onAlbum: _showAlbumSheet,
              isMultiSelect: _isMultiple,
              hasSelection: hasSelection,
              selectedCount: _isMultiple ? _multiSelected.length : (_selected != null ? 1 : 0),
              onNext: _goNext,
            ),

            // ── Preview ───────────────────────────────────
            SizedBox(
              width: screenW,
              height: previewH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Preview image
                  _selectedThumb != null
                      ? InteractiveViewer(
                          transformationController: _tx,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.memory(_selectedThumb!, fit: BoxFit.cover),
                        )
                      : Container(color: const Color(0xFF1C1C1C)),

                  // Bottom-left: expand icon
                  Positioned(
                    bottom: 12, left: 12,
                    child: _PreviewIconBtn(
                      icon: LucideIcons.maximize_2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _tx.value = Matrix4.identity();
                      },
                    ),
                  ),

                  // Bottom-right: multi-select + camera
                  Positioned(
                    bottom: 12, right: 12,
                    child: Row(
                      children: [
                        if (_createType == CreateType.post) ...[
                          _PreviewIconBtn(
                            icon: LucideIcons.layout_grid,
                            active: _isMultiple,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isMultiple = !_isMultiple;
                                _multiSelected.clear();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        _PreviewIconBtn(
                          icon: LucideIcons.camera,
                          onTap: _openCamera,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Album row ─────────────────────────────────
            _AlbumRow(
              albumName: _selectedAlbum?.name ?? 'All Photos',
              onAlbum: _showAlbumSheet,
              createType: _createType,
              isMultiple: _isMultiple,
              onToggleMultiple: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isMultiple = !_isMultiple;
                  _multiSelected.clear();
                });
              },
            ),

            // ── Filter tab ────────────────────────────────
            _FilterTabBar(
              selected: _filterTab,
              onSelect: (i) {
                if (_filterTab == i) return;
                setState(() => _filterTab = i);
                _loadAssets();
              },
            ),

            // ── Grid ──────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? _ShimmerGrid()
                  : _assets.isEmpty
                      ? const Center(
                          child: Text('No media',
                              style: TextStyle(color: Colors.white54,
                                  fontFamily: 'SF-Pro')))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (s) {
                            if (!_isLoadingMore && _hasMore &&
                                s.metrics.pixels >=
                                    s.metrics.maxScrollExtent - 300) {
                              _loadAssets(loadMore: true);
                            }
                            return false;
                          },
                          child: GridView.builder(
                            padding: EdgeInsets.only(bottom: safeBot + 8),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 1.5,
                              crossAxisSpacing: 1.5,
                              childAspectRatio: 1,
                            ),
                            itemCount: _assets.length,
                            itemBuilder: (ctx, i) {
                              final asset = _assets[i];
                              final isPreview = _selected == asset && !_isMultiple;
                              final multiIdx = _multiSelected.indexOf(asset);
                              return GestureDetector(
                                onTap: () => _isMultiple
                                    ? _toggleMulti(asset)
                                    : _selectAsset(asset),
                                child: _GridTile(
                                  asset: asset,
                                  isPreview: isPreview,
                                  isMultiple: _isMultiple,
                                  multiIndex: multiIdx >= 0 ? multiIdx + 1 : null,
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Navigation Bar ────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final double safeTop;
  final String albumName;
  final VoidCallback onClose, onAlbum, onNext;
  final bool isMultiSelect, hasSelection;
  final int selectedCount;

  const _NavBar({
    required this.safeTop,
    required this.albumName,
    required this.onClose,
    required this.onAlbum,
    required this.onNext,
    required this.isMultiSelect,
    required this.hasSelection,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(top: safeTop, left: 4, right: 4),
      height: safeTop + 50,
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: onClose,
            child: const Icon(LucideIcons.x, color: Colors.white, size: 26),
          ),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onAlbum,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(albumName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF-Pro')),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevron_down,
                    color: Colors.white, size: 16),
              ],
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: hasSelection ? onNext : null,
            child: Text(
              selectedCount > 1 ? 'Next ($selectedCount)' : 'Next',
              style: TextStyle(
                color: hasSelection
                    ? const Color(0xFF0095F6)
                    : Colors.white38,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF-Pro',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Album Row ─────────────────────────────────────────────
class _AlbumRow extends StatelessWidget {
  final String albumName;
  final VoidCallback onAlbum, onToggleMultiple;
  final CreateType createType;
  final bool isMultiple;

  const _AlbumRow({
    required this.albumName,
    required this.onAlbum,
    required this.onToggleMultiple,
    required this.createType,
    required this.isMultiple,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAlbum,
            child: Row(
              children: [
                Text(albumName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF-Pro')),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevron_down,
                    color: Colors.white54, size: 14),
              ],
            ),
          ),
          const Spacer(),
          if (createType == CreateType.story)
            GestureDetector(
              onTap: onToggleMultiple,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isMultiple
                      ? Colors.white
                      : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'MULTIPLE',
                  style: TextStyle(
                    color: isMultiple ? Colors.black : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF-Pro',
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Filter Tab Bar ────────────────────────────────────────
class _FilterTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _FilterTabBar({required this.selected, required this.onSelect});

  static const _labels = ['Recents', 'Photo', 'Video'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      color: Colors.black,
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(left: i == 0 ? 16 : 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: active ? Colors.black : Colors.white70,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  fontFamily: 'SF-Pro',
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Preview Icon Button ───────────────────────────────────
class _PreviewIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _PreviewIconBtn(
      {required this.icon, required this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.9)
              : Colors.black.withOpacity(0.58),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: active ? Colors.black : Colors.white, size: 17),
      ),
    );
  }
}

// ── Grid Tile ─────────────────────────────────────────────
class _GridTile extends StatefulWidget {
  final AssetEntity asset;
  final bool isPreview, isMultiple;
  final int? multiIndex;

  const _GridTile({
    required this.asset,
    required this.isPreview,
    required this.isMultiple,
    this.multiIndex,
  });

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.asset.thumbnailDataWithSize(
        const ThumbnailSize(300, 300));
    if (mounted) setState(() => _thumb = d);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.type == AssetType.video;
    final dur = widget.asset.videoDuration;
    final mm = dur.inMinutes.toString();
    final ss = (dur.inSeconds % 60).toString().padLeft(2, '0');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail
        _thumb != null
            ? Image.memory(_thumb!, fit: BoxFit.cover)
            : Container(color: const Color(0xFF2A2A2A)),

        // Blue border when currently previewed
        if (widget.isPreview)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0095F6), width: 3),
            ),
          ),

        // Dim selected
        if (widget.multiIndex != null)
          Container(color: Colors.black.withOpacity(0.25)),

        // Video duration
        if (isVideo)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
        if (isVideo)
          Positioned(
            bottom: 4,
            left: 5,
            child: Row(
              children: [
                const Icon(LucideIcons.play,
                    color: Colors.white, size: 10),
                const SizedBox(width: 2),
                Text('$mm:$ss',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF-Pro')),
              ],
            ),
          ),

        // Multi-select badge
        if (widget.isMultiple)
          Positioned(
            top: 6,
            right: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.multiIndex != null
                    ? const Color(0xFF0095F6)
                    : Colors.transparent,
                border: Border.all(
                  color: widget.multiIndex != null
                      ? const Color(0xFF0095F6)
                      : Colors.white,
                  width: 1.5,
                ),
              ),
              child: widget.multiIndex != null
                  ? Center(
                      child: Text(
                        '${widget.multiIndex}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'SF-Pro'),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

// ── Album Sheet ───────────────────────────────────────────
class _AlbumSheet extends StatelessWidget {
  final List<AssetPathEntity> albums;
  final AssetPathEntity? selected;
  final ValueChanged<AssetPathEntity> onSelect;

  const _AlbumSheet(
      {required this.albums, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Albums',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF-Pro')),
          ),
          const Divider(color: Color(0xFF3A3A3C), height: 0.5),
          Expanded(
            child: ListView.builder(
              itemCount: albums.length,
              itemBuilder: (ctx, i) {
                final album = albums[i];
                final isSel = selected?.id == album.id;
                return CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onSelect(album);
                  },
                  child: Row(
                    children: [
                      const Icon(LucideIcons.image,
                          color: Color(0xFF3A3A3C), size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(album.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'SF-Pro')),
                      ),
                      FutureBuilder<int>(
                        future: album.assetCountAsync,
                        builder: (_, snap) => Text(
                          snap.data?.toString() ?? '',
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                              fontFamily: 'SF-Pro'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (isSel)
                        const Icon(LucideIcons.check,
                            color: Color(0xFF0095F6), size: 20),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: safeBot),
        ],
      ),
    );
  }
}

// ── Shimmer Grid ──────────────────────────────────────────
class _ShimmerGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
      ),
      itemCount: 24,
      itemBuilder: (_, __) => Container(color: const Color(0xFF2A2A2A)),
    );
  }
}

// ── iOS Page Route ────────────────────────────────────────
PageRoute _iosRoute(Widget page) =>
    CupertinoPageRoute(builder: (_) => page);
