import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../chat/data/models/message.dart';

class MessagePopupMenu extends StatefulWidget {
  final Message message;
  final Widget messageWidget;  // the actual bubble widget
  final Offset messagePosition; // global position
  final Size messageSize;
  final bool isMine;
  final bool? canUnsend;
  final VoidCallback onDismiss;
  final Function(String emoji) onReact;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onUnsend;
  final VoidCallback onReport;
  final VoidCallback? onSave;
  final VoidCallback? onCopyLink;

  const MessagePopupMenu({
    super.key,
    required this.message,
    required this.messageWidget,
    required this.messagePosition,
    required this.messageSize,
    required this.isMine,
    this.canUnsend,
    required this.onDismiss,
    required this.onReact,
    required this.onReply,
    required this.onCopy,
    required this.onForward,
    required this.onUnsend,
    required this.onReport,
    this.onSave,
    this.onCopyLink,
  });

  @override
  State<MessagePopupMenu> createState() => _MessagePopupMenuState();
}

class _MessagePopupMenuState extends State<MessagePopupMenu>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _backdropController;
  late AnimationController _messageController;
  late AnimationController _emojiBarController;
  late AnimationController _menuController;

  // Animations
  late Animation<double> _backdropBlur;
  late Animation<double> _backdropOpacity;
  late Animation<double> _messageScale;
  late Animation<double> _messageLift;
  late Animation<double> _emojiBarOpacity;
  late Animation<double> _emojiBarSlide;
  late Animation<double> _menuOpacity;
  late Animation<double> _menuSlide;

  // Stagger controllers for emojis
  late List<AnimationController> _emojiControllers;

  final List<String> _emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
  String? _selectedEmoji;

  final double _emojiBarWidth = 300.0; // emojis + '+' + padding

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playOpenAnimation();
    // Haptic feedback on long press
    HapticFeedback.mediumImpact();
  }

  void _setupAnimations() {
    // BACKDROP
    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _backdropBlur = Tween<double>(begin: 0, end: 8).animate(CurvedAnimation(
      parent: _backdropController,
      curve: Curves.easeOut,
    ));
    _backdropOpacity = Tween<double>(begin: 0, end: 0.4).animate(CurvedAnimation(
      parent: _backdropController,
      curve: Curves.easeOut,
    ));

    // MESSAGE LIFT
    _messageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _messageScale = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(
      parent: _messageController,
      curve: Curves.easeOut,
    ));
    _messageLift = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(
      parent: _messageController,
      curve: Curves.easeOut,
    ));

    // EMOJI BAR
    _emojiBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _emojiBarOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _emojiBarController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    _emojiBarSlide = Tween<double>(begin: -20, end: 0).animate(CurvedAnimation(
      parent: _emojiBarController,
      curve: Curves.elasticOut,
    ));

    // EMOJI STAGGER (each emoji pops in separately)
    _emojiControllers = List.generate(
      _emojis.length + 1, // +1 for + button
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    // ACTION MENU
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _menuOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    _menuSlide = Tween<double>(begin: 20, end: 0).animate(CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _playOpenAnimation() async {
    // All start together
    _backdropController.forward();
    _messageController.forward();

    // Emoji bar slightly after
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) _emojiBarController.forward();

    // Each emoji pops in with stagger
    for (int i = 0; i < _emojiControllers.length; i++) {
      Future.delayed(
        Duration(milliseconds: 80 + (i * 35)),
        () {
          if (mounted) _emojiControllers[i].forward();
        },
      );
    }

    // Action menu
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) _menuController.forward();
  }

  Future<void> _playCloseAnimation() async {
    await Future.wait([
      _backdropController.reverse(),
      _messageController.reverse(),
      _emojiBarController.reverse(),
      _menuController.reverse(),
    ]);
    widget.onDismiss();
  }

  // Smart Positioning Calculation
  bool _isEmojiBarFlipped = false;

  double _getAdjustedMessageTop() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final displayHeight = widget.messageSize.height.clamp(0.0, 320.0);

    double top = widget.messagePosition.dy;
    
    // Clamp top position to avoid header collision (header is topPadding + 56px) and screen bottom.
    // Leaves at least topPadding + 68px of margin from the top, and 80px from the bottom.
    final double lower = topPadding + 68.0;
    final double upper = (screenHeight - displayHeight - 80.0).clamp(lower, screenHeight);
    top = top.clamp(lower, upper);
    return top;
  }

  bool _isMenuBelowTheMessage() {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final minSafeY = topPadding + 60.0;
    final maxSafeY = screenHeight - bottomPadding - 60.0;
    
    final adjustedTop = _getAdjustedMessageTop();
    final displayHeight = widget.messageSize.height.clamp(0.0, 320.0);
    final messageBottom = adjustedTop + displayHeight;
    
    final spaceAbove = adjustedTop - minSafeY;
    final spaceBelow = maxSafeY - messageBottom;
    
    return spaceBelow >= spaceAbove;
  }

  Offset _getEmojiBarPosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final minSafeY = topPadding + 60.0;
    final maxSafeY = screenHeight - bottomPadding - 60.0;
    
    final displayHeight = widget.messageSize.height.clamp(0.0, 320.0);
    final adjustedTop = _getAdjustedMessageTop();
    final messageBottom = adjustedTop + displayHeight;
    final msgRight = widget.messagePosition.dx + widget.messageSize.width;

    double left = widget.isMine ? (msgRight - _emojiBarWidth) : widget.messagePosition.dx;
    left = left.clamp(8.0, screenWidth - _emojiBarWidth - 8);

    double top;
    if (_isMenuBelowTheMessage()) {
      // Menu is below message, so Emoji Bar is above message
      _isEmojiBarFlipped = false;
      top = adjustedTop - 52.0 - 8.0;
    } else {
      // Menu is above message, so Emoji Bar is below message
      _isEmojiBarFlipped = true;
      top = messageBottom + 8.0;
    }

    // Clamp top coordinate to remain fully inside visible screen safety margins
    top = top.clamp(minSafeY, maxSafeY - 52.0);

    return Offset(left, top);
  }

  Offset _getMenuPosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    final minSafeY = topPadding + 60.0;
    final maxSafeY = screenHeight - bottomPadding - 60.0;
    
    final displayHeight = widget.messageSize.height.clamp(0.0, 320.0);
    final adjustedTop = _getAdjustedMessageTop();
    final messageBottom = adjustedTop + displayHeight;
    final msgRight = widget.messagePosition.dx + widget.messageSize.width;

    double left = widget.isMine ? (msgRight - 200.0) : widget.messagePosition.dx;
    left = left.clamp(8.0, screenWidth - 208.0);

    final menuHeight = _getMenuItems().length * 44.0;
    double top;

    if (_isMenuBelowTheMessage()) {
      // Place action menu below the message
      top = messageBottom + 8.0;
    } else {
      // Place action menu above the message
      top = adjustedTop - menuHeight - 8.0;
    }

    // Clamp top coordinate to remain fully inside visible screen safety margins
    top = top.clamp(minSafeY, maxSafeY - menuHeight);

    return Offset(left, top);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: _playCloseAnimation,
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _backdropController,
            _messageController,
            _emojiBarController,
            _menuController,
          ]),
          builder: (context, _) {
            return Stack(
              children: [
                // 1. BLURRED BACKDROP
                _buildBackdrop(),

                // 2. FLOATING MESSAGE
                _buildFloatingMessage(),

                // 3. EMOJI REACTION BAR
                _buildEmojiBar(),

                // 4. ACTION MENU
                _buildActionMenu(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackdrop() {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _backdropBlur.value,
          sigmaY: _backdropBlur.value,
        ),
        child: Container(
          color: Colors.black.withOpacity(_backdropOpacity.value),
        ),
      ),
    );
  }

  Widget _buildFloatingMessage() {
    final displayHeight = widget.messageSize.height.clamp(0.0, 320.0);
    final top = _getAdjustedMessageTop() + _messageLift.value;

    return Positioned(
      left: widget.messagePosition.dx,
      top: top,
      width: widget.messageSize.width,
      height: displayHeight,
      child: IgnorePointer(
        child: Transform.scale(
          scale: _messageScale.value,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                if (widget.messageSize.height > 320.0) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.85, 1.0],
                  ).createShader(bounds);
                }
                return const LinearGradient(
                  colors: [Colors.white, Colors.white],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: SizedBox(
                height: displayHeight,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: widget.messageWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiBar() {
    final pos = _getEmojiBarPosition();

    return Positioned(
      left: pos.dx,
      top: pos.dy + _emojiBarSlide.value,
      child: Opacity(
        opacity: _emojiBarOpacity.value,
        child: _EmojiReactionBar(
          emojis: _emojis,
          selectedEmoji: _selectedEmoji,
          controllers: _emojiControllers,
          onEmojiTap: (emoji) {
            setState(() => _selectedEmoji = emoji);
            widget.onReact(emoji);
            HapticFeedback.lightImpact();
            _playCloseAnimation();
          },
          onMoreTap: _showFullEmojiPicker,
        ),
      ),
    );
  }

  Widget _buildActionMenu() {
    final pos = _getMenuPosition();
    final items = _getMenuItems();

    return Positioned(
      left: pos.dx,
      top: pos.dy + _menuSlide.value,
      width: 200,
      child: Opacity(
        opacity: _menuOpacity.value,
        child: _ActionMenuCard(items: items),
      ),
    );
  }

  void _showFullEmojiPicker() {
    HapticFeedback.lightImpact();
    
    final moreEmojis = [
      '👏', '🙏', '🎉', '🔥', '💯', '✨', 
      '💔', '👀', '🤔', '🙌', '💩', '💀',
      '😻', '🌟', '🎈', '🤩', '🌸', '🧸'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Reactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: moreEmojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final emoji = moreEmojis[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedEmoji = emoji);
                      widget.onReact(emoji);
                      HapticFeedback.lightImpact();
                      _playCloseAnimation();
                    },
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<ActionMenuItem> _getMenuItems() {
    final isMine = widget.isMine;
    final canUnsend = widget.canUnsend ?? isMine;
    final type = widget.message.messageType;

    List<ActionMenuItem> items = [];

    // Reply — ALL types have this
    items.add(ActionMenuItem(
      label: 'Reply',
      icon: Icons.reply_rounded,
      onTap: () {
        widget.onReply();
        _playCloseAnimation();
      },
    ));

    // Type-specific items
    switch (type) {
      case 'text':
        items.add(ActionMenuItem(
          label: 'Copy',
          icon: Icons.copy_rounded,
          onTap: () {
            widget.onCopy();
            _playCloseAnimation();
          },
        ));
        break;

      case 'reel':
      case 'video':
        items.add(ActionMenuItem(
          label: 'Save Reel',
          icon: Icons.bookmark_border_rounded,
          onTap: () {
            widget.onSave?.call();
            _playCloseAnimation();
          },
        ));
        items.add(ActionMenuItem(
          label: 'Copy Link',
          icon: Icons.link_rounded,
          onTap: () {
            widget.onCopyLink?.call();
            _playCloseAnimation();
          },
        ));
        break;

      case 'post':
        items.add(ActionMenuItem(
          label: 'Save Post',
          icon: Icons.bookmark_border_rounded,
          onTap: () {
            widget.onSave?.call();
            _playCloseAnimation();
          },
        ));
        items.add(ActionMenuItem(
          label: 'Copy Link',
          icon: Icons.link_rounded,
          onTap: () {
            widget.onCopyLink?.call();
            _playCloseAnimation();
          },
        ));
        break;

      case 'image':
        items.add(ActionMenuItem(
          label: 'Save Photo',
          icon: Icons.download_rounded,
          onTap: () {
            widget.onSave?.call();
            _playCloseAnimation();
          },
        ));
        break;

      case 'story':
        items.add(ActionMenuItem(
          label: 'Copy',
          icon: Icons.copy_rounded,
          onTap: () {
            widget.onCopy();
            _playCloseAnimation();
          },
        ));
        break;

      default:
        break;
    }

    // Forward — all types except audio (voice message)
    if (type != 'audio') {
      items.add(ActionMenuItem(
        label: 'Forward',
        icon: Icons.forward_rounded,
        onTap: () {
          widget.onForward();
          _playCloseAnimation();
        },
      ));
    }

    // Destructive action (last item always)
    if (canUnsend) {
      items.add(ActionMenuItem(
        label: 'Unsend',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onTap: () {
          widget.onUnsend();
          _playCloseAnimation();
        },
      ));
    } else {
      items.add(ActionMenuItem(
        label: 'Report',
        icon: Icons.flag_outlined,
        isDestructive: true,
        onTap: () {
          widget.onReport();
          _playCloseAnimation();
        },
      ));
    }

    return items;
  }

  @override
  void dispose() {
    _backdropController.dispose();
    _messageController.dispose();
    _emojiBarController.dispose();
    _menuController.dispose();
    for (var c in _emojiControllers) {
      c.dispose();
    }
    super.dispose();
  }
}

class _EmojiReactionBar extends StatelessWidget {
  final List<String> emojis;
  final String? selectedEmoji;
  final List<AnimationController> controllers;
  final Function(String) onEmojiTap;
  final VoidCallback onMoreTap;

  const _EmojiReactionBar({
    required this.emojis,
    required this.selectedEmoji,
    required this.controllers,
    required this.onEmojiTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emojis with stagger pop-in
          ...emojis.asMap().entries.map((entry) {
            final index = entry.key;
            final emoji = entry.value;
            final isSelected = selectedEmoji == emoji;

            return AnimatedBuilder(
              animation: controllers[index],
              builder: (context, _) {
                final scale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                  parent: controllers[index],
                  curve: Curves.elasticOut,
                )).value;

                return Transform.scale(
                  scale: scale,
                  child: _EmojiButton(
                    emoji: emoji,
                    isSelected: isSelected,
                    onTap: () => onEmojiTap(emoji),
                  ),
                );
              },
            );
          }),

          // + More button
          AnimatedBuilder(
            animation: controllers.last,
            builder: (context, _) {
              final scale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                parent: controllers.last,
                curve: Curves.elasticOut,
              )).value;

              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: onMoreTap,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmojiButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _tapScale;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _tapScale = Tween<double>(begin: 1.0, end: 1.4).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeOut,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _tapController.forward().then((_) {
          _tapController.reverse();
        });
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _tapController,
        builder: (context, _) {
          return Transform.scale(
            scale: widget.isSelected ? 1.2 : _tapScale.value,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: widget.isSelected
                  ? BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      shape: BoxShape.circle,
                    )
                  : null,
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }
}

class ActionMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;

  const ActionMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
  });
}

class _ActionMenuCard extends StatelessWidget {
  final List<ActionMenuItem> items;

  const _ActionMenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return Column(
              children: [
                _ActionMenuItemWidget(item: item),
                if (!isLast)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ActionMenuItemWidget extends StatefulWidget {
  final ActionMenuItem item;
  const _ActionMenuItemWidget({required this.item});

  @override
  State<_ActionMenuItemWidget> createState() => _ActionMenuItemWidgetState();
}

class _ActionMenuItemWidgetState extends State<_ActionMenuItemWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.item.isDestructive
        ? const Color(0xFFED4956) // Instagram red
        : (isDark ? Colors.white : Colors.black87);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.item.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: _isPressed
            ? (isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1))
            : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.item.label,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.none,
              ),
            ),
            Icon(
              widget.item.icon,
              size: 20,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}
