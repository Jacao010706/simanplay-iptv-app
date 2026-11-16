// Versão de loja (Google Play / Amazon): o Sofae é só um player.
// Rodar com a variante:  flutter test test/loja_player_test.dart --flavor play
// (sem --flavor os testes são pulados: o APK do painel continua com licença e aparelho).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simanplay_iptv/core/lista_demo.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/core/versao.dart';
import 'package:simanplay_iptv/screens/activation_screen_v3.dart';
import 'package:simanplay_iptv/screens/device_home_screen.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/screens/inicio_loja_screen.dart';

/// Textos de pagamento, cobrança, revenda ou conta que não podem aparecer na loja.
const _proibidos = [
  'PIX', 'Pix', 'Pagar', 'pagamento', 'grátis', 'assinatura', 'Assinatura', 'assine',
  'plano', 'R\$', 'revend', 'WhatsApp', 'suporte', 'MAC', 'Chave do aparelho', 'provedor',
];

List<String> _textosNaTela() => [
      for (final e in find.byType(Text).evaluate())
        ((e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? ''),
    ];

Future<void> _tela(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: w));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // Só na variante de loja (--flavor play)
  const pular = !Loja.play;

  testWidgets('abre direto na tela de lista: só Xtream e M3U, demonstração, sem MAC nem conta', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _tela(tester, const InicioLoja());
    expect(find.byType(ActivationScreen), findsOneWidget);
    expect(find.byType(DeviceHomeScreen), findsNothing);
    expect(find.text('Xtream'), findsOneWidget);
    expect(find.text('URL M3U'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(2), reason: 'sem a aba de conta');
    expect(find.byKey(const Key('aviso_player')), findsOneWidget);
    expect(find.byKey(const Key('abrir_demo')), findsOneWidget);
    expect(find.text(versaoApp), findsOneWidget);
    expect(versaoApp, startsWith('Sofae v1.1.0+'));
    final textos = _textosNaTela();
    for (final p in _proibidos) {
      expect(textos.where((t) => t.contains(p)), isEmpty, reason: 'texto proibido na loja: "$p"');
    }
  }, skip: pular);

  testWidgets('aba M3U também sem textos de cobrança', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _tela(tester, const InicioLoja());
    await tester.tap(find.text('URL M3U'));
    await tester.pump(const Duration(milliseconds: 300));
    final textos = _textosNaTela();
    for (final p in _proibidos) {
      expect(textos.where((t) => t.contains(p)), isEmpty, reason: 'texto proibido na loja: "$p"');
    }
  }, skip: pular);

  testWidgets('com uma lista salva, entra direto nela (sem licença no caminho)', (tester) async {
    SharedPreferences.setMockInitialValues({'session': jsonEncode(ListaDemo.sessao().toJson())});
    await _tela(tester, const InicioLoja());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(ActivationScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }, skip: pular);

  testWidgets('ao sair da lista volta para a tela de lista, sem entrar sozinho', (tester) async {
    SharedPreferences.setMockInitialValues({'session': jsonEncode(ListaDemo.sessao().toJson())});
    await _tela(tester, const InicioLoja(autoEnter: false));
    expect(find.byType(ActivationScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  }, skip: pular);

  // Mesmos cuidados de layout da aba de conta do painel, na aba Xtream da loja
  for (final size in [const Size(360, 640), const Size(1280, 720), const Size(960, 540), const Size(853, 480)]) {
    for (final escala in [1.0, 1.15]) {
      testWidgets('Xtream: botão Conectar inteiro com erro na tela em ${size.width.toInt()}x${size.height.toInt()} (fonte x$escala)',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
        await tester.pump();
        final state = tester.state(find.byType(ActivationScreen)) as dynamic;
        state.debugSetError('O servidor recusou a conta agora. Verifique e tente de novo.');
        await tester.pump();
        final botao = find.widgetWithText(ElevatedButton, 'Conectar');
        expect(botao, findsOneWidget);
        await tester.ensureVisible(botao);
        await tester.pumpAndSettle();
        final b = tester.getRect(botao);
        final t = tester.getRect(find.text('Conectar'));
        expect(b.top, greaterThanOrEqualTo(0));
        expect(b.bottom, lessThanOrEqualTo(size.height), reason: 'botão cortado embaixo');
        expect(t.top, greaterThanOrEqualTo(b.top), reason: 'texto cortado em cima');
        expect(t.bottom, lessThanOrEqualTo(b.bottom), reason: 'texto cortado embaixo');
        expect(tester.takeException(), isNull);
      }, skip: pular);
    }
    for (final campo in ['URL do servidor', 'Usuário', 'Senha']) {
      testWidgets('Xtream: teclado aberto, campo "$campo" acima do teclado em ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const MaterialApp(home: ActivationScreen()));
        await tester.pump();
        await tester.tap(find.widgetWithText(TextField, campo));
        final teclado = size.height * 0.45;
        tester.view.viewInsets = FakeViewPadding(bottom: teclado);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        final visivel = size.height - teclado;
        final input = tester.getRect(find.widgetWithText(TextField, campo));
        expect(input.bottom, lessThanOrEqualTo(visivel), reason: 'campo atrás do teclado');
        expect(input.top, greaterThanOrEqualTo(0), reason: 'campo saiu pelo topo');
        expect(tester.takeException(), isNull);
      }, skip: pular);
    }
  }
}
