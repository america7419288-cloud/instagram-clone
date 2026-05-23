// lib/features/messages/presentation/widgets/chat/mute_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

class MuteBottomSheet extends StatelessWidget {
  final String username;
  final ValueChanged<String> onMuteSelected;

  const MuteBottomSheet({
    super.key,
    required this.username,
    required this.onMuteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Map<String, String> options = {
      '1 Hour': 'hour',
      '8 Hours': '8hours',
      '1 Week': '1week',
      'Until I turn it back on': 'forever',
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.only(bottom: 24, top: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bottom sheet drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white30 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Text(
              'Mute notifications for $username?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You won't get push notifications for new messages from them.",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            
            // Option items
            ...options.entries.map((entry) {
              return Column(
                children: [
                  ListTile(
                    title: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    onTap: () {
                      onMuteSelected(entry.value);
                    },
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
            
            // Cancel button
            ListTile(
              title: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
