import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/screens/activation_screen_v3.dart';
import 'package:simanplay_iptv/widgets/tv_keyboard_dialog.dart';

/// O botao "Entrar" esta com o foco do controle remoto?
bool _entrarFocado(WidgetTester tester) =>
    Focus.of(tester.element(find.text('Entrar')), createDependency: false)
        .hasPrimaryFocus;

/// Focus navegavel do campo no modo TV (o que tem focusNode e trata teclas).
FocusNode _campoTv(WidgetTester tester, String label) {
  final focus = tester
      .widgetList<Focus>(find.ancestor(
          of: find.text(label), matching: find.byType(Focus)))
      .firstWhere((f) => f.focusNode != null && f.child is Builder);
  return focus.focusNode!;
}

Future<void> _abrir(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
  await tester.pump();
}

Future<void> _esperar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(960, 540), const Size(1280, 720), const Size(853, 480)]) {
    final tam = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('teclado do sistema: seta para baixo na Senha chega no Entrar ($tam)',
        (tester) async {
      await _abrir(tester, size);
      await tester.tap(find.widgetWithText(TextField, 'Senha'));
      await _esperar(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Senha'), '1234');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _esperar(tester);
      expect(_entrarFocado(tester), isTrue,
          reason: 'controle nao chegou no botao Entrar');
    });

    testWidgets('teclado do sistema: do Usuario desce ate o Entrar ($tam)',
        (tester) async {
      await _abrir(tester, size);
      await tester.tap(find.widgetWithText(TextField, 'Usuário'));
      await _esperar(tester);
      for (var i = 0; i < 3 && !_entrarFocado(tester); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await _esperar(tester);
      }
      expect(_entrarFocado(tester), isTrue);
    });

    testWidgets('modo TV: seta para baixo na Senha chega no Entrar ($tam)',
        (tester) async {
      await _abrir(tester, size);
      (tester.state(find.byType(ActivationScreen)) as dynamic).debugSetTv(true);
      await tester.pump();

      _campoTv(tester, 'Senha').requestFocus();
      await _esperar(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await _esperar(tester);
      expect(_entrarFocado(tester), isTrue,
          reason: 'controle nao chegou no botao Entrar (modo TV)');
    });

    testWidgets('modo TV: depois de digitar a senha o foco vai para o Entrar ($tam)',
        (tester) async {
      await _abrir(tester, size);
      (tester.state(find.byType(ActivationScreen)) as dynamic).debugSetTv(true);
      await tester.pump();

      _campoTv(tester, 'Senha').requestFocus();
      await _esperar(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _esperar(tester);
      expect(find.byType(TvKeyboardDialog), findsOneWidget,
          reason: 'OK no campo nao abriu o teclado da TV');

      Navigator.of(tester.element(find.byType(TvKeyboardDialog))).pop('1234');
      await _esperar(tester);
      expect(_entrarFocado(tester), isTrue,
          reason: 'depois do teclado o foco nao foi para o Entrar');
    });
  }
}
