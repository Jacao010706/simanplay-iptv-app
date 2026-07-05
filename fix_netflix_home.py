with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """class _NetflixHomeTab extends StatelessWidget {
  final AppSession session;
  final Function(int) onNavigate;

  const _NetflixHomeTab({required this.session, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner hero
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary.withValues(alpha: 0.3), const Color(0xFF141414)],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.live_tv, size: 80, color: primary.withValues(alpha: 0.3)),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Sua plataforma de entretenimento', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => onNavigate(1),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Assistir'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => onNavigate(2),
                          icon: Icon(Icons.movie, size: 18, color: Colors.white),
                          label: const Text('Filmes', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Categorias em linha
          _buildRow(context, 'TV ao Vivo', Icons.live_tv, primary, () => onNavigate(1)),
          _buildRow(context, 'Filmes', Icons.movie, const Color(0xFF4b7bff), () => onNavigate(2)),
          _buildRow(context, 'Séries', Icons.video_library, const Color(0xFF00c896), () => onNavigate(3)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(onTap: onTap, child: Text('Ver tudo >', style: TextStyle(color: color, fontSize: 12))),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            itemBuilder: (_, i) => GestureDetector(
              onTap: onTap,
              child: Container(
                width: 160,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(child: Icon(icon, color: color, size: 32)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}"""

NEW = """class _NetflixHomeTab extends StatefulWidget {
  final AppSession session;
  final Function(int) onNavigate;

  const _NetflixHomeTab({required this.session, required this.onNavigate});

  @override
  State<_NetflixHomeTab> createState() => _NetflixHomeTabState();
}

class _NetflixHomeTabState extends State<_NetflixHomeTab> {
  List<dynamic> _channels = [];
  List<dynamic> _movies = [];
  List<dynamic> _series = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (!widget.session.hasXtreamAccess) {
      setState(() => _loading = false);
      return;
    }
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final results = await Future.wait([
        service.getLiveCategories(),
        service.getMovieCategories(),
        service.getSeriesCategories(),
      ]);
      final liveCats = results[0] as List;
      final movieCats = results[1] as List;
      final seriesCats = results[2] as List;

      if (liveCats.isNotEmpty) {
        final ch = await service.getLiveStreams(liveCats[0].id, liveCats[0].name);
        _channels = ch.take(10).toList();
      }
      if (movieCats.isNotEmpty) {
        final mv = await service.getMovies(movieCats[0].id, movieCats[0].name);
        _movies = mv.take(10).toList();
      }
      if (seriesCats.isNotEmpty) {
        final sr = await service.getSeries(seriesCats[0].id, seriesCats[0].name);
        _series = sr.take(10).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner hero
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary.withValues(alpha: 0.4), const Color(0xFF141414)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppConfig.appName, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Sua plataforma de entretenimento', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => widget.onNavigate(1),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Assistir'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => widget.onNavigate(2),
                      icon: const Icon(Icons.movie, size: 18, color: Colors.white),
                      label: const Text('Filmes', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: Color(0xFFe94bff))),
            )
          else ...[
            _buildRow('TV ao Vivo', primary, _channels, (item) => widget.onNavigate(1), isChannel: true),
            _buildRow('Filmes', const Color(0xFF4b7bff), _movies, (item) => widget.onNavigate(2)),
            _buildRow('Séries', const Color(0xFF00c896), _series, (item) => widget.onNavigate(3)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRow(String title, Color color, List items, Function(dynamic) onItemTap, {bool isChannel = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Row(
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => widget.onNavigate(isChannel ? 1 : title == 'Filmes' ? 2 : 3),
                child: Text('Ver tudo >', style: TextStyle(color: color, fontSize: 12)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: isChannel ? 80 : 140,
          child: items.isEmpty
            ? Center(child: Text('Carregando...', style: TextStyle(color: Colors.white38, fontSize: 12)))
            : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  final String? imageUrl = isChannel
                    ? (item.logoUrl?.isNotEmpty == true ? item.logoUrl : null)
                    : (item.posterUrl?.isNotEmpty == true ? item.posterUrl : null);
                  final String name = item.name ?? '';
                  return GestureDetector(
                    onTap: () => onItemTap(item),
                    child: Container(
                      width: isChannel ? 120 : 100,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null
                          ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                              errorBuilder: (_, __, ___) => _placeholder(color, name))
                          : _placeholder(color, name),
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _placeholder(Color color, String name) {
    return Container(
      color: color.withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5), size: 24),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(name, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

# Adiciona import do XtreamService
if "import '../services/xtream_service.dart';" not in content:
    content = content.replace(
        "import '../models/app_session.dart';",
        "import '../models/app_session.dart';\nimport '../services/xtream_service.dart';\nimport '../models/channel.dart';\nimport '../models/movie.dart';\nimport '../models/series.dart';"
    )
    print("imports OK")

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Netflix home atualizado com conteudo real.")