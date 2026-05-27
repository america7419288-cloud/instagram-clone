// lib/features/post/presentation/pages/edit_post_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:instagram_client/features/post/data/models/post_model.dart';
import 'package:instagram_client/features/post/presentation/providers/post_provider.dart';
import 'package:instagram_client/core/theme/ios_colors.dart';
import 'package:instagram_client/features/profile/widgets/profile_posts_grid.dart'; // contains EditAudienceSheet

class EditPostScreen extends ConsumerStatefulWidget {
  final PostModel post;

  const EditPostScreen({super.key, required this.post});

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen>
    with TickerProviderStateMixin {
  late TextEditingController _captionCtrl;
  late TextEditingController _locationCtrl;
  late AnimationController _entryCtrl;
  bool _isSaving = false;
  bool _hasChanges = false;
  final _scrollCtrl = ScrollController();
  final _captionFocus = FocusNode();

  // Local state
  late bool _hideLikesCount;
  late bool _commentsDisabled;
  late PostAudience _audience;

  @override
  void initState() {
    super.initState();
    _captionCtrl = TextEditingController(text: widget.post.caption);
    _locationCtrl = TextEditingController(
      text: widget.post.location ?? '',
    );
    _hideLikesCount = widget.post.hideLikesCount;
    _commentsDisabled = widget.post.commentsDisabled;
    _audience = widget.post.audience;

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _entryCtrl.forward();

    _captionCtrl.addListener(_checkChanges);
    _locationCtrl.addListener(_checkChanges);
  }

  void _checkChanges() {
    final changed =
      _captionCtrl.text != widget.post.caption ||
      _locationCtrl.text != (widget.post.location ?? '') ||
      _hideLikesCount != widget.post.hideLikesCount ||
      _commentsDisabled != widget.post.commentsDisabled ||
      _audience != widget.post.audience;

    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _locationCtrl.dispose();
    _captionFocus.dispose();
    _entryCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'If you leave, your edits won\'t be saved.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _save() async {
    if (!_hasChanges || _isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final provider = ref.read(postProvider.notifier);

    try {
      await provider.editPost(
        postId: widget.post.id,
        caption: _captionCtrl.text,
        location: _locationCtrl.text.isEmpty
          ? null
          : _locationCtrl.text,
      );

      if (_hideLikesCount != widget.post.hideLikesCount) {
        await provider.toggleHideLikes(widget.post.id);
      }
      if (_commentsDisabled != widget.post.commentsDisabled) {
        await provider.toggleComments(widget.post.id);
      }
      if (_audience != widget.post.audience) {
        await provider.updateAudience(widget.post.id, _audience);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: IosColors.background(context),
        appBar: _buildAppBar(isDark),
        body: FadeTransition(
          opacity: _entryCtrl,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              child: Column(
                children: [
                  _buildMediaPreview(isDark),
                  _buildCaptionField(isDark),
                  _buildDivider(isDark),
                  _buildLocationField(isDark),
                  _buildDivider(isDark),
                  _buildSectionHeader('Post Settings', isDark),
                  _buildLikesToggle(isDark),
                  _buildDivider(isDark),
                  _buildCommentsToggle(isDark),
                  _buildDivider(isDark),
                  _buildAudienceRow(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: IosColors.background(context),
      leading: CupertinoButton(
        padding: const EdgeInsets.only(left: 8),
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) Navigator.pop(context);
        },
        child: Text(
          'Cancel',
          style: TextStyle(
            color: IosColors.primary(context),
            fontSize: 17,
            decoration: TextDecoration.none,
          ),
        ),
      ),
      title: Text(
        'Edit info',
        style: TextStyle(
          color: IosColors.primary(context),
          fontSize: 17,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
        ),
      ),
      actions: [
        AnimatedOpacity(
          opacity: _hasChanges ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: CupertinoButton(
            padding: const EdgeInsets.only(right: 16),
            onPressed: _hasChanges ? _save : null,
            child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0095F6),
                  ),
                )
              : const Text(
                  'Done',
                  style: TextStyle(
                    color: IosColors.igBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaPreview(bool isDark) {
    final post = widget.post;
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
        itemCount: post.mediaUrls.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: post.mediaUrls[i],
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                ),
              ),
              if (post.type == PostType.video)
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      CupertinoIcons.play_fill,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black45,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionField(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _captionCtrl,
        focusNode: _captionFocus,
        maxLines: 4,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Write a caption...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black38,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildLocationField(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.location,
            color: isDark ? Colors.white60 : Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _locationCtrl,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Add location',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesToggle(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Hide like count',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
            ),
          ),
          CupertinoSwitch(
            value: _hideLikesCount,
            activeColor: const Color(0xFF0095F6),
            onChanged: (val) {
              setState(() {
                _hideLikesCount = val;
                _checkChanges();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsToggle(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Turn off commenting',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 15,
            ),
          ),
          CupertinoSwitch(
            value: _commentsDisabled,
            activeColor: const Color(0xFF0095F6),
            onChanged: (val) {
              setState(() {
                _commentsDisabled = val;
                _checkChanges();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceRow(bool isDark) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditAudienceSheet(
            currentAudience: _audience,
            onSelect: (audience) {
              setState(() {
                _audience = audience;
                _checkChanges();
              });
            },
          ),
        );
      },
      child: Container(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Audience',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 15,
              ),
            ),
            Row(
              children: [
                Text(
                  _audienceLabel(_audience),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _audienceLabel(PostAudience audience) {
    switch (audience) {
      case PostAudience.everyone: return 'Everyone';
      case PostAudience.followers: return 'Followers';
      case PostAudience.closeFriends: return 'Close Friends';
      case PostAudience.onlyMe: return 'Only Me';
    }
  }
}
