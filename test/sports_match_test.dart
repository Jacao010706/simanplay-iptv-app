import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/core/sports_match.dart';

void main() {
  group('normalização', () {
    test('sem acento, minúsculo, sem pontuação e sem FC/EC/SC/CF/AC', () {
      expect(normalizeText('São Paulo F.C. — Ação!'), 'sao paulo f c acao');
      expect(normalizeTeamName('Atlético-MG'), 'atletico mg');
      expect(normalizeTeamName('Fortaleza EC'), 'fortaleza');
      expect(normalizeTeamName('Criciúma SC'), 'criciuma');
      expect(normalizeTeamName('AC Milan'), 'milan');
      expect(normalizeTeamName('Sport Recife'), 'sport recife');
    });
  });

  group('título x times', () {
    test('os dois times no título', () {
      expect(titleMatchesFixture('Brasileirão: Flamengo x Palmeiras', 'Flamengo', 'Palmeiras'), isTrue);
      expect(titleMatchesFixture('FUTEBOL - GRÊMIO X INTERNACIONAL', 'Gremio', 'Internacional'), isTrue);
      expect(titleMatchesFixture('São Paulo x Corinthians (ao vivo)', 'Sao Paulo', 'Corinthians'), isTrue);
    });

    test('nome parcial: atletico mg / Atlético Mineiro, RB Bragantino / Bragantino', () {
      expect(titleMatchesFixture('Atlético Mineiro x Cruzeiro', 'Atletico-MG', 'Cruzeiro'), isTrue);
      expect(titleMatchesFixture('Atlético-MG x Cruzeiro', 'Atletico MG', 'Cruzeiro'), isTrue);
      expect(titleMatchesFixture('Bragantino x Santos', 'RB Bragantino', 'Santos'), isTrue);
      expect(titleMatchesFixture('Athletico Paranaense x Vasco', 'Athletico-PR', 'Vasco DA Gama'), isTrue);
      expect(titleMatchesFixture('Man. United x Liverpool', 'Manchester United', 'Liverpool'), isFalse,
          reason: 'abreviação diferente não deve casar por engano');
    });

    test('falso positivo: só um time no título não basta', () {
      expect(titleMatchesFixture('Flamengo x Vasco', 'Flamengo', 'Palmeiras'), isFalse);
      expect(titleMatchesFixture('Programa do Flamengo', 'Flamengo', 'Palmeiras'), isFalse);
      expect(titleMatchesFixture('Jornal Esportivo', 'Flamengo', 'Palmeiras'), isFalse);
    });

    test('sigla de estado separa times de mesmo nome', () {
      expect(titleMatchesFixture('Atlético-GO x Cruzeiro', 'Atletico-MG', 'Cruzeiro'), isFalse);
      expect(titleMatchesFixture('Atlético Goianiense x Cruzeiro', 'Atletico-GO', 'Cruzeiro'), isTrue);
    });
  });

  group('janela de horário', () {
    final kickoff = DateTime(2026, 10, 1, 21, 30);

    test('programa que cobre o início do jogo', () {
      expect(programCoversKickoff(DateTime(2026, 10, 1, 21, 0), DateTime(2026, 10, 1, 23, 30), kickoff), isTrue);
    });

    test('tolerância de 30 minutos (grade atrasada ou adiantada)', () {
      // Programa marcado para começar 20 min depois do jogo
      expect(programCoversKickoff(DateTime(2026, 10, 1, 21, 50), DateTime(2026, 10, 1, 23, 50), kickoff), isTrue);
      // Programa que terminou 20 min antes
      expect(programCoversKickoff(DateTime(2026, 10, 1, 19, 0), DateTime(2026, 10, 1, 21, 10), kickoff), isTrue);
      // Fora da tolerância
      expect(programCoversKickoff(DateTime(2026, 10, 1, 22, 1), DateTime(2026, 10, 2, 0, 0), kickoff), isFalse);
      expect(programCoversKickoff(DateTime(2026, 10, 1, 18, 0), DateTime(2026, 10, 1, 20, 59), kickoff), isFalse);
    });

    test('título certo em outro horário (reprise) não conta', () {
      expect(
        programShowsFixture(
          title: 'Flamengo x Palmeiras',
          start: DateTime(2026, 10, 2, 9, 0),
          end: DateTime(2026, 10, 2, 11, 0),
          homeTeam: 'Flamengo',
          awayTeam: 'Palmeiras',
          kickoff: kickoff,
        ),
        isFalse,
      );
      expect(
        programShowsFixture(
          title: 'Flamengo x Palmeiras',
          start: DateTime(2026, 10, 1, 21, 15),
          end: DateTime(2026, 10, 1, 23, 30),
          homeTeam: 'Flamengo',
          awayTeam: 'Palmeiras',
          kickoff: kickoff,
        ),
        isTrue,
      );
    });
  });

  test('categorias de esporte', () {
    for (final c in ['ESPORTES', 'Sports HD', 'Premiere FC', 'ESPN', 'SporTV', 'Combate', 'Brasileirão', 'Futebol',
      'DAZN', 'CazéTV', 'TNT Sports', 'Band Sports', 'GOAT']) {
      expect(isSportsCategory(c), isTrue, reason: c);
    }
    for (final c in ['Filmes', 'Notícias', 'Infantil', 'Abertos']) {
      expect(isSportsCategory(c), isFalse, reason: c);
    }
  });
}
