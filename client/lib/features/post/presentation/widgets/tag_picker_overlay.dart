// lib/features/post/presentation/widgets/tag_picker_overlay.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/design_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/post_tag_model.dart';
import '../../../search/data/repositories/search_service.dart';
import '../../../search/presentation/pages/providers/search_provider.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/verified_badge.dart';

// ─── Tag picker (shown in PostEditorPage) ─────────────
class TagPickerOverlay extends ConsumerStatefulWidget {
  final double          imageWidth;
  final double          imageHeight;
  final int             mediaIndex;
  final List<PostTagModel> existingTags;
  final void Function(PostTagModel tag) onTagAdded;
  final void Function(String userId) onTagRemoved;
  final VoidCallback    onDone;

  const TagPickerOverlay({
    super.key,
    required this.imageWidth,
    required this.imageHeight,
    required this.mediaIndex,
    required this.existingTags,
    required this.onTagAdded,
    required this.onTagRemoved,
    required this.onDone,
  });

  @override
  ConsumerState<TagPickerOverlay> createState() =>
      _TagPickerOverlayState();
}

class _TagPickerOverlayState extends ConsumerState<TagPickerOverlay> {
  // ─── Pending tap position ─────────────────────────────
  Offset? _pendingTap;

  // ─── Search ───────────────────────────────────────────
  bool                 _showSearch  = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserModel>      _searchResults = [];
  bool                 _isSearching   = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Tags for current media index ────────────────────
  List<PostTagModel> get _currentTags => widget.existingTags
      .where((t) => t.mediaIndex == widget.mediaIndex)
      .toList();

  // ─── Handle tap on image ──────────────────────────────
  void _handleTap(TapDownDetails details) {
    if (_currentTags.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:  Text('Maximum 10 tags per photo'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _pendingTap = details.localPosition;
      _showSearch = true;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  // ─── Search users ─────────────────────────────────────
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final service = ref.read(searchServiceProvider);
      final result  = await service.searchUsers(query: query);
      
      // Extract users list from the map response
      final List<dynamic> usersList = result['users'] ?? [];
      final results = usersList
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching   = false;
        });
      }
    } catch (e) {
      debugPrint('Tag search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ─── Confirm tag user ─────────────────────────────────
  void _tagUser(UserModel user) {
    if (_pendingTap == null) return;

    // Normalize position
    final xPos = (_pendingTap!.dx / widget.imageWidth).clamp(0.0, 1.0);
    final yPos = (_pendingTap!.dy / widget.imageHeight).clamp(0.0, 1.0);

    final tag = PostTagModel(
      id:         '',
      postId:     '',
      userId:     user.id,
      username:   user.username,
      fullName:   user.fullName,
      avatar:     user.profilePicture,
      isVerified: user.isVerified,
      xPosition:  xPos,
      yPosition:  yPos,
      mediaIndex: widget.mediaIndex,
    );

    HapticFeedback.mediumImpact();
    widget.onTagAdded(tag);

    setState(() {
      _pendingTap  = null;
      _showSearch  = false;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  // ─── Cancel search ────────────────────────────────────
  void _cancelSearch() {
    setState(() {
      _pendingTap  = null;
      _showSearch  = false;
      _searchResults = [];
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // ─── Tap detector ──────────────────────────────
        if (!_showSearch)
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _handleTap,
              behavior:  HitTestBehavior.opaque,
              child:     Container(color: Colors.transparent),
            ),
          ),

        // ─── Existing tag bubbles ──────────────────────
        ..._currentTags.map(
          (tag) => _TagBubble(
            tag:       tag,
            imgWidth:  widget.imageWidth,
            imgHeight: widget.imageHeight,
            onRemove:  () {
              HapticFeedback.lightImpact();
              widget.onTagRemoved(tag.userId);
            },
          ),
        ),

        // ─── Pending tap indicator ─────────────────────
        if (_pendingTap != null)
          Positioned(
            left: _pendingTap!.dx - 6,
            top:  _pendingTap!.dy - 6,
            child: Container(
              width:       12,
              height:      12,
              decoration:  const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
            ),
          ),

        // ─── Search panel ─────────────────────────────
        if (_showSearch)
          _buildSearchPanel(isDark),

        // ─── Top bar ──────────────────────────────────
        if (!_showSearch)
          Positioned(
            top:   0,
            left:  0,
            right: 0,
            child: _buildTopBar(isDark),
          ),
      ],
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical:   Spacing.md,
      ),
      child: Row(
        children: [
          const Text(
            'Tap photo to tag',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   14,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(blurRadius: 4, color: Colors.black54),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onDone,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical:   Spacing.xs,
              ),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(Radii.full),
                border: Border.all(color: Colors.white54, width: 0.5),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(bool isDark) {
    final bg   = isDark ? IgColors.darkSurface : IgColors.bg;
    final text = IgColors.text_(isDark);
    final sub  = IgColors.textSub_(isDark);
    final inp  = IgColors.inputBg_(isDark);

    return Positioned(
      bottom: 0,
      left:   0,
      right:  0,
      child:  Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.lg),
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.15),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Handle ─────────────────────────────────
            Container(
              width:  36,
              height: 4,
              margin: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.md),
              decoration: BoxDecoration(
                color:        IgColors.divider_(isDark),
                borderRadius: BorderRadius.circular(Radii.full),
              ),
            ),

            // ─── Search bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg, 0, Spacing.lg, Spacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color:        inp,
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical:   Spacing.xs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: sub,
                            size:  18,
                          ),
                          const SizedBox(width: Spacing.xs),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus:  true,
                              style:      IgText.body.copyWith(color: text),
                              decoration: InputDecoration(
                                hintText:  'Search people',
                                hintStyle: IgText.body.copyWith(color: sub),
                                border:    InputBorder.none,
                                filled:    false,
                                isDense:   true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: _searchUsers,
                            ),
                          ),
                          if (_isSearching)
                            SizedBox(
                              width:  14,
                              height: 14,
                              child:  CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color:       sub,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                  GestureDetector(
                    onTap: _cancelSearch,
                    child: Text(
                      'Cancel',
                      style: IgText.label.copyWith(color: sub),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 0.5, color: IgColors.divider_(isDark)),

            // ─── Results ────────────────────────────────
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount:  _searchResults.length,
                itemBuilder: (_, i) {
                  final user = _searchResults[i];
                  return ListTile(
                    onTap: () => _tagUser(user),
                    leading: CircleAvatar(
                      radius:          20,
                      backgroundColor: IgColors.divider_(isDark),
                      backgroundImage: user.profilePicture != null
                          ? NetworkImage(user.profilePicture!)
                          : null,
                      child: user.profilePicture == null
                          ? Text(
                              user.username[0].toUpperCase(),
                              style: IgText.label.copyWith(color: text),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.username,
                            style: IgText.username.copyWith(color: text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isVerified) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14),
                        ],
                      ],
                    ),
                    subtitle: user.fullName != null
                        ? Text(
                            user.fullName!,
                            style: IgText.bodySm.copyWith(color: sub),
                          )
                        : null,
                  );
                },
              ),
            ),

            // ─── Empty state ─────────────────────────────
            if (_searchResults.isEmpty &&
                _searchCtrl.text.isNotEmpty &&
                !_isSearching)
              Padding(
                padding: const EdgeInsets.all(Spacing.x3l),
                child: Text(
                  'No users found',
                  style: IgText.body.copyWith(color: sub),
                ),
              ),

            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// TAG BUBBLE (positioned on image)
// ─────────────────────────────────────────────────────
class _TagBubble extends StatefulWidget {
  final PostTagModel tag;
  final double       imgWidth;
  final double       imgHeight;
  final VoidCallback onRemove;

  const _TagBubble({
    required this.tag,
    required this.imgWidth,
    required this.imgHeight,
    required this.onRemove,
  });

  @override
  State<_TagBubble> createState() => _TagBubbleState();
}

class _TagBubbleState extends State<_TagBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve:  Curves.easeOutBack,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.tag.xPosition * widget.imgWidth;
    final top  = widget.tag.yPosition * widget.imgHeight;

    return Positioned(
      left: (left - 60).clamp(0, widget.imgWidth - 120), // center the bubble
      top:  (top - 36).clamp(0, widget.imgHeight - 60),
      child: ScaleTransition(
        scale: _scale,
        child: GestureDetector(
          onLongPress: widget.onRemove,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ─── Username chip ─────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical:   Spacing.xs,
                ),
                decoration: BoxDecoration(
                  color:        Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(Radii.full),
                ),
                constraints: const BoxConstraints(maxWidth: 120),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.tag.avatar != null)
                      Padding(
                        padding: const EdgeInsets.only(right: Spacing.xs),
                        child:   CircleAvatar(
                          radius:      8,
                          backgroundImage:
                              NetworkImage(widget.tag.avatar!),
                        ),
                      ),
                    Flexible(
                      child: Text(
                        widget.tag.username,
                        style: IgText.labelSm.copyWith(color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.tag.isVerified) ...[
                      const SizedBox(width: 2),
                      const VerifiedBadge(size: 10),
                    ],
                  ],
                ),
              ),
              // ─── Triangle pointer ─────────────────────
              CustomPaint(
                size:    const Size(10, 6),
                painter: _TrianglePainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Triangle painter ─────────────────────────────────
class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
