// Layout da demonstração na TV (relato da Amazon Appstore, Fire TV):
//  1. a janela de detalhes do filme ("Assistir") cabe na tela;
//  2. o destaque do item focado na grade de Filmes não passa por cima das opções de cima;
//  3. capas menores: 7 colunas de Filmes e Séries na TV e 4 no celular em pé, sem overflow;
//  4. a janela do canal (Ao Vivo) cabe na tela, com o "Assistir" inteiro e focado, e o
//     destaque do canal focado não passa por cima da busca.
//
// A demonstração só existe na variante de loja:
//   flutter test test/loja_layout_tv_test.dart --flavor play
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simanplay_iptv/core/lista_demo.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/core/modo_tv.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/screens/live_tv_screen.dart';
import 'package:simanplay_iptv/screens/movies_screen.dart';
import 'package:simanplay_iptv/screens/series_screen.dart';
import 'package:simanplay_iptv/services/xtream_service.dart';
import 'package:simanplay_iptv/widgets/grade_capas.dart';
import 'package:simanplay_iptv/widgets/modo_tv_widgets.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

class _Tela {
  const _Tela(this.nome, this.tamanho, this.dpr, this.texto);
  final String nome;
  final Size tamanho;
  final double dpr;
  final double texto;
}

const _telas = [
  _Tela('1920x1080 (Fire TV, 960x540 lógico)', Size(1920, 1080), 2.0, ModoTv.escalaTexto),
  _Tela('1920x1080, fonte 1.0', Size(1920, 1080), 2.0, 1.0),
  _Tela('1280x720, fonte 1.0', Size(1280, 720), 1.0, 1.0),
  _Tela('1920x1080, fonte do sistema 1.3', Size(1920, 1080), 2.0, 1.3),
  _Tela('1280x720 (1280x720 lógico)', Size(1280, 720), 1.0, ModoTv.escalaTexto),
  _Tela('1280x720, fonte do sistema 1.3', Size(1280, 720), 1.0, 1.3),
  _Tela('1280x720 em densidade 1.5 (853x480 lógico), fonte 1.3', Size(1280, 720), 1.5, 1.3),
];

/// Canais: as mesmas telas, também com a fonte do sistema em 1.25.
const _telasCanais = [
  ..._telas,
  _Tela('1920x1080, fonte do sistema 1.25', Size(1920, 1080), 2.0, 1.25),
  _Tela('1280x720, fonte do sistema 1.25', Size(1280, 720), 1.0, 1.25),
  _Tela('1280x720 em densidade 1.5 (853x480 lógico), fonte 1.25', Size(1280, 720), 1.5, 1.25),
];

/// O mesmo envelope do main.dart na TV: escala de texto, margem de overscan e borda de foco.
Widget _app(Widget home, double texto) => MaterialApp(
      shortcuts: appShortcuts,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(texto)),
          child: MargemTv(child: FocusRing(child: child!)),
        );
      },
      home: Scaffold(body: home),
    );

/// Guarda os erros de layout (overflow) e ignora só as capas (sem internet no teste).
Future<List<String>> _comErros(Future<void> Function() corpo) async {
  final erros = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('HTTP request failed') || s.contains('NetworkImage')) return;
    erros.add(s);
  };
  try {
    await corpo();
  } finally {
    FlutterError.onError = original;
  }
  return erros;
}

Future<void> _passar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await _passar(tester); // rolagem (200 ms) e borda de foco (até 700 ms)
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _abrirFilmes(WidgetTester tester, _Tela t) => _abrirGrade(tester, t, _Grade.filmes);

/// Lista Xtream falsa só com séries (a demonstração não tem séries).
const _hostSeries = 'http://series.exemplo';

Object _respostaSeries(String acao) => switch (acao) {
      'get_series_categories' => [
          {'category_id': '1', 'category_name': 'Séries de teste'},
          {'category_id': '2', 'category_name': 'Animação'},
        ],
      'get_series' => [
          for (var i = 1; i <= 30; i++)
            {
              'series_id': i,
              'name': 'Série de teste número $i com um nome bem comprido',
              'category_id': '${1 + i % 2}',
              'cover': 'http://series.exemplo/capa$i.jpg',
              'rating': '7.5',
              'stream_type': 'series',
            },
        ],
      _ => {'user_info': {'auth': 1, 'status': 'Active'}},
    };

/// Deixa as séries no cache do XtreamService (a tela usa o mesmo host, usuário e senha).
Future<AppSession> _sessaoSeries(WidgetTester tester) async {
  XtreamService.clearCache();
  addTearDown(XtreamService.clearCache);
  final svc = XtreamService(
    host: _hostSeries, username: 'u', password: 'p',
    client: MockClient((req) async =>
        http.Response(jsonEncode(_respostaSeries(req.url.queryParameters['action'] ?? '')), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})),
  );
  await tester.runAsync(() => svc.getSeriesPastas());
  return AppSession.xtream(host: _hostSeries, username: 'u', password: 'p');
}

enum _Grade { filmes, series }

Future<void> _abrirGrade(WidgetTester tester, _Tela t, _Grade g, {bool tv = true}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = t.tamanho;
  tester.view.devicePixelRatio = t.dpr;
  addTearDown(tester.view.reset);
  if (tv) ModoTv.debugDefinir(tv: true, pacote: ModoTv.pacoteSofae);
  addTearDown(ModoTv.debugDefinir);
  final tela = g == _Grade.filmes
      ? MoviesScreen(session: ListaDemo.sessao())
      : SeriesScreen(session: await _sessaoSeries(tester));
  await tester.pumpWidget(_app(tela, t.texto));
  // Séries: o cache foi preenchido fora do relógio falso; deixa a tela receber os dados
  if (g == _Grade.series) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await _passar(tester);
  expect(find.byType(GridView), findsOneWidget, reason: '${t.nome}: a grade de ${g.name} não abriu');
}

int _colunas(WidgetTester tester) =>
    (tester.widget<GridView>(find.byType(GridView)).gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
        .crossAxisCount;

/// Capa (o Expanded do item) em pôster 2:3.
void _conferirCapa(WidgetTester tester, String nome) {
  final capa = tester.getRect(find.descendant(of: find.byType(GridView), matching: find.byType(Expanded)).first);
  expect(capa.height / capa.width, closeTo(1.5, 0.03), reason: '$nome: capa ($capa) fora de 2:3');
}

Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

FocusNode? _foco() => FocusManager.instance.primaryFocus;

/// Foco no item do canal (a linha inteira, não a estrela de favorito dentro dela).
bool _focoNoCanal() {
  final f = _foco();
  if (f == null || f.debugLabel == 'TvTap') return false;
  final k = f.context?.findAncestorWidgetOfExactType<InkWell>()?.key;
  return k is ValueKey<String> && k.value.startsWith('canal-');
}

Future<void> _abrirCanais(WidgetTester tester, _Tela t) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = t.tamanho;
  tester.view.devicePixelRatio = t.dpr;
  addTearDown(tester.view.reset);
  ModoTv.debugDefinir(tv: true, pacote: ModoTv.pacoteSofae);
  addTearDown(ModoTv.debugDefinir);
  await tester.pumpWidget(_app(LiveTvScreen(session: ListaDemo.sessao()), t.texto));
  await _passar(tester);
  expect(find.byKey(const ValueKey('canal-demo_canal_1')), findsOneWidget,
      reason: '${t.nome}: a lista de canais da demonstração não abriu');
}

/// Controle remoto: anda até a lista de canais (busca → categorias → canais).
Future<void> _irParaCanais(WidgetTester tester, _Tela t) async {
  for (final k in [
    LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight,
  ]) {
    if (_focoNoCanal()) return;
    await _tecla(tester, k);
  }
  expect(_focoNoCanal(), isTrue, reason: '${t.nome}: o controle não chegou aos canais (foco em ${_foco()})');
}

bool _focoNaGrade() => _foco()?.context?.findAncestorWidgetOfExactType<GridView>() != null;

void main() {
  test('grade: uma fileira cabe na área visível com folga para a borda de foco', () {
    const legenda = 22.0;
    for (final (w, h, tv) in [
      (864.0, 380.0, true), (1180.0, 520.0, true), (780.0, 300.0, true), (780.0, 240.0, true),
      (366.0, 600.0, false), (820.0, 250.0, false), (1000.0, 600.0, false),
    ]) {
      final cols = GradeCapas.colunas(w, h, tv: tv, legenda: legenda);
      final item = GradeCapas.alturaDoItem(w - 2 * GradeCapas.margem, cols, legenda);
      expect(item, lessThanOrEqualTo(h - 2 * GradeCapas.margem - 2 * GradeCapas.folgaFoco),
          reason: '${w}x$h: $cols colunas, item de $item px');
    }
    expect(GradeCapas.colunas(864, 380, tv: true, legenda: legenda), 7, reason: 'TV: 7 colunas');
    expect(GradeCapas.colunas(366, 700, tv: false, legenda: legenda), 4, reason: 'celular em pé: 4 colunas');
    expect(GradeCapas.colunas(1000, 2000, tv: false, legenda: legenda), 8,
        reason: 'tablet: colunas pela largura (capa de ~110)');
  });

  for (final g in _Grade.values) {
    testWidgets('celular 390x844, ${g.name}: 4 colunas, capas 2:3, sem overflow', (tester) async {
      final erros = await _comErros(() async {
        const t = _Tela('390x844', Size(1170, 2532), 3.0, 1.0);
        await _abrirGrade(tester, t, g, tv: false);
        expect(_colunas(tester), 4, reason: 'celular em pé: 4 colunas');
        _conferirCapa(tester, t.nome);
        await _fechar(tester);
      });
      expect(erros, isEmpty, reason: 'erros de layout:\n${erros.join('\n')}');
    }, skip: !Loja.play);
  }

  for (final t in _telas) {
   for (final g in _Grade.values) {
    testWidgets('${g.name}, ${t.nome}: 7 colunas e o item focado fica inteiro na grade', (tester) async {
      final erros = await _comErros(() async {
        await _abrirGrade(tester, t, g);
        final grade = tester.getRect(find.byType(GridView));
        final logico = t.tamanho / t.dpr;
        if (logico.width >= 960) {
          expect(_colunas(tester), 7, reason: '${t.nome}: a TV tem 7 colunas');
        } else {
          expect(_colunas(tester), greaterThanOrEqualTo(7), reason: '${t.nome}: a TV tem 7 colunas ou mais');
        }
        _conferirCapa(tester, t.nome);

        var checados = 0;
        for (final k in [
          LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp,
        ]) {
          await _tecla(tester, k);
          if (!_focoNaGrade()) continue;
          checados++;
          final item = _foco()!.rect;
          final anel = tester.getRect(find.byKey(FocusRing.ringKey));
          expect(anel.top, greaterThanOrEqualTo(grade.top),
              reason: '${t.nome}, $k: a borda do item focado ($anel) sobe acima da grade ($grade)');
          expect(anel.bottom, lessThanOrEqualTo(grade.bottom),
              reason: '${t.nome}, $k: a borda do item focado ($anel) passa do fim da grade ($grade)');
          expect(item.left >= grade.left && item.right <= grade.right, isTrue,
              reason: '${t.nome}, $k: item focado ($item) cortado nas laterais da grade ($grade)');
        }
        expect(checados, greaterThanOrEqualTo(3), reason: '${t.nome}: o controle não chegou aos itens');
        await _fechar(tester);
      });
      expect(erros, isEmpty, reason: '${t.nome}: erros de layout:\n${erros.join('\n')}');
    }, skip: !Loja.play);
   }

    testWidgets('janela de detalhes, ${t.nome}: cabe na tela e "Assistir" fica visível e focado', (tester) async {
      final erros = await _comErros(() async {
        await _abrirFilmes(tester, t);
        final tela = Offset.zero & (t.tamanho / t.dpr);

        // Controle remoto: desce até a grade e abre o filme com OK
        for (var i = 0; i < 6 && !_focoNaGrade(); i++) {
          await _tecla(tester, LogicalKeyboardKey.arrowDown);
        }
        expect(_focoNaGrade(), isTrue, reason: '${t.nome}: o controle não chegou aos filmes');
        await _tecla(tester, LogicalKeyboardKey.select);
        await _passar(tester);

        final janela = find.byKey(const Key('detalhe_filme'));
        expect(janela, findsOneWidget, reason: '${t.nome}: a janela de detalhes não abriu');
        final caixa = tester.getRect(find.descendant(of: janela, matching: find.byType(Material)).first);
        final seguro = tela.deflate(tela.shortestSide * 0.04);
        expect(caixa.left >= seguro.left && caixa.top >= seguro.top &&
            caixa.right <= seguro.right && caixa.bottom <= seguro.bottom, isTrue,
            reason: '${t.nome}: janela ($caixa) fora da área segura ($seguro)');

        final assistir = find.byKey(const Key('detalhe_filme_assistir'));
        final botao = tester.getRect(assistir);
        expect(botao.top >= caixa.top && botao.bottom <= caixa.bottom, isTrue,
            reason: '${t.nome}: "Assistir" ($botao) cortado na janela ($caixa)');
        expect(Focus.of(tester.element(find.text('Assistir'))).hasFocus, isTrue,
            reason: '${t.nome}: "Assistir" sem o foco do controle');
        await _fechar(tester);
      });
      expect(erros, isEmpty, reason: '${t.nome}: erros de layout:\n${erros.join('\n')}');
    }, skip: !Loja.play);
  }

  for (final t in _telasCanais) {
    testWidgets('janela do canal, ${t.nome}: cabe na tela e "Assistir" fica inteiro e focado', (tester) async {
      final erros = await _comErros(() async {
        await _abrirCanais(tester, t);
        final tela = Offset.zero & (t.tamanho / t.dpr);
        final lista = tester.getRect(find.ancestor(
            of: find.byKey(const ValueKey('canal-demo_canal_1')), matching: find.byType(ListView)));

        await _irParaCanais(tester, t);
        // O destaque do canal focado não sobe por cima da busca
        final anel = tester.getRect(find.byKey(FocusRing.ringKey));
        expect(anel.top, greaterThanOrEqualTo(lista.top),
            reason: '${t.nome}: a borda do canal focado ($anel) sobe acima da lista ($lista)');
        expect(anel.left >= lista.left && anel.right <= lista.right, isTrue,
            reason: '${t.nome}: a borda do canal focado ($anel) passa das laterais da lista ($lista)');

        // OK no canal abre a janela de detalhes
        await _tecla(tester, LogicalKeyboardKey.select);
        await _passar(tester);

        final janela = find.byKey(const Key('detalhe_canal'));
        expect(janela, findsOneWidget, reason: '${t.nome}: a janela do canal não abriu');
        final caixa = tester.getRect(find.descendant(of: janela, matching: find.byType(Material)).first);
        final seguro = tela.deflate(tela.shortestSide * 0.04);
        expect(caixa.left >= seguro.left && caixa.top >= seguro.top &&
            caixa.right <= seguro.right && caixa.bottom <= seguro.bottom, isTrue,
            reason: '${t.nome}: janela ($caixa) fora da área segura ($seguro)');

        final botao = tester.getRect(find.byKey(const Key('detalhe_canal_assistir')));
        expect(botao.top >= caixa.top && botao.bottom <= caixa.bottom &&
            botao.left >= caixa.left && botao.right <= caixa.right, isTrue,
            reason: '${t.nome}: "Assistir" ($botao) cortado na janela ($caixa)');
        expect(Focus.of(tester.element(find.descendant(of: janela, matching: find.text('Assistir')))).hasFocus,
            isTrue, reason: '${t.nome}: "Assistir" sem o foco do controle');
        await _fechar(tester);
      });
      expect(erros, isEmpty, reason: '${t.nome}: erros de layout:\n${erros.join('\n')}');
    }, skip: !Loja.play);
  }
}
