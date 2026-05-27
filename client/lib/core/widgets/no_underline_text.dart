// lib/core/widgets/no_underline_text.dart
import 'package:flutter/material.dart';

class CleanText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const CleanText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: (style ?? const TextStyle()).copyWith(
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
        decorationThickness: 0,
      ),
    );
  }
}
