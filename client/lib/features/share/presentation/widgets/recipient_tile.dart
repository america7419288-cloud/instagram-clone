// lib/features/share/presentation/widgets/recipient_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/share_target.dart';
import '../theme/share_theme.dart';

class RecipientTile extends StatefulWidget {
  final ShareTarget target;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const RecipientTile({
    super.key,
    required this.target,
    required this.isSelected,
    required this.onTap,
    this.isDark = true,
  });

  @override
  State<RecipientTile> createState() => _RecipientTileState();
}

class _RecipientTileState extends State<RecipientTile>
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
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with selection ring
              _Avatar(
                target: widget.target,
                isSelected: widget.isSelected,
                isDark: widget.isDark,
              ),
              const SizedBox(height: 6),
              // Name
              Text(
                widget.target.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: ShareTheme.fontFamily,
                  color: widget.isDark
                      ? ShareTheme.primaryTextDark
                      : ShareTheme.primaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
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

class _Avatar extends StatelessWidget {
  final ShareTarget target;
  final bool isSelected;
  final bool isDark;

  const _Avatar({
    required this.target,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Story ring or close friends indicator
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 64,
          height: 64,
          padding: EdgeInsets.all(
              isSelected ? 2.5 : (target.hasStory ? 2 : 0)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: !isSelected && target.hasStory && 
                     !target.hasSeenStory
                ? const LinearGradient(
                    colors: ShareTheme.gradientColors,
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: isSelected
                ? ShareTheme.blue
                : (target.hasStory && target.hasSeenStory
                    ? ShareTheme.tertiaryText
                    : null),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? ShareTheme.backgroundDark
                  : ShareTheme.background,
            ),
            padding: EdgeInsets.all(
                (isSelected || target.hasStory) ? 2 : 0),
            child: _buildAvatarContent(context),
          ),
        ),

        // Selected checkmark badge
        if (isSelected)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ShareTheme.blue,
                border: Border.all(
                  color: isDark
                      ? ShareTheme.backgroundDark
                      : ShareTheme.background,
                  width: 2,
                ),
              ),
              child: const Icon(
                LucideIcons.check,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),

        // Online indicator
        if (!isSelected && target.isOnline)
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: ShareTheme.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? ShareTheme.backgroundDark
                      : ShareTheme.background,
                  width: 2,
                ),
              ),
            ),
          ),

        // Verified badge
        if (target.isVerified && !isSelected)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? ShareTheme.backgroundDark
                    : ShareTheme.background,
              ),
              child: const Icon(
                LucideIcons.badgeCheck,
                size: 16,
                color: ShareTheme.blue,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    // Group avatar (overlapping circles)
    if (target.type == ShareTargetType.group &&
        target.memberAvatars != null &&
        target.memberAvatars!.isNotEmpty) {
      return _GroupAvatar(
        avatars: target.memberAvatars!,
      );
    }

    // Close friends special icon
    if (target.type == ShareTargetType.closeFriends) {
      return Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: ShareTheme.closeFriendsGreen,
        ),
        child: const Center(
          child: Icon(
            LucideIcons.star,
            color: Colors.white,
            size: 28,
          ),
        ),
      );
    }

    // Notes special icon
    if (target.type == ShareTargetType.notes) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? ShareTheme.surfaceDark
              : const Color(0xFFEFEFEF),
        ),
        child: Center(
          child: Icon(
            LucideIcons.stickyNote,
            color: isDark
                ? Colors.white
                : ShareTheme.primaryText,
            size: 26,
          ),
        ),
      );
    }

    // Standard user avatar
    return ClipOval(
      child: target.avatarUrl != null
          ? Image.network(
              target.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
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
          size: 24,
          color: ShareTheme.secondaryText,
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  final List<String> avatars;

  const _GroupAvatar({required this.avatars});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Back avatar (top-right)
        Positioned(
          top: 0,
          right: 0,
          child: ClipOval(
            child: Image.network(
              avatars[1 % avatars.length],
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Front avatar (bottom-left)
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: Image.network(
                avatars[0],
                width: 34,
                height: 34,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
