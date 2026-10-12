// "Jogos do Dia": canal certo no jogo certo (cenário do print de 12/10/2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/core/sports_match.dart';
import 'package:simanplay_iptv/models/channel.dart';
import 'package:simanplay_iptv/services/epg_service.dart';
import 'package:simanplay_iptv/services/sports_service.dart';

Channel ch(String id, String name) =>
    Channel(id: id, name: name, streamUrl: 'http://x/$id.ts', categoryId: '1', categoryName: 'Esportes');

void main() {
  final hoje = DateTime(2026, 10, 12);
  Fixture jogo(int id, String casa, String fora, int h, int m, {String liga = 'Serie A'}) =>
      Fixture(id: id, leagueName: liga, kickoff: hoje.add(Duration(hours: h, minutes: m)), homeName: casa, awayName: fora);

  final coritiba = jogo(1, 'Coritiba', 'Botafogo', 16, 0);
  final chape = jogo(2, 'Chapecoense-sc', 'Atletico Paranaense', 19, 30);
  final braga = jogo(3, 'RB Bragantino', 'Cruzeiro', 21, 0);
  final novori = jogo(4, 'Gremio Novorizontino', 'Ponte Preta', 19, 0, liga: 'Serie B');
  final botasp = jogo(5, 'Botafogo SP', 'Ceara', 21, 0, liga: 'Serie B');
  final jogos = [coritiba, chape, braga, novori, botasp];

  final canais = [
    ch('e1', 'Grêmio Novorizont.. x Ponte Preta - 19:00 Série B FHD'),
    ch('e2', 'Grêmio Novorizont.. x Ponte Preta - 19:00 Série B HD'),
    ch('e3', 'Botafogo-SP x Ceará - 21:00 Série B FHD'),
    ch('e4', 'Botafogo-SP x Ceará - 21:00 Série B HD'),
    ch('e5', 'Coritiba x Botafogo - 16:00 Série A'),
    ch('e6', 'RB Bragantino x Cruzeiro - 21:00 Série A HD'),
    ch('s1', 'SporTV FHD'), ch('s2', 'SporTV FHD²'), ch('s3', 'SporTV HD'), ch('s4', 'SporTV HD²'),
    ch('s5', 'SporTV SD'), ch('s6', 'SporTV SD²'),
    ch('p1', 'Premiere Clubes 2 FHD'), ch('p2', 'Premiere Clubes 2 HD'),
  ];
  // A lista reaproveita a grade da emissora nos canais de evento: todos "passam" Bragantino x Cruzeiro
  List<EpgProgram> grade(Channel c) => [
        EpgProgram(
            title: 'Brasileirão Série A: RB Bragantino x Cruzeiro',
            description: '',
            start: hoje.add(const Duration(hours: 20, minutes: 50)),
            end: hoje.add(const Duration(hours: 23)))
      ];

  final r = matchFixturesToChannels(jogos, canais, grade);
  List<String> nomes(Fixture f) => (r[f.id] ?? []).map((c) => c.name).toList();

  test('canal de evento de outro jogo não entra no jogo errado', () {
    expect(nomes(braga).any((n) => n.contains('Novorizont') || n.contains('Ceará')), isFalse);
  });

  test('canal com os dois times no nome vai para o próprio jogo, mesmo sem grade', () {
    expect(nomes(coritiba), ['Coritiba x Botafogo - 16:00 Série A']);
    expect(nomes(novori), ['Grêmio Novorizont.. x Ponte Preta - 19:00 Série B FHD']);
    expect(nomes(botasp), ['Botafogo-SP x Ceará - 21:00 Série B FHD']);
  });

  test('evento do jogo primeiro, depois as emissoras, cada uma uma vez na melhor qualidade', () {
    expect(nomes(braga), [
      'RB Bragantino x Cruzeiro - 21:00 Série A HD',
      'SporTV FHD',
      'Premiere Clubes 2 FHD',
    ]);
  });

  test('jogo sem canal continua sem canal', () {
    expect(nomes(chape), isEmpty);
  });

  test('Botafogo (RJ) não pega o canal do Botafogo-SP', () {
    expect(nomes(coritiba).any((n) => n.contains('Botafogo-SP')), isFalse);
  });

  test('nome base e qualidade', () {
    expect(channelBaseName('SporTV HD²'), channelBaseName('SporTV FHD'));
    expect(channelQualityRank('SporTV FHD') > channelQualityRank('SporTV HD'), isTrue);
    expect(channelQualityRank('SporTV HD') > channelQualityRank('SporTV HD²'), isTrue);
    expect(channelQualityRank('SporTV HD²') > channelQualityRank('SporTV SD'), isTrue);
    expect(nameLooksLikeEvent('Coritiba x Botafogo - 16:00'), isTrue);
    expect(nameLooksLikeEvent('SporTV 2 HD'), isFalse);
    expect(isSportsCategory('EVENTOS AO VIVO'), isTrue);
    expect(isSportsCategory('PPV'), isTrue);
  });
}
