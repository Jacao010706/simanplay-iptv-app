import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../models/app_session.dart';
import '../widgets/tv_focus.dart';
import 'live_tv_screen.dart';
import 'movies_screen.dart';
import 'series_screen.dart';

/// Tela inicial do Sofae na TV: 4 blocos grandes (TV ao Vivo, Filmes, Séries, Favoritos) e
/// "Trocar lista / Sair", tudo pelo controle. Mesmo desenho do /tv da LG e da Samsung.
class HomeTvScreen extends StatelessWidget {
  final AppSession session;
  final Future<void> Function() onLogout;
  const HomeTvScreen({super.key, required this.session, required this.onLogout});

  static const chaveSair = ValueKey('home-tv-sair');

  void _abrir(BuildContext context, String titulo, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TelaConteudoTv(titulo: titulo, child: tela)));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final bg = Color(AppConfig.backgroundColor);
    final blocos = <(String, IconData, VoidCallback)>[
      ('TV ao Vivo', Icons.live_tv, () => _abrir(context, 'TV ao Vivo', LiveTvScreen(session: session))),
      ('Filmes', Icons.movie_outlined, () => _abrir(context, 'Filmes', MoviesScreen(session: session))),
      ('Séries', Icons.video_library_outlined, () => _abrir(context, 'Séries', SeriesScreen(session: session))),
      ('Favoritos', Icons.star_border, () => _abrir(context, 'Favoritos', LiveTvScreen(session: session, categoriaInicial: '__favs__'))),
    ];
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _logo(primary),
            const SizedBox(height: 32),
            FocusTraversalGroup(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < blocos.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: _Bloco(
                      key: ValueKey('home-tv-${blocos[i].$1}'),
                      titulo: blocos[i].$1,
                      icone: blocos[i].$2,
                      onTap: blocos[i].$3,
                      autofocus: i == 0,
                      primary: primary,
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              key: chaveSair,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              onPressed: onLogout,
              child: const Text('Trocar lista / Sair', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 14),
            const Text('Use as setas e aperte OK', style: TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _logo(Color primary) {
    if (AppConfig.useCustomLogo && AppConfig.logoUrl.isNotEmpty) {
      return Image.network(AppConfig.logoUrl, height: 64,
          errorBuilder: (_, __, ___) => _nome(primary));
    }
    return _nome(primary);
  }

  Widget _nome(Color primary) =>
      Text(AppConfig.appName, style: TextStyle(color: primary, fontSize: 36, fontWeight: FontWeight.bold));
}

/// Bloco grande da tela inicial: destaque (borda na cor da marca e leve aumento) quando tem o
/// foco do controle; OK abre.
class _Bloco extends StatefulWidget {
  final String titulo;
  final IconData icone;
  final VoidCallback onTap;
  final bool autofocus;
  final Color primary;
  const _Bloco({super.key, required this.titulo, required this.icone, required this.onTap,
      required this.autofocus, required this.primary});

  @override
  State<_Bloco> createState() => _BlocoState();
}

class _BlocoState extends State<_Bloco> {
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.primary;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (f) => setState(() => _foco = f),
      child: TvTap(
        autofocus: widget.autofocus,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _foco ? 1.06 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 170,
            height: 150,
            decoration: BoxDecoration(
              color: _foco ? p.withValues(alpha: 0.18) : Color(AppConfig.surfaceColor),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _foco ? p : Colors.transparent, width: 3),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icone, color: p, size: 48),
              const SizedBox(height: 12),
              Text(widget.titulo,
                  style: TextStyle(color: _foco ? Colors.white : Colors.white70, fontSize: 18, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// TV ao vivo, Filmes, Séries e Favoritos abertos pela tela inicial da TV: título no topo e
/// Voltar retorna à tela inicial.
class TelaConteudoTv extends StatelessWidget {
  final String titulo;
  final Widget child;
  const TelaConteudoTv({super.key, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(AppConfig.backgroundColor),
      appBar: AppBar(
        backgroundColor: Color(AppConfig.surfaceColor),
        foregroundColor: Colors.white,
        title: Text(titulo, style: TextStyle(color: Color(AppConfig.primaryColor), fontWeight: FontWeight.bold)),
      ),
      body: child,
    );
  }
}
