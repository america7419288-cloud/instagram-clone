// lib/features/post/presentation/pages/post_likes_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/comment_service.dart';

class PostLikesPage extends ConsumerStatefulWidget {
  final String postId;

  const PostLikesPage({
    super.key,
    required this.postId,
  });

  @override
  ConsumerState<PostLikesPage> createState() => _PostLikesPageState();
}

class _PostLikesPageState extends ConsumerState<PostLikesPage> {
  final CommentService _commentService = CommentService();
  List<Map<String, dynamic>> _likers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  Future<void> _loadLikers() async {
    try {
      final likers = await _commentService.getPostLikers(
        postId: widget.postId,
      );
      if (mounted) {
        setState(() {
          _likers = likers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Likes',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : _error != null
              ? Center(child: Text(_error!))
              : _likers.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 60,
                            color: AppColors.border,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No likes yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Be the first to like this post!',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _likers.length,
                      itemBuilder: (context, index) {
                        final user = _likers[index];
                        return _LikerTile(user: user);
                      },
                    ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  final Map<String, dynamic> user;

  const _LikerTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/profile/${user['username']}'),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.border,
        ),
        child: ClipOval(
          child: user['profile_pic_url'] != null
              ? CachedNetworkImage(
                  imageUrl: user['profile_pic_url'],
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.person,
                    color: AppColors.textSecondary,
                  ),
                )
              : const Icon(
                  Icons.person,
                  color: AppColors.textSecondary,
                ),
        ),
      ),
      title: Row(
        children: [
          Text(
            user['username'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (user['is_verified'] == true) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.verified,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ],
      ),
      subtitle: Text(
        user['full_name'] ?? '',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: user['is_following'] == true
          ? OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Following',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Follow',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}