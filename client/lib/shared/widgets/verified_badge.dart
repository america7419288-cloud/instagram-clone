import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      AppAssets.verified,
      width: size,
      height: size,
    );
  }
}
