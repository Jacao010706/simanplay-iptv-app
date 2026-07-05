import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../models/app_session.dart';
import '../services/xtream_service.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/series.dart';
import 'activation_screen_v3.dart';
import 'live_tv_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';
import 'player_screen.dart';

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

class HomeScreen extends StatefulWidget {
  final AppSession session;
  const HomeScreen({super.key, required this.session});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(AppConfig.surfaceColor),
        title: const Text('Sair', style: TextStyle(color: Colors.white)),
        content: const Text('Deseja desconectar?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sair', style: TextStyle(color: Color(AppConfig.primaryColor)))),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ActivationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    switch (AppConfig.appTheme) {
      case 2: return _NetflixLayout(session: widget.session, onLogout: _logout);
      case 3: return _SidebarLayout(session: widget.session, onLogout: _logout);
      case 4: return _IBOLayout4(session: widget.session, onLogout: _logout);
      case 5: return _IBOLayout5(session: widget.session, onLogout: _logout);
      case 6: return _IBOLayout6(session: widget.session, onLogout: _logout);
      default: return _GridLayout(session: widget.session, onLogout: _logout);
    }
  }
}

// ============================================================
// SHARED: Carregador de conteudo Xtream
// ============================================================
Future<Map<String, List>> _loadXtream(AppSession session) async {
  final result = <String, List>{'channels': [], 'movies': [], 'series': []};
  if (!session.hasXtreamAccess) return result;
  try {
    final svc = XtreamService(
      host: session.effectiveXtreamHost!,
      username: session.effectiveXtreamUsername!,
      password: session.effectiveXtreamPassword!,
    );
    final cats = await Future.wait([
      svc.getLiveCategories(),
      svc.getMovieCategories(),
      svc.getSeriesCategories(),
    ]);
    final liveCats = cats[0], movieCats = cats[1], seriesCats = cats[2];
    if (liveCats.isNotEmpty) {
      final all = <dynamic>[];
      // Pega o primeiro canal de cada categoria (sem duplicar)
      for (final c in liveCats.take(20)) {
        final ch = await svc.getLiveStreams(c.id, c.name);
        if (ch.isNotEmpty) all.add(ch.first);
        if (all.length >= 15) break;
      }
      result['channels'] = all;
    }
    if (movieCats.isNotEmpty) {
      final all = <dynamic>[];
      for (final c in movieCats.take(3)) { all.addAll(await svc.getMovies(c.id, c.name)); if (all.length >= 20) break; }
      all.shuffle(); result['movies'] = all.take(12).toList();
    }
    if (seriesCats.isNotEmpty) {
      final all = <dynamic>[];
      for (final c in seriesCats.take(3)) { all.addAll(await svc.getSeries(c.id, c.name)); if (all.length >= 20) break; }
      all.shuffle(); result['series'] = all.take(12).toList();
    }
  } catch (_) {}
  return result;
}

Widget _posterItem(String? url, Color color, double width, double height, VoidCallback onTap) {
  return GestureDetector(onTap: onTap, child: Container(
    width: width, margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: ClipRRect(borderRadius: BorderRadius.circular(8),
      child: url != null && url.isNotEmpty
        ? Image.network(url, fit: BoxFit.cover, width: width, height: height, errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.4)))
        : Icon(Icons.image_not_supported, color: color.withValues(alpha: 0.4)))));
}

Widget _hList(String title, List items, Color color, VoidCallback onTap, {bool isChannel = false}) {
  if (items.isEmpty) return const SizedBox.shrink();
  final h = isChannel ? 70.0 : 150.0;
  final w = isChannel ? 110.0 : 100.0;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      const Spacer(),
      GestureDetector(onTap: onTap, child: Text('Ver tudo >', style: TextStyle(color: color, fontSize: 11))),
    ])),
    SizedBox(height: h, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: items.length,
      itemBuilder: (_, i) => _posterItem(isChannel ? items[i].logoUrl : items[i].posterUrl, color, w, h, onTap))),
    const SizedBox(height: 16),
  ]);
}

// ============================================================
// TEMA 1 — Grade de icones
// ============================================================
class _GridLayout extends StatefulWidget {
  final AppSession session; final VoidCallback onLogout;
  const _GridLayout({required this.session, required this.onLogout});
  @override State<_GridLayout> createState() => _GridLayoutState();
}
class _GridLayoutState extends State<_GridLayout> {
  int _idx = 0;
  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    final screens = [
      _HomeTab(session: widget.session, onNavigate: (i) => setState(() => _idx = i)),
      LiveTvScreen(session: widget.session), MoviesScreen(session: widget.session), SeriesScreen(session: widget.session),
    ];
    return Scaffold(
      backgroundColor: Color(AppConfig.backgroundColor),
      appBar: AppBar(backgroundColor: Color(AppConfig.surfaceColor), elevation: 0,
        title: Row(children: [Icon(Icons.live_tv, color: p, size: 22), const SizedBox(width: 8), Text(AppConfig.appName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))]),
        actions: [
          if (widget.session.expiresAt != null) Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text('Vence: ${_fmtDate(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 11)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white54), onPressed: widget.onLogout),
        ]),
      body: screens[_idx],
      bottomNavigationBar: NavigationBar(backgroundColor: Color(AppConfig.surfaceColor), selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i), indicatorColor: p.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined, color: Colors.white54), selectedIcon: Icon(Icons.home, color: p), label: 'Inicio'),
          NavigationDestination(icon: const Icon(Icons.live_tv_outlined, color: Colors.white54), selectedIcon: Icon(Icons.live_tv, color: p), label: 'Ao Vivo'),
          NavigationDestination(icon: const Icon(Icons.movie_outlined, color: Colors.white54), selectedIcon: Icon(Icons.movie, color: p), label: 'Filmes'),
          NavigationDestination(icon: const Icon(Icons.video_library_outlined, color: Colors.white54), selectedIcon: Icon(Icons.video_library, color: p), label: 'Series'),
        ]),
    );
  }
}

// ============================================================
// TEMA 2 — Netflix style
// ============================================================
class _NetflixLayout extends StatefulWidget {
  final AppSession session; final VoidCallback onLogout;
  const _NetflixLayout({required this.session, required this.onLogout});
  @override State<_NetflixLayout> createState() => _NetflixLayoutState();
}
class _NetflixLayoutState extends State<_NetflixLayout> {
  int _idx = 0;
  List _ch = [], _mv = [], _sr = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final d = await _loadXtream(widget.session);
    if (mounted) setState(() { _ch = d['channels']!; _mv = d['movies']!; _sr = d['series']!; _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    final screens = [
      _NfHome(ch: _ch, mv: _mv, sr: _sr, loading: _loading, onNav: (i) => setState(() => _idx = i), p: p),
      LiveTvScreen(session: widget.session), MoviesScreen(session: widget.session), SeriesScreen(session: widget.session),
    ];
    return Scaffold(backgroundColor: const Color(0xFF141414), body: Column(children: [
      SafeArea(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
        Text(AppConfig.appName, style: TextStyle(color: p, fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        ...[('Inicio', 0), ('Ao Vivo', 1), ('Filmes', 2), ('Series', 3)].map((t) => GestureDetector(
          onTap: () => setState(() => _idx = t.$2),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t.$1, style: TextStyle(color: _idx == t.$2 ? Colors.white : Colors.white38, fontSize: 13, fontWeight: _idx == t.$2 ? FontWeight.bold : FontWeight.normal))))),
        const SizedBox(width: 8),
        GestureDetector(onTap: widget.onLogout, child: const CircleAvatar(radius: 14, backgroundColor: Color(0xFF333333), child: Icon(Icons.person, color: Colors.white, size: 16))),
      ]))),
      Expanded(child: screens[_idx]),
    ]));
  }
}
class _NfHome extends StatelessWidget {
  final List ch, mv, sr; final bool loading; final Function(int) onNav; final Color p;
  const _NfHome({required this.ch, required this.mv, required this.sr, required this.loading, required this.onNav, required this.p});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 200, width: double.infinity, decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.withValues(alpha: 0.4), const Color(0xFF141414)])),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(AppConfig.appName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), const Text('Sua plataforma de entretenimento', style: TextStyle(color: Colors.white54, fontSize: 13)), const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton.icon(onPressed: () => onNav(1), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black)),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.movie, size: 18, color: Colors.white), label: const Text('Filmes', style: TextStyle(color: Colors.white)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54))),
          ]),
        ])),
      if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: Color(0xFFe94bff))))
      else ...[
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
          _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
          _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
        ])),
      ],
    ]));
  }
}

// ============================================================
// TEMA 3 — Sidebar + lista de canais
// ============================================================
class _SidebarLayout extends StatefulWidget {
  final AppSession session; final VoidCallback onLogout;
  const _SidebarLayout({required this.session, required this.onLogout});
  @override State<_SidebarLayout> createState() => _SidebarLayoutState();
}
class _SidebarLayoutState extends State<_SidebarLayout> {
  int _idx = 0;
  List _cats = [], _ch = [];
  int _selCat = 0;
  bool _loading = true;
  final _nav = [
    {'icon': Icons.home, 'label': 'Inicio'},
    {'icon': Icons.live_tv, 'label': 'Ao Vivo'},
    {'icon': Icons.movie, 'label': 'Filmes'},
    {'icon': Icons.video_library, 'label': 'Series'},
  ];
  @override void initState() { super.initState(); _loadCats(); }
  Future<void> _loadCats() async {
    if (!widget.session.hasXtreamAccess) { setState(() => _loading = false); return; }
    try {
      final svc = XtreamService(host: widget.session.effectiveXtreamHost!, username: widget.session.effectiveXtreamUsername!, password: widget.session.effectiveXtreamPassword!);
      final cats = await svc.getLiveCategories();
      if (cats.isNotEmpty) { final ch = await svc.getLiveStreams(cats[0].id, cats[0].name); setState(() { _cats = cats; _ch = ch; _loading = false; }); }
      else setState(() => _loading = false);
    } catch (_) { setState(() => _loading = false); }
  }
  Future<void> _loadCat(int i) async {
    if (!widget.session.hasXtreamAccess || i >= _cats.length) return;
    setState(() { _selCat = i; _loading = true; });
    try {
      final svc = XtreamService(host: widget.session.effectiveXtreamHost!, username: widget.session.effectiveXtreamUsername!, password: widget.session.effectiveXtreamPassword!);
      final ch = await svc.getLiveStreams(_cats[i].id, _cats[i].name);
      setState(() { _ch = ch; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    final sf = Color(AppConfig.surfaceColor);
    final screens = [
      _SmartersHome(cats: _cats, ch: _ch, loading: _loading, selCat: _selCat, onCat: _loadCat, p: p, sf: sf),
      LiveTvScreen(session: widget.session), MoviesScreen(session: widget.session), SeriesScreen(session: widget.session),
    ];
    return Scaffold(backgroundColor: Color(AppConfig.backgroundColor), body: SafeArea(child: Row(children: [
      Container(width: 72, color: sf, child: Column(children: [
        const SizedBox(height: 12), Icon(Icons.live_tv, color: p, size: 24), const SizedBox(height: 16),
        ...List.generate(_nav.length, (i) {
          final sel = _idx == i;
          return GestureDetector(onTap: () => setState(() => _idx = i), child: Container(margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6), padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: sel ? p.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: sel ? Border.all(color: p.withValues(alpha: 0.5)) : null),
            child: Column(children: [Icon(_nav[i]['icon'] as IconData, color: sel ? p : Colors.white38, size: 20), const SizedBox(height: 3), Text(_nav[i]['label'] as String, style: TextStyle(color: sel ? p : Colors.white38, fontSize: 8), textAlign: TextAlign.center)])));
        }),
        const Spacer(), IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 18), onPressed: widget.onLogout), const SizedBox(height: 4),
      ])),
      Expanded(child: Column(children: [
        Container(height: 44, color: sf, padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
          Text(_nav[_idx]['label'] as String, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), const Spacer(),
          if (widget.session.expiresAt != null) Text('Vence: ${_fmtDate(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ])),
        Expanded(child: screens[_idx]),
      ])),
    ])));
  }
}
class _SmartersHome extends StatelessWidget {
  final List cats, ch; final bool loading; final int selCat; final Function(int) onCat; final Color p, sf;
  const _SmartersHome({required this.cats, required this.ch, required this.loading, required this.selCat, required this.onCat, required this.p, required this.sf});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 160, color: sf.withValues(alpha: 0.5), child: Column(children: [
        Container(padding: const EdgeInsets.all(12), color: sf, width: double.infinity, child: Text('Categorias', style: TextStyle(color: p, fontSize: 13, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(itemCount: cats.length, itemBuilder: (_, i) {
          final sel = selCat == i;
          return GestureDetector(onTap: () => onCat(i), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: sel ? p.withValues(alpha: 0.15) : Colors.transparent, border: Border(left: BorderSide(color: sel ? p : Colors.transparent, width: 3))),
            child: Text(cats[i].name ?? '', style: TextStyle(color: sel ? p : Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)));
        })),
      ])),
      Expanded(child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: sf, width: double.infinity,
          child: Text(cats.isNotEmpty ? (cats[selCat].name ?? 'Canais') : 'Canais', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))),
        Expanded(child: loading ? Center(child: CircularProgressIndicator(color: p)) :
          ch.isEmpty ? const Center(child: Text('Nenhum canal', style: TextStyle(color: Colors.white38))) :
          ListView.builder(itemCount: ch.length, itemBuilder: (_, i) {
            final c = ch[i];
            return ListTile(
              leading: c.logoUrl != null && c.logoUrl!.isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(c.logoUrl!, width: 40, height: 40, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.live_tv, color: p, size: 28)))
                : Icon(Icons.live_tv, color: p, size: 28),
              title: Text(c.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text(c.categoryName ?? '', style: const TextStyle(color: Colors.white38, fontSize: 10)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(urls: [c.streamUrl], title: c.name ?? ''))),
            );
          })),
      ])),
    ]);
  }
}

// ============================================================
// TEMA 4 — IBO: Banner filme + grade + listas
// ============================================================
class _IBOLayout4 extends StatefulWidget {
  final AppSession session; final VoidCallback onLogout;
  const _IBOLayout4({required this.session, required this.onLogout});
  @override State<_IBOLayout4> createState() => _IBOLayout4State();
}
class _IBOLayout4State extends State<_IBOLayout4> {
  int _idx = 0; List _mv = [], _sr = [], _ch = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final d = await _loadXtream(widget.session); if (mounted) setState(() { _ch = d['channels']!; _mv = d['movies']!; _sr = d['series']!; _loading = false; }); }
  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    final sf = Color(AppConfig.surfaceColor);
    final screens = [
      _IBO4Home(mv: _mv, sr: _sr, ch: _ch, loading: _loading, onNav: (i) => setState(() => _idx = i), p: p),
      LiveTvScreen(session: widget.session), MoviesScreen(session: widget.session), SeriesScreen(session: widget.session),
    ];
    return Scaffold(backgroundColor: const Color(0xFF0a0a0a), body: SafeArea(child: Column(children: [
      Container(height: 52, color: sf, padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Icon(Icons.live_tv, color: p, size: 22), const SizedBox(width: 8), Text(AppConfig.appName, style: TextStyle(color: p, fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(),
        ...[('Inicio', 0), ('Ao Vivo', 1), ('Filmes', 2), ('Series', 3)].map((t) => GestureDetector(onTap: () => setState(() => _idx = t.$2),
          child: Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _idx == t.$2 ? p.withValues(alpha: 0.2) : Colors.transparent, borderRadius: BorderRadius.circular(20), border: Border.all(color: _idx == t.$2 ? p : Colors.transparent)),
            child: Text(t.$1, style: TextStyle(color: _idx == t.$2 ? p : Colors.white54, fontSize: 12))))),
        const SizedBox(width: 8), GestureDetector(onTap: widget.onLogout, child: const Icon(Icons.logout, color: Colors.white38, size: 20)),
      ])),
      Expanded(child: screens[_idx]),
    ])));
  }
}
class _IBO4Home extends StatelessWidget {
  final List mv, sr, ch; final bool loading; final Function(int) onNav; final Color p;
  const _IBO4Home({required this.mv, required this.sr, required this.ch, required this.loading, required this.onNav, required this.p});
  @override
  Widget build(BuildContext context) {
    final feat = mv.isNotEmpty ? mv.first : null;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [
        // Fundo escuro
        SizedBox(height: 260, width: double.infinity, child: Container(color: const Color(0xFF050508))),
        // Poster centralizado
        SizedBox(height: 260, width: double.infinity,
          child: feat?.posterUrl != null
            ? Image.network(feat!.posterUrl!, height: 260, width: double.infinity, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox())
            : const SizedBox()),
        // Gradiente lateral
        SizedBox(height: 260, width: double.infinity, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [0.0, 0.2, 0.7, 1.0],
          colors: [Color(0xFF050508), Color(0x99050508), Colors.transparent, Color(0xFF050508)])))),
        // Gradiente inferior
        SizedBox(height: 260, width: double.infinity, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          stops: [0.0, 0.5, 1.0],
          colors: [Color(0xFF0a0a0a), Color(0x88050508), Colors.transparent])))),
        // Info sobreposta
        Positioned(bottom: 16, left: 20, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: p.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
            child: Text('EM DESTAQUE', style: TextStyle(color: p, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
          const SizedBox(height: 6),
          if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 12), Shadow(color: Colors.black, blurRadius: 24)]), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
              style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10))),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => onNav(2), style: OutlinedButton.styleFrom(side: BorderSide(color: p.withValues(alpha: 0.7)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: Text('+ Info', style: TextStyle(color: p))),
          ]),
        ])),
      ]),
      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1,
          children: [
            {'icon': Icons.live_tv, 'label': 'Ao Vivo', 'color': p, 'idx': 1},
            {'icon': Icons.movie, 'label': 'Filmes', 'color': const Color(0xFF4b7bff), 'idx': 2},
            {'icon': Icons.video_library, 'label': 'Series', 'color': const Color(0xFF00c896), 'idx': 3},
            {'icon': Icons.favorite, 'label': 'Favoritos', 'color': const Color(0xFFff6b6b), 'idx': 0},
          ].map((c) => GestureDetector(onTap: () => onNav(c['idx'] as int), child: Container(
            decoration: BoxDecoration(color: (c['color'] as Color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: (c['color'] as Color).withValues(alpha: 0.4))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(c['icon'] as IconData, color: c['color'] as Color, size: 28), const SizedBox(height: 4), Text(c['label'] as String, style: TextStyle(color: c['color'] as Color, fontSize: 10))]))))
          .toList()),
        const SizedBox(height: 16),
        if (!loading) ...[_hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true), _hList('Filmes em Destaque', mv, const Color(0xFF4b7bff), () => onNav(2)), _hList('Series Populares', sr, const Color(0xFF00c896), () => onNav(3))],
      ])),
    ]));
  }
}

// ============================================================
// TEMA 5 — IBO: Sidebar escura + destaque grande
// ============================================================
class _IBOLayout5 extends StatefulWidget {
  final AppSession session; final VoidCallback onLogout;
  const _IBOLayout5({required this.session, required this.onLogout});
  @override State<_IBOLayout5> createState() => _IBOLayout5State();
}
class _IBOLayout5State extends State<_IBOLayout5> {
  int _idx = 0; List _mv = [], _sr = [], _ch = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final d = await _loadXtream(widget.session); if (mounted) setState(() { _ch = d['channels']!; _mv = d['movies']!; _sr = d['series']!; _loading = false; }); }
  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    final sf = Color(AppConfig.surfaceColor);
    final nav = [{'icon': Icons.home, 'label': 'Home'}, {'icon': Icons.live_tv, 'label': 'Live TV'}, {'icon': Icons.movie, 'label': 'Filmes'}, {'icon': Icons.video_library, 'label': 'Series'}];
    final screens = [
      _IBO5Home(mv: _mv, sr: _sr, ch: _ch, loading: _loading, onNav: (i) => setState(() => _idx = i), p: p, session: widget.session),
      LiveTvScreen(session: widget.session), MoviesScreen(session: widget.session), SeriesScreen(session: widget.session),
    ];
    return Scaffold(backgroundColor: const Color(0xFF0f0f1a), body: SafeArea(child: Row(children: [
      Container(width: 80, decoration: BoxDecoration(color: sf, border: Border(right: BorderSide(color: p.withValues(alpha: 0.2)))), child: Column(children: [
        const SizedBox(height: 16), Icon(Icons.live_tv, color: p, size: 28), const SizedBox(height: 20),
        ...List.generate(nav.length, (i) { final sel = _idx == i; return GestureDetector(onTap: () => setState(() => _idx = i), child: Container(margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: sel ? p.withValues(alpha: 0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? p.withValues(alpha: 0.5) : Colors.transparent)),
          child: Column(children: [Icon(nav[i]['icon'] as IconData, color: sel ? p : Colors.white24, size: 22), const SizedBox(height: 4), Text(nav[i]['label'] as String, style: TextStyle(color: sel ? p : Colors.white24, fontSize: 8), textAlign: TextAlign.center)]))); }),
        const Spacer(),
        if (widget.session.expiresAt != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: Text(_fmtDate(widget.session.expiresAt!), style: const TextStyle(color: Colors.white24, fontSize: 7), textAlign: TextAlign.center)),
        IconButton(icon: const Icon(Icons.logout, color: Colors.white24, size: 18), onPressed: widget.onLogout), const SizedBox(height: 8),
      ])),
      Expanded(child: screens[_idx]),
    ])));
  }
}
class _IBO5Home extends StatelessWidget {
  final List mv, sr, ch; final bool loading; final Function(int) onNav; final Color p; final AppSession session;
  const _IBO5Home({required this.mv, required this.sr, required this.ch, required this.loading, required this.onNav, required this.p, required this.session});
  @override
  Widget build(BuildContext context) {
    if (loading) return Center(child: CircularProgressIndicator(color: p));
    final feat = mv.isNotEmpty ? mv[0] : null;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(onTap: () => onNav(2), child: Container(height: 220, width: double.infinity, color: const Color(0xFF0f0f1a),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Poster lateral esquerdo
        if (feat?.posterUrl != null)
          Image.network(feat!.posterUrl!, width: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 150)),
        // Gradiente + info
        Expanded(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xFF0f0f1a), Color(0xFF0a0a14)])),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text('EM DESTAQUE', style: TextStyle(color: p, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
            const SizedBox(height: 10),
            if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Row(children: [
              ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => onNav(3), style: OutlinedButton.styleFrom(side: BorderSide(color: p.withValues(alpha: 0.7)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                child: Text('Series', style: TextStyle(color: p, fontSize: 12))),
            ]),
          ])),
        ),
      ]))),
      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
        _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
        _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
      ])),
    ]));
  }
}

// ============================================================
// TEMA 6 — IBO: SliverAppBar + bottom nav
// ============================================================
class _IBOLayout6 extends StatefulWidget {
  final AppSession session; final VoidCallback onLogout;
  const _IBOLayout6({required this.session, required this.onLogout});
  @override State<_IBOLayout6> createState() => _IBOLayout6State();
}
class _IBOLayout6State extends State<_IBOLayout6> {
  int _idx = 0; List _mv = [], _sr = [], _ch = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final d = await _loadXtream(widget.session); if (mounted) setState(() { _ch = d['channels']!; _mv = d['movies']!; _sr = d['series']!; _loading = false; }); }
  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    final screens = [
      _IBO6Home(mv: _mv, sr: _sr, ch: _ch, loading: _loading, onNav: (i) => setState(() => _idx = i), p: p, onLogout: widget.onLogout, session: widget.session),
      LiveTvScreen(session: widget.session), MoviesScreen(session: widget.session), SeriesScreen(session: widget.session),
    ];
    final navItems = [{'icon': Icons.home, 'label': 'Home', 'idx': 0}, {'icon': Icons.live_tv, 'label': 'Ao Vivo', 'idx': 1}, {'icon': Icons.movie, 'label': 'Filmes', 'idx': 2}, {'icon': Icons.video_library, 'label': 'Series', 'idx': 3}];
    return Scaffold(backgroundColor: const Color(0xFF0d0d0d), body: screens[_idx],
      bottomNavigationBar: Container(decoration: BoxDecoration(color: const Color(0xFF1a1a1a), border: Border(top: BorderSide(color: p.withValues(alpha: 0.3)))),
        child: SafeArea(child: SizedBox(height: 56, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: navItems.map((item) {
          final sel = _idx == item['idx'];
          return GestureDetector(onTap: () => setState(() => _idx = item['idx'] as int), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(item['icon'] as IconData, color: sel ? p : Colors.white38, size: 22),
            Text(item['label'] as String, style: TextStyle(color: sel ? p : Colors.white38, fontSize: 10)),
          ]));
        }).toList())))));
  }
}
class _IBO6Home extends StatelessWidget {
  final List mv, sr, ch; final bool loading; final Function(int) onNav; final Color p; final VoidCallback onLogout; final AppSession session;
  const _IBO6Home({required this.mv, required this.sr, required this.ch, required this.loading, required this.onNav, required this.p, required this.onLogout, required this.session});
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverAppBar(expandedHeight: 280, floating: false, pinned: false, backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: Stack(children: [
            mv.isNotEmpty && mv[0].posterUrl != null
              ? Image.network(mv[0].posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 280, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)))
              : Container(color: const Color(0xFF1a1a2e)),
            Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF0d0d0d)])))),
            Positioned(top: 8, right: 8, child: SafeArea(child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (session.expiresAt != null) Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 4),
              GestureDetector(onTap: onLogout, child: const Icon(Icons.logout, color: Colors.white54, size: 20)),
              const SizedBox(width: 8),
            ]))),
            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]), maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
                  style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 38))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), minimumSize: const Size(80, 38)),
                  child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),
          ]),
        )),
      SliverToBoxAdapter(child: loading
        ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        : Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
            _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
            _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
          ]))),
    ]);
  }
}

// ============================================================
// Home Tab compartilhada (Tema 1)
// ============================================================
class _HomeTab extends StatelessWidget {
  final AppSession session;
  final Function(int) onNavigate;
  const _HomeTab({required this.session, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final p = Color(AppConfig.primaryColor);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('O que quer assistir?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
        const SizedBox(height: 20),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
          children: [
            _card(icon: Icons.live_tv, label: 'TV ao Vivo', color: p, onTap: () => onNavigate(1)),
            _card(icon: Icons.movie, label: 'Filmes', color: const Color(0xFF4b7bff), onTap: () => onNavigate(2)),
            _card(icon: Icons.video_library, label: 'Series', color: const Color(0xFF00c896), onTap: () => onNavigate(3)),
            _card(icon: Icons.favorite, label: 'Favoritos', color: const Color(0xFFff6b6b), onTap: () {}),
          ]),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Color(AppConfig.surfaceColor), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2a2538))),
          child: Row(children: [
            Icon(Icons.info_outline, color: p, size: 20), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.isXtream ? 'Conectado via Xtream Codes' : 'Conectado via ${AppConfig.appName}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              if (session.isXtream) Text(session.xtreamHost ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ])),
          ])),
      ]),
    );
  }

  Widget _card({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 36), const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
      ])));
  }
}
