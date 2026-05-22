import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../../shared/widgets/user_story_avatar.dart';
import '../../../../../shared/widgets/verified_badge.dart';
import 'chat_ui_constants.dart';

class ChatAppBar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final String? userId;
  final String? statusText;
  final bool isOnline;
  final bool isVerified;
  final bool hasStory;
  final bool hasSeenStory;
  final VoidCallback? onProfileTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onVideoTap;
  final VoidCallback? onInfoTap;
  final VoidCallback? onMoreTap;

  const ChatAppBar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.userId,
    this.statusText,
    this.isOnline = false,
    this.isVerified = false,
    this.hasStory = false,
    this.hasSeenStory = false,
    this.onProfileTap,
    this.onCallTap,
    this.onVideoTap,
    this.onInfoTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ChatUIConstants.bgDark : ChatUIConstants.bgLight;
    final separatorColor = isDark
        ? ChatUIConstants.separatorDark
        : ChatUIConstants.separatorLight;

    return Container(
      height: 50 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 2,
        right: 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: separatorColor, width: 0.33)),
      ),
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.only(left: 12, right: 4),
            minimumSize: const Size(40, 40),
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            child: Icon(
              LucideIcons.chevron_left,
              size: 30,
              color: isDark
                  ? ChatUIConstants.textPrimaryDark
                  : ChatUIConstants.textPrimaryLight,
            ),
          ),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onProfileTap == null
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onProfileTap!();
                    },
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildAvatarContainer(isDark),
                      if (isOnline)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: ChatUIConstants.onlineDot,
                              shape: BoxShape.circle,
                              border: Border.all(color: bgColor, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ChatUIConstants.usernameStyle(
                                  context,
                                  isDark,
                                ),
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const VerifiedBadge(size: 14),
                            ],
                          ],
                        ),
                        if (statusText != null)
                          Text(
                            statusText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ChatUIConstants.statusStyle(
                              context,
                              isOnline: statusText == 'Active now',
                              isDark: isDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildActionIcon(context, LucideIcons.phone, onCallTap),
          _buildActionIcon(context, LucideIcons.video, onVideoTap),
          _buildActionIcon(context, LucideIcons.info, onMoreTap ?? onInfoTap),
        ],
      ),
    );
  }

  Widget _buildAvatarContainer(bool isDark) {
    if (userId != null) {
      return UserStoryAvatar(
        userId: userId!,
        profilePicUrl: avatarUrl,
        username: username,
        size: 34,
        showPresence: false,
        isClickable: true,
      );
    }
    
    if (!hasStory) return _buildBaseAvatar(34);

    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: hasSeenStory
              ? [const Color(0xFFC7C7CC), const Color(0xFFC7C7CC)]
              : ChatUIConstants.storyGradient,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark ? ChatUIConstants.bgDark : ChatUIConstants.bgLight,
          shape: BoxShape.circle,
        ),
        child: _buildBaseAvatar(28),
      ),
    );
  }

  Widget _buildBaseAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ChatUIConstants.separatorLight,
        image: avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatarUrl == null
          ? Icon(
              LucideIcons.user,
              size: size * 0.55,
              color: const Color(0xFFAAAAAA),
            )
          : null,
    );
  }

  Widget _buildActionIcon(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
  ) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      minimumSize: const Size(38, 38),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      child: Icon(
        icon,
        size: 24,
        color: isDark
            ? ChatUIConstants.textPrimaryDark
            : ChatUIConstants.textPrimaryLight,
      ),
    );
  }
}
