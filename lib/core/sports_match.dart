// "Onde passa": reconhece na programação dos canais o jogo de dois times
// (funções puras, testáveis).

const Map<String, String> _accents = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y', 'ß': 'ss',
};

/// Minúsculo, sem acento e sem pontuação, com espaços simples.
String normalizeText(String text) {
  final lower = text.toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    final c = _accents[ch] ?? ch;
    b.write(RegExp(r'[a-z0-9]').hasMatch(c) ? c : ' ');
  }
  return b.toString().split(' ').where((w) => w.isNotEmpty).join(' ');
}

// Siglas de clube que não ajudam a reconhecer o time
const Set<String> _clubTokens = {'fc', 'ec', 'sc', 'cf', 'ac'};

/// Nome do time para comparação: sem acento, minúsculo, sem FC/EC/SC/CF/AC e pontuação.
/// "Atlético-MG" -> "atletico mg"; "Fortaleza EC" -> "fortaleza".
String normalizeTeamName(String name) =>
    normalizeText(name).split(' ').where((w) => !_clubTokens.contains(w)).join(' ');

// Siglas de estado que aparecem no nome do time ("Atletico-MG") e como a
// emissora costuma escrever ("Atlético Mineiro").
const Map<String, List<String>> _stateAliases = {
  'mg': ['mineiro'],
  'pr': ['paranaense'],
  'go': ['goianiense'],
  'rj': ['carioca'],
  'sp': ['paulista'],
  'rs': ['gaucho'],
  'ba': ['baiano'],
  'pe': ['pernambucano'],
  'ce': ['cearense'],
  'sc': ['catarinense'],
};

const Set<String> _connectors = {'de', 'da', 'do', 'das', 'dos', 'e', 'y', 'the'};

// Nomes longos da API -> como as emissoras costumam escrever (já normalizados)
const Map<String, List<String>> _teamAliases = {
  'vasco da gama': ['vasco'],
  'red bull bragantino': ['bragantino'],
  'america mineiro': ['america mg'],
  'paris saint germain': ['psg'],
  'internazionale': ['inter de milao', 'inter milan'],
};

/// O título (já normalizado com [normalizeText]) cita o time?
/// Aceita nome parcial: "Atletico MG" bate com "Atlético Mineiro" e com
/// "Atlético-MG"; "RB Bragantino" bate com "Bragantino".
bool titleMentionsTeam(String normalizedTitle, String teamName) {
  final team = normalizeTeamName(teamName);
  if (team.isEmpty) return false;
  return [team, ...?_teamAliases[team]].any((n) => _mentions(normalizedTitle, n));
}

bool _mentions(String normalizedTitle, String team) {
  final title = ' $normalizedTitle ';
  if (title.contains(' $team ')) return true;

  final words = normalizedTitle.split(' ');
  final tokens = team.split(' ');
  var significant = 0;
  for (final t in tokens) {
    if (_connectors.contains(t)) continue;
    final aliases = _stateAliases[t];
    if (aliases != null) {
      // Sigla de estado é obrigatória: separa Atletico-MG de Atletico-GO
      final ok = words.contains(t) || aliases.any(words.contains);
      if (!ok) return false;
      continue;
    }
    if (t.length <= 2) continue; // "rb", "cr"...: opcionais
    final ok = words.any((w) => w == t || (t.length >= 4 && w.length >= 4 && (w.startsWith(t) || t.startsWith(w))));
    if (!ok) return false;
    significant++;
  }
  return significant > 0;
}

/// O título cita os DOIS times? (um time só não basta: evita "Flamengo x Vasco"
/// casar com o jogo "Flamengo x Palmeiras")
bool titleMatchesFixture(String title, String homeTeam, String awayTeam) {
  final t = normalizeText(title);
  return titleMentionsTeam(t, homeTeam) && titleMentionsTeam(t, awayTeam);
}

/// O programa cobre o início do jogo (com tolerância, a grade costuma atrasar)?
bool programCoversKickoff(
  DateTime programStart,
  DateTime programEnd,
  DateTime kickoff, {
  Duration tolerance = const Duration(minutes: 30),
}) =>
    !kickoff.isBefore(programStart.subtract(tolerance)) && !kickoff.isAfter(programEnd.add(tolerance));

/// Programa transmite o jogo: título com os dois times e horário cobrindo o início.
bool programShowsFixture({
  required String title,
  required DateTime start,
  required DateTime end,
  required String homeTeam,
  required String awayTeam,
  required DateTime kickoff,
}) =>
    programCoversKickoff(start, end, kickoff) && titleMatchesFixture(title, homeTeam, awayTeam);

// Categorias de canais de esporte (comparadas sem acento e em minúsculas)
const List<String> sportsCategoryKeywords = [
  'esporte', 'sport', 'premiere', 'espn', 'sportv', 'combate', 'brasileir',
  'futebol', 'dazn', 'caze', 'tnt', 'band sports', 'goat',
  // canais de evento ("Jogos de hoje", "Eventos", "PPV")
  'evento', 'ppv', 'jogos', 'campeonato',
];

bool isSportsCategory(String categoryName) {
  final n = normalizeText(categoryName);
  return sportsCategoryKeywords.any(n.contains);
}

// ---------------------------------------------------------------------------
// Nome do canal
// ---------------------------------------------------------------------------

/// O nome parece de um canal de evento ("Coritiba x Botafogo - 16:00").
bool nameLooksLikeEvent(String name) {
  final n = ' ${normalizeText(name)} ';
  return n.contains(' x ') || n.contains(' vs ') || n.contains(' versus ');
}

/// O nome do canal traz os dois times deste jogo.
bool channelNameMatchesFixture(String name, String homeTeam, String awayTeam) =>
    titleMatchesFixture(name, homeTeam, awayTeam);

/// Canal de evento de OUTRO jogo: nunca entra neste jogo, mesmo que a grade diga
/// (listas costumam reaproveitar a grade da emissora nos canais de evento).
bool channelIsOtherEvent(String name, String homeTeam, String awayTeam) =>
    nameLooksLikeEvent(name) && !channelNameMatchesFixture(name, homeTeam, awayTeam);

const Set<String> _qualityTokens = {'fhd', 'hd', 'sd', 'uhd', '4k', 'fullhd', 'h265', 'hevc', 'h264', 'alt'};

/// Nome do canal sem a qualidade ("SporTV HD²" e "SporTV FHD" -> "sportv"),
/// para mostrar cada canal uma vez só.
String channelBaseName(String name) =>
    normalizeText(name).split(' ').where((w) => !_qualityTokens.contains(w)).join(' ');

/// Qualidade para escolher a melhor variação: FHD/4K > HD > sem marca > SD;
/// as reservas ("²", "³", "alt") ficam depois da principal.
int channelQualityRank(String name) {
  final words = normalizeText(name).split(' ').toSet();
  var r = 2;
  if (words.contains('fhd') || words.contains('uhd') || words.contains('4k') || words.contains('fullhd')) {
    r = 4;
  } else if (words.contains('hd')) {
    r = 3;
  } else if (words.contains('sd')) {
    r = 1;
  }
  final reserva = name.contains('²') || name.contains('³') || words.contains('alt');
  return r * 2 - (reserva ? 1 : 0);
}

/// O canal é de uma das emissoras marcadas pelo admin ("Premiere" -> "Premiere Clubes FHD",
/// "SporTV" -> "SporTV 2 HD"). Compara palavras inteiras, sem acento e sem qualidade.
bool channelIsBroadcaster(String channelName, List<String> emissoras) {
  final canal = ' ${channelBaseName(channelName)} ';
  return emissoras.any((e) {
    final n = normalizeText(e);
    return n.isNotEmpty && canal.contains(' $n ');
  });
}
