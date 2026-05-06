// lib/features/post/presentation/pages/finalize_post_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/spring_widget.dart';
import '../providers/create_post_provider.dart';

class FinalizePostPage extends ConsumerStatefulWidget {
  final List<File> images;
  final List<List<double>> filterMatrices;

  const FinalizePostPage({
    super.key, 
    required this.images,
    this.filterMatrices = const [],
  });

  @override
  ConsumerState<FinalizePostPage> createState() => _FinalizePostPageState();
}

class _FinalizePostPageState extends ConsumerState<FinalizePostPage> {
  final TextEditingController _captionController = TextEditingController();
  bool _shareToFacebook = false;
  bool _shareToTwitter = false;
  bool _shareToTumblr = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    final notifier = ref.read(createPostProvider.notifier);
    notifier.setCaption(_captionController.text);
    
    final success = await notifier.uploadPost(
      files: widget.images.map((e) => XFile(e.path)).toList(),
      filterMatrices: widget.filterMatrices,
    );
    
    if (success && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createPostProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New post',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: createState.isUploading ? null : _handleShare,
            child: createState.isUploading
                ? const CupertinoActivityIndicator(color: Color(0xFF0095F6))
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Color(0xFF0095F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Caption + Thumbnail Section
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _captionController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Write a caption...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        ColorFiltered(
                          colorFilter: widget.filterMatrices.isNotEmpty 
                              ? ColorFilter.matrix(widget.filterMatrices.first)
                              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: Image.file(
                            widget.images.first,
                            width: 65,
                            height: 65,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 65,
                              height: 65,
                              color: Colors.grey[900],
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                        ),
                        if (widget.images.length > 1)
                          const Positioned(
                            top: 4,
                            right: 4,
                            child: Icon(Icons.collections, color: Colors.white, size: 14),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Color(0xFF262626), height: 1),
            
            _buildActionRow(icon: PhosphorIcons.user(), title: 'Tag people'),
            _buildActionRow(icon: PhosphorIcons.mapPin(), title: 'Add location'),
            _buildActionRow(icon: PhosphorIcons.musicNotes(), title: 'Add music'),
            
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF262626), height: 1),
            
            _buildSwitchRow('Facebook', _shareToFacebook, (v) => setState(() => _shareToFacebook = v)),
            _buildSwitchRow('Twitter', _shareToTwitter, (v) => setState(() => _shareToTwitter = v)),
            _buildSwitchRow('Tumblr', _shareToTumblr, (v) => setState(() => _shareToTumblr = v)),
            
            const Divider(color: Color(0xFF262626), height: 1),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _showAdvancedSettings,
                  child: const Text(
                    'Advanced settings',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow({required IconData icon, required String title}) {
    return BouncyTap(
      onTap: () {},
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF262626), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF262626), width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Spacer(),
          CupertinoSwitch(
            value: value,
            activeColor: const Color(0xFF0095F6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showAdvancedSettings() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Advanced Settings'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Turn Off Commenting'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Write Alt Text'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
