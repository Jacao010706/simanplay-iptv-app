// Versão de loja: as abas Xtream e M3U (as únicas da loja) com teclado aberto, controle remoto
// da TV e 4 resoluções. Mesmos cuidados que a aba de conta tem no APK do painel
// (login_layout, login_keyboard, login_dpad).
// Rodar com a variante:  flutter test test/loja_teclado_controle_test.dart --flavor play
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/screens/activation_screen_v3.dart';
import 'package:simanplay_iptv/widgets/tv_keyboard_dialog.dart';

/// Aba da loja: nome na barra de abas, campos (de cima para baixo) e botão.
class _Aba {
  final String nome;
  final List<String> campos;
  final String botao;
  const _Aba(this.nome, this.campos, this.botao);
  String get ultimoCampo => campos.last;
}

const _abas = [
  _Aba('Xtream', ['URL do servidor', 'Usuário', 'Senha'], 'Conectar'),
  _Aba('URL M3U', ['https://servidor.com/lista.m3u'], 'Carregar lista'),
];

const _tamanhos = [Size(360, 640), Size(1280, 720), Size(960, 540), Size(853, 480)];

Future<void> _abrir(WidgetTester tester, Size size, _Aba aba, {double escala = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
  await tester.pump();
  if (aba.nome != 'Xtream') {
    await tester.tap(find.text(aba.nome));
    await _esperar(tester);
  }
}

Future<void> _esperar(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

/// O botão da aba está com o foco do controle remoto?
bool _botaoFocado(WidgetTester tester, _Aba aba) =>
    Focus.of(tester.element(find.text(aba.botao)), createDependency: false).hasPrimaryFocus;

/// Focus navegável do campo no modo TV (o que tem focusNode e trata teclas).
FocusNode _campoTv(WidgetTester tester, String label) => tester
    .widgetList<Focus>(find.ancestor(of: find.text(label), matching: find.byType(Focus)))
    .firstWhere((f) => f.focusNode != null && f.child is Builder)
    .focusNode!;

void main() {
  // Só na variante de loja (--flavor play)
  const pular = !Loja.play;

  for (final aba in _abas) {
    for (final size in _tamanhos) {
      final tam = '${size.width.toInt()}x${size.height.toInt()}';

      for (final escala in [1.0, 1.15]) {
        testWidgets('${aba.nome}: botão "${aba.botao}" inteiro com erro na tela em $tam (fonte x$escala)', (tester) async {
          await _abrir(tester, size, aba, escala: escala);
          (tester.state(find.byType(ActivationScreen)) as dynamic)
              .debugSetError('O servidor recusou a conta agora. Verifique e tente de novo.');
          await tester.pump();
          final botao = find.widgetWithText(ElevatedButton, aba.botao);
          expect(botao, findsOneWidget);
          await tester.ensureVisible(botao);
          await tester.pumpAndSettle();
          final b = tester.getRect(botao);
          final t = tester.getRect(find.text(aba.botao));
          expect(b.top, greaterThanOrEqualTo(0), reason: 'botão saiu pelo topo');
          expect(b.bottom, lessThanOrEqualTo(size.height), reason: 'botão cortado embaixo');
          expect(t.top, greaterThanOrEqualTo(b.top), reason: 'texto cortado em cima');
          expect(t.bottom, lessThanOrEqualTo(b.bottom), reason: 'texto cortado embaixo');
          expect(tester.takeException(), isNull, reason: 'overflow');
        }, skip: pular);
      }

      for (final campo in aba.campos) {
        testWidgets('${aba.nome}: teclado aberto, campo "$campo" e botão acima do teclado em $tam', (tester) async {
          await _abrir(tester, size, aba);
          await tester.tap(find.widgetWithText(TextField, campo));
          final teclado = size.height * 0.45; // teclado ocupando ~45% da altura
          tester.view.viewInsets = FakeViewPadding(bottom: teclado);
          await tester.pump(const Duration(milliseconds: 400)); // o app espera o teclado abrir
          await tester.pumpAndSettle();
          final visivel = size.height - teclado;
          final input = tester.getRect(find.widgetWithText(TextField, campo));
          expect(input.bottom, lessThanOrEqualTo(visivel), reason: 'campo atrás do teclado');
          expect(input.top, greaterThanOrEqualTo(0), reason: 'campo saiu pelo topo');
          if (campo == aba.ultimoCampo) {
            final botao = tester.getRect(find.widgetWithText(ElevatedButton, aba.botao));
            expect(botao.bottom, lessThanOrEqualTo(visivel), reason: 'botão atrás do teclado');
          }
          expect(tester.takeException(), isNull);
        }, skip: pular);
      }

      testWidgets('${aba.nome}: teclado do sistema, seta para baixo no último campo chega no botão ($tam)', (tester) async {
        await _abrir(tester, size, aba);
        await tester.tap(find.widgetWithText(TextField, aba.ultimoCampo));
        await _esperar(tester);
        await tester.enterText(find.widgetWithText(TextField, aba.ultimoCampo), 'x');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await _esperar(tester);
        expect(_botaoFocado(tester, aba), isTrue, reason: 'controle não chegou no botão');
      }, skip: pular);

      testWidgets('${aba.nome}: teclado do sistema, do primeiro campo desce até o botão ($tam)', (tester) async {
        await _abrir(tester, size, aba);
        await tester.tap(find.widgetWithText(TextField, aba.campos.first));
        await _esperar(tester);
        for (var i = 0; i < aba.campos.length + 2 && !_botaoFocado(tester, aba); i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await _esperar(tester);
        }
        expect(_botaoFocado(tester, aba), isTrue);
      }, skip: pular);

      testWidgets('${aba.nome}: modo TV, seta para baixo no último campo chega no botão ($tam)', (tester) async {
        await _abrir(tester, size, aba);
        (tester.state(find.byType(ActivationScreen)) as dynamic).debugSetTv(true);
        await tester.pump();
        _campoTv(tester, aba.ultimoCampo).requestFocus();
        await _esperar(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await _esperar(tester);
        expect(_botaoFocado(tester, aba), isTrue, reason: 'controle não chegou no botão (modo TV)');
      }, skip: pular);

      testWidgets('${aba.nome}: modo TV, depois do teclado da TV o foco vai para o botão ($tam)', (tester) async {
        await _abrir(tester, size, aba);
        (tester.state(find.byType(ActivationScreen)) as dynamic).debugSetTv(true);
        await tester.pump();
        _campoTv(tester, aba.ultimoCampo).requestFocus();
        await _esperar(tester);
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await _esperar(tester);
        expect(find.byType(TvKeyboardDialog), findsOneWidget, reason: 'OK no campo não abriu o teclado da TV');
        Navigator.of(tester.element(find.byType(TvKeyboardDialog))).pop('https://exemplo.invalid/l.m3u');
        await _esperar(tester);
        expect(_botaoFocado(tester, aba), isTrue, reason: 'depois do teclado o foco não foi para o botão');
      }, skip: pular);
    }
  }
}
