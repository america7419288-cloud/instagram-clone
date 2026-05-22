// lib/features/inbox/widgets/active_friend_item.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/active_friend_model.dart';
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

class ActiveFriendItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final labelColor = isDark ? const Color(0xFFA8A8A8) : const Color(0xFF737373);

    final isYourNote = friend == null;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Apply staggered slide-in and opacity
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
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // AVATAR AREA WITH OPTIONAL NOTE BUBBLE
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Note creator vs active friend avatar
                  if (isYourNote)
                    _buildYourNoteAvatar(isDark, labelColor)
                  else
                    _buildFriendAvatar(isDark),

                  // NOTE BUBBLE (above avatar)
                  if (!isYourNote && friend!.hasActiveNote && friend!.noteText != null)
                    Positioned(
                      top: -24,
                      child: _buildNoteBubble(friend!.noteText!, isDark),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // USERNAME / LABEL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  isYourNote ? 'Note' : _truncateUsername(friend!.username),
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

  Widget _buildYourNoteAvatar(bool isDark, Color labelColor) {
    final dashedColor = isDark ? const Color(0xFF363636) : const Color(0xFFDBDBDB);
    final avatarUrl = currentUserAvatar ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Dashed border around avatar
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: CustomPaint(
            painter: DashedCirclePainter(color: dashedColor, strokeWidth: 1.5),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
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

        // Blue [+] badge at bottom-right
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
              placeholder: (c, u) => Container(color: Colors.grey.withValues(alpha: 0.2)),
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

  Widget _buildNoteBubble(String text, bool isDark) {
    final bubbleColor = isDark ? const Color(0xFF262626) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.1);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Main rectangle container
        Container(
          constraints: const BoxConstraints(maxWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 9,
              color: textColor,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),

        // Small triangle pointer at bottom
        Positioned(
          bottom: -4,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8,
              height: 8,
              color: bubbleColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey.withValues(alpha: 0.2),
      child: const Icon(Icons.person, color: Colors.grey, size: 24),
    );
  }

  String _truncateUsername(String username) {
    if (username.length <= 7) return username;
    return '${username.substring(0, 6)}…';
  }
}
