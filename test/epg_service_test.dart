import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/services/epg_service.dart';

String b64(String s) => base64.encode(utf8.encode(s));
int ts(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

void main() {
  // Horário fixo: 1/out/2026 20:30 (hora local)
  final agora = DateTime(2026, 10, 1, 20, 30);

  Map<String, dynamic> item(String titulo, DateTime ini, DateTime fim, {String desc = ''}) => {
        'title': b64(titulo),
        'description': b64(desc),
        'start_timestamp': '${ts(ini)}',
        'stop_timestamp': ts(fim),
      };

  group('parseEpgListings', () {
    test('título e descrição em base64 (UTF-8), horários por timestamp', () {
      final p = parseEpgListings({
        'epg_listings': [
          item('Jornal Nacional', DateTime(2026, 10, 1, 20, 0), DateTime(2026, 10, 1, 21, 0),
              desc: 'Notícias do dia, com acentuação'),
        ]
      });
      expect(p.single.title, 'Jornal Nacional');
      expect(p.single.description, 'Notícias do dia, com acentuação');
      expect(p.single.start, DateTime(2026, 10, 1, 20, 0));
      expect(p.single.end, DateTime(2026, 10, 1, 21, 0));
    });

    test('texto que não é base64 fica como veio', () {
      expect(decodeEpgText('Futebol: Flamengo x Palmeiras'), 'Futebol: Flamengo x Palmeiras');
      expect(decodeEpgText('News'), 'News');
      expect(decodeEpgText(b64('Série B — Ação')), 'Série B — Ação');
      expect(decodeEpgText(null), '');
    });

    test('horários em texto (start/end ou start/stop) e em UTC', () {
      final p = parseEpgListings({
        'epg_listings': [
          {'title': 'Depois', 'start': '2026-10-01 22:00:00', 'stop': '2026-10-01 23:00:00'},
          {'title': 'Antes', 'start': '2026-10-01 21:00:00', 'end': '2026-10-01 22:00:00'},
          {'title': 'UTC', 'start': '2026-10-02T03:00:00Z', 'end': '2026-10-02T04:00:00Z'},
        ]
      });
      expect(p.map((e) => e.title), ['Antes', 'Depois', 'UTC'], reason: 'deve sair ordenado');
      expect(p[0].start, DateTime(2026, 10, 1, 21, 0));
      expect(p[1].end, DateTime(2026, 10, 1, 23, 0));
      expect(p[2].start, DateTime.utc(2026, 10, 2, 3).toLocal());
      expect(p[2].start.isUtc, isFalse, reason: 'deve virar hora local');
    });

    test('ignora terminados, sem horário ou com fim antes do início', () {
      final p = parseEpgListings({
        'epg_listings': [
          item('Terminou', DateTime(2026, 10, 1, 19, 0), DateTime(2026, 10, 1, 20, 0)),
          item('No ar', DateTime(2026, 10, 1, 20, 0), DateTime(2026, 10, 1, 21, 0)),
          {'title': 'Sem horario'},
          item('Invertido', DateTime(2026, 10, 1, 23, 0), DateTime(2026, 10, 1, 22, 0)),
          'lixo',
        ]
      }, now: agora);
      expect(p.map((e) => e.title), ['No ar']);
      expect(parseEpgListings(null), isEmpty);
      expect(parseEpgListings({'epg_listings': false}), isEmpty);
    });
  });

  group('atual, próximos e progresso (horário fixo)', () {
    final grade = parseEpgListings({
      'epg_listings': [
        item('A', DateTime(2026, 10, 1, 20, 0), DateTime(2026, 10, 1, 21, 0)),
        item('B', DateTime(2026, 10, 1, 21, 0), DateTime(2026, 10, 1, 22, 0)),
        item('C', DateTime(2026, 10, 1, 22, 0), DateTime(2026, 10, 1, 23, 0)),
        item('D', DateTime(2026, 10, 1, 23, 0), DateTime(2026, 10, 2, 0, 0)),
        item('E', DateTime(2026, 10, 2, 0, 0), DateTime(2026, 10, 2, 1, 0)),
      ]
    });

    test('programa atual', () {
      expect(currentProgram(grade, agora)?.title, 'A');
      expect(currentProgram(grade, DateTime(2026, 10, 1, 21, 0))?.title, 'B', reason: 'no limite vale o que começa');
      expect(currentProgram(grade, DateTime(2026, 10, 1, 19, 0)), isNull);
    });

    test('próximos N', () {
      expect(upcomingPrograms(grade, agora, 3).map((e) => e.title), ['B', 'C', 'D']);
      expect(upcomingPrograms(grade, DateTime(2026, 10, 1, 23, 30), 3).map((e) => e.title), ['E']);
    });

    test('progresso de 0 a 1', () {
      final a = grade.first;
      expect(programProgress(a, agora), closeTo(0.5, 0.001));
      expect(programProgress(a, DateTime(2026, 10, 1, 19, 0)), 0);
      expect(programProgress(a, DateTime(2026, 10, 1, 22, 0)), 1);
      expect(formatHm(a.start), '20:00');
    });
  });

  group('EpgService', () {
    test('cache: não repete a requisição por 10 minutos e descarta o que terminou', () async {
      var relogio = agora;
      var chamadas = 0;
      final svc = EpgService(
        clock: () => relogio,
        fetcher: (id, limit) async {
          chamadas++;
          expect(limit, 10);
          return {
            'epg_listings': [
              item('A', DateTime(2026, 10, 1, 20, 0), DateTime(2026, 10, 1, 21, 0)),
              item('B', DateTime(2026, 10, 1, 21, 0), DateTime(2026, 10, 1, 22, 0)),
            ]
          };
        },
      );
      expect(svc.cached('1'), isNull);
      expect((await svc.getEpg('1')).map((e) => e.title), ['A', 'B']);
      expect((await svc.getEpg('1')).length, 2);
      expect(chamadas, 1, reason: 'segunda leitura deveria vir do cache');

      relogio = DateTime(2026, 10, 1, 20, 39);
      expect(svc.cached('1')?.length, 2);
      relogio = DateTime(2026, 10, 1, 21, 5); // A terminou, cache já venceu
      expect(svc.cached('1'), isNull);
      expect((await svc.getEpg('1')).map((e) => e.title), ['B']);
      expect(chamadas, 2);

      await svc.getEpg('2');
      expect(chamadas, 3, reason: 'cada canal tem seu cache');
    });

    test('pedidos repetidos ao mesmo tempo reaproveitam o mesmo Future', () async {
      var chamadas = 0;
      final resposta = Completer<dynamic>();
      final svc = EpgService(clock: () => agora, fetcher: (id, limit) {
        chamadas++;
        return resposta.future;
      });
      final f1 = svc.getEpg('9');
      final f2 = svc.getEpg('9');
      expect(identical(f1, f2), isTrue);
      resposta.complete({'epg_listings': [item('X', DateTime(2026, 10, 1, 20), DateTime(2026, 10, 1, 21))]});
      expect((await f1).single.title, 'X');
      expect((await f2).single.title, 'X');
      expect(chamadas, 1);
    });

    test('no máximo 4 requisições simultâneas', () async {
      var ativas = 0, pico = 0;
      final pendentes = <Completer<dynamic>>[];
      final svc = EpgService(clock: () => agora, fetcher: (id, limit) async {
        ativas++;
        if (ativas > pico) pico = ativas;
        final c = Completer<dynamic>();
        pendentes.add(c);
        final r = await c.future;
        ativas--;
        return r;
      });
      final futuros = [for (var i = 0; i < 10; i++) svc.getEpg('$i')];
      await Future<void>.delayed(Duration.zero);
      expect(ativas, 4);
      while (pendentes.isNotEmpty) {
        pendentes.removeAt(0).complete({'epg_listings': []});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait(futuros);
      expect(pico, 4);
    });

    test('falha na rede devolve lista vazia; sem Xtream não busca nada', () async {
      final svc = EpgService(clock: () => agora, fetcher: (id, limit) async => throw Exception('offline'));
      expect(await svc.getEpg('1'), isEmpty);
      expect(await EpgService(clock: () => agora).getEpg('1'), isEmpty);
    });
  });
}
