import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'spring_widget.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message,
    this.onRetry,
    this.isSliver = false,
  });

  final String? message;
  final VoidCallback? onRetry;
  final bool isSliver;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.cloudSlash(),
              size: 56,
              color: isDark
                  ? const Color(0xFF555555)
                  : const Color(0xFFDBDBDB),
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF262626),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Please check your connection\nand try again.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? const Color(0xFFA8A8A8)
                    : const Color(0xFF737373),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              BouncyTap(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF0095F6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorIcons.arrowsClockwise(),
                          size: 16, color: const Color(0xFF0095F6)),
                      const SizedBox(width: 8),
                      const Text(
                        'Try again',
                        style: TextStyle(
                          color: Color(0xFF0095F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isSliver) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: content,
      );
    }

    return content;
  }
}
