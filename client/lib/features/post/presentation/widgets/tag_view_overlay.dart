// lib/features/post/presentation/widgets/tag_view_overlay.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/post_tag_service.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_tag_model.dart';

// ─────────────────────────────────────────────────────
// TAG VIEW OVERLAY
// Shown when user taps on a post image
// ─────────────────────────────────────────────────────
class TagViewOverlay extends ConsumerStatefulWidget {
  final List<PostTagModel> tags;
  final double             imgWidth;
  final double             imgHeight;
  final int                mediaIndex;
  final VoidCallback?      onRefresh;

  const TagViewOverlay({
    super.key,
    required this.tags,
    required this.imgWidth,
    required this.imgHeight,
    required this.mediaIndex,
    this.onRefresh,
  });

  @override
  ConsumerState<TagViewOverlay> createState() => _TagViewOverlayState();
}

class _TagViewOverlayState extends ConsumerState<TagViewOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;

  // ─── Visible duration ─────────────────────────────────
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _ctrl.reverse().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<PostTagModel> get _currentTags => widget.tags
      .where((t) => t.mediaIndex == widget.mediaIndex)
      .toList();

  @override
  Widget build(BuildContext context) {
    if (!_visible || _currentTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fade,
      child:   Stack(
        children: _currentTags
            .map((tag) => _TagViewBubble(
                  tag:       tag,
                  imgWidth:  widget.imgWidth,
                  imgHeight: widget.imgHeight,
                  onRefresh: widget.onRefresh,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// TAG VIEW BUBBLE (tappable → navigate to profile)
// ─────────────────────────────────────────────────────
class _TagViewBubble extends ConsumerWidget {
  final PostTagModel tag;
  final double       imgWidth;
  final double       imgHeight;
  final VoidCallback? onRefresh;

  const _TagViewBubble({
    required this.tag,
    required this.imgWidth,
    required this.imgHeight,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isMe         = tag.userId == currentUserId;
    final isPending    = !tag.isAccepted;

    // If it's pending and NOT me, don't show it (handled by backend but safe to double check)
    // Actually, if it's pending and I'm the owner, I should see it too.
    // The backend already filtered them.
    final left = tag.xPosition * imgWidth;
    final top  = tag.yPosition * imgHeight;

    return Positioned(
      left: (left - 60).clamp(0, imgWidth - 120),
      top:  (top  - 40).clamp(0, imgHeight - 60),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/profile/${tag.username}');
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Chip ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical:   Spacing.xs,
              ),
              decoration: BoxDecoration(
                color:        Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(Radii.full),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              constraints: const BoxConstraints(maxWidth: 140),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini avatar
                  if (tag.avatar != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Spacing.xs),
                      child:   CircleAvatar(
                        radius:          9,
                        backgroundImage: NetworkImage(tag.avatar!),
                      ),
                    )
                  else
                    Container(
                      width:  18,
                      height: 18,
                      margin: const EdgeInsets.only(right: Spacing.xs),
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          tag.username[0].toUpperCase(),
                          style: const TextStyle(
                            color:    Colors.white,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),

                  // Username
                  Flexible(
                    child: Text(
                      tag.username,
                      style: IgText.labelSm.copyWith(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),

                  // Verified
                  if (tag.isVerified) ...[
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.verified,
                      size:  10,
                      color: Colors.white70,
                    ),
                  ],

                  // Pending Label or Accept Button
                  if (isPending) ...[
                    const SizedBox(width: Spacing.sm),
                    if (isMe)
                      GestureDetector(
                        onTap: () async {
                          try {
                            HapticFeedback.mediumImpact();
                            await ref.read(postTagServiceProvider).acceptTag(tag.postId);
                            if (onRefresh != null) onRefresh!();
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Tag accepted!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Spacing.xs,
                            vertical:   1,
                          ),
                          decoration: BoxDecoration(
                            color:        IgColors.primary,
                            borderRadius: BorderRadius.circular(Radii.xs),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '(Pending)',
                        style: IgText.labelSm.copyWith(
                          color:    Colors.white54,
                          fontSize: 8,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            // Triangle
            CustomPaint(
              size:    const Size(8, 5),
              painter: _TrianglePainter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()
        ..color = Colors.black.withOpacity(0.72)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────
// TAGGED USERS ROW (shown below post actions)
// e.g. "With: john, sarah, mike"
// ─────────────────────────────────────────────────────
class TaggedUsersRow extends StatelessWidget {
  final List<PostTagModel> tags;
  final bool               isDark;

  const TaggedUsersRow({
    super.key,
    required this.tags,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Only show accepted tags in the summary row
    final acceptedTags = tags.where((t) => t.isAccepted).toList();
    if (acceptedTags.isEmpty) return const SizedBox.shrink();

    // Deduplicate by userId
    final unique = <String, PostTagModel>{};
    for (final t in acceptedTags) {
      unique[t.userId] = t;
    }
    final list = unique.values.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg, 0, Spacing.lg, Spacing.xs,
      ),
      child: GestureDetector(
        onTap: () => _showTaggedList(context, list),
        child: Row(
          children: [
            // Mini avatar stack
            SizedBox(
              width: list.length > 1
                  ? 16.0 + (list.length - 1).clamp(0, 3) * 12.0
                  : 16,
              height: 16,
              child:  Stack(
                children: list
                    .take(4)
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (e) => Positioned(
                        left: e.key * 10.0,
                        child: CircleAvatar(
                          radius:          8,
                          backgroundColor: IgColors.divider_(isDark),
                          backgroundImage: e.value.avatar != null
                              ? NetworkImage(e.value.avatar!)
                              : null,
                          child: e.value.avatar == null
                              ? Text(
                                  e.value.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color:    Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            // Names
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: IgText.bodySm.copyWith(
                    color: IgColors.text_(isDark),
                  ),
                  children: [
                    const TextSpan(text: 'With '),
                    ...list.take(2).map(
                      (t) => TextSpan(
                        text: t == list.take(2).last &&
                                list.length <= 2
                            ? t.username
                            : '${t.username}, ',
                        style: IgText.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color:      IgColors.text_(isDark),
                        ),
                      ),
                    ),
                    if (list.length > 2)
                      TextSpan(
                        text: 'and ${list.length - 2} other${list.length - 2 > 1 ? "s" : ""}',
                        style: IgText.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                          color:      IgColors.text_(isDark),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaggedList(BuildContext context, List<PostTagModel> tags) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context:         context,
      backgroundColor: IgColors.surface_(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Radii.lg),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  36,
              height: 4,
              margin: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.md),
              decoration: BoxDecoration(
                color:        IgColors.divider_(isDark),
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child:   Text(
                'People in this photo',
                style: IgText.h3.copyWith(color: IgColors.text_(isDark)),
              ),
            ),
            Divider(height: 0.5, color: IgColors.divider_(isDark)),
            ...tags.map(
              (tag) => ListTile(
                onTap: () {
                  Navigator.pop(context);
                  context.push('/profile/${tag.username}');
                },
                leading: CircleAvatar(
                  radius:          22,
                  backgroundColor: IgColors.divider_(isDark),
                  backgroundImage: tag.avatar != null
                      ? NetworkImage(tag.avatar!)
                      : null,
                  child: tag.avatar == null
                      ? Text(
                          tag.username[0].toUpperCase(),
                          style: IgText.label.copyWith(
                            color: IgColors.text_(isDark),
                          ),
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Text(
                      tag.username,
                      style: IgText.username.copyWith(
                        color: IgColors.text_(isDark),
                      ),
                    ),
                    if (tag.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 14, color: IgColors.verified),
                    ],
                  ],
                ),
                subtitle: tag.fullName != null
                    ? Text(
                        tag.fullName!,
                        style: IgText.bodySm.copyWith(
                          color: IgColors.textSub_(isDark),
                        ),
                      )
                    : null,
                trailing: Icon(
                  Icons.chevron_right,
                  color: IgColors.textSub_(isDark),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
  }
}
