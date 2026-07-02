import 'package:flutter/material.dart';

/// Define a "forma" de um tema completo do app: cores + tipo de fundo.
/// Cada tema é independente — adicionar um novo tema não exige tocar
/// nas telas, só criar um novo AppThemeConfig na lista [AppThemes.all].
class AppThemeConfig {
  final String id; // identificador único, ex: "dark_purple"
  final String name; // nome amigável mostrado nas Configurações

  // Cores principais
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color primary;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  // Fundo: pode ser gradiente OU imagem
  final BackgroundType backgroundType;
  final List<Color>? gradientColors; // usado se backgroundType == gradient
  final String? backgroundImageAsset; // usado se backgroundType == image

  const AppThemeConfig({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.primary,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.backgroundType,
    this.gradientColors,
    this.backgroundImageAsset,
  });

  /// Constrói o ThemeData (Material) a partir desta configuração.
  ThemeData toThemeData() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: const Color(0xFFE74C3C),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      useMaterial3: true,
    );
  }
}

enum BackgroundType { gradient, image }

/// Lista de temas disponíveis no app. Adicione novos temas aqui.
class AppThemes {
  static const AppThemeConfig darkPurple = AppThemeConfig(
    id: 'dark_purple',
    name: 'Roxo Escuro (Padrão)',
    background: Color(0xFF0D0B14),
    surface: Color(0xFF1A1625),
    surfaceLight: Color(0xFF252033),
    primary: Color(0xFF7B2FF7),
    accent: Color(0xFFE94BFF),
    textPrimary: Color(0xFFF5F3FA),
    textSecondary: Color(0xFFA9A3B8),
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0D0B14), Color(0xFF1A0B2E), Color(0xFF2D0B3D)],
  );

  static const AppThemeConfig darkBlue = AppThemeConfig(
    id: 'dark_blue',
    name: 'Azul Escuro',
    background: Color(0xFF0A0E1A),
    surface: Color(0xFF131A2B),
    surfaceLight: Color(0xFF1E2A45),
    primary: Color(0xFF2D7FF9),
    accent: Color(0xFF00D9FF),
    textPrimary: Color(0xFFF0F4FF),
    textSecondary: Color(0xFF8E9AB5),
    backgroundType: BackgroundType.gradient,
    gradientColors: [Color(0xFF0A0E1A), Color(0xFF0F1B33), Color(0xFF142847)],
  );

  /// Exemplo de tema com imagem de fundo.
  /// Para usar: coloque o arquivo em assets/backgrounds/ e registre no
  /// pubspec.yaml (faremos isso quando você tiver a imagem).
  static const AppThemeConfig customImage = AppThemeConfig(
    id: 'custom_image',
    name: 'Imagem Personalizada',
    background: Color(0xFF000000),
    surface: Color(0xFF1A1625),
    surfaceLight: Color(0xFF252033),
    primary: Color(0xFF7B2FF7),
    accent: Color(0xFFE94BFF),
    textPrimary: Color(0xFFF5F3FA),
    textSecondary: Color(0xFFA9A3B8),
    backgroundType: BackgroundType.image,
    backgroundImageAsset: 'assets/backgrounds/custom_bg.jpg',
  );

  static const List<AppThemeConfig> all = [darkPurple, darkBlue, customImage];

  static AppThemeConfig byId(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => darkPurple);
  }
}