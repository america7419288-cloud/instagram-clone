import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:photo_manager/photo_manager.dart';
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

  // ── Grid lines visibility ──────────────────────────────
  bool _showGrid = false;
  late AnimationController _gridOpacityCtrl;
  late Animation<double> _gridOpacity;

  @override
  void initState() {
    super.initState();
    _createType = widget.createType;
    _tx = TransformationController();

    _gridOpacityCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _gridOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _gridOpacityCtrl, curve: Curves.easeOut));

    _loadAssets();
  }

  @override
  void dispose() {
    _tx.dispose();
    _gridOpacityCtrl.dispose();
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
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
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
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }

    _selectedAlbum ??= _albums.first;
    final count = await _selectedAlbum!.assetCountAsync;
    final start = _page * _pageSize;
    final batch = await _selectedAlbum!
        .getAssetListRange(start: start, end: start + _pageSize);

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
    setState(() {
      _selected = asset;
      _selectedThumb = null;
    });
    final thumb = await asset.thumbnailDataWithSize(
        const ThumbnailSize(900, 900));
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
        Navigator.push(
            context, _iosRoute(ReelEditorPage(file: files.first)));
      case CreateType.story:
        Navigator.push(
            context, _iosRoute(StoryEditorPage(file: files.first)));
    }
  }

  Future<void> _openCamera() async {
    HapticFeedback.lightImpact();
    XFile? picked;
    if (_createType == CreateType.reel) {
      picked = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 2));
    } else {
      picked = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 90);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              onPressed: () {
                Navigator.pop(context);
                PhotoManager.openSetting();
              },
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

    final hasSelection =
        _selected != null || _multiSelected.isNotEmpty;

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
              selectedCount: _isMultiple
                  ? _multiSelected.length
                  : (_selected != null ? 1 : 0),
              onNext: _goNext,
            ),

            // ── Preview ───────────────────────────────────
            SizedBox(
              width: screenW,
              height: previewH,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Preview image with interactive viewer
                  _selectedThumb != null
                      ? InteractiveViewer(
                          transformationController: _tx,
                          minScale: 1.0,
                          maxScale: 4.0,
                          onInteractionStart: (_) {
                            _showGrid = true;
                            _gridOpacityCtrl.forward();
                          },
                          onInteractionEnd: (_) {
                            Future.delayed(
                                const Duration(milliseconds: 300), () {
                              if (mounted) {
                                _gridOpacityCtrl.reverse().then((_) {
                                  if (mounted) {
                                    setState(() => _showGrid = false);
                                  }
                                });
                              }
                            });
                          },
                          child:
                              Image.memory(_selectedThumb!, fit: BoxFit.cover),
                        )
                      : Container(color: const Color(0xFF1C1C1C)),

                  // Rule-of-thirds grid (fades in on scale/pan)
                  if (_showGrid)
                    AnimatedBuilder(
                      animation: _gridOpacity,
                      builder: (_, __) => Opacity(
                        opacity: _gridOpacity.value,
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _RuleOfThirdsPainter(),
                            size: Size(screenW, previewH),
                          ),
                        ),
                      ),
                    ),

                  // Expand/reset icon (bottom-left)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: _PreviewIconBtn(
                      icon: LucideIcons.maximize_2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _tx.value = Matrix4.identity();
                      },
                    ),
                  ),

                  // Multi-select + camera (bottom-right)
                  Positioned(
                    bottom: 12,
                    right: 12,
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
                              style: TextStyle(color: Colors.white54)))
                      : NotificationListener<ScrollNotification>(
                          onNotification: (s) {
                            if (!_isLoadingMore &&
                                _hasMore &&
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
                              final isPreview =
                                  _selected == asset && !_isMultiple;
                              final multiIdx =
                                  _multiSelected.indexOf(asset);
                              return GestureDetector(
                                onTap: () => _isMultiple
                                    ? _toggleMulti(asset)
                                    : _selectAsset(asset),
                                child: _GridTile(
                                  asset: asset,
                                  isPreview: isPreview,
                                  isMultiple: _isMultiple,
                                  multiIndex: multiIdx >= 0
                                      ? multiIdx + 1
                                      : null,
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

// ── Rule of Thirds Painter ────────────────────────────────
class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 0.8
      ..isAntiAlias = true;

    // Vertical lines
    canvas.drawLine(Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height), paint);

    // Horizontal lines
    canvas.drawLine(Offset(0, size.height / 3),
        Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(_RuleOfThirdsPainter oldDelegate) => false;
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
      height: safeTop + 52,
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
                Text(
                  albumName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: hasSelection
                    ? const Color(0xFF0095F6)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                selectedCount > 1 ? 'Next ($selectedCount)' : 'Next',
                style: TextStyle(
                  color: hasSelection ? Colors.white : Colors.white30,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
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
      height: 46,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAlbum,
            child: Row(
              children: [
                Text(
                  albumName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isMultiple
                      ? Colors.white
                      : Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isMultiple ? Colors.white : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Text(
                  'SELECT',
                  style: TextStyle(
                    color: isMultiple ? Colors.black : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
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
      height: 42,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () {
              onSelect(i);
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < _labels.length - 1 ? 8 : 0),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? Colors.white : Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Text(
                _labels[i],
                style: TextStyle(
                  color: active ? Colors.black : Colors.white60,
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w400,
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
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.45),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Icon(icon,
                color: active ? Colors.black : Colors.white,
                size: 17),
          ),
        ),
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
    final d = await widget.asset
        .thumbnailDataWithSize(const ThumbnailSize(300, 300));
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

        // Video duration + gradient
        if (isVideo) ...[
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            left: 5,
            child: Row(
              children: [
                const Icon(LucideIcons.play, color: Colors.white, size: 10),
                const SizedBox(width: 2),
                Text(
                  '$mm:$ss',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],

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
                boxShadow: widget.multiIndex != null
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF0095F6).withOpacity(0.4),
                          blurRadius: 4,
                        )
                      ]
                    : null,
              ),
              child: widget.multiIndex != null
                  ? Center(
                      child: Text(
                        '${widget.multiIndex}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

// ── Premium Album Sheet ───────────────────────────────────
class _AlbumSheet extends StatelessWidget {
  final List<AssetPathEntity> albums;
  final AssetPathEntity? selected;
  final ValueChanged<AssetPathEntity> onSelect;

  const _AlbumSheet(
      {required this.albums,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final safeBot = MediaQuery.of(context).padding.bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.92),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
                color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Albums',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Divider(
                  color: Colors.white.withOpacity(0.1),
                  height: 1),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.only(
                      bottom: safeBot + 12, top: 8),
                  itemCount: albums.length,
                  itemBuilder: (ctx, i) {
                    final album = albums[i];
                    final isSel = selected?.id == album.id;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        onSelect(album);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withOpacity(0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.image,
                                  color: Colors.white54, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                album.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            FutureBuilder<int>(
                              future: album.assetCountAsync,
                              builder: (_, snap) => Text(
                                snap.data?.toString() ?? '',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (isSel)
                              const Icon(LucideIcons.check,
                                  color: Color(0xFF0095F6), size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Grid ──────────────────────────────────────────
class _ShimmerGrid extends StatefulWidget {
  @override
  State<_ShimmerGrid> createState() => _ShimmerGridState();
}

class _ShimmerGridState extends State<_ShimmerGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _shimmer = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
      ),
      itemCount: 24,
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _shimmer,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFF2A2A2A),
                Color(0xFF3A3A3A),
                Color(0xFF2A2A2A),
              ],
              stops: [
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── iOS Page Route ────────────────────────────────────────
PageRoute _iosRoute(Widget page) =>
    CupertinoPageRoute(builder: (_) => page);
