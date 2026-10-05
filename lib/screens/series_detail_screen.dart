import 'package:flutter/material.dart';
import '../models/app_session.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../core/app_config.dart';
import 'player_screen.dart';
import '../widgets/tv_focus.dart';

class SeriesDetailScreen extends StatefulWidget {
  final AppSession session;
  final Series series;

  /// Só para testes: resposta do get_series_info já pronta (não acessa a rede).
  @visibleForTesting
  final Map<String, dynamic>? debugSeriesInfo;

  /// Só para testes: chamado no lugar de abrir o player.
  @visibleForTesting
  final void Function(Episode episode)? debugOnPlay;

  const SeriesDetailScreen({
    super.key,
    required this.session,
    required this.series,
    this.debugSeriesInfo,
    this.debugOnPlay,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  List<SeriesSeason> _seasons = const [];
  bool _loading = true;
  String? _error;
  int? _selectedSeason;

  @override
  void initState() {
    super.initState();
    if (widget.debugSeriesInfo != null) {
      _applyInfo(widget.debugSeriesInfo!);
      _loading = false;
    } else {
      _loadSeriesInfo();
    }
  }

  void _applyInfo(Map<String, dynamic> info) {
    _seasons = parseSeriesSeasons(info);
    // Abre na primeira temporada que tem episódios
    final firstWithEpisodes = _seasons.where((s) => s.episodes.isNotEmpty);
    _selectedSeason = firstWithEpisodes.isNotEmpty
        ? firstWithEpisodes.first.number
        : (_seasons.isNotEmpty ? _seasons.first.number : null);
  }

  Future<void> _loadSeriesInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final info = await service.getSeriesInfo(widget.series.id);
      if (!mounted) return;
      setState(() {
        _applyInfo(info);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Episode> get _episodes {
    for (final s in _seasons) {
      if (s.number == _selectedSeason) return s.episodes;
    }
    return const [];
  }

  void _playEpisode(Episode ep) {
    if (widget.debugOnPlay != null) {
      widget.debugOnPlay!(ep);
      return;
    }
    final url = ep.streamUrl(
      host: widget.session.effectiveXtreamHost!,
      username: widget.session.effectiveXtreamUsername!,
      password: widget.session.effectiveXtreamPassword!,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          urls: [url],
          title: '${widget.series.name} · ${ep.title}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);

    return Scaffold(
      backgroundColor: const Color(0xFF0d0b14),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            backgroundColor: const Color(0xFF0d0b14),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.series.posterUrl != null &&
                      widget.series.posterUrl!.isNotEmpty)
                    Image.network(
                      widget.series.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF1a1625)),
                    )
                  else
                    Container(color: const Color(0xFF1a1625)),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0d0b14)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.series.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (widget.series.releaseDate != null &&
                          widget.series.releaseDate!.isNotEmpty) ...[
                        Text(
                          widget.series.releaseDate!.length >= 4
                              ? widget.series.releaseDate!.substring(0, 4)
                              : widget.series.releaseDate!,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (widget.series.rating != null) ...[
                        const Icon(Icons.star,
                            color: Colors.amber, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          widget.series.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  if (widget.series.plot != null &&
                      widget.series.plot!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      widget.series.plot!,
                      style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                          height: 1.5),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          if (_loading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: primary),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadSeriesInfo,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primary),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            _buildEpisodesSliver(primary),
        ],
      ),
    );
  }

  Widget _buildEpisodesSliver(Color primary) {
    if (_seasons.every((s) => s.episodes.isEmpty)) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('Nenhum episódio encontrado',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final episodes = _episodes;

    return SliverList(
      delegate: SliverChildListDelegate([
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _seasons.length,
            itemBuilder: (_, i) {
              final s = _seasons[i].number;
              final isSelected = s == _selectedSeason;
              return TvTap(
                key: ValueKey('season-$s'),
                // No controle remoto a tela já abre com a temporada selecionada focada
                autofocus: isSelected,
                onTap: () => setState(() => _selectedSeason = s),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primary : const Color(0xFF1a1625),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? primary : const Color(0xFF2a2538),
                    ),
                  ),
                  child: Text(
                    'Temporada $s',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        if (episodes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Nenhum episódio nesta temporada',
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
        ...episodes.map((ep) => _buildEpisodeTile(ep, primary)),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildEpisodeTile(Episode ep, Color primary) {
    final epNum = ep.episodeNumber > 0 ? '${ep.episodeNumber}' : '?';
    final cover = ep.coverUrl ?? '';

    return TvTap(
      key: ValueKey('episode-${ep.season}-${ep.id}'),
      onTap: () => _playEpisode(ep),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1625),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2a2538)),
        ),
        child: Row(
          children: [
            if (cover.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  cover,
                  width: 72,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _epNumberBadge(epNum, primary),
                ),
              )
            else
              _epNumberBadge(epNum, primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (ep.duration != null) ...[
                    const SizedBox(height: 2),
                    Text(ep.duration!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                  if (ep.plot != null) ...[
                    const SizedBox(height: 2),
                    Text(ep.plot!,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_circle_filled, color: primary, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _epNumberBadge(String epNum, Color primary) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          epNum,
          style: TextStyle(
              color: primary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
