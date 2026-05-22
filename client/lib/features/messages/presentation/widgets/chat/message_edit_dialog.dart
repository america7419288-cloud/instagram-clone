import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';

class MessageEditDialog extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;

  const MessageEditDialog({
    super.key,
    required this.initialText,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String initialText,
    required Function(String) onSave,
  }) {
    return showCupertinoModalPopup(
      context: context,
      builder: (context) => MessageEditDialog(
        initialText: initialText,
        onSave: onSave,
      ),
    );
  }

  @override
  State<MessageEditDialog> createState() => _MessageEditDialogState();
}

class _MessageEditDialogState extends State<MessageEditDialog> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSave() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && text != widget.initialText) {
      widget.onSave(text);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                    ),
                  ),
                ),
                const Text(
                  'Edit Message',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _handleSave,
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Text Input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoTextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),

          // Info Text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Edited messages will show an "Edited" label',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
