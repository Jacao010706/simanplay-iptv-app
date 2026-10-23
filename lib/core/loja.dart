import 'package:flutter/services.dart' show appFlavor;

import 'modo_tv.dart';

/// Variante de loja (Google Play): build com `--flavor play` (ver store/google-play/COMO_GERAR.md).
///
/// [play] é constante: no build da Play o compilador descarta o atualizador interno e as telas
/// de pagamento. A Play não aceita app que se atualiza sozinho nem pagamento por fora dentro do
/// app: sem preço, PIX, plano, QR, link do site nem aviso de teste grátis.
class Loja {
  static const bool play = appFlavor == 'play';

  /// Mesma frase da Sofae nas lojas de TV.
  static const fraseProvedor = ModoTv.fraseProvedor;

  /// Telas sem pagamento: o build da Play ou a Sofae (com.sofae.app) instalada numa TV
  /// (Fire TV e lojas de TV, que também não aceitam pagamento por fora).
  static bool get semPagamento => play || ModoTv.sofaeTv;
}
