import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Diferenças por plataforma num lugar só. O código é o mesmo para todas as marcas e
/// plataformas; o que é só do PC fica atrás de [Plataforma.windows].
class Plataforma {
  /// App de PC (Windows). Nos testes pode ser forçado com [forcarWindows].
  static bool get windows => forcarWindows ?? (!kIsWeb && Platform.isWindows);

  /// Só para testes: simula o Windows (true), outra plataforma (false) ou a real (null).
  static bool? forcarWindows;

  /// Sem telas e botões de pagamento (PIX, planos, QR de pagamento).
  static bool get semPagamento => windows;

  /// Atualizador interno de APK (baixar e instalar): só Android.
  static bool get atualizadorApk => !kIsWeb && Platform.isAndroid && forcarWindows != true;
}
