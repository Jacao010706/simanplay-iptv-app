with open(r"C:\Users\Jacques\iptv-player-app\lib\services\xtream_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """  /// Filmes de uma categoria específica
  Future<List<Movie>> getMovies(
    String categoryId,
    String categoryName,
  ) async {
    final url = '$_baseApiUrl&action=get_vod_streams&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Movie.fromXtream(
              json: e,
              host: host,
              username: username,
              password: password,
              categoryName: categoryName,
            ))
        .toList();
  }"""

NEW = """  /// Todos os filmes de uma vez (sem filtro de categoria)
  Future<List<Movie>> getAllMovies() async {
    final url = '$_baseApiUrl&action=get_vod_streams';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Movie.fromXtream(
              json: e,
              host: host,
              username: username,
              password: password,
              categoryName: '',
            ))
        .toList();
  }

  /// Filmes de uma categoria específica
  Future<List<Movie>> getMovies(
    String categoryId,
    String categoryName,
  ) async {
    final url = '$_baseApiUrl&action=get_vod_streams&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Movie.fromXtream(
              json: e,
              host: host,
              username: username,
              password: password,
              categoryName: categoryName,
            ))
        .toList();
  }"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO movies: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

OLD2 = """  /// Séries de uma categoria específica
  Future<List<Series>> getSeries(
    String categoryId,
    String categoryName,
  ) async {
    final url = '$_baseApiUrl&action=get_series&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Series.fromXtream(json: e, categoryName: categoryName))
        .toList();
  }"""

NEW2 = """  /// Todas as séries de uma vez (sem filtro de categoria)
  Future<List<Series>> getAllSeries() async {
    final url = '$_baseApiUrl&action=get_series';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Series.fromXtream(json: e, categoryName: ''))
        .toList();
  }

  /// Séries de uma categoria específica
  Future<List<Series>> getSeries(
    String categoryId,
    String categoryName,
  ) async {
    final url = '$_baseApiUrl&action=get_series&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Series.fromXtream(json: e, categoryName: categoryName))
        .toList();
  }"""

count2 = content.count(OLD2)
if count2 != 1:
    print(f"ERRO series: encontrado {count2} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD2, NEW2)

with open(r"C:\Users\Jacques\iptv-player-app\lib\services\xtream_service.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! xtream_service.dart atualizado com getAllMovies e getAllSeries.")