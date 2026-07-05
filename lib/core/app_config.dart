class AppConfig {
  // ============================================================
  // PERSONALIZACAO POR CLIENTE — edite aqui antes de gerar o APK
  // ============================================================

  // Nome do aplicativo
  static const String appName = 'SimanPlay IPTV';

  // Subtitulo na tela de login
  static const String appSubtitle = 'Conecte sua lista';

  // Versao do app
  static const String appVersion = 'v1.0';

  // Cor principal (hex ARGB: 0xFF + codigo hex da cor)
  // Exemplos:
  //   Roxo (padrao):  0xFFe94bff
  //   Azul Gremio:    0xFF0066CC
  //   Vermelho Inter: 0xFFCC0000
  //   Verde:          0xFF00c896
  //   Dourado:        0xFFFFAA00
  static const int primaryColor = 0xFFe94bff;

  // Cor de fundo principal
  static const int backgroundColor = 0xFF0d0b14;

  // Cor dos cards/paineis
  static const int surfaceColor = 0xFF1a1625;

  // URL do backend SimanPlay
  static const String backendUrl = 'https://web-production-d8671.up.railway.app';

  // ============================================================
  // LOGO PERSONALIZADA
  // ============================================================

  // true  = usa a imagem em assets/logo.png
  // false = usa o icone padrao de TV
  static const bool useCustomLogo = false;

  // Tamanho da logo na tela de login
  static const double logoSize = 100.0;

  // ============================================================
  // COR SECUNDARIA DO ICONE (quando useCustomLogo = false)
  // ============================================================

  // Icone padrao quando nao ha logo personalizada
  // Opcoes: Icons.live_tv, Icons.play_circle, Icons.tv, etc.
  // (mantenha como string do nome do icone para facil troca)
  static const bool usePlayIcon = false; // false = TV, true = Play Circle
  // ============================================================
  // TEMA DO APP
  // ============================================================
  // 1 = Grade de icones (padrao)
  // 2 = Netflix style (banner + linhas)
  // 3 = Sidebar lateral (estilo Smarters)
  static const int appTheme = 6;
}
