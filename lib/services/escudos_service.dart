import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/sports_match.dart';

// Escudos dos times do plano B da aba Jogos, pela TheSportsDB (API gratuita).
// Só mostra o escudo quando o nome bate com segurança; na dúvida, as iniciais.

/// Palavras que não identificam o time (EC, FC, SC, "Clube", "Futebol"...).
const Set<String> _semValor = {'fc', 'ec', 'sc', 'cf', 'ac', 'afc', 'saf', 'clube', 'futebol', 'club'};

/// Nome sozinho que pode ser mais de um time ("Atlético" sem estado, "América"...).
const Set<String> nomesAmbiguos = {
  'atletico', 'athletico', 'america', 'nacional', 'sporting', 'racing', 'inter', 'real',
  'athletic', 'universidad', 'independiente', 'sport',
};

/// Siglas de estado que a TheSportsDB escreve por extenso.
const Map<String, String> _apelidos = {
  'atletico mg': 'atletico mineiro',
  'atletico pr': 'athletico paranaense',
  'athletico pr': 'athletico paranaense',
  'atletico go': 'atletico goianiense',
  'america mg': 'america mineiro',
  'vasco': 'vasco da gama',
  'bragantino': 'red bull bragantino',
  'rb bragantino': 'red bull bragantino',
  'sao paulo fc': 'sao paulo',
};

/// Nome para comparar: sem acento, minúsculo, sem "EC/FC/SC", com apelidos resolvidos.
String normalizarNomeTime(String nome) {
  final n = normalizeText(nome).split(' ').where((w) => !_semValor.contains(w)).join(' ');
  return _apelidos[n] ?? n;
}

/// Seleções: nome em português (normalizado) -> nome em inglês, como a TheSportsDB escreve.
const Map<String, String> selecoesEmIngles = {
  'africa do sul': 'South Africa', 'afeganistao': 'Afghanistan', 'albania': 'Albania',
  'alemanha': 'Germany', 'arabia saudita': 'Saudi Arabia', 'argelia': 'Algeria',
  'armenia': 'Armenia', 'australia': 'Australia', 'austria': 'Austria', 'azerbaijao': 'Azerbaijan',
  'belgica': 'Belgium', 'bielorrussia': 'Belarus', 'bolivia': 'Bolivia', 'brasil': 'Brazil',
  'bulgaria': 'Bulgaria', 'camaroes': 'Cameroon', 'canada': 'Canada', 'catar': 'Qatar',
  'cazaquistao': 'Kazakhstan', 'chipre': 'Cyprus', 'colombia': 'Colombia',
  'coreia do sul': 'South Korea', 'coreia do norte': 'North Korea', 'costa do marfim': 'Ivory Coast',
  'croacia': 'Croatia', 'curacao': 'Curacao', 'dinamarca': 'Denmark', 'egito': 'Egypt',
  'emirados arabes': 'United Arab Emirates', 'emirados arabes unidos': 'United Arab Emirates',
  'equador': 'Ecuador', 'escocia': 'Scotland', 'eslovaquia': 'Slovakia', 'eslovenia': 'Slovenia',
  'espanha': 'Spain', 'estados unidos': 'United States', 'eua': 'United States', 'estonia': 'Estonia',
  'finlandia': 'Finland', 'franca': 'France', 'gales': 'Wales', 'pais de gales': 'Wales',
  'gana': 'Ghana', 'georgia': 'Georgia', 'grecia': 'Greece', 'holanda': 'Netherlands',
  'paises baixos': 'Netherlands', 'hungria': 'Hungary', 'india': 'India', 'inglaterra': 'England',
  'ira': 'Iran', 'iraque': 'Iraq', 'irlanda': 'Ireland', 'irlanda do norte': 'Northern Ireland',
  'islandia': 'Iceland', 'italia': 'Italy', 'japao': 'Japan', 'jordania': 'Jordan',
  'letonia': 'Latvia', 'lituania': 'Lithuania', 'luxemburgo': 'Luxembourg',
  'macedonia do norte': 'North Macedonia', 'marrocos': 'Morocco', 'mexico': 'Mexico',
  'moldavia': 'Moldova', 'noruega': 'Norway', 'nova zelandia': 'New Zealand',
  'papua nova guine': 'Papua New Guinea', 'paquistao': 'Pakistan', 'paraguai': 'Paraguay',
  'polonia': 'Poland', 'quenia': 'Kenya', 'republica tcheca': 'Czech Republic',
  'tchequia': 'Czech Republic', 'romenia': 'Romania', 'russia': 'Russia', 'servia': 'Serbia',
  'suecia': 'Sweden', 'suica': 'Switzerland', 'tunisia': 'Tunisia', 'turquia': 'Turkey',
  'ucrania': 'Ukraine', 'uruguai': 'Uruguay', 'uzbequistao': 'Uzbekistan', 'zimbabue': 'Zimbabwe',
  'panama': 'Panama', 'peru': 'Peru', 'chile': 'Chile', 'argentina': 'Argentina',
  'portugal': 'Portugal', 'senegal': 'Senegal', 'nigeria': 'Nigeria', 'jamaica': 'Jamaica',
  'montenegro': 'Montenegro', 'san marino': 'San Marino', 'kosovo': 'Kosovo', 'malta': 'Malta',
  'sri lanka': 'Sri Lanka', 'bangladesh': 'Bangladesh', 'nepal': 'Nepal', 'oma': 'Oman',
};

/// É uma seleção (nome de país em português ou inglês)?
bool ehSelecao(String nome) {
  final n = normalizarNomeTime(nome);
  return selecoesEmIngles.containsKey(n) || selecoesEmIngles.values.any((e) => normalizarNomeTime(e) == n);
}

/// Nome a buscar, ou null quando é ambíguo/curto demais (mostra as iniciais).
String? chaveDeBusca(String nome) {
  final n = normalizarNomeTime(nome);
  if (n.length < 3 || nomesAmbiguos.contains(n)) return null;
  return n;
}

/// Buscas para o time, na ordem: seleção pelo nome em inglês e depois o nome como veio
/// ("Irlanda" -> "ireland", "irlanda"). Vazio = não buscar.
List<String> buscasPara(String nome) {
  final chave = chaveDeBusca(nome);
  if (chave == null) return const [];
  final ingles = selecoesEmIngles[chave];
  return [if (ingles != null) normalizarNomeTime(ingles), chave];
}

/// Iniciais para o círculo no lugar do escudo ("Internacional" -> "INT", "São Paulo" -> "SP").
String iniciaisTime(String nome) {
  const conectores = {'de', 'da', 'do', 'das', 'dos', 'e'};
  final palavras = normalizeText(nome)
      .split(' ')
      .where((w) => w.isNotEmpty && !_semValor.contains(w) && !conectores.contains(w))
      .toList();
  if (palavras.isEmpty) return '?';
  if (palavras.length == 1) {
    final p = palavras.first;
    return p.substring(0, p.length < 3 ? p.length : 3).toUpperCase();
  }
  return (palavras[0][0] + palavras[1][0]).toUpperCase();
}

/// Escolhe o escudo na resposta de searchteams.php: só futebol e nome (ou nome alternativo)
/// IGUAL ao buscado; mais de um igual -> prefere Brasil; se ainda sobrar mais de um, nenhum.
String? escolherEscudo(String chave, dynamic resposta) => escolherEscudoEntre([chave], resposta);

/// Igual a [escolherEscudo], aceitando qualquer um dos nomes de [chaves] (português/inglês).
String? escolherEscudoEntre(List<String> chaves, dynamic resposta) {
  final times = resposta is Map ? resposta['teams'] : null;
  if (times is! List) return null;
  final iguais = <Map>[];
  for (final t in times) {
    if (t is! Map || '${t['strSport']}' != 'Soccer') continue;
    final nomes = [
      '${t['strTeam'] ?? ''}',
      ...'${t['strTeamAlternate'] ?? ''}'.split(','),
      '${t['strTeamShort'] ?? ''}',
    ].map(normalizarNomeTime).where((n) => n.isNotEmpty);
    if (nomes.any(chaves.contains)) iguais.add(t);
  }
  var escolhidos = iguais;
  if (escolhidos.length > 1) {
    final br = escolhidos.where((t) => '${t['strCountry']}' == 'Brazil').toList();
    if (br.isNotEmpty) escolhidos = br;
  }
  if (escolhidos.length != 1) return null;
  final url = '${escolhidos.single['strBadge'] ?? escolhidos.single['strTeamBadge'] ?? ''}'.trim();
  return url.startsWith('https://') ? url : null;
}

/// Busca em segundo plano, uma de cada vez (no máximo ~15 por minuto), com cache em disco
/// de 7 dias por time. Falha de rede: fica com as iniciais (tenta de novo noutra abertura).
class EscudosService {
  EscudosService({
    this.client,
    this.intervalo = const Duration(seconds: 4),
    this.pausaLimite = const Duration(seconds: 60),
    this.validade = const Duration(days: 7),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  static final EscudosService instance = EscudosService();
  static const _chaveDisco = 'escudos_thesportsdb_v1';
  static const _url = 'https://www.thesportsdb.com/api/v1/json/123/searchteams.php';

  http.Client? client;
  final Duration intervalo;
  final Duration pausaLimite;
  final Duration validade;
  final DateTime Function() clock;

  final Map<String, ValueNotifier<String?>> _escudos = {};
  final Queue<String> _fila = Queue();
  Map<String, dynamic>? _disco;
  Future<void>? _carregandoDisco;
  bool _rodando = false;

  /// Escudo do time (null = mostrar iniciais). Atualiza sozinho quando a busca termina.
  /// [buscar] falso (ex.: jogador de tênis) = só iniciais, sem chamar a rede.
  ValueListenable<String?> escudo(String nomeDoTime, {bool buscar = true}) {
    final buscas = buscar ? buscasPara(nomeDoTime) : const <String>[];
    if (buscas.isEmpty) return ValueNotifier<String?>(null);
    final chave = buscas.last; // o nome como veio identifica o time no cache
    final existente = _escudos[chave];
    if (existente != null) return existente;
    final v = ValueNotifier<String?>(null);
    _escudos[chave] = v;
    _buscas[chave] = buscas;
    _pedir(chave);
    return v;
  }

  final Map<String, List<String>> _buscas = {};

  Future<void> _pedir(String chave) async {
    await (_carregandoDisco ??= _lerDisco());
    final salvo = _disco![chave];
    if (salvo is Map && clock().millisecondsSinceEpoch - (salvo['t'] as num? ?? 0) < validade.inMilliseconds) {
      final u = '${salvo['u'] ?? ''}';
      _escudos[chave]!.value = u.isEmpty ? null : u;
      return;
    }
    _fila.add(chave);
    _processar();
  }

  Future<void> _lerDisco() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_chaveDisco);
      _disco = txt == null ? {} : Map<String, dynamic>.from(jsonDecode(txt) as Map);
    } catch (_) {
      _disco = {};
    }
  }

  Future<void> _salvar(String chave, String? url) async {
    _disco![chave] = {'u': url ?? '', 't': clock().millisecondsSinceEpoch};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chaveDisco, jsonEncode(_disco));
    } catch (_) {}
  }

  Future<void> _processar() async {
    if (_rodando) return;
    _rodando = true;
    try {
      while (_fila.isNotEmpty) {
        final chave = _fila.removeFirst();
        final buscas = _buscas[chave] ?? [chave];
        String? url;
        var respondeu = false;
        var limite = false;
        for (final termo in buscas) {
          final http.Response res;
          try {
            final uri = Uri.parse(_url).replace(queryParameters: {'t': termo});
            res = await (client != null ? client!.get(uri) : http.get(uri)).timeout(const Duration(seconds: 10));
          } catch (_) {
            break; // sem rede: iniciais
          } finally {
            await Future.delayed(intervalo); // no máximo uma busca a cada [intervalo]
          }
          if (res.statusCode == 429) {
            limite = true;
            break;
          }
          if (res.statusCode != 200) break;
          respondeu = true;
          try {
            url = escolherEscudoEntre(buscas, jsonDecode(utf8.decode(res.bodyBytes)));
          } catch (_) {}
          if (url != null) break;
        }
        if (limite) {
          _fila.addFirst(chave); // limite da API: espera e tenta de novo
          await Future.delayed(pausaLimite);
          continue;
        }
        if (respondeu) {
          _escudos[chave]?.value = url;
          await _salvar(chave, url); // "sem escudo seguro" também fica guardado
        }
      }
    } finally {
      _rodando = false;
    }
  }
}
