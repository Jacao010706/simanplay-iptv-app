import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simanplay_iptv/core/erros.dart';
import 'package:simanplay_iptv/core/user_agent.dart';
import 'package:simanplay_iptv/services/xtream_service.dart';

/// Servidor Xtream falso: conta os pedidos por action e guarda o User-Agent recebido.
class _Servidor {
  final Map<String, int> pedidos = {};
  final List<String?> userAgents = [];
  Object? Function(String action)? resposta;
  int status = 200;

  late final MockClient client = MockClient((req) async {
    final action = req.url.queryParameters['action'] ?? '';
    pedidos[action] = (pedidos[action] ?? 0) + 1;
    userAgents.add(req.headers['User-Agent']);
    final corpo = resposta?.call(action) ?? _padrao(action);
    return http.Response(jsonEncode(corpo), status);
  });

  static Object _padrao(String action) => switch (action) {
        'get_live_categories' => [
            {'category_id': '1', 'category_name': 'Esportes'},
            {'category_id': '2', 'category_name': 'Filmes 24h'},
          ],
        'get_live_streams' => [
            {'stream_id': 10, 'name': 'Canal A', 'category_id': '1'},
            {'stream_id': 11, 'name': 'Canal B', 'category_id': '2'},
            {'stream_id': 12, 'name': 'Canal C', 'category_id': '1'},
          ],
        _ => <Object>[],
      };

  XtreamService servico() =>
      XtreamService(host: 'http://servidor.exemplo', username: 'usuario1', password: 'senha123', client: client);
}

void main() {
  setUp(XtreamService.clearCache);

  group('XtreamService: uma chamada por tipo, com cache', () {
    test('canais de todas as categorias vêm de UM get_live_streams, sem category_id', () async {
      final s = _Servidor();
      final svc = s.servico();
      final cats = await svc.getLiveCategories();
      for (final c in cats) {
        await svc.getLiveStreams(c.id, c.name);
      }
      final todos = await svc.getAllLiveStreams();
      expect(todos.map((c) => c.name), ['Canal A', 'Canal B', 'Canal C']);
      expect(todos.first.categoryName, 'Esportes');
      expect((await svc.getLiveStreams('1', 'Esportes')).map((c) => c.name), ['Canal A', 'Canal C']);
      expect(s.pedidos['get_live_streams'], 1);
      expect(s.pedidos['get_live_categories'], 1);
    });

    test('telas diferentes (outra instância, mesma conta) usam o mesmo cache', () async {
      final s = _Servidor();
      await Future.wait([s.servico().getAllLiveStreams(), s.servico().getAllLiveStreams()]);
      await s.servico().getLiveStreams('2', 'x');
      expect(s.pedidos['get_live_streams'], 1);
    });

    test('erro não fica no cache: a próxima tentativa chama o servidor de novo', () async {
      final s = _Servidor()..status = 500;
      await expectLater(s.servico().getAllLiveStreams(), throwsA(isA<ServidorException>()));
      s.status = 200;
      expect(await s.servico().getAllLiveStreams(), hasLength(3));
    });

    test('manda o User-Agent do app em todos os pedidos', () async {
      final s = _Servidor();
      await s.servico().getAllLiveStreams();
      expect(s.userAgents, everyElement(kIptvUserAgent));
    });
  });

  group('XtreamService: conta recusada e erros', () {
    test('lista que volta como objeto user_info.auth=0 vira ContaRecusadaException', () async {
      final s = _Servidor()..resposta = (_) => {'user_info': {'auth': 0}};
      await expectLater(s.servico().getLiveCategories(), throwsA(isA<ContaRecusadaException>()));
    });

    test('HTTP 401 e 403 viram ContaRecusadaException', () async {
      for (final code in [401, 403]) {
        XtreamService.clearCache();
        final s = _Servidor()..status = code;
        await expectLater(s.servico().getAllMovies(), throwsA(isA<ContaRecusadaException>()));
      }
    });

    test('a mensagem de conta recusada é a combinada, em português', () {
      expect(mensagemDeErro(const ContaRecusadaException()),
          startsWith('O servidor recusou a conta agora (pode estar em uso em outro aparelho'));
    });

    test('login com auth=0 explica senha errada OU conta recusada', () async {
      final s = _Servidor()..resposta = (_) => {'user_info': {'auth': 0}};
      await expectLater(
          s.servico().authenticate(),
          throwsA(isA<ServidorException>()
              .having((e) => e.mensagem, 'mensagem', contains('recusou a conta agora'))));
    });

    test('falha de rede não deixa vazar a URL com usuário e senha', () async {
      final client = MockClient((req) async =>
          throw http.ClientException('Connection refused', req.url));
      final svc = XtreamService(host: 'http://servidor.exemplo', username: 'usuario1', password: 'senha123', client: client);
      try {
        await svc.getLiveCategories();
        fail('devia falhar');
      } catch (e) {
        final msg = mensagemDeErro(e);
        expect(msg, isNot(contains('senha123')));
        expect(msg, isNot(contains('usuario1')));
        expect(msg, isNot(contains('http')));
      }
    });
  });

  group('mensagemDeErro / semCredenciais', () {
    test('tira URL, caminho Xtream e parâmetros de credencial', () {
      final bruto = Exception(
          'ClientException: falhou, uri=http://srv:8080/player_api.php?username=joao&password=s3cr3t&action=x');
      final msg = mensagemDeErro(bruto);
      expect(msg, isNot(contains('s3cr3t')));
      expect(msg, isNot(contains('joao')));
      expect(semCredenciais('abrir /live/joao/s3cr3t/1.ts deu erro'), 'abrir /live/***/***/1.ts deu erro');
      expect(semCredenciais('falha em http://srv/live/joao/s3cr3t/1.ts'), 'falha em [endereço oculto]');
    });
  });
}
