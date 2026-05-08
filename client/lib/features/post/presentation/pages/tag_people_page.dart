// lib/features/post/presentation/pages/tag_people_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../widgets/tag_picker_overlay.dart';
import '../../data/models/post_tag_model.dart';
import '../../../../core/design/design_tokens.dart';

class TagPeoplePage extends StatefulWidget {
  final List<File> images;
  final List<PostTagModel> initialTags;

  const TagPeoplePage({
    super.key,
    required this.images,
    this.initialTags = const [],
  });

  @override
  State<TagPeoplePage> createState() => _TagPeoplePageState();
}

class _TagPeoplePageState extends State<TagPeoplePage> {
  late List<PostTagModel> _tags;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTagAdded(PostTagModel tag) {
    setState(() {
      _tags.add(tag);
    });
  }

  void _onTagRemoved(String userId) {
    setState(() {
      _tags.removeWhere((t) => t.userId == userId && t.mediaIndex == _currentPage);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final dividerColor = isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: bgColor.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(LucideIcons.x, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'Tag People',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Done', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context, _tags),
        ),
      ),
      body: Column(
        children: [
          // Image Carousel with Tag Overlay
          Expanded(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (context, index) {
                    return Center(
                      child: Image.file(
                        widget.images[index],
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                // Tag Picker Overlay
                LayoutBuilder(
                  builder: (context, constraints) {
                    // We need the actual rendered size of the image to map tags correctly.
                    // For simplicity in this demo, we'll assume the image fills the width.
                    return TagPickerOverlay(
                      imageWidth:  constraints.maxWidth,
                      imageHeight: constraints.maxHeight,
                      mediaIndex:  _currentPage,
                      existingTags: _tags,
                      onTagAdded:   _onTagAdded,
                      onTagRemoved: _onTagRemoved,
                      onDone:       () => Navigator.pop(context, _tags),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Page Indicator (if multiple images)
          if (widget.images.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? const Color(0xFF0095F6)
                          : Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ),
          
          const Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Text(
              'Tap the photo to tag people.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
