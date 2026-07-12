import 'package:flutter/material.dart';
import '../core/app_config.dart';

class BannerBackground extends StatelessWidget {
  final Widget child;
  final double opacity;
  const BannerBackground({super.key, required this.child, this.opacity = 0.15});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.bannerUrl.isEmpty) return child;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.network(
            AppConfig.bannerUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Color(AppConfig.backgroundColor).withOpacity(1 - opacity),
          ),
        ),
        child,
      ],
    );
  }
}
