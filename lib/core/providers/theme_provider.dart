import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Gerencia qual tema está ativo no app inteiro.
/// Qualquer widget que usar `Provider.of<ThemeProvider>` ou `context.watch`
/// será reconstruído automaticamente quando o tema mudar.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'selected_theme_id';

  AppThemeConfig _currentTheme = AppThemes.darkPurple;

  AppThemeConfig get currentTheme => _currentTheme;
  ThemeData get themeData => _currentTheme.toThemeData();

  /// Carrega o tema salvo nas preferências (chame isso ao iniciar o app).
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKey);
    if (savedId != null) {
      _currentTheme = AppThemes.byId(savedId);
      notifyListeners();
    }
  }

  /// Troca o tema ativo e salva a escolha para a próxima vez que abrir o app.
  Future<void> setTheme(AppThemeConfig theme) async {
    _currentTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, theme.id);
  }
}