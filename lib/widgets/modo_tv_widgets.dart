import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_config.dart';
import '../core/modo_tv.dart';

/// Margem de segurança (overscan) em volta do app na TV. O player some com ela
/// ([ModoTv.telaCheia]) para o vídeo ir até a borda.
class MargemTv extends StatelessWidget {
  const MargemTv({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!ModoTv.tv) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: ModoTv.telaCheia,
      builder: (context, cheia, _) {
        if (cheia) return child;
        final mq = MediaQuery.of(context);
        final mx = mq.size.width * ModoTv.margemOverscan;
        final my = mq.size.height * ModoTv.margemOverscan;
        return ColoredBox(
          color: Color(AppConfig.backgroundColor),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mx, vertical: my),
            child: MediaQuery(
              data: mq.copyWith(size: Size(mq.size.width - 2 * mx, mq.size.height - 2 * my)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Na TV, o Voltar na tela inicial pergunta antes de sair ("Deseja sair do <app>?", foco em
/// Cancelar). No celular nada muda.
class ConfirmarSaida extends StatelessWidget {
  const ConfirmarSaida({super.key, required this.child});
  final Widget child;

  static const chaveSair = ValueKey('saida-sair');
  static const chaveCancelar = ValueKey('saida-cancelar');

  static Future<void> perguntar(BuildContext context) async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(AppConfig.surfaceColor),
        title: Text('Deseja sair do ${AppConfig.appName}?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            key: chaveSair,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            key: chaveCancelar,
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Color(AppConfig.primaryColor), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (sair == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!ModoTv.tv) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) perguntar(context);
      },
      child: child,
    );
  }
}

/// Tecla de favorito: Menu (☰, controle do Fire TV, que não tem teclas coloridas) ou a
/// amarela (outros controles). Envolve um item focável; a tecla chega aqui quando ele
/// está com o foco.
class TeclaFavorito extends StatelessWidget {
  const TeclaFavorito({super.key, required this.onFavorito, required this.child});
  final VoidCallback onFavorito;
  final Widget child;

  static bool ehFavorito(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.contextMenu || k == LogicalKeyboardKey.colorF2Yellow;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && ehFavorito(event.logicalKey)) {
          onFavorito();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
