// lib/features/menu/presentation/flows/unfollow_confirmation.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../three_dot_menu.dart';

class UnfollowConfirmationSheet extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final VoidCallback? onConfirm;

  const UnfollowConfirmationSheet({
    super.key,
    required this.username,
    this.avatarUrl,
    this.onConfirm,
  });

  static void show(
    BuildContext context, {
    required String username,
    String? avatarUrl,
    VoidCallback? onConfirm,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => UnfollowConfirmationSheet(
        username: username,
        avatarUrl: avatarUrl,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoActionSheet(
      title: Column(
        children: [
          if (avatarUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(avatarUrl!),
              ),
            ),
          Text(
            'Unfollow @$username?',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            if (onConfirm != null) {
              onConfirm!();
            }
          },
          isDestructiveAction: true,
          child: const Text('Unfollow'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    );
  }
}
