import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simanplay_iptv/core/plataforma.dart';
import 'package:simanplay_iptv/services/atualizacao_windows.dart';
import 'package:simanplay_iptv/widgets/pc_input.dart';
import 'package:simanplay_iptv/widgets/player_controls.dart';

Widget _player({required VoidCallback onPlayPause, VoidCallback? onFullscreen, bool fullscreen = false}) =>
    MaterialApp(
      home: Scaffold(
        body: PlayerRemoteControls(
          title: 'Canal',
          paused: false,
          onPlayPause: onPlayPause,
          onBack: () {},
          onFullscreen: onFullscreen,
          fullscreen: fullscreen,
          child: const SizedBox.expand(),
        ),
      ),
    );

void main() {
  tearDown(() => Plataforma.forcarWindows = null);

  group('Aviso de nova versão no Windows', () {
    test('só avisa quando o build do JSON é maior que o instalado', () {
      final json = {'version': '1.0.0+12', 'url': 'https://exemplo.com/Sofae.zip', 'obrigatoria': false};
      expect(VersaoWindows.seMaisNova(json, 11)?.build, 12);
      expect(VersaoWindows.seMaisNova(json, 12), isNull);
      expect(VersaoWindows.seMaisNova(json, 13), isNull);
    });

    test('build local (0), JSON inválido, sem build ou URL sem https: não avisa', () {
      final ok = {'version': '1.0.0+12', 'url': 'https://exemplo.com/a.zip'};
      expect(VersaoWindows.seMaisNova(ok, 0), isNull);
      expect(VersaoWindows.seMaisNova('lixo', 5), isNull);
      expect(VersaoWindows.seMaisNova({'version': '1.0.0', 'url': 'https://exemplo.com/a.zip'}, 5), isNull);
      expect(VersaoWindows.seMaisNova({'version': '1.0.0+12', 'url': 'http://exemplo.com/a.zip'}, 5), isNull);
    });

    test('obrigatoria só quando vier true', () {
      expect(VersaoWindows.seMaisNova({'version': '1+9', 'url': 'https://e.com/a', 'obrigatoria': true}, 1)!.obrigatoria, isTrue);
      expect(VersaoWindows.seMaisNova({'version': '1+9', 'url': 'https://e.com/a', 'obrigatoria': 'sim'}, 1)!.obrigatoria, isFalse);
    });

    test('sem URL configurada ou com falha de rede: devolve null sem lançar erro', () async {
      final quebrado = MockClient((_) async => throw http.ClientException('sem rede'));
      expect(await AtualizacaoWindows.buscar(client: quebrado), isNull);
      final ok = MockClient((_) async => http.Response(jsonEncode({'version': '1+99', 'url': 'https://e.com/a'}), 200));
      // kWindowsVersionUrl vazio (padrão das outras marcas): nem chama a rede
      expect(await AtualizacaoWindows.buscar(client: ok), isNull);
    });
  });

  group('Teclas do PC no player', () {
    testWidgets('Windows: Espaço pausa, F alterna tela cheia, Esc sai da tela cheia', (tester) async {
      Plataforma.forcarWindows = true;
      var pausas = 0, telaCheia = 0;
      await tester.pumpWidget(_player(onPlayPause: () => pausas++, onFullscreen: () => telaCheia++, fullscreen: true));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(pausas, 1);
      expect(telaCheia, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('fora do Windows (Android/TV): Espaço e F não fazem nada', (tester) async {
      Plataforma.forcarWindows = false;
      var pausas = 0, telaCheia = 0;
      await tester.pumpWidget(_player(onPlayPause: () => pausas++, onFullscreen: () => telaCheia++));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      expect(pausas, 0);
      expect(telaCheia, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('Esc/Backspace voltam no PC', () {
    Widget app(GlobalKey<NavigatorState> nav) => MaterialApp(
          navigatorKey: nav,
          builder: (_, child) => AtalhosPc(navigatorKey: nav, child: child!),
          home: Builder(
            builder: (ctx) => ElevatedButton(
              autofocus: true,
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) => const Scaffold(body: TextField(key: Key('campo'), autofocus: true)),
              )),
              child: const Text('abrir'),
            ),
          ),
        );

    testWidgets('Esc volta; Backspace num campo de texto apaga em vez de voltar', (tester) async {
      Plataforma.forcarWindows = true;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(nav));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('campo')), 'ab');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campo')), findsOneWidget, reason: 'Backspace no campo não pode voltar');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campo')), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('fora do Windows o atalho não existe', (tester) async {
      Plataforma.forcarWindows = false;
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(nav));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campo')), findsOneWidget);
    });
  });
}
