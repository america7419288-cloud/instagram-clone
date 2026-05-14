// lib/features/menu/presentation/flows/delete_confirmation.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/menu_context.dart';

class DeleteConfirmationSheet extends StatelessWidget {
  final MenuContentType contentType;
  final VoidCallback? onConfirm;

  const DeleteConfirmationSheet({
    super.key,
    required this.contentType,
    this.onConfirm,
  });

  static void show(
    BuildContext context, {
    required MenuContentType contentType,
    VoidCallback? onConfirm,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => DeleteConfirmationSheet(
        contentType: contentType,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String label = _getLabel();

    return CupertinoActionSheet(
      title: Text('Delete $label?'),
      message: Text('Are you sure you want to delete this $label? This action cannot be undone.'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            if (onConfirm != null) {
              onConfirm!();
            }
          },
          isDestructiveAction: true,
          child: const Text('Delete'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    );
  }

  String _getLabel() {
    switch (contentType) {
      case MenuContentType.post:
        return 'post';
      case MenuContentType.reel:
        return 'reel';
      case MenuContentType.story:
        return 'story';
      case MenuContentType.comment:
        return 'comment';
      case MenuContentType.message:
        return 'message';
      default:
        return 'content';
    }
  }
}
