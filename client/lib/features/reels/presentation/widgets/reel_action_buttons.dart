// lib/features/reels/presentation/widgets/reel_action_buttons.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/reel_model.dart';

class ReelActionButtons extends StatefulWidget {
  final ReelModel reel;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onAudio;

  const ReelActionButtons({
    super.key,
    required this.reel,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onAudio,
  });

  @override
  State<ReelActionButtons> createState() => _ReelActionButtonsState();
}

class _ReelActionButtonsState extends State<ReelActionButtons>
    with SingleTickerProviderStateMixin {
  // ─── Like bounce animation ────────────────────────────
  late AnimationController _likeController;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _likeController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _handleLike() {
    HapticFeedback.lightImpact();
    _likeController.forward(from: 0);
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Avatar ─────────────────────────────────────
        _buildAvatar(),
        const SizedBox(height: 24),

        // ─── Like ────────────────────────────────────────
        _buildLikeButton(),
        const SizedBox(height: 20),

        // ─── Comment ─────────────────────────────────────
        _buildActionButton(
          icon: Icons.chat_bubble_outline,
          label: _formatCount(widget.reel.commentsCount),
          onTap: widget.onComment,
        ),
        const SizedBox(height: 20),

        // ─── Share ───────────────────────────────────────
        _buildActionButton(
          icon: Icons.near_me_outlined,
          label: 'Share',
          onTap: widget.onShare,
        ),
        const SizedBox(height: 20),

        // ─── More options ────────────────────────────────
        _buildActionButton(
          icon: Icons.more_vert,
          label: '',
          onTap: () {},
        ),
        const SizedBox(height: 20),

        // ─── Audio disc ──────────────────────────────────
        _buildAudioDisc(),
      ],
    );
  }

  // ─── Avatar with follow ring ──────────────────────────
  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: widget.reel.userAvatar != null
                ? CachedNetworkImage(
                    imageUrl: widget.reel.userAvatar!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: AppColors.darkDivider),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.darkDivider,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.darkDivider,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
          ),
        ),
        // ─── Follow + button ─────────────────────────────
        if (!widget.reel.isOwnReel && !widget.reel.isFollowing)
          Positioned(
            bottom: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Like button with animation ───────────────────────
  Widget _buildLikeButton() {
    return GestureDetector(
      onTap: _handleLike,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _likeController,
            builder: (_, child) => Transform.scale(
              scale: _likeScale.value,
              child: child,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.reel.isLiked
                    ? Icons.favorite
                    : Icons.favorite_border,
                key: ValueKey(widget.reel.isLiked),
                color: widget.reel.isLiked
                    ? AppColors.like
                    : Colors.white,
                size: 32,
                shadows: const [
                  Shadow(blurRadius: 8, color: Colors.black38),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatCount(widget.reel.likesCount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Generic action button ────────────────────────────
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 30,
            shadows: const [
              Shadow(blurRadius: 8, color: Colors.black38),
            ],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(blurRadius: 4, color: Colors.black45),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Spinning audio disc ──────────────────────────────
  Widget _buildAudioDisc() {
    return _SpinningDisc(
      imageUrl: widget.reel.userAvatar,
      onTap: widget.onAudio,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

// ─────────────────────────────────────────────────────
// SPINNING AUDIO DISC
// ─────────────────────────────────────────────────────
class _SpinningDisc extends StatefulWidget {
  final String? imageUrl;
  final VoidCallback onTap;

  const _SpinningDisc({
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: RotationTransition(
        turns: _spinController,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF434343), Color(0xFF000000)],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 8,
            ),
          ),
          child: ClipOval(
            child: widget.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.imageUrl!,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: const Color(0xFF434343),
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}