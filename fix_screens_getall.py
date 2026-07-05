# Atualiza movies_screen.dart
with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\movies_screen.dart", "r", encoding="utf-8") as f:
    movies = f.read()

OLD_MOVIES = """      final cats = await service.getMovieCategories();
      final List<Movie> allMovies = [];
      for (final cat in cats) {
        final movies = await service.getMovies(cat.id, cat.name);
        allMovies.addAll(movies);
      }
      setState(() {
        _categories = cats;
        _allMovies = allMovies;
        _loading = false;
      });"""

NEW_MOVIES = """      final results = await Future.wait([
        service.getMovieCategories(),
        service.getAllMovies(),
      ]);
      final cats = results[0] as List<Category>;
      final allMovies = results[1] as List<Movie>;
      setState(() {
        _categories = cats;
        _allMovies = allMovies;
        _loading = false;
      });"""

count = movies.count(OLD_MOVIES)
if count != 1:
    print(f"ERRO movies: encontrado {count} vez(es). Abortando.")
    exit(1)

movies = movies.replace(OLD_MOVIES, NEW_MOVIES)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\movies_screen.dart", "w", encoding="utf-8") as f:
    f.write(movies)

print("OK! movies_screen.dart atualizado.")

# Atualiza series_screen.dart
with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\series_screen.dart", "r", encoding="utf-8") as f:
    series = f.read()

OLD_SERIES = """      final cats = await service.getSeriesCategories();
      final List<Series> allSeries = [];
      for (final cat in cats) {
        final series = await service.getSeries(cat.id, cat.name);
        allSeries.addAll(series);
      }
      setState(() {
        _categories = cats;
        _allSeries = allSeries;
        _loading = false;
      });"""

NEW_SERIES = """      final results = await Future.wait([
        service.getSeriesCategories(),
        service.getAllSeries(),
      ]);
      final cats = results[0] as List<Category>;
      final allSeries = results[1] as List<Series>;
      setState(() {
        _categories = cats;
        _allSeries = allSeries;
        _loading = false;
      });"""

count2 = series.count(OLD_SERIES)
if count2 != 1:
    print(f"ERRO series: encontrado {count2} vez(es). Abortando.")
    exit(1)

series = series.replace(OLD_SERIES, NEW_SERIES)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\series_screen.dart", "w", encoding="utf-8") as f:
    f.write(series)

print("OK! series_screen.dart atualizado.")
print("Pronto! Filmes e Series carregam tudo de uma vez em paralelo.")