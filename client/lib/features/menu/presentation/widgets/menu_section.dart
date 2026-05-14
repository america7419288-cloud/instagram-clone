// lib/features/menu/presentation/widgets/menu_section.dart

import 'package:flutter/material.dart';
import '../../models/menu_action.dart';
import '../three_dot_menu.dart';
import 'menu_action_tile.dart';

class MenuSectionWidget extends StatelessWidget {
  final MenuSection section;
  final Function(MenuAction) onAction;

  const MenuSectionWidget({
    super.key,
    required this.section,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              section.title!,
              style: TextStyle(
                color: isDark ? InstagramMenuTheme.textSecondaryDark : InstagramMenuTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                textBaseline: TextBaseline.alphabetic,
              ),
            ),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: section.actions.length,
          separatorBuilder: (context, index) => Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 54, // Align with text after icon
            color: isDark ? InstagramMenuTheme.sectionDividerDark : InstagramMenuTheme.sectionDivider,
          ),
          itemBuilder: (context, index) {
            final action = section.actions[index];
            return MenuActionTile(
              action: action,
              onTap: () => onAction(action),
            );
          },
        ),
      ],
    );
  }
}
