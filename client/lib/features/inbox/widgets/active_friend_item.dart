// lib/features/inbox/widgets/active_friend_item.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/active_friend_model.dart';
import '../../notes/controllers/notes_controller.dart';
import '../../notes/models/note_model.dart';
import '../../notes/widgets/note_bubble.dart';
import '../../notes/pages/note_create_sheet.dart';
import '../../notes/pages/note_view_sheet.dart';
import 'pulsing_dot.dart';

class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashesCount;

  DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashesCount = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double radius = size.width / 2;
    final double arcLength = (2 * math.pi) / dashesCount;

    for (int i = 0; i < dashesCount; i++) {
      if (i % 2 == 0) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset(radius, radius), radius: radius),
          i * arcLength,
          arcLength,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ActiveFriendItem extends ConsumerWidget {
  final ActiveFriendModel? friend; // null represents "Your Note"
  final VoidCallback onTap;
  final Animation<double> animation;
  final String? currentUserAvatar;

  const ActiveFriendItem({
    super.key,
    this.friend,
    required this.onTap,
    required this.animation,
    this.currentUserAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? const Color(0xFFA8A8A8) : const Color(0xFF737373);

    final isYourNote = friend == null;

    // Watch Notes State
    final notesState = ref.watch(notesProvider);

    NoteModel? activeNote;
    if (isYourNote) {
      activeNote = notesState.myNote;
    } else {
      // Find matching note for this friend
      for (final note in notesState.friendNotes) {
        if (note.username == friend!.username) {
          activeNote = note;
          break;
        }
      }
    }

    // Determine Tap Behavior
    final VoidCallback itemTapHandler = () {
      if (isYourNote) {
        // Open Note Creation or Edit sheet
        NoteCreateSheet.show(context, existingNote: activeNote);
      } else if (activeNote != null) {
        // Open Note View/Reply sheet
        NoteViewSheet.show(context, activeNote);
      } else {
        // Standard friend tap (opens chat)
        onTap();
      }
    };

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final translateX = (1.0 - animation.value) * 30.0;
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(translateX, 0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: itemTapHandler,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // AVATAR AREA WITH OPTIONAL STATE-OF-THE-ART NOTE BUBBLE
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Avatar Circle
                  if (isYourNote)
                    _buildYourNoteAvatar(isDark, labelColor, activeNote != null)
                  else
                    _buildFriendAvatar(isDark),

                  // NOTE BUBBLE (above avatar)
                  if (activeNote != null)
                    Positioned(
                      top: -26, // Shifted up beautifully
                      left: 14, // Aligned slightly right of center to match the bottom-left pointer tail
                      child: NoteBubble(
                        note: activeNote,
                        animateEntry: true,
                        onTap: itemTapHandler,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // USERNAME / LABEL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  isYourNote ? 'Your note' : _truncateUsername(friend!.username),
                  style: TextStyle(
                    fontSize: 12,
                    color: isYourNote ? labelColor : textColor,
                    fontWeight: isYourNote ? FontWeight.w400 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYourNoteAvatar(bool isDark, Color labelColor, bool hasNote) {
    final dashedColor = isDark ? const Color(0xFF363636) : const Color(0xFFDBDBDB);
    final avatarUrl = currentUserAvatar ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Avatar frame
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: CustomPaint(
            painter: DashedCirclePainter(
              color: hasNote ? Colors.transparent : dashedColor,
              strokeWidth: 1.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          errorWidget: (c, u, e) => _buildPlaceholderIcon(),
                        )
                      : _buildPlaceholderIcon(),
                ),
              ),
            ),
          ),
        ),

        // Show Blue [+] badge only if the user hasn't left a note yet
        if (!hasNote)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF0095F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFriendAvatar(bool isDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Profile picture
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: CachedNetworkImage(
              imageUrl: friend!.avatarUrl,
              fit: BoxFit.cover,
              placeholder: (c, u) => Container(color: Colors.grey.withOpacity(0.2)),
              errorWidget: (c, u, e) => _buildPlaceholderIcon(),
            ),
          ),
        ),

        // Online pulsing dot
        if (friend!.isActive)
          const Positioned(
            bottom: -3,
            right: -3,
            child: PulsingDot(size: 11),
          )
        else if (friend!.lastActiveTime != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF09C167),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.black : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey.withOpacity(0.2),
      child: const Icon(Icons.person, color: Colors.grey, size: 24),
    );
  }

  String _truncateUsername(String username) {
    if (username.length <= 8) return username;
    return '${username.substring(0, 7)}…';
  }
}
