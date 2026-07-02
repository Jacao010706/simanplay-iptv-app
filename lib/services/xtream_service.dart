import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/category.dart';

/// Serviço responsável por toda comunicação com servidores Xtream Codes.
class XtreamService {
  final String host; // ex: http://meuiptv.com:8080
  final String username;
  final String password;

  XtreamService({
    required this.host,
    required this.username,
    required this.password,
  });

  String get _baseApiUrl =>
      '$host/player_api.php?username=$username&password=$password';

  /// Testa o login e retorna os dados do usuário (ou lança erro se inválido).
  Future<Map<String, dynamic>> authenticate() async {
    final response = await http.get(Uri.parse(_baseApiUrl));
    if (response.statusCode != 200) {
      throw Exception('Falha ao conectar ao servidor (${response.statusCode})');
    }
    final data = json.decode(response.body);
    if (data['user_info'] == null || data['user_info']['auth'] != 1) {
      throw Exception('Usuário ou senha inválidos');
    }
    return data;
  }

  /// Categorias de canais (TV ao vivo)
  Future<List<Category>> getLiveCategories() async {
    final url = '$_baseApiUrl&action=get_live_categories';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Category.fromXtream(json: e, type: 'live'))
        .toList();
  }

  /// Canais de uma categoria específica
  Future<List<Channel>> getLiveStreams(
    String categoryId,
    String categoryName,
  ) async {
    final url = '$_baseApiUrl&action=get_live_streams&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Channel.fromXtream(
              json: e,
              host: host,
              username: username,
              password: password,
              categoryName: categoryName,
            ))
        .toList();
  }

  /// Categorias de filmes (VOD)
  Future<List<Category>> getMovieCategories() async {
    final url = '$_baseApiUrl&action=get_vod_categories';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Category.fromXtream(json: e, type: 'movie'))
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
  }

  /// Categorias de séries
  Future<List<Category>> getSeriesCategories() async {
    final url = '$_baseApiUrl&action=get_series_categories';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Category.fromXtream(json: e, type: 'series'))
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
  }

  /// Detalhes de uma série específica (temporadas e episódios)
  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    final url = '$_baseApiUrl&action=get_series_info&series_id=$seriesId';
    final response = await http.get(Uri.parse(url));
    return json.decode(response.body);
  }
}