import 'package:flutter/material.dart';
import '../models/app_session.dart';
import '../models/movie.dart';
import '../models/category.dart';
import '../services/xtream_service.dart';
import 'player_screen.dart';

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
      setState(() {
        _error = 'Filmes não disponíveis para esta playlist.';
        _loading = false;
      });
      return;
    }
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
      final results = await Future.wait([
        service.getMovieCategories(),
        service.getAllMovies(),
      ]);
      final cats = results[0] as List<Category>;
      final allMovies = results[1] as List<Movie>;
      setState(() {
        _categories = cats;
        _allMovies = allMovies;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<Movie> get _filteredMovies {
    return _allMovies.where((m) {
      final matchCat = _selectedCategoryId == 'all' ||
          m.categoryId == _selectedCategoryId;
      final matchSearch = _search.isEmpty ||
          m.name.toLowerCase().contains(_search.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFe94bff)),
            SizedBox(height: 16),
            Text('Carregando filmes...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_outlined,
                  color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Buscar filme...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF1a1625),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
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
              final catName =
                  isAll ? 'Todos' : _categories[i - 1].name;
              final isSelected = catId == _selectedCategoryId;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedCategoryId = catId),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFe94bff)
                        : const Color(0xFF1a1625),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFe94bff)
                          : const Color(0xFF2a2538),
                    ),
                  ),
                  child: Text(
                    catName,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white54,
                      fontSize: 12,
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
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _filteredMovies.length,
            itemBuilder: (_, i) {
              final movie = _filteredMovies[i];
              return _buildMovieCard(movie);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              urls: [movie.streamUrl],
              title: movie.name,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a1625),
                borderRadius: BorderRadius.circular(8),
              ),
              child: movie.posterUrl != null &&
                      movie.posterUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        movie.posterUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.movie,
                              color: Colors.white38, size: 32),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.movie,
                          color: Colors.white38, size: 32),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            movie.name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
