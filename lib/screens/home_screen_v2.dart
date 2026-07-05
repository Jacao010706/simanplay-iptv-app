import 'dart:convert';
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
        content: const Text('Deseja desconectar a lista?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sair', style: TextStyle(color: Color(AppConfig.primaryColor))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
    );
  }

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
        title: Row(
          children: [
            Icon(Icons.live_tv, color: primary, size: 22),
            const SizedBox(width: 8),
            Text(AppConfig.appName,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (widget.session.expiresAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'Vence: ${_formatDate(widget.session.expiresAt!)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: _logout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Color(AppConfig.surfaceColor),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        indicatorColor: primary.withValues(alpha: 0.2),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.home, color: primary),
            label: 'Início',
          ),
          NavigationDestination(
            icon: const Icon(Icons.live_tv_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.live_tv, color: primary),
            label: 'Ao Vivo',
          ),
          NavigationDestination(
            icon: const Icon(Icons.movie_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.movie, color: primary),
            label: 'Filmes',
          ),
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.video_library, color: primary),
            label: 'Séries',
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

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
          const Text('O que quer assistir?',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
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
                      Text(
                        session.isXtream ? 'Conectado via Xtream Codes' : 'Conectado via ${AppConfig.appName}',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      if (session.isXtream)
                        Text(session.xtreamHost ?? '',
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
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

  Widget _buildCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
