import 'package:flutter/material.dart';

class BrowserProgressBar extends StatelessWidget {
  final double progress;
  final bool isLoading;

  const BrowserProgressBar({
    super.key,
    required this.progress,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.transparent,
          valueColor: const AlwaysStoppedAnimation<Color>(
            Color(0xFF0095F6),
          ),
        ),
      ),
    );
  }
}
