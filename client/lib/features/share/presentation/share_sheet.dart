// lib/features/share/presentation/share_sheet.dart

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../models/share_target.dart';
import '../models/share_content.dart';
import 'providers/share_provider.dart';
import 'theme/share_theme.dart';
import 'widgets/recipient_grid.dart';
import 'widgets/recipient_tile.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN SHARE SHEET WIDGET
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ShareSheet extends ConsumerStatefulWidget {
  final ShareContent content;

  const ShareSheet({super.key, required this.content});

  static Future<void> show(
    BuildContext context, {
    required ShareContent content,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      builder: (_) => ShareSheet(content: content),
    );
  }

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet>
    with SingleTickerProviderStateMixin {

  late final DraggableScrollableController _sheetController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _messageFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    
    _searchCtrl.addListener(() {
      ref.read(shareSheetProvider.notifier).updateSearch(_searchCtrl.text);
    });
    
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        _sheetController.animateTo(
          0.95,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final state = ref.watch(shareSheetProvider);
    final notifier = ref.read(shareSheetProvider.notifier);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.5, 0.85, 0.95],
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? ShareTheme.backgroundDark : ShareTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _Header(
                hasSelection: state.selectedTargets.isNotEmpty,
                isDark: isDark,
                onClose: () => Navigator.pop(context),
              ),
              _SearchBar(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                isDark: isDark,
                onCancel: () {
                  _searchCtrl.clear();
                  _searchFocus.unfocus();
                },
              ),
              if (state.selectedTargets.isNotEmpty)
                _SelectedChips(
                  selectedTargets: state.selectedTargets,
                  isDark: isDark,
                  onRemove: notifier.removeTarget,
                ),
              Expanded(
                child: _buildContent(scrollController, isDark, state, notifier),
              ),
              if (state.selectedTargets.isNotEmpty)
                _SendBar(
                  messageController: _messageCtrl,
                  messageFocus: _messageFocus,
                  selectionCount: state.selectedTargets.length,
                  isSending: state.isSending,
                  isDark: isDark,
                  onSend: () => _onSend(state, notifier),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    ScrollController scrollController,
    bool isDark,
    ShareSheetState state,
    ShareSheetNotifier notifier,
  ) {
    if (state.isSearching && state.searchResults.isEmpty) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14),
      );
    }

    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (state.searchQuery.isEmpty) ...[
          if (state.recentTargets.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(text: 'Recents', isDark: isDark),
            ),
            SliverToBoxAdapter(
              child: RecipientGrid(
                targets: state.recentTargets,
                isSelected: (id) => state.selectedTargets.any((t) => t.id == id),
                onTap: notifier.toggleSelection,
                isDark: isDark,
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: _SectionLabel(text: 'Suggested', isDark: isDark),
          ),
          SliverToBoxAdapter(
            child: RecipientGrid(
              targets: state.recentTargets, // Fallback to recents for now or empty
              isSelected: (id) => state.selectedTargets.any((t) => t.id == id),
              onTap: notifier.toggleSelection,
              isDark: isDark,
            ),
          ),
        ] else ...[
          if (state.searchResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(text: 'Results', isDark: isDark),
            ),
            SliverToBoxAdapter(
              child: RecipientGrid(
                targets: state.searchResults,
                isSelected: (id) => state.selectedTargets.any((t) => t.id == id),
                onTap: notifier.toggleSelection,
                isDark: isDark,
              ),
            ),
          ] else if (!state.isSearching)
            SliverToBoxAdapter(
              child: _NoResults(query: state.searchQuery, isDark: isDark),
            ),
        ],

        if (state.searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: _ExternalShareOptions(
              content: widget.content,
              isDark: isDark,
            ),
          ),

        SliverToBoxAdapter(
          child: SizedBox(
            height: state.selectedTargets.isNotEmpty
                ? 0
                : 24 + MediaQuery.of(context).padding.bottom,
          ),
        ),
      ],
    );
  }

  Future<void> _onSend(ShareSheetState state, ShareSheetNotifier notifier) async {
    final message = _messageCtrl.text.trim();
    
    try {
      await notifier.sendShare(widget.content, message: message);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to ${state.selectedTargets.length} ${state.selectedTargets.length == 1 ? 'person' : 'people'}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ShareTheme.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: ShareTheme.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _searchCtrl.dispose();
    _messageCtrl.dispose();
    _searchFocus.dispose();
    _messageFocus.dispose();
    super.dispose();
  }
}

// ── Private Widgets (matching prompt design) ──────────────────

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: isDark ? ShareTheme.handleDark : ShareTheme.handle,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool hasSelection;
  final bool isDark;
  final VoidCallback onClose;

  const _Header({required this.hasSelection, required this.isDark, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: [
          const SizedBox(width: 28),
          Expanded(
            child: Center(
              child: Text(
                'Share',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: ShareTheme.fontFamily,
                  color: isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText,
                ),
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 28,
            onPressed: () {
              HapticFeedback.lightImpact();
              onClose();
            },
            child: Icon(
              LucideIcons.x,
              size: 22,
              color: isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final VoidCallback onCancel;

  const _SearchBar({required this.controller, required this.focusNode, required this.isDark, required this.onCancel});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _hasFocus = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() => _hasFocus = widget.focusNode.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: widget.isDark ? ShareTheme.surfaceDark : const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(LucideIcons.search, size: 16, color: ShareTheme.secondaryText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: CupertinoTextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      placeholder: 'Search',
                      placeholderStyle: const TextStyle(color: ShareTheme.secondaryText, fontSize: 15, fontFamily: ShareTheme.fontFamily),
                      style: TextStyle(color: widget.isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText, fontSize: 15, fontFamily: ShareTheme.fontFamily),
                      decoration: null,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  if (widget.controller.text.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 28,
                      onPressed: () => widget.controller.clear(),
                      child: const Icon(LucideIcons.xCircle, size: 16, color: ShareTheme.secondaryText),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: _hasFocus
                ? Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 28,
                      onPressed: widget.onCancel,
                      child: Text('Cancel', style: TextStyle(color: widget.isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText, fontSize: 15, fontFamily: ShareTheme.fontFamily)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  final List<ShareTarget> selectedTargets;
  final bool isDark;
  final Function(ShareTarget) onRemove;

  const _SelectedChips({required this.selectedTargets, required this.isDark, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: isDark ? ShareTheme.separatorDark : ShareTheme.separator, width: 0.33)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: selectedTargets.length,
        itemBuilder: (ctx, i) {
          final target = selectedTargets[i];
          return _Chip(target: target, isDark: isDark, onRemove: () => onRemove(target));
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final ShareTarget target;
  final bool isDark;
  final VoidCallback onRemove;

  const _Chip({required this.target, required this.isDark, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        decoration: BoxDecoration(
          color: isDark ? ShareTheme.surfaceDark : const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: target.avatarUrl != null
                  ? Image.network(target.avatarUrl!, width: 24, height: 24, fit: BoxFit.cover)
                  : Container(width: 24, height: 24, color: const Color(0xFFEFEFEF), child: const Icon(LucideIcons.user, size: 14, color: ShareTheme.secondaryText)),
            ),
            const SizedBox(width: 6),
            Text(target.displayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: ShareTheme.fontFamily, color: isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(LucideIcons.x, size: 14, color: ShareTheme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel({required this.text, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: ShareTheme.fontFamily, color: isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText)),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  final bool isDark;
  const _NoResults({required this.query, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const Icon(LucideIcons.searchX, size: 48, color: ShareTheme.secondaryText),
          const SizedBox(height: 16),
          Text('No results for "$query"', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: ShareTheme.fontFamily, color: isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText)),
          const SizedBox(height: 4),
          const Text('Try a different search', style: TextStyle(fontSize: 13, fontFamily: ShareTheme.fontFamily, color: ShareTheme.secondaryText)),
        ],
      ),
    );
  }
}

class _ExternalShareOptions extends StatelessWidget {
  final ShareContent content;
  final bool isDark;

  const _ExternalShareOptions({
    required this.content,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final options = _getOptionsForContent(content.type);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          // Top separator
          Container(
            height: 0.33,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: isDark ? ShareTheme.separatorDark : ShareTheme.separator,
          ),

          // Options list
          ...options.map((option) => _OptionRow(
                option: option,
                isDark: isDark,
                onTap: () => _handleOptionTap(context, option),
              )),
        ],
      ),
    );
  }

  List<ExternalShareOption> _getOptionsForContent(ShareContentType type) {
    switch (type) {
      case ShareContentType.post:
        return [
          const ExternalShareOption(
            type: ShareExternalOption.addToStory,
            label: 'Add to story',
            icon: LucideIcons.plusSquare,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.copyLink,
            label: 'Copy link',
            icon: LucideIcons.link2,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareTo,
            label: 'Share to...',
            icon: LucideIcons.share,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareToFacebook,
            label: 'Facebook',
            icon: LucideIcons.facebook,
            iconColor: Color(0xFF1877F2),
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareToWhatsApp,
            label: 'WhatsApp',
            icon: LucideIcons.messageCircle,
            iconColor: Color(0xFF25D366),
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareToMessages,
            label: 'Messages',
            icon: LucideIcons.messageSquare,
            iconColor: Color(0xFF34C759),
          ),
        ];

      case ShareContentType.reel:
        return [
          const ExternalShareOption(
            type: ShareExternalOption.addToStory,
            label: 'Add reel to your story',
            icon: LucideIcons.plusSquare,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.remix,
            label: 'Remix',
            icon: LucideIcons.copy,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.copyLink,
            label: 'Copy link',
            icon: LucideIcons.link2,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareTo,
            label: 'Share to...',
            icon: LucideIcons.share,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.saveToDevice,
            label: 'Save video',
            icon: LucideIcons.download,
          ),
        ];

      case ShareContentType.profile:
        return [
          const ExternalShareOption(
            type: ShareExternalOption.copyLink,
            label: 'Copy profile URL',
            icon: LucideIcons.link2,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.qrCode,
            label: 'QR code',
            icon: LucideIcons.qrCode,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareTo,
            label: 'Share to...',
            icon: LucideIcons.share,
          ),
        ];

      case ShareContentType.story:
        return [
          const ExternalShareOption(
            type: ShareExternalOption.copyLink,
            label: 'Copy link',
            icon: LucideIcons.link2,
          ),
          const ExternalShareOption(
            type: ShareExternalOption.shareTo,
            label: 'Share to...',
            icon: LucideIcons.share,
          ),
        ];
    }
  }

  void _handleOptionTap(BuildContext context, ExternalShareOption option) {
    HapticFeedback.lightImpact();
    
    String baseUrl = 'https://instagram-clone-im0x.onrender.com'; // Use actual app base URL
    String contentUrl = '';
    
    switch (content.type) {
      case ShareContentType.post:
        contentUrl = '$baseUrl/p/${content.id}';
        break;
      case ShareContentType.reel:
        contentUrl = '$baseUrl/reels/${content.id}';
        break;
      case ShareContentType.story:
        contentUrl = '$baseUrl/stories/${content.authorUsername ?? 'user'}/${content.id}';
        break;
      case ShareContentType.profile:
        contentUrl = '$baseUrl/${content.authorUsername ?? content.id}';
        break;
    }

    final shareText = 'Check this out on Instagram: $contentUrl';

    switch (option.type) {
      case ShareExternalOption.copyLink:
        Clipboard.setData(ClipboardData(text: contentUrl));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      
      case ShareExternalOption.shareTo:
        Navigator.pop(context);
        Share.share(shareText);
        break;
      
      case ShareExternalOption.shareToWhatsApp:
        Navigator.pop(context);
        // WhatsApp deep link would be better, but share_plus handles it if installed
        Share.share(shareText);
        break;

      case ShareExternalOption.shareToFacebook:
        Navigator.pop(context);
        Share.share(shareText);
        break;

      case ShareExternalOption.shareToMessages:
        Navigator.pop(context);
        Share.share(shareText);
        break;
      
      default:
        Navigator.pop(context);
        break;
    }
  }
}

class _OptionRow extends StatefulWidget {
  final ExternalShareOption option;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isPressed
            ? (widget.isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04))
            : Colors.transparent,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Icon(
                    widget.option.icon,
                    size: 24,
                    color: widget.option.iconColor ??
                        (widget.option.isDestructive
                            ? ShareTheme.red
                            : (widget.isDark ? Colors.white : ShareTheme.primaryText)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: ShareTheme.fontFamily,
                      color: widget.option.isDestructive
                          ? ShareTheme.red
                          : (widget.isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendBar extends StatefulWidget {
  final TextEditingController messageController;
  final FocusNode messageFocus;
  final int selectionCount;
  final bool isSending;
  final bool isDark;
  final VoidCallback onSend;

  const _SendBar({
    required this.messageController,
    required this.messageFocus,
    required this.selectionCount,
    required this.isSending,
    required this.isDark,
    required this.onSend,
  });

  @override
  State<_SendBar> createState() => _SendBarState();
}

class _SendBarState extends State<_SendBar> with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return SlideTransition(
      position: _slideAnim,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 10,
          bottom: bottomInset > 0 ? bottomInset + 10 : safeBottom + 10,
        ),
        decoration: BoxDecoration(
          color: widget.isDark ? ShareTheme.backgroundDark : ShareTheme.background,
          border: Border(
            top: BorderSide(
              color: widget.isDark ? ShareTheme.separatorDark : ShareTheme.separator,
              width: 0.33,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 40,
                  maxHeight: 100,
                ),
                decoration: BoxDecoration(
                  color: widget.isDark ? ShareTheme.surfaceDark : const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: CupertinoTextField(
                  controller: widget.messageController,
                  focusNode: widget.messageFocus,
                  placeholder: 'Write a message...',
                  placeholderStyle: const TextStyle(
                    color: ShareTheme.secondaryText,
                    fontSize: 15,
                    fontFamily: ShareTheme.fontFamily,
                  ),
                  style: TextStyle(
                    color: widget.isDark ? ShareTheme.primaryTextDark : ShareTheme.primaryText,
                    fontSize: 15,
                    fontFamily: ShareTheme.fontFamily,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: null,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SendButton(
              count: widget.selectionCount,
              isSending: widget.isSending,
              onTap: widget.onSend,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }
}

class _SendButton extends StatefulWidget {
  final int count;
  final bool isSending;
  final VoidCallback onTap;

  const _SendButton({
    required this.count,
    required this.isSending,
    required this.onTap,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(
      parent: _scaleCtrl,
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isSending) _scaleCtrl.forward();
      },
      onTapUp: (_) {
        _scaleCtrl.reverse();
        if (!widget.isSending) {
          HapticFeedback.lightImpact();
          widget.onTap();
        }
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: widget.isSending ? ShareTheme.blueDisabled : ShareTheme.blue,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: widget.isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CupertinoActivityIndicator(
                    color: Colors.white,
                    radius: 9,
                  ),
                )
              : Text(
                  widget.count > 1 ? 'Send Separately' : 'Send',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: ShareTheme.fontFamily,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }
}

