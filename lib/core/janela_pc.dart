import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app_config.dart';
import 'plataforma.dart';

/// Janela do app no PC (Windows): tamanho, título e tela cheia. Fora do Windows não faz nada.
class JanelaPc {
  static const Size tamanhoInicial = Size(1280, 720);
  static const Size tamanhoMinimo = Size(960, 540);

  /// Chamado no main(), antes do runApp. Nunca impede o app de abrir.
  static Future<void> iniciar() async {
    if (!Plataforma.windows) return;
    try {
      await windowManager.ensureInitialized();
      const opcoes = WindowOptions(
        size: tamanhoInicial,
        minimumSize: tamanhoMinimo,
        center: true,
        title: AppConfig.appName,
      );
      await windowManager.waitUntilReadyToShow(opcoes, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {}
  }

  static Future<bool> telaCheia() async {
    if (!Plataforma.windows) return false;
    try {
      return await windowManager.isFullScreen();
    } catch (_) {
      return false;
    }
  }

  static Future<void> definirTelaCheia(bool ligar) async {
    if (!Plataforma.windows) return;
    try {
      await windowManager.setFullScreen(ligar);
    } catch (_) {}
  }

  /// Liga/desliga a tela cheia e devolve o novo estado.
  static Future<bool> alternarTelaCheia() async {
    final novo = !await telaCheia();
    await definirTelaCheia(novo);
    return novo;
  }
}
