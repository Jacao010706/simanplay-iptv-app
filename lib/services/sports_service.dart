import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/sports_match.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import 'epg_service.dart';
import 'xtream_service.dart';

/// Um jogo do dia (resposta do backend /sports/fixtures).
class Fixture {
  final int id;
  final String leagueName;
  final String? leagueLogo;
  final String leagueCountry;
  final DateTime kickoff; // hora local
  final String statusShort;
  final int? elapsed;
  final String homeName;
  final String? homeLogo;
  final String awayName;
  final String? awayLogo;
  final int? goalsHome;
  final int? goalsAway;

  const Fixture({
    required this.id,
    required this.leagueName,
    this.leagueLogo,
    this.leagueCountry = '',
    required this.kickoff,
    this.statusShort = 'NS',
    this.elapsed,
    required this.homeName,
    this.homeLogo,
    required this.awayName,
    this.awayLogo,
    this.goalsHome,
    this.goalsAway,
  });

  static const _liveStatus = {'1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE', 'INT', 'SUSP'};
  static const _finishedStatus = {'FT', 'AET', 'PEN'};

  bool get isLive => _liveStatus.contains(statusShort);
  bool get isFinished => _finishedStatus.contains(statusShort);
  bool get hasScore => goalsHome != null && goalsAway != null && (isLive || isFinished);

  static Fixture? fromJson(dynamic j) {
    if (j is! Map) return null;
    final kickoff = DateTime.tryParse(j['kickoff']?.toString() ?? '');
    final id = j['id'];
    if (kickoff == null || id is! num) return null;
    Map m(dynamic v) => v is Map ? v : const {};
    int? n(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    String? s(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final league = m(j['league']), status = m(j['status']), home = m(j['home']), away = m(j['away']), goals = m(j['goals']);
    return Fixture(
      id: id.toInt(),
      leagueName: s(league['name']) ?? 'Outros',
      leagueLogo: s(league['logo']),
      leagueCountry: s(league['country']) ?? '',
      kickoff: kickoff.toLocal(),
      statusShort: s(status['short']) ?? 'NS',
      elapsed: n(status['elapsed']),
      homeName: s(home['name']) ?? '',
      homeLogo: s(home['logo']),
      awayName: s(away['name']) ?? '',
      awayLogo: s(away['logo']),
      goalsHome: n(goals['home']),
      goalsAway: n(goals['away']),
    );
  }
}

/// Backend sem a chave da API de futebol (HTTP 503).
class SportsUnavailableException implements Exception {
  @override
  String toString() => 'Jogos indisponíveis no momento';
}

/// A API de futebol não cobre a data pedida (HTTP 403: o plano só aceita
/// alguns dias em volta de hoje).
class SportsDateUnavailableException implements Exception {
  @override
  String toString() => 'Jogos desta data não estão disponíveis';
}

String fixtureDateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Canais de [channels] que transmitem cada jogo, pela programação ([epgOf]).
Map<int, List<Channel>> matchFixturesToChannels(
  List<Fixture> fixtures,
  List<Channel> channels,
  List<EpgProgram> Function(Channel channel) epgOf,
) {
  final out = <int, List<Channel>>{};
  for (final ch in channels) {
    final programs = epgOf(ch);
    if (programs.isEmpty) continue;
    for (final f in fixtures) {
      final hit = programs.any((p) => programShowsFixture(
            title: p.title,
            start: p.start,
            end: p.end,
            homeTeam: f.homeName,
            awayTeam: f.awayName,
            kickoff: f.kickoff,
          ));
      if (hit) (out[f.id] ??= []).add(ch);
    }
  }
  return out;
}

/// Jogos do dia (backend) e "onde passa" (programação dos canais de esporte).
class SportsService {
  SportsService._();
  static final SportsService instance = SportsService._();

  static const int maxSportsChannels = 150;
  static const Duration channelsTtl = Duration(minutes: 30);

  List<Channel>? _sportsChannels;
  DateTime? _sportsChannelsAt;
  String? _sportsChannelsKey;
  // fixture id -> canais, guardado por 30 min
  final Map<int, List<Channel>> _whereCache = {};
  DateTime? _whereAt;

  Future<List<Fixture>> fixtures(DateTime day) async {
    final uri = Uri.parse('${AppConfig.backendUrl}/sports/fixtures?date=${fixtureDateParam(day)}');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode == 503) throw SportsUnavailableException();
    if (res.statusCode == 403) throw SportsDateUnavailableException();
    if (res.statusCode != 200) throw Exception('Erro ao carregar os jogos (${res.statusCode})');
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return const [];
    return data.map(Fixture.fromJson).whereType<Fixture>().toList();
  }

  /// Canais das categorias de esporte (no máximo 150), guardados por 30 min.
  Future<List<Channel>> sportsChannels(AppSession session) async {
    if (!session.hasXtreamAccess) return const [];
    final key = '${session.effectiveXtreamHost}|${session.effectiveXtreamUsername}';
    final at = _sportsChannelsAt;
    if (_sportsChannels != null && key == _sportsChannelsKey && at != null &&
        DateTime.now().difference(at) < channelsTtl) {
      return _sportsChannels!;
    }
    final svc = XtreamService(
      host: session.effectiveXtreamHost!,
      username: session.effectiveXtreamUsername!,
      password: session.effectiveXtreamPassword!,
    );
    final cats = (await svc.getLiveCategories()).where((c) => isSportsCategory(c.name));
    final out = <Channel>[];
    for (final cat in cats) {
      try {
        out.addAll(await svc.getLiveStreams(cat.id, cat.name));
      } catch (_) {}
      if (out.length >= maxSportsChannels) break;
    }
    _sportsChannels = out.take(maxSportsChannels).toList();
    _sportsChannelsAt = DateTime.now();
    _sportsChannelsKey = key;
    return _sportsChannels!;
  }

  /// Procura onde passa cada jogo. [onUpdate] recebe o resultado parcial
  /// conforme a programação dos canais chega (a lista não fica travada).
  Future<Map<int, List<Channel>>> findWhereToWatch(
    AppSession session,
    List<Fixture> fixtures,
    void Function(Map<int, List<Channel>> partial) onUpdate,
  ) async {
    final at = _whereAt;
    if (at != null && DateTime.now().difference(at) < channelsTtl &&
        fixtures.every((f) => _whereCache.containsKey(f.id))) {
      final cached = {for (final f in fixtures) f.id: _whereCache[f.id]!};
      onUpdate(cached);
      return cached;
    }
    EpgService.instance.useSession(session);
    final channels = await sportsChannels(session);
    final epg = <String, List<EpgProgram>>{};
    var pending = channels.length;
    Map<int, List<Channel>> current() =>
        matchFixturesToChannels(fixtures, channels, (c) => epg[c.id] ?? const []);

    final done = Completer<void>();
    if (pending == 0) done.complete();
    var lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
    for (final ch in channels) {
      // O EpgService limita a 4 requisições simultâneas e guarda cada canal por 10 min
      EpgService.instance.getEpg(ch.id).then((list) {
        epg[ch.id] = list;
      }).catchError((_) {}).whenComplete(() {
        pending--;
        final now = DateTime.now();
        if (pending == 0) {
          if (!done.isCompleted) done.complete();
        } else if (now.difference(lastUpdate) > const Duration(milliseconds: 700)) {
          lastUpdate = now;
          onUpdate(current());
        }
      });
    }
    await done.future;
    final result = current();
    for (final f in fixtures) {
      _whereCache[f.id] = result[f.id] ?? const [];
    }
    _whereAt = DateTime.now();
    onUpdate(result);
    return result;
  }
}
