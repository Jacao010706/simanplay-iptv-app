import 'package:flutter/services.dart' show appFlavor;

/// Variante de loja (Google Play): build com `--flavor play` (ver store/google-play/COMO_GERAR.md).
///
/// [play] é constante: no build da Play o compilador descarta o atualizador interno e as telas
/// de pagamento. A Play não aceita app que se atualiza sozinho nem pagamento por fora dentro do
/// app: sem preço, PIX, plano, QR, link do site nem aviso de teste grátis.
class Loja {
  static const bool play = appFlavor == 'play';

  /// Mesma frase da Sofae nas lojas de TV (feature/firetv, ModoTv.fraseProvedor).
  static const fraseProvedor = 'Informe este código ao seu provedor para liberar o acesso.';
}
