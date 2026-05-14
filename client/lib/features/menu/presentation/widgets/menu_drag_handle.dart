// lib/features/menu/presentation/widgets/menu_drag_handle.dart

import 'package:flutter/material.dart';

class MenuDragHandle extends StatelessWidget {
  const MenuDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
