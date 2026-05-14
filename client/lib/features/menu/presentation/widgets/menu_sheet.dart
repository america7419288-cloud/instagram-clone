// lib/features/menu/presentation/widgets/menu_sheet.dart

import 'package:flutter/material.dart';
import '../../models/menu_action.dart';
import '../../models/menu_context.dart';
import '../../controllers/menu_controller.dart';
import '../three_dot_menu.dart';
import 'menu_action_tile.dart';
import 'menu_section.dart';
import 'menu_drag_handle.dart';
import '../flows/unfollow_confirmation.dart';
import '../flows/delete_confirmation.dart';

class MenuSheet extends StatelessWidget {
  final MenuContext menuContext;
  final Function(MenuAction)? onAction;

  const MenuSheet({
    super.key,
    required this.menuContext,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = MenuActionResolver.getSections(menuContext);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? InstagramMenuTheme.backgroundDark : InstagramMenuTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MenuDragHandle(),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: sections.length,
              separatorBuilder: (context, index) => Container(
                height: 8,
                color: isDark ? InstagramMenuTheme.sectionGapDark : InstagramMenuTheme.sectionGap,
              ),
              itemBuilder: (context, index) {
                final section = sections[index];
                return MenuSectionWidget(
                  section: section,
                  onAction: (action) => _handleAction(context, action),
                );
              },
            ),
          ),
          const SizedBox(height: 20), // Bottom padding for iOS home indicator
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, MenuAction action) {
    if (action.requiresConfirmation) {
      if (action.type == MenuActionType.delete) {
        Navigator.pop(context);
        DeleteConfirmationSheet.show(
          context,
          contentType: menuContext.contentType,
          onConfirm: () => onAction?.call(action),
        );
        return;
      }
      if (action.type == MenuActionType.unfollow) {
        Navigator.pop(context);
        UnfollowConfirmationSheet.show(
          context,
          username: menuContext.authorUsername ?? 'User',
          avatarUrl: menuContext.authorAvatarUrl,
          onConfirm: () => onAction?.call(action),
        );
        return;
      }
    }

    if (onAction != null) {
      onAction!(action);
    }
    Navigator.pop(context);
  }
}
