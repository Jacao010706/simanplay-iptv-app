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
}
