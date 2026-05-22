// lib/features/auth/signup/presentation/widgets/suggestion_tile.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/suggested_user.dart';
import '../theme/auth_theme.dart';
import '../../../../../shared/widgets/verified_badge.dart';

class SuggestionTile extends StatelessWidget {
  final SuggestedUser user;
  final VoidCallback onFollowTap;

  const SuggestionTile({
    super.key,
    required this.user,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: [

          // ── AVATAR ────────────────────────────
          _Avatar(user: user),

          const SizedBox(width: 12),

          // ── USER INFO ─────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [

                // Username + Verified
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: fontFamily,
                          color: AuthColors.primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isVerified) ...[
                      const SizedBox(width: 3),
                      const VerifiedBadge(size: 13),
                    ],
                  ],
                ),

                const SizedBox(height: 1),

                // Display name
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontFamily: fontFamily,
                    color: AuthColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                // Reason text
                Text(
                  user.displayReason,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: fontFamily,
                    color: AuthColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── FOLLOW BUTTON ─────────────────────
          _FollowButton(
            isFollowing: user.isFollowing,
            isPending: user.isFollowingPending,
            onTap: onFollowTap,
          ),

        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// AVATAR (with story ring + online state)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _Avatar extends StatelessWidget {
  final SuggestedUser user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.hasStory) {
      // With gradient story ring
      return Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: user.hasSeenStory
              ? null
              : const LinearGradient(
                  colors: AuthColors.gradientColors,
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
          color: user.hasSeenStory
              ? AuthColors.tertiaryText
              : null,
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AuthColors.white,
          ),
          padding: const EdgeInsets.all(2),
          child: _AvatarImage(url: user.avatarUrl),
        ),
      );
    }

    // Plain avatar
    return SizedBox(
      width: 56,
      height: 56,
      child: _AvatarImage(url: user.avatarUrl),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  final String? url;

  const _AvatarImage({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: url != null
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _placeholder(),
              loadingBuilder: (_, child, prog) {
                if (prog == null) return child;
                return _placeholder();
              },
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFEFEFEF),
      child: const Center(
        child: Icon(
          LucideIcons.user,
          size: 22,
          color: AuthColors.secondaryText,
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// FOLLOW BUTTON
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FollowButton extends StatefulWidget {
  final bool isFollowing;
  final bool isPending;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.isPending,
    required this.onTap,
  });

  @override
  State<_FollowButton> createState() =>
      _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton>
    with SingleTickerProviderStateMixin {

  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isFollowing = widget.isFollowing;
    final isPending = widget.isPending;

    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        if (!isPending) {
          HapticFeedback.lightImpact();
          widget.onTap();
        }
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 96,
          height: 32,
          decoration: BoxDecoration(
            color: isFollowing
                ? AuthColors.buttonGray
                : AuthColors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: isPending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CupertinoActivityIndicator(
                    radius: 7,
                    color: Colors.white, // Default to white, can refine
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(
                      milliseconds: 200),
                  child: Text(
                    isFollowing
                        ? 'Following'
                        : 'Follow',
                    key: ValueKey(isFollowing),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: fontFamily,
                      color: isFollowing
                          ? AuthColors.primaryText
                          : Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }
}
