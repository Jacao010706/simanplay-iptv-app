import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/screens/activation_screen_v3.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(1280, 720),
    const Size(960, 540),
    const Size(853, 480),
  ]) {
    for (final scale in [1.0, 1.15]) {
      testWidgets(
          'botao Entrar inteiro e texto sem corte em ${size.width.toInt()}x${size.height.toInt()} (fonte x$scale)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
        await tester.pump();

        // Caso que cortava: mensagem de erro embaixo dos campos
        final state = tester.state(find.byType(ActivationScreen)) as dynamic;
        state.debugSetError('Usuario ou senha invalidos. Verifique e tente de novo.');
        await tester.pump();

        final button = find.widgetWithText(ElevatedButton, 'Entrar');
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();

        final b = tester.getRect(button);
        final t = tester.getRect(find.text('Entrar'));
        expect(b.top, greaterThanOrEqualTo(0), reason: 'botao saiu pelo topo');
        expect(b.bottom, lessThanOrEqualTo(size.height), reason: 'botao cortado embaixo');
        expect(t.top, greaterThanOrEqualTo(b.top), reason: 'texto cortado em cima');
        expect(t.bottom, lessThanOrEqualTo(b.bottom), reason: 'texto cortado embaixo');
        expect(tester.takeException(), isNull); // sem overflow
      });
    }
  }
}
