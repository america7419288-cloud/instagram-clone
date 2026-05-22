// lib/features/inbox/widgets/active_friends_bar.dart

import 'package:flutter/material.dart';
import '../models/active_friend_model.dart';
import 'active_friend_item.dart';

class ActiveFriendsBar extends StatelessWidget {
  final List<ActiveFriendModel> friends;
  final AnimationController entryController;
  final Function(ActiveFriendModel) onFriendTap;
  final VoidCallback onNoteTap;
  final String? currentUserAvatar;

  const ActiveFriendsBar({
    super.key,
    required this.friends,
    required this.entryController,
    required this.onFriendTap,
    required this.onNoteTap,
    this.currentUserAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = Colors.grey.withValues(alpha: 0.15);

    return Container(
      height: 115, // Expanded from 90px to beautifully fit note bubbles above avatars without clipping
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: dividerColor, width: 0.5),
        ),
      ),
      child: ShaderMask(
        shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.88, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 24, top: 12),
          itemCount: friends.length + 1, // +1 for "Your Note"
          itemBuilder: (context, index) {
            // STAGGERED ANIMATION SPEC:
            // item[0] (Your Note): delay 0ms, elastic scale (handled in entry or local controller)
            // item[i] (Friends): delay 50ms + (i-1) * 60ms, translateX: 30px -> 0, opacity: 0 -> 1, duration: 350ms
            
            final double delay = (index * 0.06).clamp(0.0, 0.4);
            final double end = (delay + 0.35).clamp(0.0, 1.0);
            
            final animation = CurvedAnimation(
              parent: entryController,
              curve: Interval(delay, end, curve: Curves.easeOutCubic),
            );

            if (index == 0) {
              return ActiveFriendItem(
                friend: null,
                currentUserAvatar: currentUserAvatar,
                onTap: onNoteTap,
                animation: animation,
              );
            }

            final friend = friends[index - 1];
            return ActiveFriendItem(
              friend: friend,
              onTap: () => onFriendTap(friend),
              animation: animation,
            );
          },
        ),
      ),
    );
  }
}
