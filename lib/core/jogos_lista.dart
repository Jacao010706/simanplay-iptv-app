// Plano B da aba Jogos: monta os jogos a partir da própria lista do cliente, quando o
// backend de jogos (/sports/fixtures) não responde.
//   1) nomes dos canais de evento ("15/11 14:00 - INTER X FLAMENGO | FINAL ... |",
//      "Internacional x Flamengo - 16:00 FHD");
//   2) programação (EPG) dos canais de esporte ("Copa do Brasil: Inter x Flamengo").
// Funções puras (testáveis e executáveis em outro isolate).

import '../models/channel.dart';
import 'sports_match.dart';

/// Um jogo achado na lista, com os canais onde passa.
class JogoDaLista {
  final DateTime inicio; // hora local
  final String casa;
  final String fora;
  final String? campeonato;
  final List<Channel> canais;

  /// Veio do nome de um canal de evento (horário mais confiável que o da grade).
  final bool doNome;

  JogoDaLista({
    required this.inicio,
    required this.casa,
    required this.fora,
    this.campeonato,
    List<Channel>? canais,
    this.doNome = true,
  }) : canais = canais ?? [];

  /// Identificador estável (mesmo jogo, mesmo id entre recargas).
  int get id {
    var h = 0x811c9dc5;
    final chave = '${normalizeTeamName(casa)}|${normalizeTeamName(fora)}|'
        '${inicio.year}-${inicio.month}-${inicio.day} ${inicio.hour}:${inicio.minute}';
    for (final c in chave.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  @override
  String toString() => 'JogoDaLista($inicio $casa x $fora | $campeonato | ${canais.map((c) => c.name).toList()})';
}

// ---------------------------------------------------------------------------
// Categorias e canais
// ---------------------------------------------------------------------------

/// Palavras de categorias de canais de evento (comparadas sem acento, minúsculas).
const List<String> palavrasCategoriaDeJogos = ['jogos', 'ppv', 'pay per view', 'eventos', 'evento', 'ao vivo'];

bool ehCategoriaDeJogos(String categoria) {
  final n = ' ${normalizeText(categoria)} ';
  return palavrasCategoriaDeJogos.any((p) => n.contains(' $p '));
}

/// Emissoras de esporte cuja programação é lida (nome do canal começa com uma delas).
/// Em ordem de prioridade (as primeiras são consultadas antes).
const List<String> emissorasDeEsporte = [
  'sportv', 'premiere', 'espn', 'globo', 'tnt', 'caze', 'cazetv', 'band', 'combate', 'dazn',
  'goat', 'record', 'sbt', 'nosso futebol',
];

/// No máximo tantos canais por marca ("Band SP", "Band RJ"...: a grade quase sempre é a mesma).
const int maxCanaisPorMarca = 8;

/// Canal de esporte que vale a pena consultar a programação.
bool ehCanalDeEsporte(Channel c) {
  if (isSportsCategory(c.categoryName)) return true;
  final base = channelBaseName(c.name);
  return emissorasDeEsporte.any((e) => base == e || base.startsWith('$e '));
}

// ---------------------------------------------------------------------------
// Nome do canal / título do programa
// ---------------------------------------------------------------------------

final RegExp _reData = RegExp(r'(?<![\d/])(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?(?![\d/])');
final RegExp _reHora = RegExp(r'(?<![\d:])([01]?\d|2[0-3])\s*[:hH]\s*([0-5]\d)(?![\d:])');
final RegExp _reConfronto = RegExp(r'\s+(?:x|vs\.?|versus)\s+', caseSensitive: false);
final RegExp _reParenteses = RegExp(r'\([^)]*\)|\[[^\]]*\]');
final RegExp _reAoVivo = RegExp(r'\b(?:ao\s*vivo|live|aovivo)\b\s*[:\-–]?', caseSensitive: false);
final RegExp _reBordas = RegExp(r'^[\s\-–—:,.;/]+|[\s\-–—:,.;/]+$');
const Set<String> _qualidade = {'fhd', 'hd', 'sd', 'uhd', '4k', 'fullhd', 'h265', 'hevc', 'h264', 'alt'};

/// Tira qualidade ("FHD", "HD²"), sinais e espaços das pontas do nome do time.
String _limparTime(String s) {
  var t = s.replaceAll(RegExp(r'[²³¹]'), ' ').replaceAll(_reBordas, '').trim();
  final palavras = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  while (palavras.isNotEmpty && _qualidade.contains(normalizeText(palavras.last))) {
    palavras.removeLast();
  }
  while (palavras.isNotEmpty && _qualidade.contains(normalizeText(palavras.first))) {
    palavras.removeAt(0);
  }
  return palavras.join(' ').replaceAll(_reBordas, '').trim();
}

bool _timeValido(String t, {int maxPalavras = 6}) {
  if (t.length < 2 || t.length > 40) return false;
  if (!RegExp(r'[A-Za-zÀ-ÿ]{2}').hasMatch(t)) return false;
  return t.split(' ').length <= maxPalavras;
}

/// Ano mais próximo de [ref] para uma data sem ano ("15/11" em janeiro = novembro passado).
DateTime? _dataSemAno(int dia, int mes, DateTime ref) {
  DateTime? melhor;
  for (final ano in [ref.year - 1, ref.year, ref.year + 1]) {
    final d = DateTime(ano, mes, dia);
    if (d.month != mes || d.day != dia) return null;
    if (melhor == null || d.difference(ref).abs() < melhor.difference(ref).abs()) melhor = d;
  }
  return melhor;
}

/// Lado da casa: o que vem depois do último ":" ou " - "; visitante: antes do primeiro.
(String, String?) _ladoCasa(String s) {
  String? antes;
  var t = s;
  for (final sep in [':', ' - ', ' – ', '|']) {
    final i = t.lastIndexOf(sep);
    if (i != -1) {
      final a = t.substring(0, i).trim();
      if (a.isNotEmpty) antes = antes == null ? a : '$a $antes';
      t = t.substring(i + sep.length);
    }
  }
  return (t, antes);
}

String _ladoFora(String s) {
  var t = s;
  for (final sep in [' - ', ' – ', ':', '|', ',', '(']) {
    final i = t.indexOf(sep);
    if (i != -1) t = t.substring(0, i);
  }
  return t;
}

/// Jogo no nome de um canal de evento. Precisa de horário e de "A x B" (ou "A vs B").
/// Data opcional ("15/11"); sem data, vale o dia de [referencia].
/// Ex.: "15/11 14:00 - INTER X FLAMENGO | FINAL DA COPA DO BRASIL FEMININA | ..."
///      "Internacional x Flamengo - 16:00 FHD"
JogoDaLista? jogoDoNomeDoCanal(String nome, DateTime referencia) {
  final partes = nome.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  // Parte com o confronto (de preferência a que também tem o horário)
  var i = partes.indexWhere((p) => _reConfronto.hasMatch(p) && _reHora.hasMatch(p));
  if (i == -1) i = partes.indexWhere((p) => _reConfronto.hasMatch(p));
  if (i == -1) return null;
  var principal = partes[i];

  // Data e hora: na parte do confronto ou, se não estiverem lá, em qualquer parte
  final RegExpMatch? hora;
  final RegExpMatch? data;
  if (_reHora.hasMatch(principal)) {
    hora = _reHora.firstMatch(principal);
    data = _reData.firstMatch(principal);
  } else {
    final outras = partes.where((p) => !_reConfronto.hasMatch(p) && _reHora.hasMatch(p)).firstOrNull;
    if (outras == null) return null;
    hora = _reHora.firstMatch(outras);
    data = _reData.firstMatch(outras);
    principal = ' $principal'; // sem hora para tirar
  }
  if (hora == null) return null;
  DateTime dia;
  if (data != null) {
    final d = int.parse(data.group(1)!), m = int.parse(data.group(2)!);
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final anoTxt = data.group(3);
    if (anoTxt != null) {
      final a = int.parse(anoTxt);
      dia = DateTime(a < 100 ? 2000 + a : a, m, d);
      if (dia.month != m) return null;
    } else {
      final achou = _dataSemAno(d, m, referencia);
      if (achou == null) return null;
      dia = achou;
    }
  } else {
    dia = DateTime(referencia.year, referencia.month, referencia.day);
  }
  final inicio = DateTime(dia.year, dia.month, dia.day, int.parse(hora.group(1)!), int.parse(hora.group(2)!));

  // Tira data, hora, parênteses e "AO VIVO" e separa os times
  principal = principal
      .replaceAll(_reHora, ' ')
      .replaceAll(_reData, ' ')
      .replaceAll(_reParenteses, ' ')
      .replaceAll(_reAoVivo, ' ');
  final lados = principal.split(_reConfronto);
  if (lados.length != 2) return null;
  final casa = _limparTime(_ladoCasa(lados[0]).$1);
  final fora = _limparTime(_ladoFora(lados[1]));
  if (!_timeValido(casa) || !_timeValido(fora)) return null;

  String? campeonato;
  for (final p in [...partes.skip(i + 1), ...partes.take(i).toList().reversed]) {
    final c = _limparTime(p.replaceAll(_reHora, ' ').replaceAll(_reData, ' '));
    if (c.length >= 3 && RegExp(r'[A-Za-zÀ-ÿ]{3}').hasMatch(c)) {
      campeonato = c;
      break;
    }
  }
  return JogoDaLista(inicio: inicio, casa: casa, fora: fora, campeonato: campeonato);
}

/// Jogo no título de um programa da grade ("Copa do Brasil: Inter x Flamengo",
/// "Futebol - Grêmio vs Palmeiras (ao vivo)"). Mais conservador que o nome do canal:
/// cada time com no máximo 4 palavras e sem números.
JogoDaLista? jogoDoTituloDoPrograma(String titulo, DateTime inicio) {
  final partes = titulo.split('|').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  final i = partes.indexWhere((p) => _reConfronto.hasMatch(p));
  if (i == -1) return null;
  final principal = partes[i]
      .replaceAll(_reParenteses, ' ')
      .replaceAll(_reAoVivo, ' ')
      .replaceAll(_reHora, ' ')
      .replaceAll(_reData, ' ');
  final lados = principal.split(_reConfronto);
  if (lados.length != 2) return null;
  final (casaBruta, antes) = _ladoCasa(lados[0]);
  final casa = _limparTime(casaBruta);
  final fora = _limparTime(_ladoFora(lados[1]));
  bool ok(String t) => _timeValido(t, maxPalavras: 4) && !RegExp(r'\d').hasMatch(t);
  if (!ok(casa) || !ok(fora)) return null;
  final camp = antes == null ? null : _limparTime(antes);
  return JogoDaLista(
    inicio: inicio,
    casa: casa,
    fora: fora,
    campeonato: camp != null && camp.length >= 3 ? camp : null,
    doNome: false,
  );
}

// ---------------------------------------------------------------------------
// Juntar duplicatas
// ---------------------------------------------------------------------------

bool _cita(String outroConfronto, String time) => titleMentionsTeam(normalizeText(outroConfronto), time);

/// Mesmo confronto (em qualquer ordem, com nomes parciais: "Inter" = "Internacional")
/// e horário até 30 min de diferença (a grade costuma começar antes do jogo).
bool mesmoJogo(JogoDaLista a, JogoDaLista b) {
  if (a.inicio.difference(b.inicio).abs() > const Duration(minutes: 30)) return false;
  final ta = '${a.casa} ${a.fora}', tb = '${b.casa} ${b.fora}';
  return (_cita(tb, a.casa) && _cita(tb, a.fora)) || (_cita(ta, b.casa) && _cita(ta, b.fora));
}

/// Junta jogos repetidos (canais FHD/HD do mesmo jogo, nome + grade), soma os canais
/// (cada um uma vez; os de evento primeiro, depois a melhor qualidade) e ordena por horário.
/// Quem vem do nome do canal define horário e nomes.
List<JogoDaLista> juntarJogos(Iterable<JogoDaLista> jogos) {
  final ordenados = jogos.toList()
    ..sort((a, b) {
      if (a.doNome != b.doNome) return a.doNome ? -1 : 1;
      return a.inicio.compareTo(b.inicio);
    });
  final out = <JogoDaLista>[];
  for (final j in ordenados) {
    final igual = out.where((o) => mesmoJogo(o, j)).firstOrNull;
    if (igual == null) {
      out.add(JogoDaLista(
        inicio: j.inicio, casa: j.casa, fora: j.fora, campeonato: j.campeonato,
        canais: [...j.canais], doNome: j.doNome,
      ));
      continue;
    }
    final out2 = JogoDaLista(
      inicio: igual.inicio, casa: igual.casa, fora: igual.fora,
      campeonato: igual.campeonato ?? j.campeonato,
      canais: [
        ...igual.canais,
        for (final c in j.canais)
          if (!igual.canais.any((x) => x.id == c.id)) c,
      ],
      doNome: igual.doNome,
    );
    out[out.indexOf(igual)] = out2;
  }
  for (final j in out) {
    final evento = {for (final c in j.canais) c.id: nameLooksLikeEvent(c.name)};
    j.canais.sort((a, b) {
      final e = (evento[b.id]! ? 1 : 0) - (evento[a.id]! ? 1 : 0);
      return e != 0 ? e : channelQualityRank(b.name).compareTo(channelQualityRank(a.name));
    });
  }
  out.sort((a, b) => a.inicio.compareTo(b.inicio));
  return out;
}

bool mesmoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// Análise da lista inteira (roda num isolate)
// ---------------------------------------------------------------------------

/// Resultado da leitura dos canais: jogos dos nomes (todas as datas) e os canais de
/// esporte cuja programação vale consultar (um por emissora, na melhor qualidade).
class AnaliseDaLista {
  final List<JogoDaLista> jogosDosNomes;
  final List<Channel> canaisParaEpg;
  const AnaliseDaLista(this.jogosDosNomes, this.canaisParaEpg);
}

const int maxCanaisEpg = 120;

AnaliseDaLista analisarCanais((List<Channel>, DateTime) entrada) {
  final (canais, referencia) = entrada;
  final jogos = <JogoDaLista>[];
  final porEmissora = <String, Channel>{};
  for (final c in canais) {
    if (ehCategoriaDeJogos(c.categoryName)) {
      final j = jogoDoNomeDoCanal(c.name, referencia);
      if (j != null) {
        j.canais.add(c);
        jogos.add(j);
        continue;
      }
    }
    if (nameLooksLikeEvent(c.name) || !ehCanalDeEsporte(c)) continue;
    final base = channelBaseName(c.name);
    final atual = porEmissora[base];
    if (atual == null || channelQualityRank(c.name) > channelQualityRank(atual.name)) porEmissora[base] = c;
  }
  // Emissoras conhecidas primeiro (na ordem da lista acima), depois o resto das categorias
  // de esporte; poucas por marca
  int prioridade(Channel c) {
    final base = channelBaseName(c.name);
    final i = emissorasDeEsporte.indexWhere((e) => base == e || base.startsWith('$e '));
    return i == -1 ? emissorasDeEsporte.length : i;
  }

  final ordem = porEmissora.values.toList();
  final pos = {for (var k = 0; k < ordem.length; k++) ordem[k].id: k};
  ordem.sort((a, b) {
    final p = prioridade(a).compareTo(prioridade(b));
    return p != 0 ? p : pos[a.id]!.compareTo(pos[b.id]!);
  });
  final porMarca = <String, int>{};
  final escolhidos = <Channel>[];
  for (final c in ordem) {
    final marca = channelBaseName(c.name).split(' ').first;
    final n = porMarca[marca] = (porMarca[marca] ?? 0) + 1;
    if (n > maxCanaisPorMarca) continue;
    escolhidos.add(c);
    if (escolhidos.length >= maxCanaisEpg) break;
  }
  return AnaliseDaLista(jogos, escolhidos);
}
