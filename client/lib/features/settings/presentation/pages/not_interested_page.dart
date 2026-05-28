// lib/features/settings/presentation/pages/not_interested_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../post/presentation/providers/feed_provider.dart';
import '../providers/not_interested_provider.dart';

class NotInterestedPage extends ConsumerWidget {
  const NotInterestedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notInterestedProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.8),
        middle: const Text(
          'Not interested',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17, fontFamily: 'SF-Pro'),
        ),
      ),
      child: SafeArea(
        child: state.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.eye_off,
                        size: 40,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No items here',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'When you mark posts or reels as "Not interested", they will appear here, and we will show you fewer posts like them.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.items.length,
                itemBuilder: (context, index) {
                  final post = state.items[index];
                  final postId = post['id'] ?? '';
                  final username = post['username'] ?? 'username';
                  final caption = post['caption'] ?? '';
                  final thumbnailUrl = post['thumbnailUrl'] ?? post['thumbnail_url'] ?? '';
                  final isVideo = post['mediaType'] == 'video' || post['media_type'] == 'video';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (thumbnailUrl.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: thumbnailUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: isDark ? Colors.white10 : Colors.black12,
                                    ),
                                  )
                                else
                                  Container(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                    child: const Icon(LucideIcons.image, color: Colors.grey),
                                  ),
                                if (isVideo)
                                  const Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      LucideIcons.play,
                                      color: Colors.white,
                                      size: 14,
                                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Username + Caption
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Undo button
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          color: const Color(0xFF0095F6),
                          borderRadius: BorderRadius.circular(20),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            // Call API to undo interaction
                            try {
                              await ref.read(postServiceProvider).recordInteraction(
                                    contentId: postId,
                                    contentType: isVideo ? 'reel' : 'post',
                                    action: 'interested',
                                    authorId: post['userId'] ?? post['user_id'],
                                  );
                            } catch (e) {
                              // Silent fallback
                            }

                            // Remove from local not interested settings
                            await ref.read(notInterestedProvider.notifier).removePost(postId);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Marked as interested. Post restored.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Undo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
