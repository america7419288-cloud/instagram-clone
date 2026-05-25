import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/mention_model.dart';
import '../services/mention_service.dart';

// ── CUSTOM TEXT EDITING CONTROLLER FOR HIGHLIGHTING ─────────
class MentionTextFieldController extends TextEditingController {
  final TextStyle mentionStyle;
  final List<Map<String, dynamic>> _selectedUsers = [];

  MentionTextFieldController({
    String? text,
    this.mentionStyle = const TextStyle(
      color: Color(0xFF3897F0), // Instagram blue
      fontWeight: FontWeight.bold,
    ),
  }) : super(text: text);

  void addSelectedUser(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? user['_id']?.toString() ?? '';
    if (id.isNotEmpty && !_selectedUsers.any((u) => (u['id']?.toString() ?? u['_id']?.toString()) == id)) {
      _selectedUsers.add(user);
    }
  }

  List<Map<String, dynamic>> get selectedUsers => _selectedUsers;

  List<MentionModel> getMentions() {
    final List<MentionModel> mentions = [];
    final currentText = text;

    for (final user in _selectedUsers) {
      final username = user['username'] as String? ?? '';
      if (username.isEmpty) continue;

      final mentionText = '@$username';
      int index = currentText.indexOf(mentionText);
      while (index != -1) {
        bool isFullWord = true;
        final nextCharIdx = index + mentionText.length;
        if (nextCharIdx < currentText.length) {
          final nextChar = currentText[nextCharIdx];
          if (RegExp(r'[a-zA-Z0-9_.]').hasMatch(nextChar)) {
            isFullWord = false;
          }
        }

        if (isFullWord) {
          mentions.add(MentionModel(
            userId: (user['id'] ?? user['_id'] ?? '').toString(),
            username: username,
            offset: index,
            length: mentionText.length,
          ));
        }

        index = currentText.indexOf(mentionText, index + 1);
      }
    }
    return mentions;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final pattern = RegExp(r'@[a-zA-Z0-9_.]+');

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        children.add(TextSpan(
          text: match[0],
          style: mentionStyle,
        ));
        return '';
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return '';
      },
    );

    return TextSpan(style: style, children: children);
  }
}

// ── MENTION TEXT FIELD WITH AUTOCOMPLETE OVERLAY ───────────
class MentionTextField extends ConsumerStatefulWidget {
  final MentionTextFieldController controller;
  final String contextType; // 'group' | 'community' | 'comment' | 'story' | 'general'
  final String? contextId;  // conversationId or communityId
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextStyle? style;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final double overlayWidth;
  final double overlayMaxHeight;

  const MentionTextField({
    Key? key,
    required this.controller,
    this.contextType = 'general',
    this.contextId,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.style,
    this.maxLines = 5,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.newline,
    this.overlayWidth = 300,
    this.overlayMaxHeight = 220,
  }) : super(key: key);

  @override
  ConsumerState<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends ConsumerState<MentionTextField> {
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  
  String? _mentionQuery;
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _hideOverlay();
    widget.controller.removeListener(_onTextChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
    }
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.baseOffset <= 0) {
      _hideOverlay();
      return;
    }

    final currentOffset = selection.baseOffset;
    final textBeforeCursor = text.substring(0, currentOffset);

    // Find the last index of '@' before the cursor
    final lastAtIdx = textBeforeCursor.lastIndexOf('@');
    if (lastAtIdx == -1) {
      _hideOverlay();
      return;
    }

    // Check if there's a space between '@' and cursor
    final textAfterAt = textBeforeCursor.substring(lastAtIdx + 1);
    if (textAfterAt.contains(' ')) {
      _hideOverlay();
      return;
    }

    _mentionQuery = textAfterAt.trim();
    _mentionStartIndex = lastAtIdx;

    _searchMentions(_mentionQuery!);
  }

  Future<void> _searchMentions(String query) async {
    setState(() {
      _isLoading = true;
    });

    final mentionService = ref.read(mentionServiceProvider);
    final results = await mentionService.searchUsers(
      query: query,
      context: widget.contextType,
      contextId: widget.contextId,
    );

    if (!mounted) return;

    setState(() {
      _suggestions = results;
      _isLoading = false;
    });

    if (_suggestions.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? '';
    if (username.isEmpty) return;

    widget.controller.addSelectedUser(user);

    final currentText = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;
    
    // Replace from _mentionStartIndex to cursorPosition with '@username '
    final before = currentText.substring(0, _mentionStartIndex);
    final after = currentText.substring(cursorPosition);
    final newText = '$before@$username $after';

    widget.controller.text = newText;
    
    // Position cursor after the selected mention and space
    final newCursorOffset = _mentionStartIndex + username.length + 2; // +1 for @, +1 for space
    widget.controller.selection = TextSelection.collapsed(offset: newCursorOffset);

    _hideOverlay();
    _focusNode.requestFocus();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: widget.overlayWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          // Positions the overlay right above the text field
          offset: Offset(0, -widget.overlayMaxHeight - 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.85),
            child: Container(
              height: widget.overlayMaxHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.at, size: 14, color: Colors.white54),
                          const SizedBox(width: 6),
                          const Text(
                            'Mentions',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          if (_isLoading)
                            const CupertinoActivityIndicator(radius: 6, color: Colors.white70),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final user = _suggestions[index];
                          final avatarUrl = user['avatarUrl'] ?? user['profile_pic_url'];
                          final username = user['username'] ?? '';
                          final fullName = user['fullName'] ?? user['full_name'] ?? '';
                          final isVerified = user['isVerified'] ?? user['is_verified'] ?? false;

                          return InkWell(
                            onTap: () => _selectUser(user),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: avatarUrl != null
                                        ? CachedNetworkImageProvider(avatarUrl)
                                        : null,
                                    backgroundColor: Colors.white10,
                                    child: avatarUrl == null
                                        ? Text(
                                            username.substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              username,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (isVerified) ...[
                                              const SizedBox(width: 4),
                                              const Icon(
                                                CupertinoIcons.checkmark_seal_fill,
                                                color: CupertinoColors.activeBlue,
                                                size: 13,
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (fullName.isNotEmpty)
                                          Text(
                                            fullName,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: widget.decoration,
        style: widget.style,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onSubmitted: (val) {
          _hideOverlay();
          if (widget.onSubmitted != null) {
            widget.onSubmitted!(val);
          }
        },
      ),
    );
  }
}
