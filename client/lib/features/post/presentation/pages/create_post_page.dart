// lib/features/post/presentation/pages/create_post_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../providers/media_picker_provider.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  bool _isPreviewExpanded = false;
  double _aspectRatio = 1.0;
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(mediaPickerProvider.notifier).initialize());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickerState = ref.watch(mediaPickerProvider);
    final pickerNotifier = ref.read(mediaPickerProvider.notifier);

    if (pickerState.error != null) {
      return _buildErrorState(pickerState.error!, isDark);
    }

    String title = "New post";
    String actionText = "Next";
    if (pickerState.mode == CreateMode.story) {
      title = "New story";
      actionText = "Add to story";
    } else if (pickerState.mode == CreateMode.reel) {
      title = "New reel";
      actionText = "Next";
    } else if (pickerState.mode == CreateMode.live) {
      title = "Live";
      actionText = "Go Live";
    }

    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _handleNext(pickerState),
            child: Text(
              actionText,
              style: const TextStyle(
                color: Color(0xFF0095F6),
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── MEDIA PREVIEW AREA ──────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _isPreviewExpanded 
                  ? MediaQuery.of(context).size.height * 0.7 
                  : MediaQuery.of(context).size.height * 0.45,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildSelectedPreview(pickerState.selectedAsset, isDark),
                  
                  // Top Overlay Buttons
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _OverlayButton(
                          icon: PhosphorIcons.camera(),
                          onTap: () {}, // Open camera
                        ),
                        Row(
                          children: [
                            _OverlayButton(
                              icon: PhosphorIcons.crop(),
                              onTap: () {},
                            ),
                            const SizedBox(width: 8),
                            _OverlayButton(
                              icon: _isPreviewExpanded 
                                  ? PhosphorIcons.arrowsIn() 
                                  : PhosphorIcons.arrowsOut(),
                              onTap: () => setState(() => _isPreviewExpanded = !_isPreviewExpanded),
                            ),
                            const SizedBox(width: 8),
                            _OverlayButton(
                              icon: PhosphorIcons.squaresFour(),
                              isActive: pickerState.isMultiSelect,
                              onTap: () => pickerNotifier.toggleMultiSelect(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Aspect Ratio Toggle
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: BouncyTap(
                      onTap: _toggleAspectRatio,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.black.withValues(alpha: 0.6) 
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: isDark ? null : Border.all(color: Colors.grey[300]!, width: 0.5),
                        ),
                        child: Text(
                          _getAspectRatioText(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black, 
                            fontSize: 12, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── RECENTS HEADER ──────────────────────────────
            _buildRecentsHeader(pickerState, pickerNotifier, isDark),

            // ─── MEDIA GRID ──────────────────────────────────
            Expanded(
              child: _buildMediaGrid(pickerState, pickerNotifier, isDark),
            ),

            // ─── MODE SWITCHER ───────────────────────────────
            _buildModeSwitcher(pickerState, pickerNotifier, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.warningCircle(), color: textColor, size: 60),
              const SizedBox(height: 20),
              Text(
                'Permission Denied',
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095F6),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => ref.read(mediaPickerProvider.notifier).initialize(),
                child: const Text('Try Again', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => PhotoManager.openSetting(),
                child: const Text('Open Settings', style: TextStyle(color: Color(0xFF0095F6))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedPreview(AssetEntity? asset, bool isDark) {
    if (asset == null) {
      return Container(
        color: isDark ? Colors.black : Colors.grey[200], 
        child: Center(child: CupertinoActivityIndicator(color: isDark ? Colors.white : Colors.black))
      );
    }

    if (asset.type == AssetType.video) {
      return _VideoPreview(asset: asset);
    }

    return AssetEntityImage(
      asset,
      isOriginal: true,
      fit: BoxFit.cover,
    );
  }

  Widget _buildRecentsHeader(MediaPickerState state, MediaPickerNotifier notifier, bool isDark) {
    final Color textColor = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark ? Colors.black : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          BouncyTap(
            onTap: () => _showAlbumPicker(state, notifier, isDark),
            child: Row(
              children: [
                Text(
                  state.selectedAlbum?.name ?? 'Recents',
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.keyboard_arrow_down, color: textColor, size: 20),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderCircleButton(
                icon: PhosphorIcons.camera(PhosphorIconsStyle.bold),
                onTap: () {},
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(MediaPickerState state, MediaPickerNotifier notifier, bool isDark) {
    if (state.isLoading && state.assets.isEmpty) {
      return Center(child: CupertinoActivityIndicator(color: isDark ? Colors.white : Colors.black));
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: state.assets.length,
      itemBuilder: (context, index) {
        final asset = state.assets[index];
        final isSelected = state.selectedAssets.contains(asset);
        final selectionIndex = state.selectedAssets.indexOf(asset) + 1;
        final isPrimary = state.selectedAsset == asset;

        return GestureDetector(
          onTap: () => notifier.selectAsset(asset),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetEntityImage(
                asset,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(250),
                fit: BoxFit.cover,
              ),
              
              if (asset.type == AssetType.video)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(PhosphorIcons.videoCamera(PhosphorIconsStyle.fill), color: Colors.white, size: 16),
                ),

              if (state.isMultiSelect)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF0095F6) : Colors.black.withValues(alpha: 0.3),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: isSelected 
                      ? Center(child: Text("$selectionIndex", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))
                      : null,
                  ),
                )
              else if (isPrimary)
                Container(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeSwitcher(MediaPickerState state, MediaPickerNotifier notifier, bool isDark) {
    return Container(
      height: 70 + MediaQuery.of(context).padding.bottom,
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  ...CreateMode.values.map((mode) {
                    final isActive = state.mode == mode;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.setMode(mode);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          mode.name.toUpperCase(),
                          style: TextStyle(
                            color: isActive 
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.grey[600] : Colors.grey[400]),
                            fontSize: 14,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  void _toggleAspectRatio() {
    setState(() {
      if (_aspectRatio == 1.0) _aspectRatio = 4 / 5;
      else if (_aspectRatio == 4 / 5) _aspectRatio = 16 / 9;
      else _aspectRatio = 1.0;
    });
  }

  String _getAspectRatioText() {
    if (_aspectRatio == 1.0) return "1:1";
    if (_aspectRatio == 0.8) return "4:5";
    return "16:9";
  }

  void _showAlbumPicker(MediaPickerState state, MediaPickerNotifier notifier, bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Album', 
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black, 
                  fontSize: 17, 
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: state.albums.length,
                itemBuilder: (context, index) {
                  final album = state.albums[index];
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        album.name, 
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      ),
                      onTap: () {
                        notifier.loadAssets(album);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNext(MediaPickerState state) async {
    if (state.selectedAsset == null) return;
    
    final asset = state.selectedAsset!;
    final file = await asset.file;
    if (file != null && mounted) {
      context.push(AppRoutes.finalizePost, extra: file);
    }
  }
}

class _HeaderCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderCircleButton({
    required this.icon, 
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F2F2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 20),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _OverlayButton({required this.icon, this.isActive = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFF0095F6) 
              : (isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8)),
          shape: BoxShape.circle,
          border: (!isActive && !isDark) ? Border.all(color: Colors.grey[300]!, width: 0.5) : null,
        ),
        child: Icon(
          icon, 
          color: isActive ? Colors.white : (isDark ? Colors.white : Colors.black), 
          size: 20
        ),
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final AssetEntity asset;
  const _VideoPreview({required this.asset});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final file = await widget.asset.file;
    if (file != null) {
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _isInitialized = true);
            _controller?.play();
            _controller?.setLooping(true);
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return AssetEntityImage(widget.asset, fit: BoxFit.cover);
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}
