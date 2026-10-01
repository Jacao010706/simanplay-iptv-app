import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/screens/activation_screen_v3.dart';

void main() {
  // Teclado ocupando ~45% da altura, como nas TVs Android e celulares.
  for (final size in [const Size(360, 640), const Size(1280, 720)]) {
    for (final field in ['Usuário', 'Senha']) {
      testWidgets(
          'teclado aberto: campo "$field" e botão Entrar acima do teclado em ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
        await tester.pump();

        await tester.tap(find.widgetWithText(TextField, field));
        final keyboard = size.height * 0.45;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        // O app espera o teclado terminar de abrir (350 ms) antes de rolar.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final visibleBottom = size.height - keyboard;
        final button = tester.getRect(find.widgetWithText(ElevatedButton, 'Entrar'));
        final input = tester.getRect(find.widgetWithText(TextField, field));
        expect(button.bottom, lessThanOrEqualTo(visibleBottom - 12), reason: 'botão atrás do teclado (ou sem folga)');
        expect(input.bottom, lessThanOrEqualTo(visibleBottom), reason: 'campo atrás do teclado');
        expect(input.top, greaterThanOrEqualTo(0), reason: 'campo saiu pelo topo');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
