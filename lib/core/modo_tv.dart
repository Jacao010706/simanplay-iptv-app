import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/tv_utils.dart';

/// Modo TV (Android TV, TV box, Fire TV) e o pacote do APK, lidos uma vez na abertura.
///
/// - [tv]: vale para todas as marcas (fonte maior, margem de overscan, Voltar pergunta
///   antes de sair).
/// - [sofaeTv]: Sofae (com.sofae.app) na TV. As lojas de TV (Amazon, LG, Samsung) não
///   aceitam pagamento fora delas dentro do app: sem preço, PIX, plano, QR, link do site nem
///   teste grátis. A tela do aparelho mostra só o código e [fraseProvedor].
class ModoTv {
  static bool tv = false;
  static String pacote = '';
  static const pacoteSofae = 'com.sofae.app';
  static const fraseProvedor = 'Informe este código ao seu provedor para liberar o acesso.';

  /// Texto maior na TV (lido a uns 3 m de distância).
  static const escalaTexto = 1.25;

  /// Margem de segurança (overscan) de cada lado da tela, em fração da largura/altura.
  static const margemOverscan = 0.03;

  /// true enquanto o player ocupa a tela: o vídeo vai até a borda, sem a margem.
  static final telaCheia = ValueNotifier<bool>(false);

  static const _canal = MethodChannel('primetv/device');

  static bool get sofaeTv => tv && pacote == pacoteSofae;

  static Future<void> iniciar() async {
    tv = await TvUtils.isAndroidTV();
    try {
      final info = await _canal.invokeMapMethod<String, dynamic>('apkInfo');
      pacote = (info?['package'] ?? '').toString();
    } catch (_) {
      pacote = '';
    }
  }

  /// Só para testes.
  @visibleForTesting
  static void debugDefinir({bool tv = false, String pacote = ''}) {
    ModoTv.tv = tv;
    ModoTv.pacote = pacote;
    telaCheia.value = false;
  }
}
