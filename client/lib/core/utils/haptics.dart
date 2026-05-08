import 'package:flutter/services.dart';

class AppHaptics {
  static Future<void> light() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    await HapticFeedback.selectionClick();
  }

  static Future<void> success() async {
    // Note: Success haptics are usually multiple light pulses, handled by platform.
    await HapticFeedback.mediumImpact();
  }
}
