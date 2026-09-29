// AUTO-GERADO por scripts/generate_app_config.py no build do white-label.
// Para testes locais pode ser editado; o build sobrescreve este arquivo.
class AppConfig {
  static const String appName = 'SimanPlay IPTV';
  static const String appSubtitle = 'Conecte sua lista';
  static const String appVersion = 'v1.0';

  // Cores (ARGB)
  static const int primaryColor = 0xFFE94BFF;
  static const int backgroundColor = 0xFF0D0B14;
  static const int surfaceColor = 0xFF1A1625;

  // Backend SimanPlay
  static const String backendUrl = 'https://web-production-d8671.up.railway.app';

  // Banner de fundo da tela de login (vazio = sem banner)
  static const String bannerUrl = '';

  // Logo do revendedor (URL). Vazio = ícone padrão.
  static const String logoUrl = '';
  static const bool useCustomLogo = false;
  static const double logoSize = 100.0;
  static const bool usePlayIcon = false; // false = TV, true = Play Circle

  // Tema da home: 1 Grade, 2 Netflix, 3 Sidebar, 4 IBO Banner+Grade,
  // 5 IBO Sidebar Escura, 6 IBO Banner Tela Cheia
  static const int appTheme = 6;

  static const String resellerId = '';
  static const String resellerUsername = '';
}
