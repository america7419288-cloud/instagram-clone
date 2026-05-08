// lib/features/post/presentation/pages/finalize_post_page.dart

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../data/models/music_track.dart';
import '../../data/models/post_tag_model.dart';
import '../../data/models/location_model.dart';
import '../../data/repositories/post_tag_service.dart';
import '../providers/create_post_provider.dart';
import 'music_selection_page.dart';
import 'tag_people_page.dart';
import 'location_search_page.dart';

class FinalizePostPage extends ConsumerStatefulWidget {
  final List<File> images;
  final List<List<double>> filterMatrices;
  final List<Matrix4> transformations;

  const FinalizePostPage({
    super.key,
    required this.images,
    this.filterMatrices = const [],
    this.transformations = const [],
  });

  @override
  ConsumerState<FinalizePostPage> createState() => _FinalizePostPageState();
}

class _FinalizePostPageState extends ConsumerState<FinalizePostPage> {
  final _captionCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _shareToFacebook = false;
  List<PostTagModel> _tags = [];
  LocationModel? _location;

  final _suggestedLocations = [
    LocationModel(id: '1', name: 'Milan', address: 'Italy'),
    LocationModel(id: '2', name: 'Duomo di Milano', address: 'Milan, Italy'),
    LocationModel(id: '3', name: 'Piazza Cordusio', address: 'Milan, Italy'),
  ];

  @override
  void dispose() {
    _captionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      AppSnackbar.info(context, 'Starting upload…');
      final notifier = ref.read(createPostProvider.notifier);
      notifier.setCaption(_captionCtrl.text);
      final success = await notifier.uploadPost(
        files: widget.images.map((e) => XFile(e.path)).toList(),
        filterMatrices: widget.filterMatrices,
        transformations: widget.transformations,
      );
      if (success && mounted) {
        if (_tags.isNotEmpty) {
          final postId = ref.read(createPostProvider).lastPostId;
          if (postId != null) {
            await ref.read(postTagServiceProvider).addTags(
                postId: postId, tags: _tags);
          }
        }
        context.go(AppRoutes.home);
      } else if (!success && mounted) {
        AppSnackbar.error(context,
            ref.read(createPostProvider).errorMessage ?? 'Failed to share');
      }
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Unexpected error: $e');
    }
  }

  Future<void> _tagPeople() async {
    final result = await Navigator.push<List<PostTagModel>>(
      context,
      CupertinoPageRoute(
          builder: (_) =>
              TagPeoplePage(images: widget.images, initialTags: _tags)),
    );
    if (result != null) setState(() => _tags = result);
  }

  Future<void> _addLocation() async {
    final result = await Navigator.push<LocationModel>(
      context,
      CupertinoPageRoute(builder: (_) => const LocationSearchPage()),
    );
    if (result != null) setState(() => _location = result);
  }

  Future<void> _pickMusic() async {
    final result = await Navigator.push<MusicTrack>(
      context,
      CupertinoPageRoute(builder: (_) => const MusicSelectionPage()),
    );
    if (result != null) {
      ref.read(createPostProvider.notifier).setSelectedMusic(result);
    }
  }

  // ── BUILD ──────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostProvider);
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBot = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ── Nav bar ───────────────────────────────────
            Container(
              height: safeTop + 44,
              padding: EdgeInsets.only(top: safeTop, left: 4, right: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: Color(0xFFDBDBDB), width: 0.33)),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(LucideIcons.chevron_left,
                        color: Color(0xFF262626), size: 28),
                  ),
                  const Spacer(),
                  const Text('New post',
                      style: TextStyle(
                          color: Color(0xFF262626),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF-Pro')),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    onPressed: state.isUploading ? null : _handleShare,
                    child: state.isUploading
                        ? const CupertinoActivityIndicator(
                            color: Color(0xFF0095F6))
                        : const Text('Share',
                            style: TextStyle(
                                color: Color(0xFF0095F6),
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'SF-Pro')),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildCaptionSection(state),
                    _divider(),
                    _buildDetailsSection(state),
                    _divider(),
                    _buildCrossPostSection(),
                    _divider(),
                    _buildDetailRow(
                      icon: LucideIcons.settings,
                      label: 'Advanced settings',
                      onTap: _showAdvanced,
                    ),
                    SizedBox(height: safeBot + 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Caption ────────────────────────────────────────────
  Widget _buildCaptionSection(CreatePostState state) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(widget.images.first,
                    width: 68, height: 68, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              // Caption input
              Expanded(
                child: CupertinoTextField(
                  controller: _captionCtrl,
                  placeholder: 'Write a caption or add a poll…',
                  placeholderStyle: const TextStyle(
                      color: Color(0xFF8E8E8E),
                      fontSize: 15,
                      fontFamily: 'SF-Pro'),
                  style: const TextStyle(
                      color: Color(0xFF262626),
                      fontSize: 15,
                      fontFamily: 'SF-Pro'),
                  maxLines: null,
                  minLines: 4,
                  decoration: null,
                  padding: EdgeInsets.zero,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        // Char count
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_captionCtrl.text.length}/2,200',
              style: const TextStyle(
                  color: Color(0xFF8E8E8E),
                  fontSize: 12,
                  fontFamily: 'SF-Pro'),
            ),
          ),
        ),
        // Emoji / Mention / Hashtag quick bar
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border.symmetric(
                horizontal: BorderSide(
                    color: Color(0xFFDBDBDB), width: 0.33)),
          ),
          child: Row(
            children: [
              _quickBtn(LucideIcons.smile, 'Emoji', () {}),
              const SizedBox(width: 20),
              _quickBtn(LucideIcons.at_sign, 'Mention', () {}),
              const SizedBox(width: 20),
              _quickBtn(LucideIcons.hash, 'Hashtag', () {}),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0095F6), size: 18),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF0095F6),
                  fontSize: 13,
                  fontFamily: 'SF-Pro')),
        ],
      ),
    );
  }

  // ── Details section ────────────────────────────────────
  Widget _buildDetailsSection(CreatePostState state) {
    return Column(
      children: [
        _buildDetailRow(
          icon: LucideIcons.tag,
          label: _tags.isEmpty ? 'Tag people' : '${_tags.length} tagged',
          onTap: _tagPeople,
        ),
        _indentDivider(),
        _buildDetailRow(
          icon: LucideIcons.music,
          label: state.selectedMusic?.title ?? 'Add music',
          onTap: _pickMusic,
        ),
        _indentDivider(),
        _buildDetailRow(
          icon: LucideIcons.map_pin,
          label: _location?.name ?? 'Add location',
          onTap: _addLocation,
          trailing: _location != null
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _location = null),
                  child: const Icon(CupertinoIcons.xmark_circle_fill,
                      color: Color(0xFFC7C7CC), size: 20))
              : null,
        ),
        // Location suggestion chips
        if (_location == null)
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _suggestedLocations.length,
              itemBuilder: (_, i) {
                final loc = _suggestedLocations[i];
                return GestureDetector(
                  onTap: () => setState(() => _location = loc),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(loc.name,
                        style: const TextStyle(
                            color: Color(0xFF262626),
                            fontSize: 13,
                            fontFamily: 'SF-Pro')),
                  ),
                );
              },
            ),
          ),
        _indentDivider(),
        _buildDetailRow(
          icon: LucideIcons.globe,
          label: 'Audience',
          value: 'Public',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? value,
    Widget? trailing,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF262626), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Color(0xFF262626),
                      fontSize: 15,
                      fontFamily: 'SF-Pro')),
            ),
            if (value != null)
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF8E8E8E),
                      fontSize: 15,
                      fontFamily: 'SF-Pro')),
            const SizedBox(width: 6),
            trailing ??
                const Icon(LucideIcons.chevron_right,
                    color: Color(0xFFC7C7CC), size: 18),
          ],
        ),
      ),
    );
  }

  // ── Cross-post section ─────────────────────────────────
  Widget _buildCrossPostSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('ALSO SHARE TO',
              style: TextStyle(
                  color: Color(0xFF8E8E8E),
                  fontSize: 12,
                  letterSpacing: 0.5,
                  fontFamily: 'SF-Pro')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                    color: Color(0xFF1877F2), shape: BoxShape.circle),
                child: Icon(PhosphorIcons.facebookLogo(PhosphorIconsStyle.fill),
                    color: Colors.white, size: 15),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Facebook',
                    style: TextStyle(
                        color: Color(0xFF262626),
                        fontSize: 15,
                        fontFamily: 'SF-Pro')),
              ),
              CupertinoSwitch(
                value: _shareToFacebook,
                activeColor: const Color(0xFF0095F6),
                onChanged: (v) => setState(() => _shareToFacebook = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Advanced settings ──────────────────────────────────
  void _showAdvanced() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Advanced Settings'),
        actions: [
          CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hide like and view counts')),
          CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Turn off commenting')),
          CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Pin to profile')),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _divider() =>
      Container(height: 0.33, color: const Color(0xFFDBDBDB));

  Widget _indentDivider() => Container(
      height: 0.33,
      margin: const EdgeInsets.only(left: 52),
      color: const Color(0xFFDBDBDB));
}
