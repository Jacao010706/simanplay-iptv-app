import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/category.dart';

class XtreamService {
  final String host;
  final String username;
  final String password;

  XtreamService({
    required this.host,
    required this.username,
    required this.password,
  });

  String get _baseApiUrl =>
      '$host/player_api.php?username=$username&password=$password';

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

  Future<List<Category>> getLiveCategories() async {
    final url = '$_baseApiUrl&action=get_live_categories';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data.map((e) => Category.fromXtream(json: e, type: 'live')).toList();
  }

  Future<List<Channel>> getLiveStreams(String categoryId, String categoryName) async {
    final url = '$_baseApiUrl&action=get_live_streams&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Channel.fromXtream(
              json: e, host: host,
              username: username, password: password,
              categoryName: categoryName,
            ))
        .toList();
  }

  Future<List<Category>> getMovieCategories() async {
    final url = '$_baseApiUrl&action=get_vod_categories';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data.map((e) => Category.fromXtream(json: e, type: 'movie')).toList();
  }

  Future<List<Movie>> getAllMovies() async {
    final url = '$_baseApiUrl&action=get_vod_streams';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Movie.fromXtream(
              json: e, host: host,
              username: username, password: password,
              categoryName: '',
            ))
        .toList();
  }

  Future<List<Movie>> getMovies(String categoryId, String categoryName) async {
    final url = '$_baseApiUrl&action=get_vod_streams&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data
        .map((e) => Movie.fromXtream(
              json: e, host: host,
              username: username, password: password,
              categoryName: categoryName,
            ))
        .toList();
  }

  Future<List<Category>> getSeriesCategories() async {
    final url = '$_baseApiUrl&action=get_series_categories';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data.map((e) => Category.fromXtream(json: e, type: 'series')).toList();
  }

  Future<List<Series>> getAllSeries() async {
    final url = '$_baseApiUrl&action=get_series';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data.map((e) => Series.fromXtream(json: e, categoryName: '')).toList();
  }

  Future<List<Series>> getSeries(String categoryId, String categoryName) async {
    final url = '$_baseApiUrl&action=get_series&category_id=$categoryId';
    final response = await http.get(Uri.parse(url));
    final List data = json.decode(response.body);
    return data.map((e) => Series.fromXtream(json: e, categoryName: categoryName)).toList();
  }

  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    final url = '$_baseApiUrl&action=get_series_info&series_id=$seriesId';
    final response = await http.get(Uri.parse(url));
    return json.decode(response.body);
  }

  /// EPG resumido: programa atual + próximo do canal
  Future<Map<String, dynamic>> getShortEpg(String streamId) async {
    final url = '$_baseApiUrl&action=get_short_epg&stream_id=$streamId&limit=2';
    final response = await http.get(Uri.parse(url));
    return json.decode(response.body);
  }

  /// Detalhes completos de um filme (sinopse, elenco, diretor, etc.)
  Future<Map<String, dynamic>> getVodInfo(String vodId) async {
    final url = '$_baseApiUrl&action=get_vod_info&vod_id=$vodId';
    final response = await http.get(Uri.parse(url));
    return json.decode(response.body);
  }
}
