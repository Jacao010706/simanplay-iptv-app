// Variante da Google Play (Loja.play). Rodar nas duas formas:
//   flutter test test/loja_play_test.dart
//   flutter test test/loja_play_test.dart --flavor play
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/screens/license_gate.dart';
import 'package:simanplay_iptv/services/license_service.dart';

const _vencido = LicenseState(
  deviceCode: 'abc',
  mac: '7A:3F:91:C2:0B:E4',
  deviceKey: '123456',
  status: 'expired',
  allowed: false,
  daysLeft: 0,
  until: null,
  payUrl: 'https://exemplo.invalid/pagar',
);

Future<void> _abrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: LicenseBlockedScreen(state: _vencido, onCheckAgain: () async {}),
  ));
  await tester.pump();
}

bool _temTexto(String trecho) => find
    .byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').contains(trecho))
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('acesso vencido: na Play sem preço, PIX, QR nem link; fora dela, com pagamento', (tester) async {
    await _abrir(tester);
    if (Loja.play) {
      for (final proibido in ['PIX', r'R$', 'Pagar', 'site', 'grátis', 'assin']) {
        expect(_temTexto(proibido), isFalse, reason: 'Play não pode mostrar "$proibido"');
      }
      expect(find.byType(QrImageView), findsNothing);
      expect(_temTexto(Loja.fraseProvedor), isTrue);
      expect(_temTexto('7A:3F:91:C2:0B:E4'), isTrue);
      expect(find.text('Verificar novamente'), findsOneWidget);
    } else {
      expect(_temTexto('PIX'), isTrue);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Pagar pelo site'), findsOneWidget);
    }
    // Para o Timer de 15 s da tela
    await tester.pumpWidget(const SizedBox());
  });
}
