import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simanplay_iptv/core/jogos_lista.dart';
import 'package:simanplay_iptv/models/channel.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/services/grade_esportes_service.dart';
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
    final fim = DateTime(2026, 11, 15, 18);
    test('campeonato antes de ":" e marca de ao vivo', () {
      final j = jogoDoTituloDoPrograma('Copa do Brasil Feminina: Inter x Flamengo (ao vivo)', ini, fim: fim)!;
      expect((j.casa, j.fora, j.campeonato, j.doNome, j.aoVivo), ('Inter', 'Flamengo', 'Copa do Brasil Feminina', false, true));
      expect(jogoDoTituloDoPrograma('Brasileirão: Grêmio x Bahia', ini, fim: fim)!.aoVivo, isFalse);
      expect(jogoDoTituloDoPrograma('Grêmio x Bahia', ini, descricao: 'Transmissão AO VIVO da Arena', fim: fim)!.aoVivo, isTrue);
    });
    test('títulos que não são jogo', () {
      for (final t in ['SporTV News', 'Seleção SporTV', 'Os Simpsons', 'Futebol Brasileirão 2026 Flamengo x Vasco']) {
        expect(jogoDoTituloDoPrograma(t, ini, fim: fim), isNull, reason: t);
      }
    });
  });

  group('Grade real (Premiere, jes.lat, 16/11/2026)', () {
    // Entradas reais do get_short_epg: start/stop em timestamp (UTC). O servidor diz
    // America/Moncton (UTC-4), mas o "start" em texto vem em hora de Brasília.
    DateTime ts(int s) => emBrasilia(DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true));

    test('fuso: timestamp vira hora de Brasília (UTC-3), seja qual for o fuso do aparelho', () {
      expect(ts(1794834000), DateTime(2026, 11, 16, 10, 0)); // start='2026-11-16 10:00:00'
      expect(ts(1794884400), DateTime(2026, 11, 17, 0, 0)); // start='2026-11-17 00:00:00'
      expect(emBrasilia(DateTime.utc(2026, 11, 17, 2, 30)), DateTime(2026, 11, 16, 23, 30));
    });

    test('"Dia 18/11 - Corinthians x Botafogo" na grade de 16/11 e 17/11 00:00: chamada, fora', () {
      for (final (ini, fim) in [(1794834000, 1794841200), (1794884400, 1794891600)]) {
        expect(
            jogoDoTituloDoPrograma('Dia 18/11 - Corinthians x Botafogo', ts(ini),
                descricao: 'Corinthians e Botafogo jogam pela 35ª rodada do Segundo Turno do Brasileirão',
                fim: ts(fim)),
            isNull);
      }
      expect(jogoDoTituloDoPrograma('Dia 18/11 - Grêmio x Bahia', ts(1794884400), fim: ts(1794891600)), isNull);
      // No próprio dia 18/11 a data bate: vale (se estiver ao vivo)
      expect(jogoDoTituloDoPrograma('Dia 18/11 - Grêmio x Bahia (AO VIVO)', DateTime(2026, 11, 18, 21, 30),
              fim: DateTime(2026, 11, 18, 23, 30))?.aoVivo, isTrue);
    });

    test('reprises fora: VT, reprise, melhores momentos, compacto, gols da rodada', () {
      final ini = DateTime(2026, 11, 16, 11, 30), fim = DateTime(2026, 11, 16, 12);
      for (final (titulo, desc) in [
        ('VT - Botafogo x Atlético-MG', 'Aqui no Brasileirão tem coisa pra caramba!'),
        ('REPRISE: Flamengo x Palmeiras', ''),
        ('Melhores Momentos - Santos x Vasco', ''),
        ('Compacto: Bahia x Flamengo', ''),
        ('Gols da Rodada: Grêmio x Inter', ''),
        ('Grêmio x Inter', 'Reapresentação do clássico (VT)'),
      ]) {
        expect(jogoDoTituloDoPrograma('$titulo (AO VIVO)', ini, descricao: desc, fim: fim), isNull, reason: titulo);
      }
    });

    test('sem horário confiável: 00:00 com 24 h, bloco de 12 h, sem fim', () {
      final meiaNoite = DateTime(2026, 11, 16);
      expect(jogoDoTituloDoPrograma('Inter x Flamengo (AO VIVO)', meiaNoite, fim: DateTime(2026, 11, 17)), isNull);
      expect(jogoDoTituloDoPrograma('Inter x Flamengo (AO VIVO)', DateTime(2026, 11, 16, 8), fim: DateTime(2026, 11, 16, 20)), isNull);
      expect(jogoDoTituloDoPrograma('Inter x Flamengo (AO VIVO)', meiaNoite), isNull);
    });
  });

  group('Nomes dos times', () {
    test('PPV+, (ESP), (USA), qualidade e campeonato depois do "-"', () {
      final a = jogoDoNomeDoCanal(
          'PPV+ 01: Carlos Alcaraz (ESP) x Frances Tiafoe (USA) - ATP Finals (Round Robin - Day #2) 14:00 FHD', _ref)!;
      expect((a.casa, a.fora, a.campeonato, a.esporte), ('Carlos Alcaraz', 'Frances Tiafoe', 'ATP Finals', 'tenis'));
      final b = jogoDoNomeDoCanal('PPV 3 | 16/11 09:30 - Sri Lanka x Papua New Guinea 4K | ICC T20 World Cup Qualifier', _ref)!;
      expect((b.casa, b.fora, b.campeonato, b.esporte), ('Sri Lanka', 'Papua New Guinea', 'ICC T20 World Cup Qualifier', 'criquete'));
      final c = jogoDoNomeDoCanal('Irlanda x Portugal - 16:45 HD²', _ref)!;
      expect((c.casa, c.fora, c.campeonato, c.esporte), ('Irlanda', 'Portugal', null, null));
    });

    test('esporte pela categoria do canal (NBA PAY-PER-VIEW)', () {
      final r = analisarCanais(([_canal('9', 'Lakers x Celtics - 21:30', 'NBA PAY-PER-VIEW')], _ref));
      expect(r.jogosDosNomes.single.esporte, 'basquete');
    });

    test('detectarEsporte', () {
      expect(detectarEsporte('UFC 320: Pereira x Ankalaev'), 'mma');
      expect(detectarEsporte('Superliga de Vôlei'), 'volei');
      expect(detectarEsporte('NFL: Chiefs x Bills'), 'futebol_americano');
      expect(detectarEsporte('Copa do Brasil'), isNull);
      expect(detectarEsporte('Atlético-MG x Cruzeiro'), isNull);
    });
  });

  group('Duplicatas', () {
    test('FHD/HD do mesmo jogo e a grade viram um jogo só, com todos os canais', () {
      final fhd = jogoDoNomeDoCanal('Internacional x Flamengo - 16:00 FHD', _ref)!..canais.add(_canal('1', 'Internacional x Flamengo - 16:00 FHD'));
      final hd = jogoDoNomeDoCanal('Internacional x Flamengo - 16:00 HD', _ref)!..canais.add(_canal('2', 'Internacional x Flamengo - 16:00 HD'));
      final grade = jogoDoTituloDoPrograma('Copa do Brasil: Inter x Flamengo', DateTime(2026, 11, 15, 15, 45),
          fim: DateTime(2026, 11, 15, 18))!
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

    test('seleções: busca em inglês e no nome como veio', () {
      expect(buscasPara('Irlanda'), ['ireland', 'irlanda']);
      expect(buscasPara('Papua-Nova Guiné'), ['papua new guinea', 'papua nova guine']);
      expect(buscasPara('República Tcheca'), ['czech republic', 'republica tcheca']);
      expect(buscasPara('Sri Lanka'), ['sri lanka', 'sri lanka']);
      expect(buscasPara('Flamengo'), ['flamengo']);
      expect(buscasPara('Atlético'), isEmpty);
      expect(ehSelecao('Ireland'), isTrue);
      expect(ehSelecao('Irlanda'), isTrue);
      expect(ehSelecao('Carlos Alcaraz'), isFalse);
      // Resposta real da TheSportsDB para "Czech Republic" (alternativo em português)
      final czech = {'teams': [{'strTeam': 'Czech Republic', 'strSport': 'Soccer', 'strCountry': 'Czechia', 'strTeamAlternate': 'República Tcheca', 'strBadge': 'https://r2.thesportsdb.com/b.png'}]};
      expect(escolherEscudoEntre(buscasPara('República Tcheca'), czech), 'https://r2.thesportsdb.com/b.png');
    });

    test('serviço: seleção tenta o nome em inglês primeiro', () async {
      SharedPreferences.setMockInitialValues({});
      final termos = <String>[];
      final s = EscudosService(
          client: MockClient((req) async {
            termos.add(req.url.queryParameters['t']!);
            return http.Response(jsonEncode({'teams': [{'strTeam': 'Ireland', 'strSport': 'Soccer', 'strCountry': 'Ireland', 'strBadge': 'https://r2.thesportsdb.com/ie.png'}]}), 200);
          }),
          intervalo: Duration.zero);
      final v = s.escudo('Irlanda');
      await _esperar(v);
      expect(v.value, 'https://r2.thesportsdb.com/ie.png');
      expect(termos, ['ireland']);
      expect(s.escudo('Carlos Alcaraz', buscar: false).value, isNull);
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
    final hoje = agoraEmBrasilia();
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    DateTime h(int hora, [int m = 0, int d = 0]) => DateTime(dia.year, dia.month, dia.day + d, hora, m);
    ProgramaGrade prog(String c, String t, DateTime i, DateTime f, [String desc = '']) => ProgramaGrade(c, t, desc, i, f);

    test('nomes primeiro; grade do painel que marca AO VIVO: só ao vivo ou o que está nos eventos', () async {
      final svc = JogosDaListaService(
        carregarCanais: (_) async => [
          _canal('1', 'Internacional x Flamengo - 16:00 FHD'),
          _canal('2', 'Internacional x Flamengo - 16:00 HD'),
          _canal('3', 'SporTV FHD', 'SPORTV'),
          _canal('4', 'Premiere Clubes FHD', 'PREMIERE'),
        ],
        carregarGrade: (_, __, {ate}) async => [
          prog('3', 'Copa do Brasil: Inter x Flamengo', h(15, 45), h(18)),
          prog('3', 'Grécia x Sérvia - Ao Vivo', h(16, 15), h(18, 40)),
          prog('3', 'Ilhas Faroé x Moldávia - Ao Vivo', h(11, 45), h(14)),
          prog('3', 'Estônia x Bulgária - Ao Vivo', h(14), h(16)),
          prog('4', 'VT - Bahia x Flamengo', h(16, 30), h(17)),
          prog('4', 'Brasileirão: Grêmio x Bahia', h(20), h(22)),
          prog('3', 'País de Gales x Portugal - Ao Vivo', h(16, 15, 1), h(18, 40, 1)),
        ],
      );
      final parciais = <int>[];
      final r = await svc.buscar(const AppSession(type: SessionType.simanplay), dia, parcial: (p) => parciais.add(p.jogos.length));
      expect(parciais.first, 1, reason: 'primeiro os nomes, sem esperar a grade');
      expect(r.jogos.map((j) => '${j.casa} x ${j.fora}'),
          ['Ilhas Faroé x Moldávia', 'Estônia x Bulgária', 'Internacional x Flamengo', 'Grécia x Sérvia']);
      expect(r.jogos[2].canais.map((c) => c.id), ['1', '2', '3']);
      expect(r.temDadosDoDia, isTrue);
      final amanha = await svc.buscar(const AppSession(type: SessionType.simanplay), dia.add(const Duration(days: 1)));
      expect(amanha.jogos.map((j) => j.casa), ['País de Gales']);
      expect(amanha.diasComDados, containsAll([dia, dia.add(const Duration(days: 1))]));
      expect(amanha.diasComDados.contains(dia.subtract(const Duration(days: 1))), isFalse);
    });

    test('lista sem dados para o dia: temDadosDoDia falso', () async {
      final svc = JogosDaListaService(carregarCanais: (_) async => [], carregarGrade: (_, __, {ate}) async => []);
      final r = await svc.buscar(const AppSession(type: SessionType.simanplay), dia.subtract(const Duration(days: 1)));
      expect(r.jogos, isEmpty);
      expect(r.temDadosDoDia, isFalse);
    });

    test('lista que não carrega: nenhum jogo (sem erro)', () async {
      final svc = JogosDaListaService(carregarCanais: (_) async => throw Exception('x'), carregarGrade: (_, __, {ate}) async => []);
      final r = await svc.buscar(const AppSession(type: SessionType.simanplay), DateTime.now());
      expect(r.jogos, isEmpty);
    });
  });

  group('Regra AO VIVO adaptável (jogosDaGrade)', () {
    final dia = DateTime(2026, 11, 17);
    DateTime h(int hora, [int m = 0, int d = 0]) => DateTime(2026, 11, 17 + d, hora, m);
    final canais = {'5': _canal('5', 'Combate FHD', 'COMBATE'), '6': _canal('6', 'ESPN FHD', 'ESPN')};

    test('painel que marca AO VIVO: boxe repetido do Combate fica fora', () {
      final r = jogosDaGrade([
        ProgramaGrade('6', 'Dinamarca x Noruega - Ao Vivo', '', h(16, 30), h(18, 45)),
        ProgramaGrade('6', 'Polônia x Suécia - Ao Vivo', '', h(16, 15), h(18, 45)),
        ProgramaGrade('6', 'NBB: Corinthians x Paulistano - Ao Vivo', '', h(20, 20), h(22, 30)),
        ProgramaGrade('5', 'Boxe - Baumgardner x Turhan', 'Boxe - Baumgardner X Turhan', h(14, 10), h(16, 10)),
      ], dia, const [], canais);
      expect(r.map((j) => j.casa), isNot(contains('Baumgardner')));
      expect(r, hasLength(3));
    });

    test('painel que não marca AO VIVO: aceita 08:00-23:59, sem repetição em 48 h', () {
      final r = jogosDaGrade([
        ProgramaGrade('6', 'Brasileirão: Atlético-MG x São Paulo', '', h(18, 45), h(21)),
        ProgramaGrade('6', 'Liga dos Campeões: Real Madrid x Liverpool', '', h(7, 0), h(9)),
        ProgramaGrade('5', 'Boxe - Baumgardner x Turhan', '', h(21, 40, -1), h(23, 35, -1)),
        ProgramaGrade('5', 'Boxe - Baumgardner x Turhan', '', h(14, 10), h(16, 10)),
        ProgramaGrade('6', 'JOGO COMPLETO: PRAIA CLUBE X MACKENZIE | SUPERLIGA FEMININA DE VÔLEI', '', h(15), h(18)),
      ], dia, const [], canais);
      expect(r.map((j) => '${j.casa} x ${j.fora}'), ['Atlético-MG x São Paulo']);
      expect(r.single.canais.single.id, '6');
    });
  });

  group('Títulos reais da grade (jes.lat)', () {
    test('"Hoje a partir das 20:30 - Cruzeiro x Palmeiras" às 00:00: jogo do dia às 20:30', () {
      final j = jogoDoTituloDoPrograma('Hoje a partir das 20:30 - Cruzeiro x Palmeiras', DateTime(2026, 11, 18, 0),
          descricao: 'Cruzeiro e Palmeiras jogam pela 35ª rodada', fim: DateTime(2026, 11, 18, 2))!;
      expect((j.casa, j.fora, j.inicio, j.aoVivo), ('Cruzeiro', 'Palmeiras', DateTime(2026, 11, 18, 20, 30), true));
      final b = jogoDoTituloDoPrograma('Hoje a partir das 20:30 - Cruzeiro x Palmeiras', DateTime(2026, 11, 18, 2),
          fim: DateTime(2026, 11, 18, 4))!;
      expect(juntarJogos([j, b]), hasLength(1));
    });

    test('"AO VIVO E COM IMAGENS", "E EXCLUSIVO" e campeonato depois do "|"', () {
      final a = jogoDoTituloDoPrograma(
          'BORUSSIA MONCHENGLABACH X BORUSSIA DORTMUND AO VIVO E COM IMAGENS | RODADA 10 | BUNDESLIGA',
          DateTime(2026, 11, 21, 11, 30), fim: DateTime(2026, 11, 21, 14, 30))!;
      expect((a.casa, a.fora, a.aoVivo), ('BORUSSIA MONCHENGLABACH', 'BORUSSIA DORTMUND', true));
      final b = jogoDoTituloDoPrograma('SEVILLA X REAL BÉTIS: AO VIVO, COM IMAGENS E EXCLUSIVO | LALIGA | RODADA 13',
          DateTime(2026, 11, 21, 14, 30), fim: DateTime(2026, 11, 21, 17, 30))!;
      expect((b.casa, b.fora, b.campeonato), ('SEVILLA', 'REAL BÉTIS', 'LALIGA'));
    });

    test('"JOGO COMPLETO" é reprise; "LOGO APÓS O AMISTOSO..." não é jogo', () {
      expect(jogoDoTituloDoPrograma('JOGO COMPLETO: PRAIA CLUBE X MACKENZIE | SUPERLIGA', DateTime(2026, 11, 16, 15),
          fim: DateTime(2026, 11, 16, 18)), isNull);
      expect(jogoDoTituloDoPrograma('AO VIVO: LOGO APÓS O AMISTOSO BRASIL X CINGAPURA | GERAL CAZÉTV',
          DateTime(2026, 11, 17, 8, 45), fim: DateTime(2026, 11, 17, 11, 45)), isNull);
    });
  });

  group('xmltv.php', () {
    const xml = '<?xml version="1.0" encoding="utf-8" ?><tv>\n'
        '<channel id="SPORTV"><display-name>SporTV</display-name></channel>\n'
        '<programme start="20261115135500 -0300" stop="20261115160000 -0300" channel="SPORTV"><title>Finlândia x San Marino - Ao Vivo</title><desc>Eliminatórias</desc></programme>\n'
        '<programme start="20261115213000 -0300" stop="20261115223000 -0300" channel="SPORTV"><title>VT - França x Turquia</title></programme>\n'
        '<programme start="20261115160000 -0300" stop="20261115164500 -0300" channel="SPORTV"><title>Aquecimento sportv - Ao Vivo</title></programme>\n'
        '<programme start="20261115190000 +0000" stop="20261115210000 +0000" channel="OUTRO"><title>A x B</title></programme>\n'
        '<programme start="20261116191500 +0000" stop="20261116214000 +0000" channel="SPORTV"><title>Grécia &amp; Cia x Sérvia</title></programme>\n'
        '</tv>';

    test('lê só os canais de esporte, só o que parece jogo, com fuso convertido', () {
      final r = lerXmltv((xml, {'SPORTV': ['6928', '6929']}));
      expect(r.map((p) => '${p.canal} ${p.titulo}'), [
        '6928 Finlândia x San Marino - Ao Vivo', '6929 Finlândia x San Marino - Ao Vivo',
        '6928 VT - França x Turquia', '6929 VT - França x Turquia',
        '6928 Grécia & Cia x Sérvia', '6929 Grécia & Cia x Sérvia',
      ]);
      expect(r.first.inicio, DateTime(2026, 11, 15, 13, 55));
      expect(r.first.descricao, 'Eliminatórias');
      expect(r.last.inicio, DateTime(2026, 11, 16, 16, 15), reason: '19:15 UTC = 16:15 em Brasília');
    });

    test('horaXmltv', () {
      expect(horaXmltv('20261115135500 -0300'), DateTime(2026, 11, 15, 13, 55));
      expect(horaXmltv('20261116030000 +0000'), DateTime(2026, 11, 16, 0, 0));
      expect(horaXmltv('20261116000000 -0400'), DateTime(2026, 11, 16, 1, 0), reason: 'America/Moncton');
      expect(horaXmltv('lixo'), isNull);
    });

    final sessao = AppSession.xtream(host: 'http://painel.exemplo', username: 'u', password: 'p');
    List<Channel> canais() => [
          Channel(id: '6928', name: 'SporTV FHD', streamUrl: '', categoryId: '1', categoryName: 'SPORTV', epgKey: 'SPORTV'),
          for (var i = 1; i <= 30; i++)
            Channel(id: '${100 + i}', name: 'Premiere Clubes $i FHD', streamUrl: '', categoryId: '2', categoryName: 'PREMIERE'),
        ];

    test('UM pedido (xmltv) na primeira abertura; nenhum ao reabrir em 60 min; ontem fica guardado', () async {
      SharedPreferences.setMockInitialValues({});
      final caminhos = <String>[];
      var agora = DateTime(2026, 11, 16, 12);
      final g = GradeEsportesService(
        client: MockClient((req) async {
          caminhos.add(req.url.path);
          return http.Response.bytes(utf8.encode(xml), 200);
        }),
        clock: () => agora,
      );
      final p1 = await g.programas(sessao, canais());
      expect(caminhos, ['/xmltv.php']);
      expect(p1.where((p) => p.inicio.day == 15), isNotEmpty);

      agora = agora.add(const Duration(minutes: 59));
      final g2 = GradeEsportesService(client: MockClient((_) async => throw Exception('não devia chamar')), clock: () => agora);
      expect(await g2.programas(sessao, canais()), hasLength(p1.length));
      expect(g2.pedidos, 0);

      agora = agora.add(const Duration(minutes: 2));
      final so16 = xml.split('\n').where((l) => !l.contains('start="20261115')).join('\n');
      final g3 = GradeEsportesService(client: MockClient((_) async => http.Response.bytes(utf8.encode(so16), 200)), clock: () => agora);
      final p3 = await g3.programas(sessao, canais());
      expect(g3.pedidos, 1);
      expect(p3.where((p) => p.inicio.day == 15), isNotEmpty, reason: 'ontem continua guardado em disco');
      expect(p3.where((p) => p.inicio.day == 16), isNotEmpty);
    });

    test('xmltv curto (~24 h): "Amanhã" complementa canal a canal uma vez; reabrir em 60 min: 0 pedidos', () async {
      SharedPreferences.setMockInitialValues({});
      final caminhos = <String>[];
      final agora = DateTime(2026, 11, 16, 12);
      MockClient cliente() => MockClient((req) async {
            caminhos.add(req.url.path.endsWith('xmltv.php') ? 'xmltv' : 'tabela ${req.url.queryParameters['stream_id']}');
            if (req.url.path.endsWith('xmltv.php')) return http.Response.bytes(utf8.encode(xml), 200);
            return http.Response.bytes(utf8.encode(jsonEncode({'epg_listings': [
              {'title': 'País de Gales x Portugal - Ao Vivo', 'start_timestamp': DateTime.utc(2026, 11, 17, 19, 15).millisecondsSinceEpoch ~/ 1000,
               'stop_timestamp': DateTime.utc(2026, 11, 17, 21, 40).millisecondsSinceEpoch ~/ 1000},
            ]})), 200);
          });
      final g = GradeEsportesService(client: cliente(), intervalo: Duration.zero, clock: () => agora);
      // Hoje: só o xmltv (sem "ate": hoje e ontem saem do xmltv)
      await g.programas(sessao, canais());
      expect(caminhos, ['xmltv']);
      // Amanhã: o xmltv para em 16/11 21:40 -> complemento canal a canal (até 25)
      final amanha = await g.programas(sessao, canais(), ate: DateTime(2026, 11, 17, 23));
      expect(caminhos.where((c) => c.startsWith('tabela')).length, inInclusiveRange(1, maxCanaisGradeCanalACanal));
      expect(amanha.where((p) => p.titulo.startsWith('País de Gales')), isNotEmpty);
      expect(amanha.where((p) => p.inicio.day == 15), isNotEmpty, reason: 'ontem (do xmltv) continua');
      // Reabrir o app em 30 min (outro serviço, mesma cópia em disco): nenhum pedido
      final g2 = GradeEsportesService(client: MockClient((_) async => throw Exception('não devia chamar')),
          clock: () => agora.add(const Duration(minutes: 30)));
      await g2.programas(sessao, canais(), ate: DateTime(2026, 11, 17, 23));
      await g2.programas(sessao, canais());
      expect(g2.pedidos, 0);
    });

    test('sem xmltv.php: no máximo 25 canais relevantes, 2 por vez', () async {
      SharedPreferences.setMockInitialValues({});
      var aoMesmoTempo = 0, maximo = 0;
      final ids = <String>[];
      final g = GradeEsportesService(
        intervalo: Duration.zero,
        client: MockClient((req) async {
          if (req.url.path.endsWith('xmltv.php')) return http.Response('', 404);
          aoMesmoTempo++;
          maximo = aoMesmoTempo > maximo ? aoMesmoTempo : maximo;
          ids.add(req.url.queryParameters['stream_id']!);
          await Future.delayed(const Duration(milliseconds: 5));
          aoMesmoTempo--;
          return http.Response(jsonEncode({'epg_listings': []}), 200);
        }),
      );
      await g.programas(sessao, canais());
      expect(ids.length, lessThanOrEqualTo(maxCanaisGradeCanalACanal));
      expect(maximo, lessThanOrEqualTo(2));
      expect(ids.first, '6928', reason: 'SporTV antes do Premiere');
    });

    test('conta recusada (429/401/auth 0): para na hora', () async {
      for (final resposta in [
        http.Response('', 429),
        http.Response('', 401),
        http.Response(jsonEncode({'user_info': {'auth': 0}}), 200),
      ]) {
        SharedPreferences.setMockInitialValues({});
        var pedidos = 0;
        final g = GradeEsportesService(
          intervalo: Duration.zero,
          client: MockClient((req) async {
            pedidos++;
            if (req.url.path.endsWith('xmltv.php')) return http.Response('', 404);
            return resposta;
          }),
        );
        expect(await g.programas(sessao, canais()), isEmpty);
        expect(pedidos, lessThanOrEqualTo(3), reason: 'xmltv + no máximo os 2 que já estavam em andamento');
      }
      SharedPreferences.setMockInitialValues({});
      var pedidos = 0;
      final g = GradeEsportesService(client: MockClient((_) async {
        pedidos++;
        return http.Response('', 429);
      }));
      await g.programas(sessao, canais());
      expect(pedidos, 1, reason: '429 já no xmltv: nem tenta canal a canal');
    });
  });
}


Future<void> _esperar(ValueListenable<String?> v) async {
  for (var i = 0; i < 100 && v.value == null; i++) {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}
