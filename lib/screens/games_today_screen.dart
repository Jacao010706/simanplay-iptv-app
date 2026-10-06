import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import '../services/epg_service.dart' show formatHm;
import '../services/sports_service.dart';
import '../widgets/tv_focus.dart';
import 'player_screen.dart';

typedef FixturesLoader = Future<List<Fixture>> Function(DateTime day);
typedef WhereToWatchLoader = Future<Map<int, List<Channel>>> Function(
    List<Fixture> fixtures, void Function(Map<int, List<Channel>> partial) onUpdate);

/// "Jogos do Dia": jogos dos campeonatos acompanhados, com escudos, horário ou
/// placar e os canais da lista do cliente que transmitem cada jogo.
class GamesTodayScreen extends StatefulWidget {
  final AppSession session;

  /// Só para testes: jogos e "onde passa" sem rede, e abrir canal sem o player.
  @visibleForTesting
  final FixturesLoader? debugFixtures;
  @visibleForTesting
  final WhereToWatchLoader? debugWhereToWatch;
  @visibleForTesting
  final void Function(Channel channel)? debugOnOpenChannel;
  @visibleForTesting
  final DateTime Function()? clock;

  const GamesTodayScreen({
    super.key,
    required this.session,
    this.debugFixtures,
    this.debugWhereToWatch,
    this.debugOnOpenChannel,
    this.clock,
  });

  @override
  State<GamesTodayScreen> createState() => _GamesTodayScreenState();
}

class _GamesTodayScreenState extends State<GamesTodayScreen> {
  int _dayOffset = 0; // -1 ontem, 0 hoje, 1 amanhã
  bool _loading = true;
  bool _unavailable = false;
  String? _error;
  List<Fixture> _fixtures = const [];
  Map<int, List<Channel>> _where = const {};
  bool _searchingChannels = false;
  int _loadToken = 0;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  DateTime get _day {
    final n = _now;
    return DateTime(n.year, n.month, n.day + _dayOffset);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      _loading = true;
      _unavailable = false;
      _error = null;
      _where = const {};
      _searchingChannels = false;
    });
    try {
      final fixtures = await (widget.debugFixtures ?? SportsService.instance.fixtures)(_day);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _fixtures = fixtures;
        _loading = false;
        _searchingChannels = fixtures.isNotEmpty;
      });
      if (fixtures.isNotEmpty) _findChannels(fixtures, token);
    } on SportsUnavailableException {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _unavailable = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = 'Não foi possível carregar os jogos. Verifique a conexão.';
        _loading = false;
      });
    }
  }

  Future<void> _findChannels(List<Fixture> fixtures, int token) async {
    void update(Map<int, List<Channel>> partial) {
      if (mounted && token == _loadToken) setState(() => _where = partial);
    }

    try {
      final finder = widget.debugWhereToWatch ??
          (f, onUpdate) => SportsService.instance.findWhereToWatch(widget.session, f, onUpdate);
      update(await finder(fixtures, update));
    } catch (_) {}
    if (mounted && token == _loadToken) setState(() => _searchingChannels = false);
  }

  void _setDay(int offset) {
    if (offset == _dayOffset) return;
    setState(() => _dayOffset = offset);
    _load();
  }

  void _openChannel(Channel ch) {
    if (widget.debugOnOpenChannel != null) {
      widget.debugOnOpenChannel!(ch);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          urls: [ch.streamUrl],
          title: ch.name,
          isLive: true,
          recordName: ch.name,
          streamId: widget.session.hasXtreamAccess ? ch.id : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Icon(Icons.sports_soccer, color: primary, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Jogos do Dia',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              for (final d in const [(-1, 'Ontem'), (0, 'Hoje'), (1, 'Amanhã')])
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: TvTap(
                    key: ValueKey('day-${d.$1}'),
                    autofocus: d.$1 == 0,
                    onTap: () => _setDay(d.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _dayOffset == d.$1 ? primary : const Color(0xFF1a1625),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(d.$2,
                          style: TextStyle(
                              color: _dayOffset == d.$1 ? Colors.white : Colors.white60,
                              fontSize: 12,
                              fontWeight: _dayOffset == d.$1 ? FontWeight.bold : FontWeight.normal)),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(child: _body(primary)),
        ]),
      ),
    );
  }

  Widget _message(String text, {IconData icon = Icons.sports_soccer, bool retry = false}) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white24, size: 48),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
        if (retry) ...[
          const SizedBox(height: 12),
          TvTap(
            onTap: _load,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF2a2538), borderRadius: BorderRadius.circular(8)),
              child: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _body(Color primary) {
    if (_loading) return Center(child: CircularProgressIndicator(color: primary));
    if (_unavailable) return _message('Jogos indisponíveis no momento', icon: Icons.event_busy);
    if (_error != null) return _message(_error!, icon: Icons.wifi_off, retry: true);
    if (_fixtures.isEmpty) return _message('Nenhum jogo dos campeonatos acompanhados neste dia.');

    // Agrupa por campeonato, na ordem do primeiro jogo de cada um
    final groups = <String, List<Fixture>>{};
    for (final f in _fixtures) {
      (groups['${f.leagueName}|${f.leagueCountry}'] ??= []).add(f);
    }
    final children = <Widget>[];
    for (final g in groups.values) {
      final first = g.first;
      children.add(Padding(
        key: ValueKey('league-${first.leagueName}'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(children: [
          _logo(first.leagueLogo, 22, Icons.emoji_events_outlined),
          const SizedBox(width: 8),
          Flexible(
            child: Text(first.leagueName,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          if (first.leagueCountry.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(first.leagueCountry, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ]),
      ));
      for (final f in g) {
        children.add(_fixtureCard(f, primary));
      }
    }
    children.add(const SizedBox(height: 24));
    return ListView(children: children);
  }

  Widget _logo(String? url, double size, IconData fallback) {
    final icon = Icon(fallback, color: Colors.white38, size: size);
    if (url == null || url.isEmpty) return SizedBox(width: size, height: size, child: icon);
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (_, __) => SizedBox(width: size, height: size),
      errorWidget: (_, __, ___) => icon,
    );
  }

  Widget _team(String name, String? logo, {required bool home}) {
    final text = Flexible(
      child: Text(name,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: home ? TextAlign.right : TextAlign.left),
    );
    final shield = _logo(logo, 34, Icons.shield_outlined);
    return Expanded(
      child: Row(
        mainAxisAlignment: home ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: home
            ? [text, const SizedBox(width: 10), shield]
            : [shield, const SizedBox(width: 10), text],
      ),
    );
  }

  Widget _center(Fixture f) {
    if (f.hasScore) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${f.goalsHome} x ${f.goalsAway}',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        if (f.isLive)
          Container(
            key: ValueKey('live-${f.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
            child: Text(f.elapsed != null ? "AO VIVO ${f.elapsed}'" : 'AO VIVO',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          )
        else
          const Text('Encerrado', style: TextStyle(color: Colors.white38, fontSize: 10)),
      ]);
    }
    if (f.isLive) {
      return Container(
        key: ValueKey('live-${f.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
        child: const Text('AO VIVO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      );
    }
    return Text(formatHm(f.kickoff),
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
  }

  Widget _fixtureCard(Fixture f, Color primary) {
    final channels = _where[f.id] ?? const <Channel>[];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1625),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: f.isLive ? Colors.red.withValues(alpha: 0.6) : const Color(0xFF2a2538)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TvTap(
          key: ValueKey('fixture-${f.id}'),
          // OK no jogo com um único canal abre direto
          onTap: () {
            if (channels.length == 1) _openChannel(channels.single);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              _team(f.homeName, f.homeLogo, home: true),
              SizedBox(width: 92, child: Center(child: _center(f))),
              _team(f.awayName, f.awayLogo, home: false),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
          child: _channelsRow(f, channels, primary),
        ),
      ]),
    );
  }

  Widget _channelsRow(Fixture f, List<Channel> channels, Color primary) {
    if (channels.isEmpty) {
      if (_searchingChannels) {
        return const Row(children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38)),
          SizedBox(width: 8),
          Text('Procurando canais...', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]);
      }
      return const Text('Canal não encontrado na sua lista',
          style: TextStyle(color: Colors.white38, fontSize: 11));
    }
    return Wrap(spacing: 8, runSpacing: 6, children: [
      for (final ch in channels)
        TvTap(
          key: ValueKey('channel-chip-${f.id}-${ch.id}'),
          onTap: () => _openChannel(ch),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.live_tv, color: primary, size: 14),
              const SizedBox(width: 6),
              Text(ch.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      if (_searchingChannels)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white38)),
        ),
    ]);
  }
}
