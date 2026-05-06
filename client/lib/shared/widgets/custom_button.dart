// lib/shared/widgets/custom_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;  // null = disabled
  final bool isLoading;
  final bool isOutlined;          // Outlined style
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;
  final Widget? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width = double.infinity,
    this.height = 44,
    this.borderRadius = 8,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors
    final bgColor = isOutlined
        ? Colors.transparent
        : (backgroundColor ?? AppColors.primary);

    final fgColor = isOutlined
        ? (textColor ?? AppColors.primary)
        : (textColor ?? Colors.white);

    return SizedBox(
      width: width,
      height: height,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              child: _buildChild(fgColor),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: fgColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              child: _buildChild(fgColor),
            ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CupertinoActivityIndicator(
          color: color,
          radius: 8,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
