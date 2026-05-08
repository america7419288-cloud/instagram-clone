import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/app_assets.dart';

class AppLoader extends StatelessWidget {
  final double size;
  
  const AppLoader({
    super.key,
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        AppAssets.spinner,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
