import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:instagram_client/features/browser/services/browser_launcher.dart';
import '../../data/models/ad_model.dart';
import '../../data/repositories/ad_service.dart';
import '../widgets/ad_card_widget.dart'; // import the browser
import '../../../../shared/widgets/spring_widget.dart';

class AdReelWidget extends ConsumerStatefulWidget {
  final AdModel ad;
  final bool isActive;
  const AdReelWidget({super.key, required this.ad, required this.isActive});

  @override
  ConsumerState<AdReelWidget> createState() => _AdReelWidgetState();
}

class _AdReelWidgetState extends ConsumerState<AdReelWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _impressionLogged = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(AdReelWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _play();
      } else {
        _pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (widget.ad.videoUrl == null) return;
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.ad.videoUrl!),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      if (!mounted) return;
      _controller!.setLooping(true);
      _controller!.setVolume(1.0);
      setState(() => _isInitialized = true);
      if (widget.isActive) _play();
    } catch (_) {}
  }

  void _play() {
    if (_isInitialized && _controller != null) {
      _controller!.play();
      _logImpression();
    }
  }

  void _pause() {
    if (_isInitialized && _controller != null) {
      _controller!.pause();
    }
  }

  void _logImpression() {
    if (_impressionLogged) return;
    _impressionLogged = true;
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'impression',
          placement: 'reels',
        );
  }

  void _handleCTATap() {
    HapticFeedback.mediumImpact();
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'cta_click',
          placement: 'reels',
        );
    
    _pause();
    BrowserLauncher.open(
      context: context,
      url: widget.ad.ctaUrl ?? '',
      title: widget.ad.advertiserName,
      isAd: true,
      adSource: widget.ad.advertiserName,
      adCampaignId: widget.ad.campaignId,
    ).then((_) {
      if (mounted && widget.isActive) {
        _play();
      }
    });
  }

  void _handleLike() {
    HapticFeedback.selectionClick();
    setState(() => _isLiked = !_isLiked);
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'click',
          placement: 'reels',
        );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return VisibilityDetector(
      key: ValueKey('reel-ad-${widget.ad.adId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.6) {
          _logImpression();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player
            if (_isInitialized && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else if (widget.ad.videoThumbnailUrl != null)
              CachedNetworkImage(
                imageUrl: widget.ad.videoThumbnailUrl!,
                fit: BoxFit.cover,
              )
            else
              const Center(child: CupertinoActivityIndicator(color: Colors.white)),

            // Gradient Overlays
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent, Colors.black54],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Left Bottom Info
            Positioned(
              left: 16,
              bottom: 32,
              right: 88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: widget.ad.advertiserAvatarUrl != null ? CachedNetworkImageProvider(widget.ad.advertiserAvatarUrl!) : null,
                        child: widget.ad.advertiserAvatarUrl == null ? const Icon(LucideIcons.store, size: 16, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.ad.advertiserName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Color(0xFF0095F6), size: 13),
                              ],
                            ),
                            const Text(
                              'Sponsored',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.ad.primaryText,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.ad.headline != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.ad.headline!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // CTA Button
                  if (widget.ad.ctaType != AdCTAType.noButton)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      color: const Color(0xFF0095F6),
                      borderRadius: BorderRadius.circular(8),
                      onPressed: _handleCTATap,
                      child: Text(
                        AdModel.ctaLabel(widget.ad.ctaType).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            // Right Sidebar Actions
            Positioned(
              right: 16,
              bottom: 80,
              child: Column(
                children: [
                  // Like
                  _buildSidebarBtn(
                    icon: _isLiked ? Icons.favorite : LucideIcons.heart,
                    color: _isLiked ? Colors.red : Colors.white,
                    label: 'Like',
                    onTap: _handleLike,
                  ),
                  const SizedBox(height: 20),
                  // Comments
                  _buildSidebarBtn(
                    icon: LucideIcons.message_circle,
                    label: 'Comments',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(adServiceProvider).trackAdEvent(
                            adId: widget.ad.adId,
                            campaignId: widget.ad.campaignId,
                            advertiserId: widget.ad.advertiserId,
                            action: 'click',
                            placement: 'reels',
                          );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Share
                  _buildSidebarBtn(
                    icon: LucideIcons.send,
                    label: 'Share',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarBtn({
    required IconData icon,
    Color color = Colors.white,
    required String label,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
