// lib/features/story/presentation/widgets/create_highlight_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/ios_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/story_service.dart';
import '../../data/models/story_model.dart';
import '../widgets/highlights_bar.dart';

class CreateHighlightSheet extends ConsumerStatefulWidget {
  final bool isDark;
  final String username;

  const CreateHighlightSheet({
    super.key,
    required this.isDark,
    required this.username,
  });

  @override
  ConsumerState<CreateHighlightSheet> createState() => _CreateHighlightSheetState();
}

class _CreateHighlightSheetState extends ConsumerState<CreateHighlightSheet>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<Offset> _slideAnim;
  final _nameCtrl = TextEditingController();
  final Set<String> _selectedStoryIds = {};
  String? _selectedCoverUrl;
  int _step = 0; // 0 = select stories, 1 = choose cover+name
  bool _isLoading = true;
  List<StoryModel> _stories = [];

  final List<Map<String, dynamic>> _mockStories = List.generate(
    15,
    (i) => {
      'id': 'story_$i',
      'url': 'https://picsum.photos/400/700?random=$i',
    },
  );

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    _loadStoryArchive();
  }

  Future<void> _loadStoryArchive() async {
    try {
      final archive = await ref.read(storyServiceProvider).getStoryArchive();
      setState(() {
        _stories = archive;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // ── Handle ──
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark
                  ? const Color(0xFF48484A)
                  : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Navigation bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_step > 0)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _step--),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          color: IosColors.primary(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    )
                  else
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: IosColors.primary(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _step == 0 ? 'New Highlight' : 'Edit Highlight',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: IosColors.primary(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _selectedStoryIds.isEmpty
                      ? null
                      : () {
                          if (_step == 0) {
                            setState(() {
                              if (_stories.isNotEmpty) {
                                _selectedCoverUrl = _stories
                                  .firstWhere((s) => _selectedStoryIds.contains(s.id))
                                  .mediaUrl;
                              } else {
                                _selectedCoverUrl = _mockStories
                                  .firstWhere((s) => _selectedStoryIds.contains(s['id']))['url'];
                              }
                              _step = 1;
                            });
                          } else {
                            _createHighlight();
                          }
                        },
                    child: Text(
                      _step == 0 ? 'Next' : 'Add',
                      style: TextStyle(
                        color: _selectedStoryIds.isEmpty
                          ? IosColors.igBlue.withOpacity(0.4)
                          : IosColors.igBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 0.5, thickness: 0.5),

            Expanded(
              child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 12))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: child,
                    ),
                    child: _step == 0
                      ? _StorySelector(
                          key: const ValueKey(0),
                          stories: _stories,
                          mockStories: _mockStories,
                          selected: _selectedStoryIds,
                          onToggle: (id) => setState(() {
                            if (_selectedStoryIds.contains(id)) {
                              _selectedStoryIds.remove(id);
                            } else {
                              _selectedStoryIds.add(id);
                            }
                          }),
                          isDark: widget.isDark,
                        )
                      : _HighlightEditor(
                          key: const ValueKey(1),
                          coverUrl: _selectedCoverUrl,
                          nameCtrl: _nameCtrl,
                          onChangeCover: () => _showCoverPicker(),
                          isDark: widget.isDark,
                        ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoverPicker() {
    final List<String> coverOptions = [];
    if (_stories.isNotEmpty) {
      coverOptions.addAll(
        _stories
          .where((s) => _selectedStoryIds.contains(s.id))
          .map((s) => s.mediaUrl)
      );
    } else {
      coverOptions.addAll(
        _mockStories
          .where((s) => _selectedStoryIds.contains(s['id']))
          .map((s) => s['url'] as String)
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoverPickerSheet(
        covers: coverOptions,
        onSelect: (url) {
          setState(() => _selectedCoverUrl = url);
          Navigator.pop(context);
        },
        isDark: widget.isDark,
      ),
    );
  }

  Future<void> _createHighlight() async {
    HapticFeedback.mediumImpact();
    // Show saving overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CupertinoActivityIndicator(color: Colors.white, radius: 14),
      ),
    );

    try {
      final name = _nameCtrl.text.trim();
      final title = name.isEmpty ? 'Highlight' : name;
      
      // Real API create highlight call
      await ref.read(storyServiceProvider).createHighlight(
        title: title,
        storyIds: _selectedStoryIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        Navigator.pop(context); // Pop sheet
        ref.invalidate(highlightsProvider(widget.username));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create highlight: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Step 0: Story Grid Selector ──
class _StorySelector extends StatelessWidget {
  final List<StoryModel> stories;
  final List<Map<String, dynamic>> mockStories;
  final Set<String> selected;
  final Function(String) onToggle;
  final bool isDark;

  const _StorySelector({
    super.key,
    required this.stories,
    required this.mockStories,
    required this.selected,
    required this.onToggle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final useMocks = stories.isEmpty;
    final count = useMocks ? mockStories.length : stories.length;

    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 9 / 16,
      ),
      itemCount: count,
      itemBuilder: (ctx, i) {
        final id = useMocks ? mockStories[i]['id'] as String : stories[i].id;
        final url = useMocks ? mockStories[i]['url'] as String : stories[i].mediaUrl;
        final isSelected = selected.contains(id);

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(id);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: isDark ? Colors.grey[900] : Colors.grey[200]),
              ),
              // Selection overlay
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: isSelected
                  ? Colors.black.withOpacity(0.3)
                  : Colors.transparent,
              ),
              // Checkmark
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.elasticOut,
                    builder: (_, v, __) => Transform.scale(
                      scale: v,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0095F6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Step 1: Highlight Editor ──
class _HighlightEditor extends StatelessWidget {
  final String? coverUrl;
  final TextEditingController nameCtrl;
  final VoidCallback onChangeCover;
  final bool isDark;

  const _HighlightEditor({
    super.key,
    required this.coverUrl,
    required this.nameCtrl,
    required this.onChangeCover,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Cover circle
          Stack(
            children: [
              GestureDetector(
                onTap: onChangeCover,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFEFEFEF),
                  ),
                  child: coverUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: coverUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.photo,
                        size: 36,
                        color: IosColors.secondary(context),
                      ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE0E0E0),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.black : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    size: 14,
                    color: IosColors.primary(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onChangeCover,
            child: const Text(
              'Edit Cover',
              style: TextStyle(
                color: Color(0xFF0095F6),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          Container(
            decoration: BoxDecoration(
              color: isDark
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'Highlight name...',
              placeholderStyle: TextStyle(
                color: IosColors.secondary(context),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              style: TextStyle(
                color: IosColors.primary(context),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              decoration: null,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              maxLength: 15,
              textAlign: TextAlign.center,
              autofocus: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cover Picker Sheet ──
class _CoverPickerSheet extends StatelessWidget {
  final List<String> covers;
  final ValueChanged<String> onSelect;
  final bool isDark;

  const _CoverPickerSheet({
    required this.covers,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Text(
            'Choose Cover Image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 0.5, thickness: 0.5),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: covers.length,
              itemBuilder: (ctx, i) {
                final url = covers[i];
                return GestureDetector(
                  onTap: () => onSelect(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
