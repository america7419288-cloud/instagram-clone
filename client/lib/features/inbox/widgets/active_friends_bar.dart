// lib/features/inbox/widgets/active_friends_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/active_friend_model.dart';
import '../controllers/inbox_controller.dart';
import '../../notes/controllers/notes_controller.dart';
import 'active_friend_item.dart';

class ActiveFriendsBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final dividerColor = Colors.grey.withOpacity(0.15);

    // Watch Notes State & Conversations to merge offline friends with notes
    final notesState = ref.watch(notesProvider);
    final inboxState = ref.watch(inboxPageProvider);

    // 1. Build Merged Tray List
    final List<ActiveFriendModel> mergedFriends = [];
    final Set<String> addedUsernames = {};

    // 2. Add online friends first (from parameter)
    for (final friend in friends) {
      mergedFriends.add(friend);
      addedUsernames.add(friend.username);
    }

    // 3. Add friends who have shared notes but are offline
    for (final note in notesState.friendNotes) {
      if (!addedUsernames.contains(note.username)) {
        // Resolve conversationId if we have one
        String convId = '';
        for (final conv in inboxState.conversations) {
          if (conv.username == note.username) {
            convId = conv.id;
            break;
          }
        }
        mergedFriends.add(
          ActiveFriendModel(
            id: note.userId,
            username: note.username,
            avatarUrl: note.avatarUrl,
            isActive: false, // offline
            conversationId: convId,
            hasActiveNote: true,
            noteText: note.text,
          ),
        );
        addedUsernames.add(note.username);
      }
    }

    return Container(
      height: 154, // Increased to accommodate larger 82px avatars + note bubbles
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
            stops: [0.0, 0.90, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 24, top: 24), // Increased top padding to 24 to make room for bubbles
          itemCount: mergedFriends.length + 1, // +1 for "Your Note"
          itemBuilder: (context, index) {
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

            final friend = mergedFriends[index - 1];
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
