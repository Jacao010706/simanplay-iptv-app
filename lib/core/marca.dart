import 'package:flutter/widgets.dart';

import 'app_config.dart';
import 'loja.dart';

/// Marca exibida no app.
///
/// APK do painel: a do revendedor, que o workflow grava no [AppConfig] (valores iguais aos de
/// antes; tudo é constante). Google Play: sempre a Sofae, sem depender do workflow nem de logo
/// baixado da internet (o logo vai junto no app, só no flavor `play`).
class Marca {
  static const String appName = Loja.play ? 'Sofae' : AppConfig.appName;
  static const String appSubtitle = Loja.play ? '' : AppConfig.appSubtitle;

  // Cores (ARGB). Sofae: as mesmas do /tv e da versão Fire TV.
  static const int primaryColor = Loja.play ? 0xFFFF8A1A : AppConfig.primaryColor;
  static const int backgroundColor = Loja.play ? 0xFF1A0B33 : AppConfig.backgroundColor;
  static const int surfaceColor = Loja.play ? 0xFF2E1F4D : AppConfig.surfaceColor;

  static const String bannerUrl = Loja.play ? '' : AppConfig.bannerUrl;
  static const bool useCustomLogo = Loja.play || AppConfig.useCustomLogo;
  static const int appTheme = Loja.play ? 6 : AppConfig.appTheme;

  /// Logo da Sofae no app da Play (asset declarado só para o flavor `play` no pubspec).
  static const String logoAsset = 'assets/play/sofae_logo.png';

  static Widget logo({required double height, required ImageErrorWidgetBuilder errorBuilder}) => Loja.play
      ? Image.asset(logoAsset, height: height, errorBuilder: errorBuilder)
      : Image.network(AppConfig.logoUrl, height: height, errorBuilder: errorBuilder);
}
