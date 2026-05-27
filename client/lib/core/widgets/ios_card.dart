// lib/core/widgets/ios_card.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/ios_colors.dart';
import '../theme/app_theme.dart'; // import to resolve .ms duration extensions

class IosCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  final EdgeInsets margin;

  const IosCard({
    super.key,
    required this.children,
    required this.isDark,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children.asMap().entries.map((e) {
              return Column(
                children: [
                  e.value,
                  if (e.key < children.length - 1)
                    Divider(
                      height: 0.5,
                      indent: 16,
                      color: isDark
                        ? const Color(0xFF38383A)
                        : const Color(0xFFE0E0E0),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class IosListTile extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? leading;
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final Widget? trailingWidget;
  final bool showChevron;
  final bool isDark;
  final VoidCallback? onTap;

  const IosListTile({
    super.key,
    required this.title,
    required this.isDark,
    this.subtitle,
    this.leadingIcon,
    this.leading,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.trailingWidget,
    this.showChevron = false,
    this.onTap,
  });

  @override
  State<IosListTile> createState() => _IosListTileState();
}

class _IosListTileState extends State<IosListTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor
      ?? IosColors.primary(context);
    final titleColor = widget.titleColor
      ?? IosColors.primary(context);

    return GestureDetector(
      onTapDown: widget.onTap != null
        ? (_) => setState(() => _pressed = true)
        : null,
      onTapUp: widget.onTap != null
        ? (_) {
            setState(() => _pressed = false);
            widget.onTap!();
          }
        : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: 80.ms,
        color: _pressed
          ? (widget.isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.04))
          : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 13),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 12),
            ] else if (widget.leadingIcon != null) ...[
              Icon(
                widget.leadingIcon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        color: IosColors.secondary(context),
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!
            else if (widget.trailingWidget != null)
              widget.trailingWidget!
            else if (widget.showChevron)
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: IosColors.secondary(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Member Row ──
class MemberRow extends StatelessWidget {
  final Map<String, dynamic> member;
  final bool isAdmin;
  final bool isDark;
  final VoidCallback onLongPress;

  const MemberRow({
    super.key,
    required this.member,
    required this.isAdmin,
    required this.isDark,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: Container(
        color: IosColors.background(context),
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: CachedNetworkImageProvider(member['avatar'] ?? 'https://i.pravatar.cc/150'),
                ),
                if (member['isOnline'] == true)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF58C322),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: IosColors.background(context),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member['username'] ?? 'User',
                    style: TextStyle(
                      color: IosColors.primary(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  if (member['role'] != 'member')
                    Text(
                      member['role'] == 'owner'
                        ? 'Group owner'
                        : 'Admin',
                      style: TextStyle(
                        color: IosColors.secondary(context),
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                    ),
                ],
              ),
            ),
            if (member['role'] == 'owner')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IosColors.igBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Owner',
                  style: TextStyle(
                    color: IosColors.igBlue,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              )
            else if (member['role'] == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SeeAllMembersButton extends StatelessWidget {
  final int count;
  final bool isDark;
  final VoidCallback onTap;

  const SeeAllMembersButton({
    super.key,
    required this.count,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: IosColors.background(context),
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: IosColors.secondaryBg(context),
                border: Border.all(
                  color: IosColors.separator(context),
                  width: 0.5,
                ),
              ),
              child: Icon(
                CupertinoIcons.chevron_down,
                size: 18,
                color: IosColors.primary(context),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'See all $count members',
              style: TextStyle(
                color: IosColors.primary(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Circle Icon Buttons for App Bar ──
class CircleBackButton extends StatelessWidget {
  final bool isDark;
  const CircleBackButton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
          ),
          child: const Icon(
            CupertinoIcons.chevron_back,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.4),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const AppBarAction({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: onTap,
      child: Icon(
        icon,
        size: 26,
        color: IosColors.primary(context),
      ),
    );
  }
}
