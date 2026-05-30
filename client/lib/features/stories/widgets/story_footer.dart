import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../models/story_model.dart';
import 'story_music_bar.dart';

class StoryFooter extends StatefulWidget {
  final StoryModel story;
  final bool isOwner;
  final Function(String) onReply;
  final Function(String) onReaction;
  final VoidCallback onShare;
  final Function(bool) onFocusChanged;
  final VoidCallback onDelete;
  final Function(String) onAddMention;
  final bool commentingEnabled;
  final VoidCallback onToggleCommenting;

  const StoryFooter({
    super.key,
    required this.story,
    required this.isOwner,
    required this.onReply,
    required this.onReaction,
    required this.onShare,
    required this.onFocusChanged,
    required this.onDelete,
    required this.onAddMention,
    required this.commentingEnabled,
    required this.onToggleCommenting,
  });

  @override
  State<StoryFooter> createState() => _StoryFooterState();
}

class _StoryFooterState extends State<StoryFooter>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
      widget.onFocusChanged(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwner) {
      return _buildOwnerFooter();
    }
    return _buildViewerFooter();
  }

  // ─── Viewer footer ─────────────────────────────────
  Widget _buildViewerFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Music bar (if story has music)
            if (widget.story.music != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StoryMusicBar(
                  music: widget.story.music!,
                  isPlaying: true, // Playing by default
                ),
              ),

            // Input row
            Row(
              children: [
                // Reply text field / Comments disabled indicator
                Expanded(
                  child: GestureDetector(
                    onTap: widget.commentingEnabled ? () => _focusNode.requestFocus() : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _isFocused
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: widget.commentingEnabled
                          ? Row(
                              children: [
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: widget.story.question != null
                                          ? 'Answer...'
                                          : 'Send message',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    cursorColor: Colors.white,
                                    onSubmitted: (val) {
                                      if (val.isNotEmpty) {
                                        widget.onReply(val);
                                        _controller.clear();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Like Heart Icon on reply bar
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isLiked = !_isLiked;
                                    });
                                    HapticFeedback.mediumImpact();
                                    if (_isLiked) {
                                      widget.onReaction('❤️');
                                    }
                                  },
                                  child: Icon(
                                    _isLiked ? Icons.favorite : LucideIcons.heart,
                                    color: _isLiked ? Colors.red : Colors.white.withOpacity(0.9),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            )
                          : Center(
                              child: Text(
                                'Commenting turned off',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Share button (when not focused)
                if (!_isFocused)
                  GestureDetector(
                    onTap: widget.onShare,
                    child: const Icon(
                      LucideIcons.send,
                      color: Colors.white,
                      size: 24,
                      shadows: [
                        Shadow(color: Colors.black38, blurRadius: 4),
                      ],
                    ),
                  ),

                // Send button (when focused)
                if (_isFocused && widget.commentingEnabled)
                  GestureDetector(
                    onTap: () {
                      final val = _controller.text;
                      if (val.isNotEmpty) {
                        widget.onReply(val);
                        _controller.clear();
                        _focusNode.unfocus();
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Owner footer ───────────────────────────────────
  Widget _buildOwnerFooter() {
    final story = widget.story;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Views count
            GestureDetector(
              onTap: _showViewers,
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.eye,
                    color: Colors.white,
                    size: 22,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${story.viewCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),

            // More options
            GestureDetector(
              onTap: _showMoreOptions,
              child: Icon(
                LucideIcons.ellipsis,
                color: Colors.white,
                size: 26,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showViewers() {
    widget.onFocusChanged(true); // Pause story while viewing viewers list
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        final viewers = [
          {'username': 'alex_adams', 'name': 'Alex Adams', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=alex'},
          {'username': 'sarah_c', 'name': 'Sarah Connor', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=sarah'},
          {'username': 'john_doe', 'name': 'John Doe', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=john'},
          {'username': 'lisa_s', 'name': 'Lisa Smith', 'avatar': 'https://api.dicebear.com/7.x/avataaars/svg?seed=lisa'},
        ];

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            height: MediaQuery.of(context).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.eye, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Story Views (${viewers.length})',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: viewers.length,
                    itemBuilder: (context, index) {
                      final v = viewers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(v['avatar']!),
                        ),
                        title: Text(
                          v['username']!,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          v['name']!,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Removed ${v['username']} from story viewers')),
                            );
                          },
                          child: const Text('Remove', style: TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      widget.onFocusChanged(false); // Resume story
    });
  }

  void _showMoreOptions() {
    widget.onFocusChanged(true); // Pause story
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Add Mention
                ListTile(
                  leading: const Icon(LucideIcons.at_sign),
                  title: const Text('Add Mention'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddMentionDialog();
                  },
                ),
                
                // Toggle Commenting
                ListTile(
                  leading: Icon(
                    widget.commentingEnabled 
                        ? LucideIcons.message_square_off 
                        : LucideIcons.message_square
                  ),
                  title: Text(widget.commentingEnabled ? 'Turn Off Commenting' : 'Turn On Commenting'),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    widget.onToggleCommenting();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.commentingEnabled 
                            ? 'Commenting turned off for this story' 
                            : 'Commenting turned on for this story'),
                        backgroundColor: Colors.indigo,
                      ),
                    );
                  },
                ),
                
                // Story Settings
                ListTile(
                  leading: const Icon(LucideIcons.settings),
                  title: const Text('Story Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    _showStorySettings();
                  },
                ),
                
                const Divider(),
                
                // Delete Story
                ListTile(
                  leading: const Icon(LucideIcons.trash_2, color: Colors.red),
                  title: const Text('Delete Story', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation();
                  },
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      widget.onFocusChanged(false); // Resume story
    });
  }

  void _showAddMentionDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          title: Row(
            children: [
              const Icon(LucideIcons.at_sign, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Add Mention'),
            ],
          ),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter username (e.g. alex_adams)',
              prefixText: '@',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final username = textController.text.trim();
                if (username.isNotEmpty) {
                  Navigator.pop(context);
                  HapticFeedback.mediumImpact();
                  widget.onAddMention(username);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mentioned @$username on this story'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Mention'),
            ),
          ],
        );
      },
    );
  }

  void _showStorySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            height: MediaQuery.of(context).size.height * 0.45,
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Story Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(LucideIcons.archive),
                        title: const Text('Save Story to Archive'),
                        value: true,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(LucideIcons.arrow_down_to_line),
                        title: const Text('Save Story to Gallery'),
                        value: false,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                        },
                      ),
                      SwitchListTile(
                        secondary: const Icon(LucideIcons.globe),
                        title: const Text('Allow Sharing to Facebook'),
                        value: true,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      HapticFeedback.mediumImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Story settings updated successfully!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          title: const Text('Delete Story?'),
          content: const Text('Are you sure you want to permanently delete this story segment? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                HapticFeedback.heavyImpact();
                widget.onDelete();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
