import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simanplay_iptv/services/xtream_service.dart';

/// Painel que devolve TODOS os tipos em cada lista (como o que mostrou
/// "FILMES: GUERRA 312" na aba Ao Vivo).
final _misturado = [
  {'stream_id': 1, 'name': 'Globo', 'stream_type': 'live', 'category_id': '10'},
  {'stream_id': 2, 'name': 'Canal Criado', 'stream_type': 'created_live', 'category_id': '10'},
  {'stream_id': 3, 'name': 'Rádio', 'stream_type': 'radio_streams', 'category_id': '11'},
  {'stream_id': 4, 'name': 'Sem tipo', 'category_id': '10'},
  {'stream_id': 5, 'name': 'Tipo vazio', 'stream_type': '', 'category_id': '11'},
  {'stream_id': 6, 'name': 'Canal fora das categorias', 'stream_type': 'live', 'category_id': '999'},
  {'stream_id': 50, 'name': 'Filme de Guerra', 'stream_type': 'movie', 'category_id': '312'},
  {'stream_id': 51, 'name': 'Filme sem tipo', 'category_id': '312'},
  {'stream_id': 52, 'name': 'Filme num id de canal', 'stream_type': 'movie', 'category_id': '10'},
  {'series_id': 70, 'stream_id': 70, 'name': 'Série X', 'stream_type': 'series', 'category_id': '500'},
  {'series_id': 71, 'name': 'Série sem tipo', 'category_id': '500'},
  {'series_id': 72, 'name': 'Série num id de filme', 'stream_type': 'series', 'category_id': '312'},
];

Object _resposta(String action) => switch (action) {
      'get_live_categories' => [
          {'category_id': '10', 'category_name': 'Abertos'},
          {'category_id': '11', 'category_name': 'Rádios'},
          {'category_id': '12', 'category_name': 'Vazia depois do filtro'},
        ],
      'get_vod_categories' => [
          {'category_id': '312', 'category_name': 'FILMES: GUERRA'},
          {'category_id': '313', 'category_name': 'FILMES: VAZIA'},
        ],
      'get_series_categories' => [
          {'category_id': '500', 'category_name': 'SÉRIES: DRAMA'},
        ],
      'get_live_streams' || 'get_vod_streams' || 'get_series' => _misturado,
      _ => <Object>[],
    };

XtreamService _servico() => XtreamService(
      host: 'http://servidor.exemplo',
      username: 'u',
      password: 'p',
      client: MockClient((req) async =>
          http.Response(jsonEncode(_resposta(req.url.queryParameters['action'] ?? '')), 200)),
    );

void main() {
  setUp(XtreamService.clearCache);

  test('Ao Vivo: só live/created_live/radio_streams (ou sem tipo) das categorias ao vivo', () async {
    final svc = _servico();
    final canais = await svc.getAllLiveStreams();
    expect(canais.map((c) => c.name), ['Globo', 'Canal Criado', 'Rádio', 'Sem tipo', 'Tipo vazio']);
    expect(canais.map((c) => c.categoryName).toSet(), {'Abertos', 'Rádios'});
    final pastas = await svc.getLivePastas();
    expect(pastas.map((c) => c.name), ['Abertos', 'Rádios'], reason: 'pasta vazia some, e nenhuma pasta de filme');
  });

  test('Filmes: só movie (ou sem tipo) das categorias de filmes', () async {
    final svc = _servico();
    final filmes = await svc.getAllMovies();
    expect(filmes.map((m) => m.name), ['Filme de Guerra', 'Filme sem tipo']);
    expect((await svc.getMoviePastas()).map((c) => c.name), ['FILMES: GUERRA']);
  });

  test('Séries: só series (ou sem tipo) das categorias de séries', () async {
    final svc = _servico();
    final series = await svc.getAllSeries();
    expect(series.map((s) => s.name), ['Série X', 'Série sem tipo']);
    expect((await svc.getSeriesPastas()).map((c) => c.name), ['SÉRIES: DRAMA']);
  });

  test('categoria por category_ids quando o painel manda a lista', () {
    final out = XtreamService.filtrarItens([
      {'stream_type': 'live', 'category_id': null, 'category_ids': [7, 10]},
      {'stream_type': 'live', 'category_ids': [7]},
    ], tipos: XtreamService.tiposAoVivo, categorias: {'10'});
    expect(out, hasLength(1));
  });
}
