// lib/features/story/presentation/widgets/highlights_bar.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/story_advanced_model.dart';
import '../../data/repositories/story_service.dart';

// ─── Provider ─────────────────────────────────────────
final highlightsProvider = FutureProvider.family<List<HighlightModel>, String>(
  (ref, username) async {
    final service = ref.read(storyServiceProvider);
    return service.getUserHighlights(username);
  },
);

class HighlightsBar extends ConsumerWidget {
  final String   username;
  final bool     isMyProfile;
  final VoidCallback? onAddHighlight;

  const HighlightsBar({
    super.key,
    required this.username,
    this.isMyProfile    = false,
    this.onAddHighlight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(highlightsProvider(username));

    return highlightsAsync.when(
      loading: () => const _HighlightsBarSkeleton(),
      error:   (_, __) => const SizedBox.shrink(),
      data:    (highlights) {
        // ─── Empty + not my profile → hide bar ─────────
        if (highlights.isEmpty && !isMyProfile) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection:    Axis.horizontal,
            padding:            const EdgeInsets.symmetric(horizontal: 16),
            itemCount:          highlights.length + (isMyProfile ? 1 : 0),
            separatorBuilder:   (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              // ─── "New" button (my profile) ────────────
              if (isMyProfile && index == 0) {
                return _AddHighlightBubble(
                  onTap: onAddHighlight ?? () {},
                );
              }

              final highlight = highlights[isMyProfile ? index - 1 : index];

              return _HighlightBubble(
                highlight: highlight,
                onTap:     () => _viewHighlight(context, highlight),
                onLongPress: isMyProfile
                    ? () => _showHighlightOptions(
                          context,
                          ref,
                          highlight,
                        )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  void _viewHighlight(BuildContext context, HighlightModel highlight) {
    HapticFeedback.lightImpact();
    if (highlight.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:  Text('This highlight is empty'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context:          context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HighlightViewer(highlight: highlight),
    );
  }

  void _showHighlightOptions(
    BuildContext context,
    WidgetRef ref,
    HighlightModel highlight,
  ) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context:         context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color:        isDark
                    ? AppColors.darkDivider
                    : AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.error),
              title: const Text(
                'Delete highlight',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _deleteHighlight(context, ref, highlight);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteHighlight(
    BuildContext context,
    WidgetRef ref,
    HighlightModel highlight,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Delete highlight?'),
        content: Text(
          'Delete "${highlight.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(storyServiceProvider).deleteHighlight(highlight.id);
      ref.invalidate(highlightsProvider(username));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:  Text('Failed to delete: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────
// HIGHLIGHT BUBBLE
// ─────────────────────────────────────────────────────
class _HighlightBubble extends StatelessWidget {
  final HighlightModel highlight;
  final VoidCallback   onTap;
  final VoidCallback?  onLongPress;

  const _HighlightBubble({
    required this.highlight,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap:       onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Cover circle ─────────────────────────
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkDivider : AppColors.divider,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkDivider
                      : AppColors.divider,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: highlight.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl:    highlight.coverUrl!,
                      fit:         BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: isDark
                            ? AppColors.darkShimmerBase
                            : AppColors.shimmerBase,
                      ),
                      errorWidget: (_, __, ___) => _buildDefaultCover(isDark),
                    )
                  : _buildDefaultCover(isDark),
            ),
            const SizedBox(height: 6),

            // ─── Title ────────────────────────────────
            Text(
              highlight.title,
              style: TextStyle(
                fontSize:  12,
                color:     isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
              maxLines:  1,
              overflow:  TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCover(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkDivider : AppColors.divider,
      child: Icon(
        Icons.auto_stories,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.textSecondary,
        size:  28,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// ADD HIGHLIGHT BUBBLE ("+New")
// ─────────────────────────────────────────────────────
class _AddHighlightBubble extends StatefulWidget {
  final VoidCallback onTap;
  const _AddHighlightBubble({required this.onTap});

  @override
  State<_AddHighlightBubble> createState() => _AddHighlightBubbleState();
}

class _AddHighlightBubbleState extends State<_AddHighlightBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width:  64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurface : AppColors.white,
                  border: Border.all(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  size:  28,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'New',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// HIGHLIGHT VIEWER (simple media slideshow)
// ─────────────────────────────────────────────────────
class _HighlightViewer extends StatefulWidget {
  final HighlightModel highlight;
  const _HighlightViewer({required this.highlight});

  @override
  State<_HighlightViewer> createState() => _HighlightViewerState();
}

class _HighlightViewerState extends State<_HighlightViewer> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final items = widget.highlight.items;
    final item  = items[_index];

    return Container(
      height:          size.height * 0.88,
      color:           Colors.black,
      child: Stack(
        children: [
          // ─── Media ─────────────────────────────────
          Positioned.fill(
            child: item.displayUrl != null
                ? CachedNetworkImage(
                    imageUrl:    item.displayUrl!,
                    fit:         BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size:  48,
                      ),
                    ),
                  )
                : Container(color: Colors.black),
          ),

          // ─── Progress bars ─────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: List.generate(
                  items.length,
                  (i) => Expanded(
                    child: Container(
                      height: 2.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color:        i <= _index
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Header ───────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    widget.highlight.title,
                    style: const TextStyle(
                      color:      Colors.white,
                      fontSize:   16,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(blurRadius: 4, color: Colors.black54),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon:      const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // ─── Prev/Next tap areas ───────────────────
          Row(
            children: [
              // Prev
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_index > 0) {
                      setState(() => _index--);
                    }
                  },
                ),
              ),
              // Next
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_index < items.length - 1) {
                      setState(() => _index++);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// SKELETON
// ─────────────────────────────────────────────────────
class _HighlightsBarSkeleton extends StatelessWidget {
  const _HighlightsBarSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base   = isDark ? AppColors.darkShimmerBase : AppColors.shimmerBase;

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection:  Axis.horizontal,
        padding:          const EdgeInsets.symmetric(horizontal: 16),
        itemCount:        4,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  64,
              height: 64,
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width:  48,
              height: 10,
              decoration: BoxDecoration(
                color:        base,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
