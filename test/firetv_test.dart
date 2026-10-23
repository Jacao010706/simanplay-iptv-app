// Fire TV / modo TV: telas do Sofae sem pagamento, saída com confirmação, tecla de favorito
// (Menu ☰ / amarela), tela inicial de 4 blocos pelo controle e layout de TV sem estouro.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/core/modo_tv.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/screens/device_home_screen.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/screens/home_tv_screen.dart';
import 'package:simanplay_iptv/screens/license_gate.dart';
import 'package:simanplay_iptv/services/license_service.dart';
import 'package:simanplay_iptv/widgets/modo_tv_widgets.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

final _futuro = DateTime.now().toUtc().add(const Duration(days: 5));
LicenseState _lic({bool allowed = true, String status = 'trial'}) => LicenseState(
      deviceCode: 'X1',
      mac: 'AA:BB:CC:DD:EE:07',
      deviceKey: '777777',
      status: status,
      allowed: allowed,
      daysLeft: allowed ? 5 : 0,
      until: allowed ? _futuro : null,
      payUrl: 'https://exemplo.invalid/app',
    );

/// Nada de site, pagamento ou teste grátis em nenhum texto da tela.
final _proibido = RegExp(r'vercel\.app|/dispositivo|/app\b|PIX|R\$|plano|assin|renovar|Pagar|Teste grátis|QR|câmera',
    caseSensitive: false);

List<String> _textos(WidgetTester tester) => [
      ...tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? t.textSpan?.toPlainText() ?? ''),
      ...tester.widgetList<SelectableText>(find.byType(SelectableText)).map((t) => t.data ?? ''),
    ];

void _telaTv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0; // 960x540 lógico, como no Fire TV Stick
  addTearDown(tester.view.reset);
}

/// O mesmo envelope do main.dart na TV: texto maior, margem de overscan e anel de foco.
Widget _app(Widget home) => MaterialApp(
      shortcuts: appShortcuts,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: ModoTv.tv ? const TextScaler.linear(ModoTv.escalaTexto) : mq.textScaler),
          child: MargemTv(child: FocusRing(child: child!)),
        );
      },
      home: home,
    );

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _telaAparelho(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'device_playlists_cache': jsonEncode([])});
  LicenseService.current = _lic();
  await tester.pumpWidget(_app(const DeviceHomeScreen(autoEnter: false)));
  // Listas: o pedido ao backend falha no teste e cai no cache (vazio)
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump();
  await tester.pump();
}

Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox()); // encerra os timers das telas
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() {
    ModoTv.debugDefinir();
    LicenseService.current = null;
  });

  group('tela do aparelho', () {
    testWidgets('Sofae na TV: só MAC, chave e a frase do provedor; sem QR, site nem teste grátis', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true, pacote: ModoTv.pacoteSofae);
      await _telaAparelho(tester);
      final textos = _textos(tester);
      expect(textos, contains('AA:BB:CC:DD:EE:07'));
      expect(textos, contains('777777'));
      expect(find.text(ModoTv.fraseProvedor), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      final ruins = textos.where(_proibido.hasMatch).toList();
      expect(ruins, isEmpty, reason: 'textos proibidos: $ruins');
      expect(textos.any((t) => t.contains('Nenhuma lista liberada ainda')), isTrue);
      await _fechar(tester);
    });

    testWidgets('outra marca na TV: continua com site, QR e teste grátis', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true, pacote: 'com.revenda.exemplo');
      await _telaAparelho(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(_textos(tester).any((t) => t.contains('vercel.app/dispositivo')), isTrue);
      expect(_textos(tester).any((t) => t.startsWith('Teste grátis')), isTrue);
      expect(find.text(ModoTv.fraseProvedor), findsNothing);
      await _fechar(tester);
    }, skip: Loja.play); // na Play não há site, QR nem pagamento em nenhum aparelho

    testWidgets('Sofae no celular: continua com site e QR', (tester) async {
      ModoTv.debugDefinir(tv: false, pacote: ModoTv.pacoteSofae);
      await _telaAparelho(tester);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(ModoTv.fraseProvedor), findsNothing);
      await _fechar(tester);
    }, skip: Loja.play); // na Play não há site, QR nem pagamento em nenhum aparelho
  });

  group('acesso vencido', () {
    testWidgets('Sofae na TV: sem PIX, preço, QR nem botão de pagamento; foco em Verificar', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true, pacote: ModoTv.pacoteSofae);
      var verificou = 0;
      await tester.pumpWidget(_app(LicenseBlockedScreen(
          state: _lic(allowed: false, status: 'expired'), onCheckAgain: () async => verificou++)));
      await tester.pump();
      final textos = _textos(tester);
      expect(find.byType(QrImageView), findsNothing);
      final ruins = textos.where(_proibido.hasMatch).toList();
      expect(ruins, isEmpty, reason: 'textos proibidos: $ruins');
      expect(textos.any((t) => t.contains(ModoTv.fraseProvedor)), isTrue);
      expect(textos, contains('AA:BB:CC:DD:EE:07'));
      // OK do controle aciona "Verificar novamente", que já começa com o foco
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(verificou, 1);
      await _fechar(tester);
    });

    testWidgets('outra marca na TV: tela de pagamento continua igual', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true, pacote: 'com.revenda.exemplo');
      await tester.pumpWidget(_app(LicenseBlockedScreen(
          state: _lic(allowed: false, status: 'expired'), onCheckAgain: () async {})));
      await tester.pump();
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Pagar pelo site'), findsOneWidget);
      await _fechar(tester);
    }, skip: Loja.play); // na Play não há site, QR nem pagamento em nenhum aparelho
  });

  group('Voltar na tela inicial', () {
    late List<String> chamadas;
    setUp(() {
      chamadas = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        chamadas.add(call.method);
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    Widget tela() => _app(const ConfirmarSaida(child: Scaffold(body: Center(child: Text('inicio')))));
    final dialogo = find.textContaining('Deseja sair do');

    testWidgets('na TV pergunta antes de sair, com foco em Cancelar; Voltar fecha a pergunta', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true);
      await tester.pumpWidget(tela());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(dialogo, findsOneWidget);
      final foco = FocusManager.instance.primaryFocus?.context;
      expect(foco?.findAncestorWidgetOfExactType<TextButton>()?.key, ConfirmarSaida.chaveCancelar);

      await tester.binding.handlePopRoute(); // Voltar com a pergunta aberta: só fecha
      await tester.pumpAndSettle();
      expect(dialogo, findsNothing);
      expect(chamadas, isNot(contains('SystemNavigator.pop')));

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tecla(tester, LogicalKeyboardKey.select); // OK em Cancelar
      await tester.pumpAndSettle();
      expect(dialogo, findsNothing);
      expect(chamadas, isNot(contains('SystemNavigator.pop')));
    });

    testWidgets('na TV, Sair encerra o app', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true);
      await tester.pumpWidget(tela());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tecla(tester, LogicalKeyboardKey.arrowLeft); // Cancelar -> Sair
      await _tecla(tester, LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(chamadas, contains('SystemNavigator.pop'));
    });

    testWidgets('no celular não pergunta', (tester) async {
      ModoTv.debugDefinir(tv: false);
      await tester.pumpWidget(tela());
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(dialogo, findsNothing);
    });
  });

  testWidgets('tecla de favorito: Menu (☰) e amarela favoritam o item com foco; setas não', (tester) async {
    var favoritou = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TeclaFavorito(
          onFavorito: () => favoritou++,
          child: InkWell(autofocus: true, onTap: () {}, child: const SizedBox(width: 200, height: 60)),
        ),
      ),
    ));
    await tester.pump();
    await _tecla(tester, LogicalKeyboardKey.contextMenu);
    expect(favoritou, 1);
    // O simulador do teste não conhece a tecla física da amarela: vale a tecla lógica
    await tester.sendKeyEvent(LogicalKeyboardKey.colorF2Yellow, physicalKey: PhysicalKeyboardKey.keyY);
    await tester.pump();
    expect(favoritou, 2);
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(favoritou, 2);
  });

  // Na TV (todas as marcas): texto 1,25x e margem de overscan em 960x540 sem estourar o layout
  for (var tema = 1; tema <= 6; tema++) {
    testWidgets('modo TV: tema $tema da tela inicial cabe na tela com texto maior e margem', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true, pacote: 'com.revenda.exemplo');
      SharedPreferences.setMockInitialValues({});
      final sessao = AppSession.simanplay(username: 'm3u', password: '', primaryM3uUrl: '');
      await tester.pumpWidget(_app(HomeScreen(session: sessao, debugTheme: tema)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'tema $tema estourou o layout na TV');
      await _fechar(tester);
    });
  }

  group('tela inicial de 4 blocos (Sofae na TV)', () {
    final sessao = AppSession.simanplay(username: 'm3u', password: '', primaryM3uUrl: '');
    double escala(WidgetTester tester, String bloco) => tester
        .widget<AnimatedScale>(find.descendant(of: find.byKey(ValueKey('home-tv-$bloco')), matching: find.byType(AnimatedScale)))
        .scale;

    testWidgets('setas andam pelos blocos com destaque, baixo chega em Sair, OK abre a tela', (tester) async {
      _telaTv(tester);
      ModoTv.debugDefinir(tv: true, pacote: ModoTv.pacoteSofae);
      var saiu = 0;
      await tester.pumpWidget(_app(HomeTvScreen(session: sessao, onLogout: () async => saiu++)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TV ao Vivo'), findsOneWidget);
      expect(find.text('Favoritos'), findsOneWidget);
      expect(escala(tester, 'TV ao Vivo'), greaterThan(1), reason: 'primeiro bloco sem foco inicial');

      // Direita: Filmes; OK abre; Voltar volta para a tela inicial
      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      expect(escala(tester, 'Filmes'), greaterThan(1), reason: 'seta direita não chegou em Filmes');
      await _tecla(tester, LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.byType(TelaConteudoTv), findsOneWidget);
      expect(find.text('Filmes não disponíveis para esta playlist.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TelaConteudoTv), findsNothing);

      for (final b in ['Séries', 'Favoritos']) {
        await _tecla(tester, LogicalKeyboardKey.arrowRight);
        expect(escala(tester, b), greaterThan(1), reason: 'seta direita não chegou em $b');
        expect(find.byKey(FocusRing.ringKey), findsOneWidget);
      }
      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(saiu, 1, reason: 'seta para baixo + OK não acionou "Trocar lista / Sair"');
    });
  });
}
