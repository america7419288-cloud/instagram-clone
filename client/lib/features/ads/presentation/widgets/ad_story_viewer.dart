import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';

import 'package:instagram_client/features/browser/services/browser_launcher.dart';
import '../../data/models/ad_model.dart';
import '../../data/repositories/ad_service.dart';
import 'ad_card_widget.dart'; // import the browser
import '../../../../shared/widgets/spring_widget.dart';

// ─── SPONSORED STORY CIRCLE CIRCULAR AVATAR WIDGET ────────────────
class SponsoredStoryCircle extends ConsumerWidget {
  final AdModel ad;
  const SponsoredStoryCircle({super.key, required this.ad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => AdStoryViewerPage(ad: ad),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Column(
          children: [
            // Custom ad circle with blue/cyan gradient ring
            Container(
              width: 78,
              height: 78,
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)], // cyan to blue ad gradient
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: ad.advertiserAvatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ad.advertiserAvatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.grey),
                        )
                      : Container(
                          color: Colors.grey,
                          child: const Icon(LucideIcons.store, color: Colors.white, size: 28),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 80,
              child: Text(
                ad.advertiserName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF262626),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULLSCREEN STORY AD VIEWER SCREEN ───────────────────────────
class AdStoryViewerPage extends ConsumerStatefulWidget {
  final AdModel ad;
  const AdStoryViewerPage({super.key, required this.ad});

  @override
  ConsumerState<AdStoryViewerPage> createState() => _AdStoryViewerPageState();
}

class _AdStoryViewerPageState extends ConsumerState<AdStoryViewerPage>
    with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late AnimationController _progressController;
  bool _isInitialized = false;
  bool _isPaused = false;
  bool _impressionLogged = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // default 5s for image
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pop(context); // close story ad
      }
    });

    if (widget.ad.type == AdType.storyVideo || widget.ad.type == AdType.video) {
      _initVideo();
    } else {
      _startProgress();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    if (widget.ad.videoUrl == null) return;
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.ad.videoUrl!));
      await _videoController!.initialize();
      if (!mounted) return;
      _videoController!.setLooping(false);
      _videoController!.setVolume(1.0);
      
      setState(() {
        _isInitialized = true;
        _progressController.duration = _videoController!.value.duration;
      });

      _startProgress();
      _videoController!.play();
    } catch (_) {}
  }

  void _startProgress() {
    _progressController.forward();
    _logImpression();
  }

  void _logImpression() {
    if (_impressionLogged) return;
    _impressionLogged = true;
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'impression',
          placement: 'stories',
        );
  }

  void _pause() {
    if (_isPaused) return;
    _progressController.stop();
    _videoController?.pause();
    setState(() => _isPaused = true);
  }

  void _resume() {
    if (!_isPaused) return;
    _progressController.forward();
    _videoController?.play();
    setState(() => _isPaused = false);
  }

  void _handleSwipeUp() {
    _pause();
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'swipe_up',
          placement: 'stories',
        );
    
    BrowserLauncher.open(
      context: context,
      url: widget.ad.ctaUrl ?? '',
      title: widget.ad.advertiserName,
      isAd: true,
      adSource: widget.ad.advertiserName,
      adCampaignId: widget.ad.campaignId,
    ).then((_) => _resume());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _pause(),
        onLongPressEnd: (_) => _resume(),
        onVerticalDragEnd: (details) {
          // Swipe up detection (velocity or delta)
          if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
            _handleSwipeUp();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Asset
            if (widget.ad.type == AdType.storyVideo || widget.ad.type == AdType.video)
              _isInitialized && _videoController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Center(child: CupertinoActivityIndicator(color: Colors.white))
            else
              widget.ad.imageUrl != null
                  ? CachedNetworkImage(imageUrl: widget.ad.imageUrl!, fit: BoxFit.cover)
                  : Container(color: Colors.grey[900]),

            // Gradients overlay
            _buildGradients(),

            // Top Header: Progress Bar & Info
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress line
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _progressController.value,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 3,
                          ),
                        );
                      },
                    ),
                  ),
                  // User Details header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.ad.advertiserAvatarUrl != null ? CachedNetworkImageProvider(widget.ad.advertiserAvatarUrl!) : null,
                          child: widget.ad.advertiserAvatarUrl == null ? const Icon(LucideIcons.store, size: 16) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.ad.advertiserName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: Color(0xFF0095F6), size: 12),
                                ],
                              ),
                              const Text('Sponsored', style: TextStyle(color: Colors.white70, fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Swipe Up CTA Overlay
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: BouncyTap(
                onTap: _handleSwipeUp,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.chevron_up, color: Colors.white, size: 20),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Text(
                        widget.ad.storySwipeUpText ?? 'See More',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradients() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black38, Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black38, Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
