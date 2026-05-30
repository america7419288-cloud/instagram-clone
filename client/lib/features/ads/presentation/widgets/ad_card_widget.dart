import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:instagram_client/features/browser/services/browser_launcher.dart';
import '../../data/models/ad_model.dart';
import '../../data/repositories/ad_service.dart';
import '../../../post/presentation/widgets/video_player_widget.dart';
import '../../../../shared/widgets/spring_widget.dart';

class AdCardWidget extends ConsumerStatefulWidget {
  final AdModel ad;
  const AdCardWidget({super.key, required this.ad});

  @override
  ConsumerState<AdCardWidget> createState() => _AdCardWidgetState();
}

class _AdCardWidgetState extends ConsumerState<AdCardWidget> {
  int _currentPage = 0;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _impressionLogged = false;

  @override
  void initState() {
    super.initState();
  }

  void _logImpression() {
    if (_impressionLogged) return;
    _impressionLogged = true;
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'impression',
          placement: 'feed',
        );
  }

  void _handleCTATap() {
    HapticFeedback.mediumImpact();
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'cta_click',
          placement: 'feed',
        );
    
    // Open in-app mock browser dialog
    _openBrowser(widget.ad.ctaUrl);
  }

  void _handleLikeTap() {
    HapticFeedback.selectionClick();
    setState(() => _isLiked = !_isLiked);
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'click',
          placement: 'feed',
        );
  }

  void _openBrowser(String url) {
    BrowserLauncher.open(
      context: context,
      url: url,
      title: widget.ad.advertiserName,
      isAd: true,
      adSource: widget.ad.advertiserName,
      adCampaignId: widget.ad.campaignId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;

    return VisibilityDetector(
      key: ValueKey('ad-${widget.ad.adId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.6) {
          _logImpression();
        }
      },
      child: Container(
        color: isDark ? Colors.black : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(isDark),
            // Media
            _buildMedia(isDark),
            // CTA Banner Button
            if (widget.ad.ctaType != AdCTAType.noButton) _buildCtaBanner(isDark),
            // Action Row
            _buildActionRow(isDark),
            // Likes & Copy
            _buildDetails(isDark),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
            backgroundImage: widget.ad.advertiserAvatarUrl != null ? CachedNetworkImageProvider(widget.ad.advertiserAvatarUrl!) : null,
            child: widget.ad.advertiserAvatarUrl == null ? const Icon(LucideIcons.store, size: 16, color: Colors.grey) : null,
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF262626),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Color(0xFF0095F6), size: 13),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Sponsored',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.ellipsis, color: isDark ? Colors.white : Colors.black),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(bool isDark) {
    final width = MediaQuery.of(context).size.width;

    if (widget.ad.type == AdType.video) {
      return AspectRatio(
        aspectRatio: 1.0, // Square feed ad video
        child: widget.ad.videoUrl != null
            ? VideoPlayerWidget(videoUrl: widget.ad.videoUrl!, fit: BoxFit.cover)
            : Container(color: Colors.black),
      );
    } else if (widget.ad.type == AdType.carousel) {
      return AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              itemCount: widget.ad.carouselCards.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, idx) {
                final card = widget.ad.carouselCards[idx];
                return CachedNetworkImage(
                  imageUrl: card.imageUrl,
                  fit: BoxFit.cover,
                  width: width,
                );
              },
            ),
            if (widget.ad.carouselCards.length > 1)
              Positioned(
                bottom: 12,
                child: Row(
                  children: List.generate(
                    widget.ad.carouselCards.length,
                    (idx) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == idx ? const Color(0xFF0095F6) : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      // Normal single image ad
      return AspectRatio(
        aspectRatio: 1.0,
        child: widget.ad.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: widget.ad.imageUrl!,
                fit: BoxFit.cover,
                width: width,
              )
            : Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),
      );
    }
  }

  Widget _buildCtaBanner(bool isDark) {
    return BouncyTap(
      onTap: _handleCTATap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AdModel.ctaLabel(widget.ad.ctaType),
                style: const TextStyle(
                  color: Color(0xFF0095F6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(LucideIcons.chevron_right, color: Color(0xFF0095F6), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(bool isDark) {
    final iconColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isLiked ? Icons.favorite : LucideIcons.heart,
              color: _isLiked ? CupertinoColors.systemRed : iconColor,
              size: 26,
            ),
            onPressed: _buildActionTap,
          ),
          IconButton(
            icon: Icon(LucideIcons.message_circle, color: iconColor, size: 26),
            onPressed: _buildActionTap,
          ),
          IconButton(
            icon: Icon(LucideIcons.send, color: iconColor, size: 26),
            onPressed: _buildActionTap,
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : LucideIcons.bookmark,
              color: iconColor,
              size: 26,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isSaved = !_isSaved);
              _buildActionTap();
            },
          ),
        ],
      ),
    );
  }

  void _buildActionTap() {
    HapticFeedback.selectionClick();
    ref.read(adServiceProvider).trackAdEvent(
          adId: widget.ad.adId,
          campaignId: widget.ad.campaignId,
          advertiserId: widget.ad.advertiserId,
          action: 'click',
          placement: 'feed',
        );
  }

  Widget _buildDetails(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Liked by thousands of users',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF262626),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
              children: [
                TextSpan(text: '${widget.ad.advertiserName} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: widget.ad.primaryText),
              ],
            ),
          ),
          if (widget.ad.headline != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.ad.headline!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


