// lib/features/share/presentation/widgets/recipient_grid.dart

import 'package:flutter/material.dart';
import '../../models/share_target.dart';
import 'recipient_tile.dart';

class RecipientGrid extends StatelessWidget {
  final List<ShareTarget> targets;
  final bool Function(String) isSelected;
  final Function(ShareTarget) onTap;
  final bool isDark;

  const RecipientGrid({
    super.key,
    required this.targets,
    required this.isSelected,
    required this.onTap,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 4),
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 0,
        childAspectRatio: 0.78,
      ),
      itemCount: targets.length,
      itemBuilder: (ctx, i) {
        final target = targets[i];
        return RecipientTile(
          target: target,
          isSelected: isSelected(target.id),
          onTap: () => onTap(target),
          isDark: isDark,
        );
      },
    );
  }
}
