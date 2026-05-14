// lib/features/menu/presentation/widgets/menu_action_tile.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/menu_action.dart';
import '../three_dot_menu.dart';

class MenuActionTile extends StatelessWidget {
  final MenuAction action;
  final VoidCallback onTap;

  const MenuActionTile({
    super.key,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color textColor;
    switch (action.style) {
      case MenuActionStyle.destructive:
        textColor = InstagramMenuTheme.destructive;
        break;
      case MenuActionStyle.primary:
        textColor = InstagramMenuTheme.primary;
        break;
      case MenuActionStyle.normal:
      default:
        textColor = isDark ? InstagramMenuTheme.textDark : InstagramMenuTheme.text;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                action.icon,
                size: 22,
                color: textColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        fontFamily: InstagramMenuTheme.fontFamily,
                      ),
                    ),
                    if (action.subtitle != null)
                      Text(
                        action.subtitle!,
                        style: TextStyle(
                          color: isDark ? InstagramMenuTheme.textSecondaryDark : InstagramMenuTheme.textSecondary,
                          fontSize: 12,
                          fontFamily: InstagramMenuTheme.fontFamily,
                        ),
                      ),
                  ],
                ),
              ),
              if (action.trailing != null) action.trailing!,
              if (action.showChevron)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: isDark ? InstagramMenuTheme.textSecondaryDark : InstagramMenuTheme.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
