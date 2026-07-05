with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """// ============================================================
// TEMA 3 — Sidebar lateral (estilo Smarters)
// ============================================================
class _SidebarLayout extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _SidebarLayout({required this.session, required this.onLogout});

  @override
  State<_SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<_SidebarLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final screens = [
      _HomeTab(session: widget.session, onNavigate: (i) => setState(() => _selectedIndex = i)),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];

    final navItems = [
      {'icon': Icons.home, 'label': 'Início'},
      {'icon': Icons.live_tv, 'label': 'Ao Vivo'},
      {'icon': Icons.movie, 'label': 'Filmes'},
      {'icon': Icons.video_library, 'label': 'Séries'},
    ];

    return Scaffold(
      backgroundColor: Color(AppConfig.backgroundColor),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 72,
              color: Color(AppConfig.surfaceColor),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Icon(Icons.live_tv, color: primary, size: 28),
                  const SizedBox(height: 24),
                  ...List.generate(navItems.length, (i) {
                    final selected = _selectedIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? primary.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: selected ? Border.all(color: primary.withValues(alpha: 0.5)) : null,
                        ),
                        child: Column(
                          children: [
                            Icon(navItems[i]['icon'] as IconData, color: selected ? primary : Colors.white38, size: 22),
                            const SizedBox(height: 4),
                            Text(navItems[i]['label'] as String, style: TextStyle(color: selected ? primary : Colors.white38, fontSize: 9), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: widget.onLogout),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 48,
                    color: Color(AppConfig.surfaceColor),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(navItems[_selectedIndex]['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (widget.session.expiresAt != null)
                          Text('Vence: \${_fmt(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                  Expanded(child: screens[_selectedIndex]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) => '\${dt.day.toString().padLeft(2,\'0\')}/\${dt.month.toString().padLeft(2,\'0\')}/\${dt.year}';
}"""

NEW = """// ============================================================
// TEMA 3 — Sidebar lateral (estilo Smarters)
// ============================================================
class _SidebarLayout extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _SidebarLayout({required this.session, required this.onLogout});

  @override
  State<_SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<_SidebarLayout> {
  int _selectedIndex = 0;
  List _categories = [];
  List _channels = [];
  int _selectedCat = 0;
  bool _loading = true;

  final navItems = [
    {'icon': Icons.home, 'label': 'Início'},
    {'icon': Icons.live_tv, 'label': 'Ao Vivo'},
    {'icon': Icons.movie, 'label': 'Filmes'},
    {'icon': Icons.video_library, 'label': 'Séries'},
  ];

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
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
      final cats = await service.getLiveCategories();
      if (cats.isNotEmpty) {
        final ch = await service.getLiveStreams(cats[0].id, cats[0].name);
        setState(() { _categories = cats; _channels = ch; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadCategory(int index) async {
    if (!widget.session.hasXtreamAccess || index >= _categories.length) return;
    setState(() { _selectedCat = index; _loading = true; });
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final ch = await service.getLiveStreams(_categories[index].id, _categories[index].name);
      setState(() { _channels = ch; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final bg = Color(AppConfig.backgroundColor);
    final surface = Color(AppConfig.surfaceColor);

    final screens = [
      _SmartersHome(session: widget.session, categories: _categories, channels: _channels,
        loading: _loading, selectedCat: _selectedCat, onCatSelected: _loadCategory,
        primary: primary, surface: surface),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 72,
              color: surface,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Icon(Icons.live_tv, color: primary, size: 26),
                  const SizedBox(height: 4),
                  Text(AppConfig.appName.split(' ')[0], style: TextStyle(color: primary, fontSize: 8, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ...List.generate(navItems.length, (i) {
                    final selected = _selectedIndex == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIndex = i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? primary.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: selected ? Border.all(color: primary.withValues(alpha: 0.5)) : null,
                        ),
                        child: Column(
                          children: [
                            Icon(navItems[i]['icon'] as IconData, color: selected ? primary : Colors.white38, size: 20),
                            const SizedBox(height: 3),
                            Text(navItems[i]['label'] as String,
                              style: TextStyle(color: selected ? primary : Colors.white38, fontSize: 8),
                              textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  if (widget.session.expiresAt != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(_fmt(widget.session.expiresAt!),
                        style: const TextStyle(color: Colors.white24, fontSize: 7), textAlign: TextAlign.center),
                    ),
                  const SizedBox(height: 4),
                  IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 18), onPressed: widget.onLogout),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            // Content
            Expanded(child: screens[_selectedIndex]),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) => '\${dt.day.toString().padLeft(2,\'0\')}/\${dt.month.toString().padLeft(2,\'0\')}/\${dt.year}';
}

class _SmartersHome extends StatelessWidget {
  final AppSession session;
  final List categories;
  final List channels;
  final bool loading;
  final int selectedCat;
  final Function(int) onCatSelected;
  final Color primary;
  final Color surface;

  const _SmartersHome({
    required this.session, required this.categories, required this.channels,
    required this.loading, required this.selectedCat, required this.onCatSelected,
    required this.primary, required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Lista de categorias
        Container(
          width: 160,
          color: surface.withValues(alpha: 0.5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: surface,
                width: double.infinity,
                child: Text('Categorias', style: TextStyle(color: primary, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (_, i) {
                    final selected = selectedCat == i;
                    return GestureDetector(
                      onTap: () => onCatSelected(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? primary.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border(left: BorderSide(color: selected ? primary : Colors.transparent, width: 3)),
                        ),
                        child: Text(categories[i].name ?? '',
                          style: TextStyle(color: selected ? primary : Colors.white54, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Lista de canais
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: surface,
                width: double.infinity,
                child: Text(
                  categories.isNotEmpty ? (categories[selectedCat].name ?? 'Canais') : 'Canais',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: loading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : channels.isEmpty
                    ? const Center(child: Text('Nenhum canal', style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: channels.length,
                        itemBuilder: (_, i) {
                          final ch = channels[i];
                          return ListTile(
                            leading: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(ch.logoUrl!, width: 40, height: 40, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(Icons.live_tv, color: primary, size: 28)),
                                )
                              : Icon(Icons.live_tv, color: primary, size: 28),
                            title: Text(ch.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                            subtitle: Text(ch.categoryName ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => PlayerScreen(urls: [ch.streamUrl], title: ch.name ?? ''))),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

# Adiciona import do PlayerScreen se não existir
if "import 'player_screen.dart';" not in content:
    content = content.replace(
        "import 'series_screen.dart';",
        "import 'series_screen.dart';\nimport 'player_screen.dart';"
    )
    print("import player_screen OK")

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Tema 3 atualizado com sidebar + categorias + lista de canais.")