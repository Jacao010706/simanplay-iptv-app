import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/theme/app_theme.dart';

/// Envolve o conteúdo de uma tela com o fundo do tema ativo
/// (gradiente ou imagem, conforme configurado em AppThemeConfig).
///
/// Uso:
/// ThemedBackground(
///   child: Scaffold(
///     backgroundColor: Colors.transparent,
///     body: ...,
///   ),
/// )
class ThemedBackground extends StatelessWidget {
  final Widget child;

  const ThemedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;

    if (theme.backgroundType == BackgroundType.image &&
        theme.backgroundImageAsset != null) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(theme.backgroundImageAsset!),
            fit: BoxFit.cover,
          ),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.gradientColors ??
              [theme.background, theme.background],
        ),
      ),
      child: child,
    );
  }
}