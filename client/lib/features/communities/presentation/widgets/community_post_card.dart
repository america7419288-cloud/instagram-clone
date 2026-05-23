import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:instagram_client/features/communities/presentation/widgets/poll_widget.dart';
import 'package:instagram_client/features/communities/presentation/widgets/event_widget.dart';
import '../../data/models/community_post.dart';

class CommunityPostCard extends StatefulWidget {
  final CommunityPost post;
  final String currentUserId;
  final bool isAdminOrMod;
  final VoidCallback onLike;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final ValueChanged<int> onVote;
  final VoidCallback onRSVP;

  const CommunityPostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.isAdminOrMod,
    required this.onLike,
    required this.onPin,
    required this.onDelete,
    required this.onVote,
    required this.onRSVP,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  int _currentMediaIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authorName = widget.post.author?.username ?? 'Anonymous';
    final authorAvatar = widget.post.author?.profilePicUrl;
    final isLiked = widget.post.likes.contains(widget.currentUserId);
    final isPinned = widget.post.isPinned;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: authorAvatar != null && authorAvatar.isNotEmpty
                      ? NetworkImage(authorAvatar)
                      : null,
                  backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.1),
                  child: authorAvatar == null || authorAvatar.isEmpty
                      ? Icon(LucideIcons.user, color: isDark ? Colors.white54 : Colors.black54, size: 18)
                      : null,
                ),
                const SizedBox(width: 10),
                // Username + Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.post.authorId == widget.post.authorId) ...[
                            const SizedBox(width: 4),
                            // Owner badge
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFFF58529),
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(widget.post.createdAt),
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pinned Indicator
                if (isPinned)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1306C).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.pin, color: Color(0xFFE1306C), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'PINNED',
                          style: TextStyle(
                            color: Color(0xFFE1306C),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Actions Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    LucideIcons.ellipsis_vertical,
                    color: isDark ? Colors.white54 : Colors.black54,
                    size: 18,
                  ),
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'pin') {
                      widget.onPin();
                    } else if (val == 'delete') {
                      widget.onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (widget.isAdminOrMod)
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(LucideIcons.pin, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                            const SizedBox(width: 10),
                            Text(isPinned ? 'Unpin Post' : 'Pin Post'),
                          ],
                        ),
                      ),
                    if (widget.isAdminOrMod || widget.post.authorId == widget.currentUserId)
                      PopupMenuItem(
                        value: 'delete',
                        child: const Row(
                          children: [
                            Icon(LucideIcons.trash_2, size: 16, color: Color(0xFFFD1D1D)),
                            const SizedBox(width: 10),
                            Text('Delete', style: TextStyle(color: Color(0xFFFD1D1D))),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Content Text
          if (widget.post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                widget.post.content,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Media Slider
          if (widget.post.mediaUrls.isNotEmpty) ...[
            Container(
              height: 280,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: PageView.builder(
                itemCount: widget.post.mediaUrls.length,
                onPageChanged: (idx) {
                  setState(() => _currentMediaIndex = idx);
                },
                itemBuilder: (context, idx) {
                  final media = widget.post.mediaUrls[idx];
                  final url = media['url'] as String? ?? '';
                  final isVideo = media['type'] == 'video';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: isVideo
                          ? null
                          : DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: isVideo
                        ? Center(
                            child: Icon(
                              LucideIcons.play,
                              color: Colors.white,
                              size: 50,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            // Page Indicators
            if (widget.post.mediaUrls.length > 1)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.post.mediaUrls.length,
                      (idx) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentMediaIndex == idx
                              ? const Color(0xFFFD1D1D)
                              : (isDark ? Colors.white30 : Colors.black12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],

          // Poll Widget
          if (widget.post.type == 'poll' && widget.post.poll != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: PollWidget(
                poll: widget.post.poll!,
                currentUserId: widget.currentUserId,
                onVote: widget.onVote,
              ),
            ),

          // Event Widget
          if (widget.post.type == 'event' && widget.post.event != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: EventWidget(
                event: widget.post.event!,
                currentUserId: widget.currentUserId,
                onRSVP: widget.onRSVP,
              ),
            ),

          const SizedBox(height: 12),
          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                // Like Button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onLike();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? const Color(0xFFFD1D1D).withOpacity(0.1)
                          : isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? LucideIcons.heart : LucideIcons.heart,
                          color: isLiked ? const Color(0xFFFD1D1D) : (isDark ? Colors.white70 : Colors.black87),
                          size: 16,
                          fill: isLiked ? 1.0 : 0.0,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.post.likeCount}',
                          style: TextStyle(
                            color: isLiked ? const Color(0xFFFD1D1D) : (isDark ? Colors.white70 : Colors.black87),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Comment Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.message_circle,
                        color: isDark ? Colors.white70 : Colors.black87,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.post.commentCount}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
