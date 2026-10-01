import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/screens/activation_screen_v3.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(1280, 720)]) {
    testWidgets('botão Entrar inteiro visível em ${size.width.toInt()}x${size.height.toInt()} (com mensagem de erro)',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
      await tester.pump();

      // Força o caso que cortava o botão: mensagem de erro embaixo dos campos
      final state = tester.state(find.byType(ActivationScreen)) as dynamic;
      state.debugSetError('Usuário ou senha inválidos. Verifique e tente de novo.');
      await tester.pump();

      final button = find.widgetWithText(ElevatedButton, 'Entrar');
      expect(button, findsOneWidget);
      final tabs = tester.getRect(find.byType(TabBarView));
      final rect = tester.getRect(button);
      expect(rect.bottom, lessThanOrEqualTo(tabs.bottom), reason: 'botão cortado embaixo');
      expect(rect.top, greaterThanOrEqualTo(tabs.top));
      expect(tester.takeException(), isNull); // sem "overflow"
    });
  }
}
