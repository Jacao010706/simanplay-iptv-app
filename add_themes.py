# Passo 1: Adiciona campo theme no AppConfig
with open(r"C:\Users\Jacques\iptv-player-app\lib\core\app_config.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = "  static const bool usePlayIcon = false; // false = TV, true = Play Circle\n}"
NEW = """  static const bool usePlayIcon = false; // false = TV, true = Play Circle
  // ============================================================
  // TEMA DO APP
  // ============================================================
  // 1 = Grade de icones (padrao)
  // 2 = Netflix style (banner + linhas)
  // 3 = Sidebar lateral (estilo Smarters)
  static const int appTheme = 1;
}"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\core\app_config.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! appTheme adicionado no AppConfig.")

# Passo 2: Cria home_screen_v2.dart com suporte a 3 temas
home_content = r"""import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../models/app_session.dart';
import 'activation_screen_v3.dart';
import 'live_tv_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSession session;
  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(AppConfig.surfaceColor),
        title: const Text('Sair', style: TextStyle(color: Colors.white)),
        content: const Text('Deseja desconectar a lista?', style: TextStyle(color: Colors.white70)),
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
    if (AppConfig.appTheme == 3) {
      return _SidebarLayout(session: widget.session, onLogout: _logout);
    }
    if (AppConfig.appTheme == 2) {
      return _NetflixLayout(session: widget.session, onLogout: _logout);
    }
    return _GridLayout(session: widget.session, onLogout: _logout);
  }
}

// ============================================================
// TEMA 1 — Grade de icones (padrao)
// ============================================================
class _GridLayout extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _GridLayout({required this.session, required this.onLogout});

  @override
  State<_GridLayout> createState() => _GridLayoutState();
}

class _GridLayoutState extends State<_GridLayout> {
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

    return Scaffold(
      backgroundColor: Color(AppConfig.backgroundColor),
      appBar: AppBar(
        backgroundColor: Color(AppConfig.surfaceColor),
        elevation: 0,
        title: Row(children: [
          Icon(Icons.live_tv, color: primary, size: 22),
          const SizedBox(width: 8),
          Text(AppConfig.appName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          if (widget.session.expiresAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('Vence: ${_fmt(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 11))),
            ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white54), onPressed: widget.onLogout),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Color(AppConfig.surfaceColor),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        indicatorColor: primary.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined, color: Colors.white54), selectedIcon: Icon(Icons.home, color: primary), label: 'Início'),
          NavigationDestination(icon: const Icon(Icons.live_tv_outlined, color: Colors.white54), selectedIcon: Icon(Icons.live_tv, color: primary), label: 'Ao Vivo'),
          NavigationDestination(icon: const Icon(Icons.movie_outlined, color: Colors.white54), selectedIcon: Icon(Icons.movie, color: primary), label: 'Filmes'),
          NavigationDestination(icon: const Icon(Icons.video_library_outlined, color: Colors.white54), selectedIcon: Icon(Icons.video_library, color: primary), label: 'Séries'),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
}

// ============================================================
// TEMA 2 — Netflix style
// ============================================================
class _NetflixLayout extends StatefulWidget {
  final AppSession session;
  final VoidCallback onLogout;
  const _NetflixLayout({required this.session, required this.onLogout});

  @override
  State<_NetflixLayout> createState() => _NetflixLayoutState();
}

class _NetflixLayoutState extends State<_NetflixLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final screens = [
      _NetflixHomeTab(session: widget.session, onNavigate: (i) => setState(() => _selectedIndex = i)),
      LiveTvScreen(session: widget.session),
      MoviesScreen(session: widget.session),
      SeriesScreen(session: widget.session),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Column(
        children: [
          // Topbar Netflix style
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(AppConfig.appName, style: TextStyle(color: primary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const Spacer(),
                  if (widget.session.expiresAt != null)
                    Text('Vence: ${_fmt(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: widget.onLogout, child: const CircleAvatar(radius: 14, backgroundColor: Color(0xFF333333), child: Icon(Icons.person, color: Colors.white, size: 16))),
                ],
              ),
            ),
          ),
          // Tab bar Netflix style
          Container(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NetflixTab(label: 'Início', selected: _selectedIndex == 0, onTap: () => setState(() => _selectedIndex = 0), primary: primary),
                _NetflixTab(label: 'Ao Vivo', selected: _selectedIndex == 1, onTap: () => setState(() => _selectedIndex = 1), primary: primary),
                _NetflixTab(label: 'Filmes', selected: _selectedIndex == 2, onTap: () => setState(() => _selectedIndex = 2), primary: primary),
                _NetflixTab(label: 'Séries', selected: _selectedIndex == 3, onTap: () => setState(() => _selectedIndex = 3), primary: primary),
              ],
            ),
          ),
          Expanded(child: screens[_selectedIndex]),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
}

class _NetflixTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;

  const _NetflixTab({required this.label, required this.selected, required this.onTap, required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(height: 4),
          if (selected) Container(width: 20, height: 2, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(1))),
        ],
      ),
    );
  }
}

class _NetflixHomeTab extends StatelessWidget {
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
}

// ============================================================
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
                          Text('Vence: ${_fmt(widget.session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
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

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
}

// ============================================================
// Home Tab compartilhada (Tema 1 e 3)
// ============================================================
class _HomeTab extends StatelessWidget {
  final AppSession session;
  final Function(int) onNavigate;

  const _HomeTab({required this.session, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('O que quer assistir?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildCard(icon: Icons.live_tv, label: 'TV ao Vivo', color: primary, onTap: () => onNavigate(1)),
              _buildCard(icon: Icons.movie, label: 'Filmes', color: const Color(0xFF4b7bff), onTap: () => onNavigate(2)),
              _buildCard(icon: Icons.video_library, label: 'Séries', color: const Color(0xFF00c896), onTap: () => onNavigate(3)),
              _buildCard(icon: Icons.favorite, label: 'Favoritos', color: const Color(0xFFff6b6b), onTap: () {}),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(AppConfig.surfaceColor),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2a2538)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.isXtream ? 'Conectado via Xtream Codes' : 'Conectado via ${AppConfig.appName}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                      if (session.isXtream) Text(session.xtreamHost ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
"""

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(home_content)

print("OK! home_screen_v2.dart reescrito com 3 temas.")
print("Para trocar o tema, edite AppConfig.appTheme (1, 2 ou 3).")