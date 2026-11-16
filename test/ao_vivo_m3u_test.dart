import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simanplay_iptv/core/app_config.dart';
import 'package:simanplay_iptv/core/m3u_service.dart';
import 'package:simanplay_iptv/core/versao.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/services/ao_vivo_loader.dart';
import 'package:simanplay_iptv/services/xtream_service.dart';

/// M3U como o do get.php de um painel Xtream: canais, canal 24h, filmes e episódios juntos.
const _m3u = '''#EXTM3U
#EXTINF:-1 tvg-logo="http://h/l/globo.png" group-title="ABERTOS",Globo
http://h:80/live/u/p/1.m3u8
#EXTINF:-1 group-title="FILMES: GUERRA",O Resgate
http://h:80/movie/u/p/50.mp4
#EXTINF:-1 group-title="FILMES 24 HORAS",Marvel 24h
http://h:80/live/u/p/2.ts
#EXTINF:-1 group-title="SÉRIES: DRAMA",Série S01 E01
http://h:80/series/u/p/70.mkv
#EXTINF:-1 group-title="FILMES: TERROR",Filme solto
http://outro.cdn/videos/filme.MP4?token=1
#EXTINF:-1 group-title="RÁDIOS",Rádio
http://radio.exemplo:8000/stream
''';

http.Response _resp(Object corpo, [int status = 200]) =>
    http.Response.bytes(utf8.encode(corpo is String ? corpo : jsonEncode(corpo)), status);

/// Painel falso: [api] responde o player_api.php; o get.php devolve [_m3u].
MockClient _painel({required http.Response Function(String action) api, List<String>? log}) =>
    MockClient((req) async {
      log?.add(req.url.path);
      if (req.url.path.endsWith('player_api.php')) return api(req.url.queryParameters['action'] ?? '');
      return _resp(_m3u);
    });

AppSession _listaM3u(String url) => AppSession.simanplay(username: 'm3u', password: '', primaryM3uUrl: url);
const _getPhp = 'http://h:80/get.php?username=u&password=p&type=m3u_plus';

void main() {
  setUp(XtreamService.clearCache);

  group('M3U no Ao Vivo', () {
    test('ehAoVivo: descarta /movie/, /series/ e arquivos de vídeo; mantém canais e 24h', () {
      expect(M3uService.ehAoVivo('http://h/live/u/p/1.m3u8'), isTrue);
      expect(M3uService.ehAoVivo('http://h/u/p/1'), isTrue);
      expect(M3uService.ehAoVivo('http://h:8000/stream'), isTrue);
      expect(M3uService.ehAoVivo('http://h/live/u/p/2.ts'), isTrue);
      expect(M3uService.ehAoVivo('http://h/movie/u/p/5.mp4'), isFalse);
      expect(M3uService.ehAoVivo('http://h/series/u/p/7.mkv'), isFalse);
      expect(M3uService.ehAoVivo('http://cdn/x/filme.MP4?t=1'), isFalse);
      expect(M3uService.ehAoVivo('http://cdn/x/filme.avi'), isFalse);
    });

    test('parse soAoVivo: só canais, ids iguais aos de antes do filtro', () {
      final todos = M3uService().parse(_m3u);
      final aoVivo = M3uService().parse(_m3u, soAoVivo: true);
      expect(todos, hasLength(6));
      expect(aoVivo.map((c) => c.name), ['Globo', 'Marvel 24h', 'Rádio']);
      expect(aoVivo.map((c) => c.id), ['m3u_1', 'm3u_3', 'm3u_6']);
      expect(aoVivo.first.logoUrl, 'http://h/l/globo.png');
      expect(aoVivo.map((c) => c.categoryName), ['ABERTOS', 'FILMES 24 HORAS', 'RÁDIOS']);
    });

    test('lista grande (~300 mil linhas) é lida em outro isolate e devolve só os canais', () async {
      final b = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 150000; i++) {
        final live = i % 100 == 0;
        b
          ..writeln('#EXTINF:-1 group-title="${live ? 'CANAIS' : 'FILMES: X'}",Item $i')
          ..writeln(live ? 'http://h/live/u/p/$i.m3u8' : 'http://h/movie/u/p/$i.mp4');
      }
      final client = MockClient((_) async => _resp(b.toString()));
      final canais = await M3uService(client: client).fetchAoVivo('http://h/lista.m3u');
      expect(canais, hasLength(1500));
      expect(canais.every((c) => c.categoryName == 'CANAIS'), isTrue);
    });
  });

  group('CarregadorAoVivo', () {
    test('M3U sem credenciais: só canais, pastas só deles, sem chamar a API', () async {
      final log = <String>[];
      final r = await CarregadorAoVivo.carregar(_listaM3u('http://h/lista.m3u'),
          client: _painel(api: (_) => _resp({}, 500), log: log));
      expect(r.canais.map((c) => c.name), ['Globo', 'Marvel 24h', 'Rádio']);
      expect(r.categorias.map((c) => c.name), ['ABERTOS', 'FILMES 24 HORAS', 'RÁDIOS']);
      expect(log.where((p) => p.endsWith('player_api.php')), isEmpty);
    });

    test('M3U com credenciais e API ok: usa a API (pastas do get_live_categories)', () async {
      final r = await CarregadorAoVivo.carregar(_listaM3u(_getPhp),
          client: _painel(api: (a) => _resp(switch (a) {
                'get_live_categories' => [{'category_id': '3', 'category_name': 'ABERTOS (API)'}],
                'get_live_streams' => [
                    {'stream_id': 9, 'name': 'Globo API', 'stream_type': 'live', 'category_id': '3'},
                  ],
                _ => [],
              })));
      expect(r.canais.map((c) => c.name), ['Globo API']);
      expect(r.categorias.map((c) => c.name), ['ABERTOS (API)']);
    });

    final falhas = <String, http.Response Function(String)>{
      'servidor sem player_api.php (404)': (_) => _resp('Not Found', 404),
      'resposta inválida (HTML)': (_) => _resp('<html>erro</html>'),
      'conta recusada (auth 0)': (_) => _resp({'user_info': {'auth': 0}}),
      'API sem canais': (_) => _resp([]),
    };
    falhas.forEach((nome, api) {
      test('M3U com credenciais, $nome: cai no M3U filtrado sem erro', () async {
        final r = await CarregadorAoVivo.carregar(_listaM3u(_getPhp), client: _painel(api: api));
        expect(r.canais.map((c) => c.name), ['Globo', 'Marvel 24h', 'Rádio']);
      });
    });

    test('M3U com credenciais, erro de rede na API: cai no M3U', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('player_api.php')) throw http.ClientException('sem rede');
        return _resp(_m3u);
      });
      final r = await CarregadorAoVivo.carregar(_listaM3u(_getPhp), client: client);
      expect(r.canais, hasLength(3));
    });

    test('conta Xtream: erro da API continua aparecendo (sem M3U)', () async {
      final s = AppSession.xtream(host: 'http://h', username: 'u', password: 'p');
      await expectLater(
          CarregadorAoVivo.carregar(s, client: _painel(api: (_) => _resp({'user_info': {'auth': 0}}))),
          throwsA(anything));
    });
  });

  test('versão mostrada: "Sofae v1.0.0+N", igual ao pubspec e ao build do CI', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(pubspec.split(':').last.trim().split('+').first, kVersaoNome);
    expect(versaoApp, '${AppConfig.appName} v$kVersaoNome+${AppConfig.buildNumber}');
  });
}
