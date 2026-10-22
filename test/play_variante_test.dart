// Variante da Google Play: marca Sofae, sem Jogos do Dia, sem gravação e com a lista de
// demonstração. Rodar nas duas formas (cada teste confere a Play e também o APK do painel):
//   flutter test test/play_variante_test.dart
//   flutter test test/play_variante_test.dart --flavor play
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simanplay_iptv/core/app_config.dart';
import 'package:simanplay_iptv/core/lista_demo.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/core/marca.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/screens/device_home_screen.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/screens/live_tv_screen.dart';
import 'package:simanplay_iptv/services/xtream_service.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

void _telaTv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

/// Avisos de layout (overflow) e imagens de rede (sem internet no teste) não fazem parte daqui.
Future<void> _semRuido(Future<void> Function() corpo) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('overflowed') || s.contains('HTTP request failed') || s.contains('NetworkImage')) return;
    original?.call(d);
  };
  try {
    await corpo();
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('marca', () {
    test('Play é sempre Sofae; o painel continua com a marca do revendedor (AppConfig)', () {
      if (Loja.play) {
        expect(Marca.appName, 'Sofae');
        expect(Marca.primaryColor, 0xFFFF8A1A);
        expect(Marca.backgroundColor, 0xFF1A0B33);
        expect(Marca.surfaceColor, 0xFF2E1F4D);
        expect(Marca.useCustomLogo, isTrue);
        expect(Marca.bannerUrl, isEmpty);
      } else {
        expect(Marca.appName, AppConfig.appName);
        expect(Marca.primaryColor, AppConfig.primaryColor);
        expect(Marca.backgroundColor, AppConfig.backgroundColor);
        expect(Marca.surfaceColor, AppConfig.surfaceColor);
        expect(Marca.useCustomLogo, AppConfig.useCustomLogo);
        expect(Marca.bannerUrl, AppConfig.bannerUrl);
        expect(Marca.appTheme, AppConfig.appTheme);
      }
    });

    testWidgets('logo da Sofae vem do próprio app na Play (sem baixar da internet)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Marca.logo(height: 50, errorBuilder: (_, __, ___) => const Text('sem logo')),
      ));
      await tester.pump();
      final img = tester.widget<Image>(find.byType(Image));
      if (Loja.play) {
        expect(img.image, isA<AssetImage>());
        expect((img.image as AssetImage).assetName, Marca.logoAsset);
      } else {
        expect(img.image, isA<NetworkImage>());
      }
    });
  });

  for (var tema = 1; tema <= 6; tema++) {
    testWidgets('tema $tema: "Jogos" some na Play e continua no painel', (tester) async {
      _telaTv(tester);
      await _semRuido(() async {
        await tester.pumpWidget(MaterialApp(
          shortcuts: appShortcuts,
          builder: (c, child) => FocusRing(child: child!),
          home: HomeScreen(session: const AppSession(type: SessionType.simanplay), debugTheme: tema),
        ));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Jogos'), Loja.play ? findsNothing : findsWidgets, reason: 'tema $tema');
      });
    });
  }

  // Usa a lista de demonstração (sem rede), que só existe na Play; fora dela a tela de canais
  // é a mesma da main.
  testWidgets('TV ao Vivo na Play: sem "Minhas Gravações", "Gravar" nem "Agendar"', (tester) async {
    _telaTv(tester);
    await _semRuido(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: LiveTvScreen(session: ListaDemo.sessao())),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Demo 1 · Big Buck Bunny'), findsOneWidget, reason: 'a lista de canais carregou');
      expect(find.byTooltip('Minhas Gravações'), findsNothing);
      await tester.tap(find.text('Demo 1 · Big Buck Bunny'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Assistir'), findsOneWidget, reason: 'o painel do canal abriu');
      expect(find.text('Gravar'), findsNothing);
      expect(find.text('Agendar'), findsNothing);
    });
  }, skip: !Loja.play);

  group('lista de demonstração', () {
    test('só conteúdo livre: filmes abertos da Blender com licença CC, por HTTPS em hosts conhecidos', () {
      const hosts = {'upload.wikimedia.org', 'thumb.wikimedia.org', 'test-streams.mux.dev', 'demo.unified-streaming.com'};
      expect(ListaDemo.filmesInfo, hasLength(10));
      for (final f in ListaDemo.filmesInfo) {
        expect(f.licenca, startsWith('CC BY'), reason: f.titulo);
      }
      final urls = [
        for (final m in ListaDemo.filmes) ...[m.streamUrl, m.posterUrl!],
        for (final c in ListaDemo.canais) ...[c.streamUrl, c.logoUrl!],
      ];
      for (final u in urls) {
        final uri = Uri.parse(u);
        expect(uri.scheme, 'https', reason: u);
        expect(hosts, contains(uri.host), reason: u);
      }
      expect(ListaDemo.canais, hasLength(3));
      expect(Uri.parse(ListaDemo.host).host, endsWith('.invalid'), reason: 'o host da demo nunca pode resolver');
    });

    test('na Play responde no aparelho, sem rede; no painel o host da demo não tem nada especial', () async {
      final svc = XtreamService(host: ListaDemo.host, username: ListaDemo.usuario, password: ListaDemo.senha);
      if (Loja.play) {
        expect((await svc.authenticate())['user_info']['auth'], 1);
        final cats = await svc.getLiveCategories();
        final canais = await svc.getLiveStreams(cats.first.id, cats.first.name);
        expect(canais.map((c) => c.name), contains('Demo 1 · Big Buck Bunny'));
        final filmes = await svc.getAllMovies();
        expect(filmes.map((m) => m.name), containsAll(['Big Buck Bunny', 'Sintel', 'Tears of Steel']));
        expect(filmes.first.streamUrl, startsWith('https://upload.wikimedia.org/'));
        final info = await svc.getVodInfo(filmes.first.id);
        expect(info['info']['plot'], contains('Blender Foundation'));
        expect(await svc.getAllSeries(), isEmpty);
        expect((await svc.getShortEpg('demo_canal_1'))['epg_listings'], isEmpty);
      } else {
        expect(ListaDemo.ativa(ListaDemo.host), isFalse);
        expect(svc.runtimeType, XtreamService);
      }
    });

    testWidgets('tela do aparelho: botão da demonstração só na Play', (tester) async {
      _telaTv(tester);
      await _semRuido(() async {
        await tester.pumpWidget(const MaterialApp(home: DeviceHomeScreen(autoEnter: false)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.byKey(const Key('abrir_demo')), Loja.play ? findsOneWidget : findsNothing);
        // Para os timers da tela
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 20));
      });
    });
  });
}
