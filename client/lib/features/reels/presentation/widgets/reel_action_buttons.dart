// lib/features/reels/presentation/widgets/reel_action_buttons.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/spring_widget.dart';
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
        _buildLikeButton(),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: LucideIcons.message_circle,
          label: _formatCount(widget.reel.commentsCount),
          onTap: widget.onComment,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: LucideIcons.send,
          label: 'Send',
          onTap: widget.onShare,
        ),
        const SizedBox(height: 20),
        _buildActionButton(
          icon: LucideIcons.eclipse,
          label: '',
          onTap: () {},
        ),
        const SizedBox(height: 20),
        _buildAudioDisc(),
      ],
    );
  }

  Widget _buildLikeButton() {
    return BouncyTap(
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
            child: Icon(
              LucideIcons.heart,
              color: widget.reel.isLiked ? Colors.red : Colors.white,
              size: 24, // Consistent size
              fill: widget.reel.isLiked ? 1.0 : 0.0,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24, // Consistent size
            shadows: const [Shadow(blurRadius: 8, color: Colors.black38)],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: widget.onTap,
      child: RotationTransition(
        turns: _spinController,
        child: Container(
          width: 30,
          height: 30,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
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
                      size: 14,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
