// lib/features/chat/presentation/widgets/chat_app_bar.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/chat_theme.dart';
import '../../../../shared/widgets/verified_badge.dart';

class ChatAppBar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final bool isOnline;
  final bool isVerified;
  final bool hasStory;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onInfoTap;
  final VoidCallback onCall;
  final VoidCallback onVideo;

  const ChatAppBar({
    super.key,
    required this.username,
    this.avatarUrl,
    required this.isOnline,
    required this.isVerified,
    required this.hasStory,
    required this.isDark,
    required this.onBack,
    required this.onInfoTap,
    required this.onCall,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: isDark
            ? ChatColors.black
            : ChatColors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? ChatColors.separatorDark
                : ChatColors.separatorLight,
            width: 0.33,
          ),
        ),
      ),
      child: Row(
        children: [

          // ── Back ─────────────────────────────
          CupertinoButton(
            padding: const EdgeInsets.fromLTRB(
                8, 0, 4, 0),
            onPressed: () {
              HapticFeedback.lightImpact();
              onBack();
            },
            child: Icon(
              LucideIcons.chevronLeft,
              color: isDark
                  ? Colors.white
                  : ChatColors.primaryLight,
              size: 28,
            ),
          ),

          // ── User Info ─────────────────────────
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onInfoTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar
                  _AppBarAvatar(
                    url: avatarUrl,
                    hasStory: hasStory,
                    isOnline: isOnline,
                    isDark: isDark,
                  ),

                  const SizedBox(width: 10),

                  // Name + status
                  Flexible(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Username + verified
                        Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                username,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : ChatColors
                                          .primaryLight,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w700,
                                  fontFamily:
                                      ChatTextStyles
                                          .fontFamily,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow
                                    .ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 3),
                              const VerifiedBadge(size: 13),
                            ],
                          ],
                        ),

                        // Active status
                        Text(
                          isOnline
                              ? 'Active now'
                              : 'Active 2h ago',
                          style: TextStyle(
                            color: isOnline
                                ? ChatColors.green
                                : ChatColors.secondary,
                            fontSize: 12,
                            fontFamily: ChatTextStyles
                                .fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right Icons ───────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppBarIcon(
                icon: LucideIcons.phone,
                isDark: isDark,
                onTap: onCall,
              ),
              _AppBarIcon(
                icon: LucideIcons.video,
                isDark: isDark,
                onTap: onVideo,
              ),
              const SizedBox(width: 6),
            ],
          ),

        ],
      ),
    );
  }
}

// ── App Bar Avatar ─────────────────────────

class _AppBarAvatar extends StatelessWidget {
  final String? url;
  final bool hasStory;
  final bool isOnline;
  final bool isDark;

  const _AppBarAvatar({
    this.url,
    required this.hasStory,
    required this.isOnline,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Story ring or plain avatar
        if (hasStory)
          Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: ChatColors.gradientColors,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? ChatColors.black
                    : ChatColors.white,
              ),
              padding: const EdgeInsets.all(1.5),
              child: _Avatar(url: url, radius: 13),
            ),
          )
        else
          _Avatar(url: url, radius: 18),

        // Online dot
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: ChatColors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? ChatColors.black
                      : ChatColors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double radius;

  const _Avatar({this.url, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          const Color(0xFFEFEFEF),
      backgroundImage:
          url != null ? NetworkImage(url!) : null,
      child: url == null
          ? Icon(
              LucideIcons.user,
              size: radius * 0.85,
              color: ChatColors.secondary,
            )
          : null,
    );
  }
}

// ── App Bar Icon ───────────────────────────

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _AppBarIcon({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(
          horizontal: 10),
      onPressed: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Icon(
        icon,
        color: isDark
            ? Colors.white
            : ChatColors.primaryLight,
        size: 23,
      ),
    );
  }
}
