import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/app_session.dart';
import '../models/movie.dart';
import '../models/category.dart';
import '../core/marca.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';
import '../widgets/grade_capas.dart';
import '../widgets/janela_detalhes.dart';
import '../widgets/tv_focus.dart';
import '../widgets/tv_search_field.dart';
import '../core/erros.dart';

class MoviesScreen extends StatefulWidget {
  final AppSession session;
  const MoviesScreen({super.key, required this.session});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  List<Movie> _allMovies = [];
  List<Category> _categories = [];
  String _selectedCategoryId = 'all';
  bool _loading = true;
  String? _error;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    if (!widget.session.hasXtreamAccess) {
      setState(() { _error = 'Filmes não disponíveis para esta playlist.'; _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final results = await Future.wait([service.getMoviePastas(), service.getAllMovies()]);
      setState(() {
        _categories = results[0] as List<Category>;
        _allMovies = results[1] as List<Movie>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = mensagemDeErro(e); _loading = false; });
    }
  }

  List<Movie> get _filteredMovies {
    return _allMovies.where((m) {
      final matchCat = _selectedCategoryId == 'all' || m.categoryId == _selectedCategoryId;
      final matchSearch = _search.isEmpty || m.name.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  void _showMovieDetail(Movie movie) {
    // Janela no meio da tela (cabe inteira na TV; ver _MovieDetailSheet.build)
    showDialog(
      context: context,
      builder: (_) => _MovieDetailSheet(
        movie: movie,
        session: widget.session,
        primary: Color(Marca.primaryColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(Marca.primaryColor);
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: primary),
        const SizedBox(height: 16),
        const Text('Carregando filmes...', style: TextStyle(color: Colors.white54)),
      ]));
    }
    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.movie_outlined, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        ]),
      ));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TvSearchField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white),
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Buscar filme...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.search, color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF1a1625),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length + 1,
          itemBuilder: (_, i) {
            final isAll = i == 0;
            final catId = isAll ? 'all' : _categories[i - 1].id;
            final catName = isAll ? 'Todos' : _categories[i - 1].name;
            final isSelected = catId == _selectedCategoryId;
            return TvTap(
              onTap: () => setState(() => _selectedCategoryId = catId),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? primary : const Color(0xFF1a1625),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? primary : const Color(0xFF2a2538)),
                ),
                child: Text(catName, style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: GradeCapas(
          proporcao: 0.65,
          itemCount: _filteredMovies.length,
          itemBuilder: (_, i) => _buildMovieCard(_filteredMovies[i], primary),
        ),
      ),
    ]);
  }

  Widget _buildMovieCard(Movie movie, Color primary) {
    return TvTap(
      onTap: () => _showMovieDetail(movie),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF1a1625), borderRadius: BorderRadius.circular(8)),
            child: movie.posterUrl != null && movie.posterUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(movie.posterUrl!, fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.movie, color: Colors.white38, size: 32))))
                : const Center(child: Icon(Icons.movie, color: Colors.white38, size: 32)),
          ),
        ),
        const SizedBox(height: 4),
        Text(movie.name, style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

class _MovieDetailSheet extends StatefulWidget {
  final Movie movie;
  final AppSession session;
  final Color primary;

  const _MovieDetailSheet({required this.movie, required this.session, required this.primary});

  @override
  State<_MovieDetailSheet> createState() => _MovieDetailSheetState();
}

class _MovieDetailSheetState extends State<_MovieDetailSheet> {
  Map<String, dynamic>? _info;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );
      final data = await service.getVodInfo(widget.movie.id);
      setState(() { _info = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _decode(String? val) {
    if (val == null || val.isEmpty) return '';
    try { return utf8.decode(base64.decode(val)); } catch (_) { return val; }
  }

  void _play() {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(urls: [widget.movie.streamUrl], title: widget.movie.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final movieInfo = _info?['info'] != null ? Map<String, dynamic>.from(_info!['info'] as Map) : <String, dynamic>{};
    final plot = _decode(movieInfo['plot']?.toString()).isNotEmpty
        ? _decode(movieInfo['plot'].toString())
        : (movieInfo['description']?.toString() ?? '');
    final rating = movieInfo['rating']?.toString() ?? movieInfo['tmdb_rating']?.toString() ?? '';
    final year = movieInfo['releaseDate']?.toString() ?? movieInfo['year']?.toString() ?? '';
    final genre = movieInfo['genre']?.toString() ?? '';
    final duration = movieInfo['duration']?.toString() ?? '';
    final director = movieInfo['director']?.toString() ?? '';
    final cast = movieInfo['cast']?.toString() ?? '';
    final backdropUrl = (movieInfo['backdrop_path'] as List?)?.isNotEmpty == true
        ? movieInfo['backdrop_path'][0]?.toString()
        : null;

    // Cabe na tela (TV 1920x1080 e 1280x720, texto ampliado): margem de 5% de cada lado,
    // capa e fundo proporcionais à altura, textos com rolagem e "Assistir" sempre visível
    // embaixo, fora da rolagem.
    final altura = JanelaDetalhes.alturaUtil(MediaQuery.sizeOf(context));
    final capaH = (altura * 0.3).clamp(72.0, 130.0);
    final capaW = capaH * 90 / 130;
    final fundoH = (altura * 0.3).clamp(0.0, 180.0);
    Widget capaVazia() => Container(width: capaW, height: capaH, color: const Color(0xFF0d0b14),
        child: const Icon(Icons.movie, color: Colors.white38, size: 36));

    return JanelaDetalhes(
      key: const Key('detalhe_filme'),
      conteudo: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Backdrop or poster
        if (backdropUrl != null && backdropUrl.isNotEmpty && fundoH >= 80)
          Stack(children: [
            Image.network(backdropUrl, height: fundoH, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox()),
            Container(height: fundoH,
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF1a1625)]))),
          ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Poster + info side by side
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.movie.posterUrl != null && widget.movie.posterUrl!.isNotEmpty
                    ? Image.network(widget.movie.posterUrl!, width: capaW, height: capaH, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => capaVazia())
                    : capaVazia(),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.movie.name,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (year.isNotEmpty) _badge(year),
                  if (duration.isNotEmpty) _badge(duration),
                  if (rating.isNotEmpty) _badgeIcon(Icons.star, Colors.amber, rating),
                ]),
                if (genre.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(genre, style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ])),
            ]),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
              ),

            if (plot.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('SINOPSE', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(plot, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
            ],

            if (director.isNotEmpty) ...[
              const SizedBox(height: 12),
              _infoRow('Diretor', director),
            ],
            if (cast.isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoRow('Elenco', cast),
            ],
          ]),
        ),
      ]),
      rodape: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: ElevatedButton.icon(
          key: const Key('detalhe_filme_assistir'),
          autofocus: true, // controle remoto ja cai no "Assistir"
          onPressed: _play,
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text('Assistir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF0d0b14), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    );
  }

  Widget _badgeIcon(IconData icon, Color color, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        TextSpan(text: value, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
