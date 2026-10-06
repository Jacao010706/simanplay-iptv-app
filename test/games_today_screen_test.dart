import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/models/channel.dart';
import 'package:simanplay_iptv/screens/games_today_screen.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/services/sports_service.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

final agora = DateTime(2026, 10, 1, 18, 0);

Fixture jogo(int id, String liga, int hora, String casa, String fora,
        {String status = 'NS', int? gc, int? gf, int? minuto}) =>
    Fixture(
      id: id,
      leagueName: liga,
      leagueLogo: 'https://logo/$liga.png',
      leagueCountry: 'Brazil',
      kickoff: DateTime(2026, 10, 1, hora),
      statusShort: status,
      elapsed: minuto,
      homeName: casa,
      homeLogo: 'https://escudo/$casa.png',
      awayName: fora,
      awayLogo: 'https://escudo/$fora.png',
      goalsHome: gc,
      goalsAway: gf,
    );

Channel canal(String id, String nome) => Channel(
      id: id,
      name: nome,
      streamUrl: 'http://srv/live/u/p/$id.m3u8',
      categoryId: '1',
      categoryName: 'Esportes',
    );

final jogos = [
  jogo(1, 'Serie A', 16, 'Flamengo', 'Palmeiras', status: '2H', gc: 1, gf: 0, minuto: 67),
  jogo(2, 'Premier League', 17, 'Arsenal', 'Chelsea'),
  jogo(3, 'Serie A', 21, 'Gremio', 'Internacional'),
];

void _telaTv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0; // 960x540 logico, como nas TVs
  addTearDown(tester.view.reset);
}

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

String? _chaveFocada() {
  String? achou;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      achou = k.value;
      return false;
    }
    return true;
  });
  return achou;
}

Future<List<Channel>> abrir(
  WidgetTester tester, {
  FixturesLoader? fixtures,
  WhereToWatchLoader? onde,
}) async {
  _telaTv(tester);
  final abertos = <Channel>[];
  await tester.pumpWidget(MaterialApp(
    shortcuts: appShortcuts,
    builder: (c, child) => FocusRing(child: child!),
    home: GamesTodayScreen(
      session: const AppSession(type: SessionType.simanplay),
      clock: () => agora,
      debugFixtures: fixtures ?? (day) async => jogos,
      debugWhereToWatch: onde ??
          (f, onUpdate) async => {
                1: [canal('10', 'Premiere 1'), canal('11', 'SporTV')],
                2: [canal('20', 'ESPN')],
              },
      debugOnOpenChannel: abertos.add,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return abertos;
}

void main() {
  testWidgets('agrupa por campeonato, com escudos, placar ao vivo e horario', (tester) async {
    await abrir(tester);
    expect(find.text('Serie A'), findsOneWidget, reason: 'cada liga aparece uma vez, como cabecalho');
    expect(find.text('Premier League'), findsOneWidget);
    // Os dois jogos da Serie A ficam juntos, embaixo do cabecalho da liga
    final serieA = tester.getTopLeft(find.byKey(const ValueKey('league-Serie A'))).dy;
    final premier = tester.getTopLeft(find.byKey(const ValueKey('league-Premier League'))).dy;
    final gremio = tester.getTopLeft(find.text('Gremio')).dy;
    expect(gremio, greaterThan(serieA));
    expect(gremio, lessThan(premier), reason: 'Gremio x Inter deve ficar no grupo da Serie A');

    final escudos = tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((w) => w.imageUrl).toSet();
    expect(escudos, containsAll(['https://escudo/Flamengo.png', 'https://escudo/Palmeiras.png', 'https://logo/Serie A.png']));

    expect(find.text('1 x 0'), findsOneWidget);
    expect(find.text("AO VIVO 67'"), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('Premiere 1'), findsOneWidget);
    expect(find.text('Canal não encontrado na sua lista'), findsOneWidget, reason: 'Gremio x Inter sem canal');
  });

  testWidgets('setas chegam num chip de canal e OK abre o canal', (tester) async {
    final abertos = await abrir(tester);
    expect(_chaveFocada(), 'day-0', reason: 'tela abre com "Hoje" focado');

    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_chaveFocada(), 'fixture-1');
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_chaveFocada(), startsWith('channel-chip-1-'), reason: 'seta para baixo deveria ir para um chip de canal do jogo');
    // Seta para a esquerda/direita anda entre os canais do jogo
    await _tecla(tester, LogicalKeyboardKey.arrowLeft);
    expect(_chaveFocada(), 'channel-chip-1-10');
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    expect(_chaveFocada(), 'channel-chip-1-11');
    await _tecla(tester, LogicalKeyboardKey.arrowLeft);
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(abertos.map((c) => c.name), ['Premiere 1']);

    // Proximo jogo da mesma liga (Serie A) e depois o da Premier League
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_chaveFocada(), 'fixture-3');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(abertos.map((c) => c.name), ['Premiere 1'], reason: 'jogo sem canal: OK nao abre nada');

    // Jogo com um unico canal: OK no card abre direto
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_chaveFocada(), 'fixture-2');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(abertos.map((c) => c.name), ['Premiere 1', 'ESPN']);
  });

  testWidgets('chips carregam aos poucos sem travar a lista', (tester) async {
    final fim = Completer<Map<int, List<Channel>>>();
    late void Function(Map<int, List<Channel>>) parcial;
    await abrir(tester, onde: (f, onUpdate) {
      parcial = onUpdate;
      return fim.future;
    });
    expect(find.text('Flamengo'), findsOneWidget, reason: 'a lista aparece antes dos canais');
    expect(find.text('Procurando canais...'), findsNWidgets(3));

    parcial({1: [canal('10', 'Premiere 1')]});
    await tester.pump();
    expect(find.text('Premiere 1'), findsOneWidget);
    expect(find.text('Procurando canais...'), findsNWidgets(2));

    fim.complete({1: [canal('10', 'Premiere 1')]});
    await tester.pump();
    await tester.pump();
    expect(find.text('Procurando canais...'), findsNothing);
    expect(find.text('Canal não encontrado na sua lista'), findsNWidgets(2));
  });

  testWidgets('backend sem chave: Jogos indisponiveis no momento', (tester) async {
    await abrir(tester, fixtures: (day) async => throw SportsUnavailableException());
    expect(find.text('Jogos indisponíveis no momento'), findsOneWidget);
  });

  testWidgets('Ontem/Hoje/Amanha trocam a data pedida', (tester) async {
    final pedidos = <DateTime>[];
    await abrir(tester, fixtures: (day) async {
      pedidos.add(day);
      return jogos;
    });
    await _tecla(tester, LogicalKeyboardKey.arrowLeft);
    expect(_chaveFocada(), 'day--1');
    await _tecla(tester, LogicalKeyboardKey.select);
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    expect(_chaveFocada(), 'day-1');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(pedidos, [DateTime(2026, 10, 1), DateTime(2026, 9, 30), DateTime(2026, 10, 2)]);
  });

  for (var tema = 1; tema <= 6; tema++) {
    testWidgets('home tema $tema: menu tem "Jogos" e abre a pagina Jogos do Dia', (tester) async {
      _telaTv(tester);
      final original = FlutterError.onError;
      // Avisos de layout e imagens sem rede nao fazem parte deste teste
      FlutterError.onError = (d) {
        final t = d.exceptionAsString();
        if (!t.contains('overflowed') && !t.contains('HTTP') && !t.contains('NetworkImage')) original?.call(d);
      };
      try {
        await tester.pumpWidget(MaterialApp(
          shortcuts: appShortcuts,
          builder: (c, child) => FocusRing(child: child!),
          home: HomeScreen(session: const AppSession(type: SessionType.simanplay), debugTheme: tema),
        ));
        await tester.pump();
        final item = find.text('Jogos');
        expect(item, findsOneWidget, reason: 'tema $tema sem o item Jogos no menu');
        await tester.tap(item, warnIfMissed: false);
        await tester.pump();
        expect(find.byType(GamesTodayScreen), findsOneWidget, reason: 'tema $tema: Jogos nao abriu a pagina');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 25));
      } finally {
        FlutterError.onError = original;
      }
    });
  }
}
