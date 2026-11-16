import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simanplay_iptv/core/jogos_lista.dart';
import 'package:simanplay_iptv/models/channel.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/services/epg_service.dart';
import 'package:simanplay_iptv/services/escudos_service.dart';
import 'package:simanplay_iptv/services/jogos_lista_service.dart';

final _ref = DateTime(2026, 11, 15, 10);
Channel _canal(String id, String nome, [String cat = 'JOGOS DO DIA']) =>
    Channel(id: id, name: nome, streamUrl: 'http://h/live/u/p/$id.m3u8', categoryId: '1', categoryName: cat);

void main() {
  group('Jogo no nome do canal', () {
    test('formato com data, hora, confronto e campeonato', () {
      final j = jogoDoNomeDoCanal(
          '15/11 14:00 - INTER X FLAMENGO | FINAL DA COPA DO BRASIL FEMININA | SPORTV', _ref)!;
      expect(j.inicio, DateTime(2026, 11, 15, 14, 0));
      expect(j.casa, 'INTER');
      expect(j.fora, 'FLAMENGO');
      expect(j.campeonato, 'FINAL DA COPA DO BRASIL FEMININA');
    });

    test('nomes reais do jes.lat (sem data: dia de referência)', () {
      final a = jogoDoNomeDoCanal('Internacional x Flamengo - 16:00 FHD', _ref)!;
      expect((a.inicio, a.casa, a.fora, a.campeonato), (DateTime(2026, 11, 15, 16), 'Internacional', 'Flamengo', null));
      final b = jogoDoNomeDoCanal('Ravenna (Ronaldinho) x Forli - 13:30 HD', _ref)!;
      expect((b.casa, b.fora, b.inicio.hour, b.inicio.minute), ('Ravenna', 'Forli', 13, 30));
      final c = jogoDoNomeDoCanal('Croácia x República Tcheca - 16:45 FHD', _ref)!;
      expect((c.casa, c.fora), ('Croácia', 'República Tcheca'));
      final d = jogoDoNomeDoCanal('Danubio x Liverpool UY - 16:30 HD²', _ref)!;
      expect(d.fora, 'Liverpool UY');
    });

    test('outros formatos: vs, 21h30, data com ano, "AO VIVO"', () {
      final a = jogoDoNomeDoCanal('AO VIVO: Grêmio vs Palmeiras 21h30', _ref)!;
      expect((a.casa, a.fora, a.inicio.hour, a.inicio.minute), ('Grêmio', 'Palmeiras', 21, 30));
      final b = jogoDoNomeDoCanal('16/11/2026 - 18:30 | São Paulo x Corinthians', _ref)!;
      expect(b.inicio, DateTime(2026, 11, 16, 18, 30));
      expect((b.casa, b.fora), ('São Paulo', 'Corinthians'));
    });

    test('virada de ano: "02/01" visto em dezembro é janeiro do ano seguinte', () {
      final j = jogoDoNomeDoCanal('02/01 16:00 - Vasco x Botafogo', DateTime(2026, 12, 30))!;
      expect(j.inicio, DateTime(2027, 1, 2, 16));
    });

    test('sem horário ou sem confronto: não é jogo', () {
      for (final n in [
        'Prime Video Copa do Brasil 01 FHD', 'Caze TV 01', 'Jogo 01', 'NBA 03',
        'Flamengo x Vasco', // sem horário
        'Premiere 2 FHD 16:00', // sem confronto
        'SporTV X', 'X-Men 14:00',
      ]) {
        expect(jogoDoNomeDoCanal(n, _ref), isNull, reason: n);
      }
    });
  });

  group('Jogo no título da grade', () {
    final ini = DateTime(2026, 11, 15, 15, 50);
    test('campeonato antes de ":"', () {
      final j = jogoDoTituloDoPrograma('Copa do Brasil Feminina: Inter x Flamengo (ao vivo)', ini)!;
      expect((j.casa, j.fora, j.campeonato, j.doNome), ('Inter', 'Flamengo', 'Copa do Brasil Feminina', false));
    });
    test('títulos que não são jogo', () {
      for (final t in ['SporTV News', 'Seleção SporTV', 'Os Simpsons', 'Futebol Brasileirão 2026 Flamengo x Vasco']) {
        expect(jogoDoTituloDoPrograma(t, ini), isNull, reason: t);
      }
    });
  });

  group('Duplicatas', () {
    test('FHD/HD do mesmo jogo e a grade viram um jogo só, com todos os canais', () {
      final fhd = jogoDoNomeDoCanal('Internacional x Flamengo - 16:00 FHD', _ref)!..canais.add(_canal('1', 'Internacional x Flamengo - 16:00 FHD'));
      final hd = jogoDoNomeDoCanal('Internacional x Flamengo - 16:00 HD', _ref)!..canais.add(_canal('2', 'Internacional x Flamengo - 16:00 HD'));
      final grade = jogoDoTituloDoPrograma('Copa do Brasil: Inter x Flamengo', DateTime(2026, 11, 15, 15, 45))!
        ..canais.add(_canal('3', 'SporTV FHD', 'ESPORTES'));
      final outro = jogoDoNomeDoCanal('Chipre x Montenegro - 11:00 FHD', _ref)!..canais.add(_canal('4', 'Chipre x Montenegro - 11:00 FHD'));
      final r = juntarJogos([grade, hd, outro, fhd]);
      expect(r.map((j) => j.casa), ['Chipre', 'Internacional'], reason: 'ordenado por horário');
      final inter = r[1];
      expect(inter.inicio, DateTime(2026, 11, 15, 16), reason: 'horário do nome do canal');
      expect(inter.campeonato, 'Copa do Brasil');
      expect(inter.canais.map((c) => c.id), ['1', '2', '3'], reason: 'evento FHD, evento HD, depois a emissora');
    });

    test('mesmo confronto em horários distantes não junta', () {
      final a = JogoDaLista(inicio: DateTime(2026, 11, 15, 16), casa: 'Flamengo', fora: 'Vasco');
      final b = JogoDaLista(inicio: DateTime(2026, 11, 15, 21), casa: 'Flamengo', fora: 'Vasco');
      expect(juntarJogos([a, b]), hasLength(2));
      final c = JogoDaLista(inicio: DateTime(2026, 11, 15, 16), casa: 'Flamengo', fora: 'Palmeiras');
      expect(mesmoJogo(a, c), isFalse);
    });

    test('análise da lista: só categorias de jogos para nomes; esporte para a grade', () {
      final r = analisarCanais(([
        _canal('1', 'Internacional x Flamengo - 16:00 FHD'),
        _canal('2', 'Flamengo x Vasco - 16:00', 'FILMES 24 HORAS'), // categoria não é de jogos
        _canal('3', 'SporTV FHD', 'SPORTV'),
        _canal('4', 'SporTV HD', 'SPORTV'),
        _canal('5', 'Globo SP FHD', 'GLOBO CAPITAIS'),
        _canal('6', 'Discovery HD', 'DISCOVERY'),
      ], _ref));
      expect(r.jogosDosNomes.map((j) => j.casa), ['Internacional']);
      expect(r.canaisParaEpg.map((c) => c.id), ['3', '5'], reason: 'uma vez por emissora, melhor qualidade');
    });
  });

  group('Escudos: nomes e casos ambíguos', () {
    test('normalização', () {
      expect(normalizarNomeTime('Grêmio FBPA'), 'gremio fbpa');
      expect(normalizarNomeTime('Fortaleza EC'), 'fortaleza');
      expect(normalizarNomeTime('SÃO PAULO FC'), 'sao paulo');
      expect(normalizarNomeTime('Atlético-MG'), 'atletico mineiro');
      expect(normalizarNomeTime('Vasco'), 'vasco da gama');
    });

    test('ambíguos não buscam: iniciais', () {
      expect(chaveDeBusca('ATLETICO'), isNull);
      expect(chaveDeBusca('Atlético'), isNull);
      expect(chaveDeBusca('América'), isNull);
      expect(chaveDeBusca('Inter'), isNull);
      expect(chaveDeBusca('Internacional'), 'internacional');
    });

    test('iniciais', () {
      expect(iniciaisTime('Internacional'), 'INT');
      expect(iniciaisTime('São Paulo'), 'SP');
      expect(iniciaisTime('Vasco da Gama'), 'VG');
      expect(iniciaisTime('Fortaleza EC'), 'FOR');
    });

    Map<String, dynamic> resp(List<Map<String, String>> times) => {'teams': times};
    const badge = 'https://r2.thesportsdb.com/images/media/team/badge/x.png';

    test('só aceita futebol com nome igual (respostas reais da TheSportsDB)', () {
      // "Atletico MG" na TheSportsDB devolveu o ATK da Índia: não pode virar escudo
      expect(escolherEscudo('atletico mineiro',
          resp([{'strTeam': 'ATK', 'strSport': 'Soccer', 'strCountry': 'India', 'strTeamAlternate': 'Atlético de Kolkata', 'strBadge': badge}])), isNull);
      expect(escolherEscudo('atletico mineiro',
          resp([{'strTeam': 'Atlético Mineiro', 'strSport': 'Soccer', 'strCountry': 'Brazil', 'strTeamAlternate': 'Atlético', 'strBadge': badge}])), badge);
      expect(escolherEscudo('flamengo',
          resp([{'strTeam': 'Flamengo', 'strSport': 'Basketball', 'strCountry': 'Brazil', 'strBadge': badge}])), isNull);
      expect(escolherEscudo('sao paulo',
          resp([{'strTeam': 'São Paulo', 'strSport': 'Soccer', 'strCountry': 'Brazil', 'strTeamAlternate': 'São Paulo Futebol Clube', 'strBadge': badge}])), badge);
    });

    test('dois iguais: prefere Brasil; dois do Brasil: nenhum', () {
      final br = {'strTeam': 'Nacional', 'strSport': 'Soccer', 'strCountry': 'Brazil', 'strBadge': badge};
      final uy = {'strTeam': 'Nacional', 'strSport': 'Soccer', 'strCountry': 'Uruguay', 'strBadge': '${badge}2'};
      expect(escolherEscudo('nacional', resp([uy, br])), badge);
      expect(escolherEscudo('nacional', resp([br, {...br, 'strBadge': '${badge}3'}])), isNull);
    });

    test('serviço: busca uma vez, guarda em disco, 429 espera e tenta de novo', () async {
      SharedPreferences.setMockInitialValues({});
      var pedidos = 0, limite = 1;
      final client = MockClient((req) async {
        pedidos++;
        if (limite-- > 0) return http.Response('', 429);
        return http.Response(jsonEncode(resp([{'strTeam': 'Palmeiras', 'strSport': 'Soccer', 'strCountry': 'Brazil', 'strBadge': badge}])), 200);
      });
      final s = EscudosService(client: client, intervalo: Duration.zero, pausaLimite: Duration.zero);
      final v = s.escudo('Palmeiras');
      expect(v.value, isNull);
      await _esperar(v);
      expect(v.value, badge);
      expect(pedidos, 2);
      expect(identical(s.escudo('PALMEIRAS'), v), isTrue);

      // Outra abertura do app: vem do disco, sem rede
      final s2 = EscudosService(client: MockClient((_) async => throw Exception('sem rede')), intervalo: Duration.zero);
      final v2 = s2.escudo('Palmeiras');
      await _esperar(v2);
      expect(v2.value, badge);
    });

    test('serviço: falha de rede fica nas iniciais; ambíguo nem chama a rede', () async {
      SharedPreferences.setMockInitialValues({});
      var pedidos = 0;
      final s = EscudosService(
          client: MockClient((_) async {
            pedidos++;
            throw http.ClientException('sem rede');
          }),
          intervalo: Duration.zero);
      expect(s.escudo('Atlético').value, isNull);
      final v = s.escudo('Grêmio');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(v.value, isNull);
      expect(pedidos, 1);
    });
  });

  group('Plano B (serviço)', () {
    test('jogos do dia pelos nomes e pela grade, juntos e ordenados', () async {
      final epg = EpgService(
        fetcher: (id, limit) async => id == '3'
            ? {
                'epg_listings': [
                  {'title': 'Copa do Brasil: Inter x Flamengo', 'start_timestamp': DateTime(2026, 11, 15, 15, 45).millisecondsSinceEpoch ~/ 1000, 'stop_timestamp': DateTime(2099).millisecondsSinceEpoch ~/ 1000},
                  {'title': 'Brasileirão: Grêmio x Palmeiras', 'start_timestamp': DateTime(2026, 11, 15, 21, 30).millisecondsSinceEpoch ~/ 1000, 'stop_timestamp': DateTime(2099).millisecondsSinceEpoch ~/ 1000},
                ]
              }
            : {'epg_listings': []},
      );
      final svc = JogosDaListaService(
        carregarCanais: (_) async => [
          _canal('1', 'Internacional x Flamengo - 16:00 FHD'),
          _canal('2', 'Internacional x Flamengo - 16:00 HD'),
          _canal('3', 'SporTV FHD', 'SPORTV'),
        ],
        epg: epg,
      );
      final parciais = <int>[];
      final hoje = DateTime.now();
      final r = await svc.buscar(const AppSession(type: SessionType.simanplay), DateTime(hoje.year, hoje.month, hoje.day),
          parcial: (p) => parciais.add(p.jogos.length));
      // As datas dos nomes sem data são "hoje"; a grade de teste é de 15/11/2026
      expect(parciais.first, 1, reason: 'primeiro os nomes, sem esperar a grade');
      expect(r.jogos.first.casa, 'Internacional');
      expect(r.jogos.first.canais.map((c) => c.id), ['1', '2']);
    });

    test('lista que não carrega: nenhum jogo (sem erro)', () async {
      final svc = JogosDaListaService(carregarCanais: (_) async => throw Exception('x'));
      final r = await svc.buscar(const AppSession(type: SessionType.simanplay), DateTime.now());
      expect(r.jogos, isEmpty);
    });
  });
}

Future<void> _esperar(ValueListenable<String?> v) async {
  for (var i = 0; i < 100 && v.value == null; i++) {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}
