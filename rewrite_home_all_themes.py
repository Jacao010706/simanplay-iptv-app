dart_code = open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", encoding="utf-8").read()

# Adiciona os temas 4, 5, 6 antes do _HomeTab
NEW_THEMES = r"""
// ============================================================
// TEMA 3 — Sidebar + lista de canais (estilo Smarters)
// ============================================================
class _SidebarLayout extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _SidebarLayout({required this.session, required this.onLogout});
  @override
  State<_SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<_SidebarLayout> {
  int _idx = 0;
  List _categories = [], _channels = [];
  int _selectedCat = 0;
  bool _loading = true;

  final _navItems = [
    {'icon': Icons.home, 'label': 'Início'},
    {'icon': Icons.live_tv, 'label': 'Ao Vivo'},
    {'icon': Icons.movie, 'label': 'Filmes'},
    {'icon': Icons.video_library, 'label': 'Séries'},
  ];

  @override
  void initState() { super.initState(); _loadCats(); }

  Future<void> _loadCats() async {
    if (!widget.session.hasXtreamAccess) { setState(() => _loading = false); return; }
    try {
      final svc = XtreamService(host: widget.session.effectiveXtreamHost!, username: widget.session.effectiveXtreamUsername!, password: widget.session.effectiveXtreamPassword!);
      final cats = await svc.getLiveCategories();
      if (cats.isNotEmpty) {
        final ch = await svc.getLiveStreams(cats[0].id, cats[0].name);
        setState(() { _categories = cats; _channels = ch; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadCat(int i) async {
    if (!widget.session.hasXtreamAccess || i >= _categories.length) return;
    setState(() { _selectedCat = i; _loading = true; });
    try {
      final svc = XtreamService(host: widget.session.effectiveXtreamHost!, username: widget.session.effectiveXtreamUsername!, password: widget.session.effectiveXtreamPassword!);
      final ch = await svc.getLiveStreams(_categories[i].id, _categories[i].name);
      setState(() { _channels = ch; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final surface = Color(AppConfig.surfaceColor);
    final screens = [
      _SmartersHome(categories: _categories, channels: _channels, loading: _loading, selectedCat: _selectedCat, onCatSelected: _loadCat, primary: primary, surface: surface),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];
    return Scaffold(
      backgroundColor: Color(AppConfig.backgroundColor),
      body: SafeArea(child: Row(children: [
        Container(width: 72, color: surface, child: Column(children: [
          const SizedBox(height: 12),
          Icon(Icons.live_tv, color: primary, size: 24),
          const SizedBox(height: 16),
          ...List.generate(_navItems.length, (i) {
            final sel = _idx == i;
            return GestureDetector(onTap: () => setState(() => _idx = i),
              child: Container(margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: sel ? primary.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10),
                  border: sel ? Border.all(color: primary.withValues(alpha: 0.5)) : null),
                child: Column(children: [
                  Icon(_navItems[i]['icon'] as IconData, color: sel ? primary : Colors.white38, size: 20),
                  const SizedBox(height: 3),
                  Text(_navItems[i]['label'] as String, style: TextStyle(color: sel ? primary : Colors.white38, fontSize: 8), textAlign: TextAlign.center),
                ])));
          }),
          const Spacer(),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 18), onPressed: widget.onLogout),
          const SizedBox(height: 4),
        ])),
        Expanded(child: Column(children: [
          Container(height: 44, color: surface, padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text(_navItems[_idx]['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (widget.session.expiresAt != null)
                Text('Vence: ${_fmtDate(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ])),
          Expanded(child: screens[_idx]),
        ])),
      ])),
    );
  }
}

class _SmartersHome extends StatelessWidget {
  final List categories, channels;
  final bool loading;
  final int selectedCat;
  final Function(int) onCatSelected;
  final Color primary, surface;
  const _SmartersHome({required this.categories, required this.channels, required this.loading, required this.selectedCat, required this.onCatSelected, required this.primary, required this.surface});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 160, color: surface.withValues(alpha: 0.5), child: Column(children: [
        Container(padding: const EdgeInsets.all(12), color: surface, width: double.infinity,
          child: Text('Categorias', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(itemCount: categories.length, itemBuilder: (_, i) {
          final sel = selectedCat == i;
          return GestureDetector(onTap: () => onCatSelected(i),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: sel ? primary.withValues(alpha: 0.15) : Colors.transparent,
                border: Border(left: BorderSide(color: sel ? primary : Colors.transparent, width: 3))),
              child: Text(categories[i].name ?? '', style: TextStyle(color: sel ? primary : Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)));
        })),
      ])),
      Expanded(child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: surface, width: double.infinity,
          child: Text(categories.isNotEmpty ? (categories[selectedCat].name ?? 'Canais') : 'Canais', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
        Expanded(child: loading ? Center(child: CircularProgressIndicator(color: primary)) :
          channels.isEmpty ? const Center(child: Text('Nenhum canal', style: TextStyle(color: Colors.white38))) :
          ListView.builder(itemCount: channels.length, itemBuilder: (_, i) {
            final ch = channels[i];
            return ListTile(
              leading: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: Image.network(ch.logoUrl!, width: 40, height: 40, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.live_tv, color: primary, size: 28)))
                : Icon(Icons.live_tv, color: primary, size: 28),
              title: Text(ch.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text(ch.categoryName ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(urls: [ch.streamUrl], title: ch.name ?? ''))),
            );
          })),
      ])),
    ]);
  }
}

// ============================================================
// TEMA 4 — IBO Style: Banner filme destaque + grade
// ============================================================
class _IBOLayout4 extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _IBOLayout4({required this.session, required this.onLogout});
  @override
  State<_IBOLayout4> createState() => _IBOLayout4State();
}

class _IBOLayout4State extends State<_IBOLayout4> {
  int _idx = 0;
  List _movies = [], _series = [], _channels = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _XtreamLoader.load(widget.session);
    if (mounted) setState(() { _channels = data['channels']!; _movies = data['movies']!; _series = data['series']!; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final surface = Color(AppConfig.surfaceColor);
    final screens = [
      _IBO4Home(movies: _movies, series: _series, channels: _channels, loading: _loading, onNavigate: (i) => setState(() => _idx = i), primary: primary),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      body: SafeArea(child: Column(children: [
        Container(height: 52, color: surface, padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(Icons.live_tv, color: primary, size: 22),
            const SizedBox(width: 8),
            Text(AppConfig.appName, style: TextStyle(color: primary, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            ...[('Início',0),('Ao Vivo',1),('Filmes',2),('Séries',3)].map((t) => GestureDetector(
              onTap: () => setState(() => _idx = t.$2),
              child: Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _idx == t.$2 ? primary.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _idx == t.$2 ? primary : Colors.transparent)),
                child: Text(t.$1, style: TextStyle(color: _idx == t.$2 ? primary : Colors.white54, fontSize: 12))))),
            const SizedBox(width: 8),
            GestureDetector(onTap: widget.onLogout, child: const Icon(Icons.logout, color: Colors.white38, size: 20)),
          ])),
        Expanded(child: screens[_idx]),
      ])),
    );
  }
}

class _IBO4Home extends StatelessWidget {
  final List movies, series, channels;
  final bool loading;
  final Function(int) onNavigate;
  final Color primary;
  const _IBO4Home({required this.movies, required this.series, required this.channels, required this.loading, required this.onNavigate, required this.primary});

  @override
  Widget build(BuildContext context) {
    final featuredMovie = movies.isNotEmpty ? movies.first : null;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Banner destaque
      Stack(children: [
        Container(height: 260, width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFF1a1a2e)),
          child: featuredMovie?.posterUrl != null
            ? Image.network(featuredMovie!.posterUrl!, fit: BoxFit.cover, width: double.infinity,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)))
            : Container(color: const Color(0xFF1a1a2e))),
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerRight, end: Alignment.centerLeft,
          colors: [Colors.transparent, const Color(0xFF0a0a0a).withValues(alpha: 0.9)])))),
        Positioned(left: 20, bottom: 20, right: 200, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (featuredMovie != null) ...[
            Text(featuredMovie.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), maxLines: 2),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(onPressed: () => onNavigate(2), icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => onNavigate(2), style: OutlinedButton.styleFrom(side: BorderSide(color: primary), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                child: Text('+ Info', style: TextStyle(color: primary, fontSize: 12))),
            ]),
          ],
        ])),
      ]),
      // Grade de categorias
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCatGrid(context),
        const SizedBox(height: 20),
        if (!loading) ...[
          _buildHorizontalList('Filmes em Destaque', movies, const Color(0xFF4b7bff), () => onNavigate(2)),
          _buildHorizontalList('Séries Populares', series, const Color(0xFF00c896), () => onNavigate(3)),
          _buildHorizontalList('TV ao Vivo', channels, primary, () => onNavigate(1), isChannel: true),
        ],
      ])),
    ]));
  }

  Widget _buildCatGrid(BuildContext context) {
    final cats = [
      {'icon': Icons.live_tv, 'label': 'Ao Vivo', 'color': primary, 'idx': 1},
      {'icon': Icons.movie, 'label': 'Filmes', 'color': const Color(0xFF4b7bff), 'idx': 2},
      {'icon': Icons.video_library, 'label': 'Séries', 'color': const Color(0xFF00c896), 'idx': 3},
      {'icon': Icons.favorite, 'label': 'Favoritos', 'color': const Color(0xFFff6b6b), 'idx': 0},
    ];
    return GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1,
      children: cats.map((c) => GestureDetector(
        onTap: () => onNavigate(c['idx'] as int),
        child: Container(decoration: BoxDecoration(color: (c['color'] as Color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: (c['color'] as Color).withValues(alpha: 0.4))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(c['icon'] as IconData, color: c['color'] as Color, size: 28),
            const SizedBox(height: 4),
            Text(c['label'] as String, style: TextStyle(color: c['color'] as Color, fontSize: 10, fontWeight: FontWeight.w500)),
          ])))).toList());
  }

  Widget _buildHorizontalList(String title, List items, Color color, VoidCallback onTap, {bool isChannel = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(width: 3, height: 16, color: color, margin: const EdgeInsets.only(right: 8)),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(onTap: onTap, child: Text('Ver tudo', style: TextStyle(color: color, fontSize: 11))),
        ])),
      SizedBox(height: isChannel ? 70 : 130, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length,
        itemBuilder: (_, i) {
          final url = isChannel ? items[i].logoUrl : items[i].posterUrl;
          return GestureDetector(onTap: onTap, child: Container(width: isChannel ? 110 : 90, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5)))
                : Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5)))));
        })),
      const SizedBox(height: 16),
    ]);
  }
}

// ============================================================
// TEMA 5 — IBO Style: Sidebar esquerda + destaque grande
// ============================================================
class _IBOLayout5 extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _IBOLayout5({required this.session, required this.onLogout});
  @override
  State<_IBOLayout5> createState() => _IBOLayout5State();
}

class _IBOLayout5State extends State<_IBOLayout5> {
  int _idx = 0;
  List _movies = [], _series = [], _channels = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _XtreamLoader.load(widget.session);
    if (mounted) setState(() { _channels = data['channels']!; _movies = data['movies']!; _series = data['series']!; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final surface = Color(AppConfig.surfaceColor);
    final navItems = [
      {'icon': Icons.home, 'label': 'Home'},
      {'icon': Icons.live_tv, 'label': 'Live TV'},
      {'icon': Icons.movie, 'label': 'Filmes'},
      {'icon': Icons.video_library, 'label': 'Séries'},
    ];
    final screens = [
      _IBO5Home(movies: _movies, series: _series, channels: _channels, loading: _loading, onNavigate: (i) => setState(() => _idx = i), primary: primary),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      body: SafeArea(child: Row(children: [
        Container(width: 80, decoration: BoxDecoration(color: surface, border: Border(right: BorderSide(color: primary.withValues(alpha: 0.2)))),
          child: Column(children: [
            const SizedBox(height: 16),
            Icon(Icons.live_tv, color: primary, size: 28),
            const SizedBox(height: 20),
            ...List.generate(navItems.length, (i) {
              final sel = _idx == i;
              return GestureDetector(onTap: () => setState(() => _idx = i),
                child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: sel ? primary.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? primary.withValues(alpha: 0.5) : Colors.transparent)),
                  child: Column(children: [
                    Icon(navItems[i]['icon'] as IconData, color: sel ? primary : Colors.white24, size: 22),
                    const SizedBox(height: 4),
                    Text(navItems[i]['label'] as String, style: TextStyle(color: sel ? primary : Colors.white24, fontSize: 8), textAlign: TextAlign.center),
                  ])));
            }),
            const Spacer(),
            if (widget.session.expiresAt != null)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(_fmtDate(widget.session.expiresAt!), style: const TextStyle(color: Colors.white24, fontSize: 7), textAlign: TextAlign.center)),
            IconButton(icon: const Icon(Icons.logout, color: Colors.white24, size: 18), onPressed: widget.onLogout),
            const SizedBox(height: 8),
          ])),
        Expanded(child: screens[_idx]),
      ])),
    );
  }
}

class _IBO5Home extends StatelessWidget {
  final List movies, series, channels;
  final bool loading;
  final Function(int) onNavigate;
  final Color primary;
  const _IBO5Home({required this.movies, required this.series, required this.channels, required this.loading, required this.onNavigate, required this.primary});

  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator(color: primary));
    final featured = movies.isNotEmpty ? movies[0] : null;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Destaque grande
      GestureDetector(onTap: () => onNavigate(2), child: Container(height: 300, width: double.infinity,
        child: Stack(children: [
          featured?.posterUrl != null
            ? Image.network(featured!.posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 300,
                errorBuilder: (_, __, ___) => Container(height: 300, color: const Color(0xFF1a1a2e)))
            : Container(height: 300, color: const Color(0xFF1a1a2e),
                child: Center(child: Icon(Icons.movie, size: 80, color: primary.withValues(alpha: 0.3)))),
          Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xFF0f0f1a)])))),
          Positioned(bottom: 20, left: 20, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (featured != null) Text(featured.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 2),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton.icon(onPressed: () => onNavigate(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
                style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white)),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: () => onNavigate(3), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                child: const Text('Séries', style: TextStyle(color: Colors.white))),
            ]),
          ])),
        ]))),
      // Listas horizontais
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _list('Filmes', movies, const Color(0xFF4b7bff), () => onNavigate(2)),
        _list('Séries', series, const Color(0xFF00c896), () => onNavigate(3)),
        _list('TV ao Vivo', channels, primary, () => onNavigate(1), isChannel: true),
      ])),
    ]));
  }

  Widget _list(String title, List items, Color color, VoidCallback onTap, {bool isChannel = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(onTap: onTap, child: Text('Ver tudo >', style: TextStyle(color: color, fontSize: 11))),
        ])),
      SizedBox(height: isChannel ? 70 : 150, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length,
        itemBuilder: (_, i) {
          final url = isChannel ? items[i].logoUrl : items[i].posterUrl;
          return GestureDetector(onTap: onTap, child: Container(width: isChannel ? 110 : 100, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5)))
                : Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5)))));
        })),
      const SizedBox(height: 16),
    ]);
  }
}

// ============================================================
// TEMA 6 — IBO Style: Bottom nav + banner lateral + conteúdo
// ============================================================
class _IBOLayout6 extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _IBOLayout6({required this.session, required this.onLogout});
  @override
  State<_IBOLayout6> createState() => _IBOLayout6State();
}

class _IBOLayout6State extends State<_IBOLayout6> {
  int _idx = 0;
  List _movies = [], _series = [], _channels = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await _XtreamLoader.load(widget.session);
    if (mounted) setState(() { _channels = data['channels']!; _movies = data['movies']!; _series = data['series']!; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final screens = [
      _IBO6Home(movies: _movies, series: _series, channels: _channels, loading: _loading, onNavigate: (i) => setState(() => _idx = i), primary: primary, onLogout: widget.onLogout, session: widget.session),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF0d0d0d),
      body: screens[_idx],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: const Color(0xFF1a1a1a), border: Border(top: BorderSide(color: primary.withValues(alpha: 0.3)))),
        child: SafeArea(child: SizedBox(height: 56, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ...[
            {'icon': Icons.home, 'label': 'Home', 'idx': 0},
            {'icon': Icons.live_tv, 'label': 'Ao Vivo', 'idx': 1},
            {'icon': Icons.movie, 'label': 'Filmes', 'idx': 2},
            {'icon': Icons.video_library, 'label': 'Séries', 'idx': 3},
          ].map((item) {
            final sel = _idx == item['idx'];
            return GestureDetector(onTap: () => setState(() => _idx = item['idx'] as int),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(item['icon'] as IconData, color: sel ? primary : Colors.white38, size: 22),
                Text(item['label'] as String, style: TextStyle(color: sel ? primary : Colors.white38, fontSize: 10)),
              ]));
          }),
        ]))),
      ),
    );
  }
}

class _IBO6Home extends StatelessWidget {
  final List movies, series, channels;
  final bool loading;
  final Function(int) onNavigate;
  final Color primary;
  final VoidCallback onLogout;
  final AppSession session;
  const _IBO6Home({required this.movies, required this.series, required this.channels, required this.loading, required this.onNavigate, required this.primary, required this.onLogout, required this.session});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 280,
        floating: false, pinned: true,
        backgroundColor: const Color(0xFF1a1a1a),
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(children: [
            movies.isNotEmpty && movies[0].posterUrl != null
              ? Image.network(movies[0].posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 280,
                  errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)))
              : Container(color: const Color(0xFF1a1a2e)),
            Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xFF0d0d0d)])))),
            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppConfig.appName, style: TextStyle(color: primary, fontSize: 14, fontWeight: FontWeight.bold)),
              if (movies.isNotEmpty) Text(movies[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton(onPressed: () => onNavigate(2), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, minimumSize: const Size(100, 36)),
                  child: const Text('▶ Assistir')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNavigate(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), minimumSize: const Size(80, 36)),
                  child: const Text('📺 Live', style: TextStyle(color: Colors.white))),
              ]),
            ])),
          ]),
          title: Row(children: [
            Icon(Icons.live_tv, color: primary, size: 18),
            const SizedBox(width: 6),
            Text(AppConfig.appName, style: const TextStyle(fontSize: 14)),
          ]),
        ),
        actions: [
          if (session.expiresAt != null)
            Center(child: Padding(padding: const EdgeInsets.only(right: 8),
              child: Text('Vence: ${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: onLogout),
        ],
      ),
      SliverToBoxAdapter(child: loading
        ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        : Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _section('🎬 Filmes', movies, const Color(0xFF4b7bff), () => onNavigate(2)),
            _section('📺 Séries', series, const Color(0xFF00c896), () => onNavigate(3)),
            _section('📡 TV ao Vivo', channels, primary, () => onNavigate(1), isChannel: true),
          ]))),
    ]);
  }

  Widget _section(String title, List items, Color color, VoidCallback onTap, {bool isChannel = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          GestureDetector(onTap: onTap, child: Text('Ver tudo >', style: TextStyle(color: color, fontSize: 11))),
        ])),
      SizedBox(height: isChannel ? 70 : 150, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length,
        itemBuilder: (_, i) {
          final url = isChannel ? items[i].logoUrl : items[i].posterUrl;
          return GestureDetector(onTap: onTap, child: Container(width: isChannel ? 110 : 100, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: url != null && url.isNotEmpty
                ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5)))
                : Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.5)))));
        })),
      const SizedBox(height: 16),
    ]);
  }
}
"""

# Insere os temas antes do _HomeTab
OLD = "// ============================================================\n// Home Tab compartilhada (Tema 1 e 3)"
NEW = NEW_THEMES + "\n// ============================================================\n// Home Tab compartilhada (Tema 1 e 3)"

count = dart_code.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es).")
    # Mostra o que tem perto do final
    print("Tentando encontrar _HomeTab...")
    if "_HomeTab" in dart_code:
        idx = dart_code.index("_HomeTab")
        print(dart_code[max(0,idx-100):idx+50])
    exit(1)

dart_code = dart_code.replace(OLD, NEW)

# Atualiza o switch no build
OLD_SWITCH = """    switch (AppConfig.appTheme) {
      case 2: return _NetflixLayout(session: widget.session, onLogout: _logout);
      case 3: return _SidebarLayout(session: widget.session, onLogout: _logout);
      case 4: return _IBOLayout4(session: widget.session, onLogout: _logout);
      case 5: return _IBOLayout5(session: widget.session, onLogout: _logout);
      case 6: return _IBOLayout6(session: widget.session, onLogout: _logout);
      default: return _GridLayout(session: widget.session, onLogout: _logout);
    }"""

if OLD_SWITCH not in dart_code:
    # Tenta adicionar o switch
    OLD_BUILD = "    if (AppConfig.appTheme == 3) {\n      return _SidebarLayout(session: widget.session, onLogout: _logout);\n    }\n    if (AppConfig.appTheme == 2) {\n      return _NetflixLayout(session: widget.session, onLogout: _logout);\n    }\n    return _GridLayout(session: widget.session, onLogout: _logout);"
    if OLD_BUILD in dart_code:
        dart_code = dart_code.replace(OLD_BUILD, OLD_SWITCH)
        print("switch atualizado OK")

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(dart_code)

print("OK! Temas 3, 4, 5 e 6 adicionados com sucesso!")
print("Use: python change_theme.py [1-6]")