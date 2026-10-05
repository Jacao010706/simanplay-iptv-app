import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/models/series.dart';
import 'package:simanplay_iptv/screens/series_detail_screen.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

// "episodes" como Map (formato mais comum), chaves fora de ordem, números em texto
final Map<String, dynamic> episodiosMap = {
  'seasons': [],
  'info': {'name': 'Série teste'},
  'episodes': {
    '2': [
      {'id': '201', 'episode_num': '2', 'title': 'S02E02', 'container_extension': 'mkv', 'season': '2'},
      {'id': '200', 'episode_num': '1', 'title': 'S02E01', 'container_extension': 'mkv', 'season': '2'},
    ],
    '1': [
      {'id': '102', 'episode_num': 10, 'title': 'S01E10', 'container_extension': 'mp4', 'season': 1,
        'info': {'duration': '00:42:00', 'plot': 'Fim da temporada'}},
      {'id': '101', 'episode_num': '9', 'title': '', 'container_extension': 'mp4', 'season': 1},
    ],
  },
};

// "episodes" como List de listas (uma por temporada), sem "seasons"
final Map<String, dynamic> episodiosLista = {
  'info': {'name': 'Série teste'},
  'episodes': [
    [
      {'id': 11, 'episode_num': 1, 'title': 'T1 E1'},
      {'id': 12, 'episode_num': 2, 'title': 'T1 E2'},
    ],
    [
      {'id': 21, 'episode_num': '1', 'title': 'T2 E1'},
    ],
  ],
};

// "episodes" como List plana de episódios com o campo "season"
final Map<String, dynamic> episodiosListaPlana = {
  'seasons': [],
  'episodes': [
    {'id': 'b', 'episode_num': '2', 'season': '3', 'title': 'T3 E2'},
    {'id': 'a', 'episode_num': '1', 'season': 3, 'title': 'T3 E1'},
    {'id': 'c', 'episode_num': 1, 'season': '1', 'title': 'T1 E1'},
  ],
};

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
  BuildContext? ctx = FocusManager.instance.primaryFocus?.context;
  String? achou;
  ctx?.visitAncestorElements((e) {
    final k = e.widget.key;
    if (k is ValueKey<String>) {
      achou = k.value;
      return false;
    }
    return true;
  });
  return achou;
}

void main() {
  group('parseSeriesSeasons', () {
    test('episodes como Map, seasons vazio: temporadas pelas chaves, tudo em ordem', () {
      final t = parseSeriesSeasons(episodiosMap);
      expect(t.map((s) => s.number), [1, 2]);
      expect(t[0].episodes.map((e) => e.episodeNumber), [9, 10]);
      expect(t[1].episodes.map((e) => e.id), ['200', '201']);
      expect(t[0].episodes[0].title, 'Episódio 9', reason: 'título vazio vira "Episódio N"');
      expect(t[0].episodes[1].duration, '00:42:00');
      expect(t[0].episodes[1].plot, 'Fim da temporada');
      expect(t[1].episodes[0].extension, 'mkv');
      expect(
        t[1].episodes[0].streamUrl(host: 'http://srv:80', username: 'u', password: 'p'),
        'http://srv:80/series/u/p/200.mkv',
      );
    });

    test('episodes como List de listas, sem seasons', () {
      final t = parseSeriesSeasons(episodiosLista);
      expect(t.map((s) => s.number), [1, 2]);
      expect(t[0].episodes.map((e) => e.title), ['T1 E1', 'T1 E2']);
      expect(t[1].episodes.single.id, '21');
      expect(t[1].episodes.single.episodeNumber, 1);
    });

    test('episodes como List plana com o campo season', () {
      final t = parseSeriesSeasons(episodiosListaPlana);
      expect(t.map((s) => s.number), [1, 3]);
      expect(t[1].episodes.map((e) => e.title), ['T3 E1', 'T3 E2']);
    });

    test('temporadas de "seasons" sem episódios também aparecem', () {
      final t = parseSeriesSeasons({
        'seasons': [
          {'season_number': '1'},
          {'season_number': 2},
        ],
        'episodes': {
          '2': [
            {'id': 'x', 'episode_num': '1'},
          ],
        },
      });
      expect(t.map((s) => s.number), [1, 2]);
      expect(t[0].episodes, isEmpty);
      expect(t[1].episodes.single.id, 'x');
    });

    test('sem episódios', () {
      expect(parseSeriesSeasons({'seasons': [], 'episodes': []}), isEmpty);
      expect(parseSeriesSeasons({'episodes': null}), isEmpty);
      expect(parseSeriesSeasons(null), isEmpty);
    });
  });

  group('tela de detalhe com controle remoto', () {
    Future<List<Episode>> abrir(WidgetTester tester, Map<String, dynamic> info) async {
      _telaTv(tester);
      final abertos = <Episode>[];
      await tester.pumpWidget(MaterialApp(
        shortcuts: appShortcuts,
        builder: (c, child) => FocusRing(child: child!),
        home: SeriesDetailScreen(
          session: const AppSession(type: SessionType.simanplay),
          series: Series(id: '1', name: 'Série teste', categoryId: '1', categoryName: 'Séries'),
          debugSeriesInfo: info,
          debugOnPlay: abertos.add,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return abertos;
    }

    testWidgets('abre na primeira temporada com episódios e seta para baixo chega no episódio; OK abre',
        (tester) async {
      // Temporada 1 vazia: deve abrir direto na 2
      final abertos = await abrir(tester, {
        'seasons': [
          {'season_number': 1},
        ],
        'episodes': {
          '2': [
            {'id': 'e1', 'episode_num': '1', 'title': 'Piloto'},
            {'id': 'e2', 'episode_num': '2', 'title': 'Segundo'},
          ],
        },
      });
      expect(find.text('Piloto'), findsOneWidget, reason: 'episódios da temporada 2 não aparecem');
      expect(_chaveFocada(), 'season-2', reason: 'a temporada selecionada deveria abrir focada');

      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      expect(_chaveFocada(), 'episode-2-e1', reason: 'seta para baixo não chegou no primeiro episódio');

      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      expect(_chaveFocada(), 'episode-2-e2');

      await _tecla(tester, LogicalKeyboardKey.select);
      expect(abertos.map((e) => e.id), ['e2'], reason: 'OK não abriu o episódio');
    });

    testWidgets('trocar de temporada pelo controle atualiza a lista de episódios', (tester) async {
      await abrir(tester, episodiosMap);
      expect(_chaveFocada(), 'season-1');
      expect(find.text('Episódio 9'), findsOneWidget);

      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      expect(_chaveFocada(), 'season-2');
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(find.text('S02E01'), findsOneWidget, reason: 'lista não mudou para a temporada 2');
      expect(find.text('Episódio 9'), findsNothing);

      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      expect(_chaveFocada(), 'episode-2-200');
    });

    testWidgets('mostra "Nenhum episódio encontrado" quando vem vazio', (tester) async {
      await abrir(tester, {'seasons': [], 'episodes': {}});
      expect(find.text('Nenhum episódio encontrado'), findsOneWidget);
    });
  });
}
