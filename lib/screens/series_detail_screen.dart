import 'package:flutter/material.dart';
import '../models/app_session.dart';
import '../models/series.dart';
import '../services/xtream_service.dart';
import '../core/app_config.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final AppSession session;
  final Series series;

  const SeriesDetailScreen({
    super.key,
    required this.session,
    required this.series,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  Map<String, dynamic>? _seriesInfo;
  bool _loading = true;
  String? _error;
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
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
      setState(() {
        _seriesInfo = info;
        _loading = false;
      });
      final seasons = _getSeasons();
      if (seasons.isNotEmpty) {
        setState(() => _selectedSeason = seasons.first);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<int> _getSeasons() {
    if (_seriesInfo == null) return [];
    final episodes = _seriesInfo!['episodes'];
    if (episodes == null) return [];
    final keys = (episodes as Map<String, dynamic>)
        .keys
        .map((k) => int.tryParse(k) ?? 0)
        .where((n) => n > 0)
        .toList();
    keys.sort();
    return keys;
  }

  List<Map<String, dynamic>> _getEpisodes(int season) {
    if (_seriesInfo == null) return [];
    final episodes = _seriesInfo!['episodes'];
    if (episodes == null) return [];
    final seasonEps =
        (episodes as Map<String, dynamic>)[season.toString()];
    if (seasonEps == null) return [];
    return List<Map<String, dynamic>>.from(seasonEps);
  }

  void _playEpisode(Map<String, dynamic> ep) {
    final host = widget.session.effectiveXtreamHost!;
    final user = widget.session.effectiveXtreamUsername!;
    final pass = widget.session.effectiveXtreamPassword!;
    final epId = ep['id'].toString();
    final ext = ep['container_extension'] ?? 'mp4';
    final url = '$host/series/$user/$pass/$epId.$ext';
    final epNum = ep['episode_num']?.toString() ?? '?';
    final title = (ep['title'] as String?)?.isNotEmpty == true
        ? ep['title'] as String
        : 'Ep. $epNum';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          urls: [url],
          title: '${widget.series.name} · $title',
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
    final seasons = _getSeasons();
    if (seasons.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text('Nenhum episódio disponível',
              style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    final episodes = _getEpisodes(_selectedSeason);

    return SliverList(
      delegate: SliverChildListDelegate([
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: seasons.length,
            itemBuilder: (_, i) {
              final s = seasons[i];
              final isSelected = s == _selectedSeason;
              return GestureDetector(
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
        ...episodes.map((ep) => _buildEpisodeTile(ep, primary)),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildEpisodeTile(Map<String, dynamic> ep, Color primary) {
    final epNum = ep['episode_num']?.toString() ?? '?';
    final title = (ep['title'] as String?)?.isNotEmpty == true
        ? ep['title'] as String
        : 'Episódio $epNum';
    final info = ep['info'] as Map<String, dynamic>? ?? {};
    final duration = info['duration']?.toString() ?? '';
    final plot = info['plot']?.toString() ?? '';
    final cover = info['movie_image']?.toString().isNotEmpty == true
        ? info['movie_image'] as String
        : (info['cover_big']?.toString() ?? '');

    return InkWell(
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
                    title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (duration.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(duration,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                  if (plot.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(plot,
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
