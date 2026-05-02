import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SnackbarType { success, error, warning, info }

class AppSnackbar {
  AppSnackbar._();

  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final config = _getConfig(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(config.icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 4,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  static void success(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    show(context, message: message, type: SnackbarType.success);
  }

  static void error(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    show(
      context,
      message: message,
      type: SnackbarType.error,
      duration: const Duration(seconds: 4),
    );
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: SnackbarType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: SnackbarType.info);
  }

  static _SnackbarConfig _getConfig(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return const _SnackbarConfig(
          color: Color(0xFF00C853),
          icon: Icons.check_circle_outline,
        );
      case SnackbarType.error:
        return const _SnackbarConfig(
          color: Color(0xFFFF3040),
          icon: Icons.error_outline,
        );
      case SnackbarType.warning:
        return const _SnackbarConfig(
          color: Color(0xFFFFB800),
          icon: Icons.warning_amber_outlined,
        );
      case SnackbarType.info:
        return const _SnackbarConfig(
          color: Color(0xFF323232),
          icon: Icons.info_outline,
        );
    }
  }
}

class _SnackbarConfig {
  const _SnackbarConfig({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
