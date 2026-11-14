import 'dart:async';

import 'package:http/http.dart' as http;
import '../core/erros.dart';
import '../core/text_fix.dart';
import '../core/user_agent.dart';
import '../models/channel.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../models/category.dart';

/// Acesso à API Xtream (player_api.php) do servidor do usuário.
///
/// Listas (canais, filmes, séries e categorias) vêm de UMA chamada por tipo, sem
/// category_id, e ficam em cache em memória (compartilhado por todas as telas da mesma
/// conta). Antes, a aba Ao Vivo fazia uma chamada por categoria (50+ seguidas), e alguns
/// painéis bloqueiam a conta por um tempo quando recebem pedidos demais.
class XtreamService {
  final String host;
  final String username;
  final String password;

  /// Só para testes: cliente HTTP falso. null = cliente padrão.
  final http.Client? client;

  XtreamService({
    required this.host,
    required this.username,
    required this.password,
    this.client,
  });

  /// Tempo de vida do cache das listas.
  static Duration cacheTtl = const Duration(minutes: 30);
  static final Map<String, _Memo> _cache = {};

  /// Esquece todas as listas guardadas (ex.: botão "Atualizar" ou troca de conta).
  static void clearCache() => _cache.clear();

  static const _timeoutApi = Duration(seconds: 20);
  static const _timeoutLista = Duration(seconds: 60);

  String get _baseApiUrl =>
      '$host/player_api.php?username=$username&password=$password';

  String get _conta => '$host|$username|$password';

  // ---------------------------------------------------------------- HTTP

  /// GET na API. Erros saem como [ContaRecusadaException] ou [ServidorException],
  /// sempre sem URL, usuário ou senha.
  Future<dynamic> _get(String action, {Duration timeout = _timeoutApi, bool conferirConta = true}) async {
    final url = action.isEmpty ? _baseApiUrl : '$_baseApiUrl&action=$action';
    final http.Response res;
    try {
      final uri = Uri.parse(url);
      res = await (client != null
              ? client!.get(uri, headers: kIptvHeaders)
              : http.get(uri, headers: kIptvHeaders))
          .timeout(timeout);
    } on TimeoutException {
      throw const ServidorException(
          'O servidor demorou demais para responder. Verifique a internet e tente novamente.');
    } catch (_) {
      // ClientException/SocketException trazem a URL com usuário e senha: não repassa o texto
      throw const ServidorException(
          'Não foi possível conectar ao servidor. Verifique a internet e o endereço da lista.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) throw const ContaRecusadaException();
    if (res.statusCode != 200) {
      throw ServidorException('O servidor respondeu com erro (HTTP ${res.statusCode}). Tente novamente em alguns minutos.');
    }
    final dynamic data;
    try {
      data = decodeJson(res);
    } on FormatException {
      throw const ServidorException('O servidor enviou uma resposta inválida. Tente novamente em alguns minutos.');
    }
    if (conferirConta && contaRecusada(data)) throw const ContaRecusadaException();
    return data;
  }

  /// Resposta do Xtream dizendo que a conta não foi aceita: {"user_info": {"auth": 0, ...}}.
  static bool contaRecusada(dynamic data) =>
      data is Map && data['user_info'] is Map && '${(data['user_info'] as Map)['auth']}' != '1';

  Future<List<dynamic>> _getList(String action) async {
    final data = await _get(action, timeout: _timeoutLista);
    if (data is List) return data;
    // Alguns painéis mandam {} quando não há nada
    if (data is Map && data.isEmpty) return const [];
    // Objeto com user_info no lugar da lista = conta recusada
    if (data is Map && data.containsKey('user_info')) throw const ContaRecusadaException();
    throw const ServidorException('O servidor enviou uma resposta inesperada. Tente novamente em alguns minutos.');
  }

  Future<Map<String, dynamic>> _getMap(String action) async {
    final data = await _get(action);
    if (data is Map) return Map<String, dynamic>.from(data);
    // get_short_epg/get_series_info sem dados às vezes vêm como []
    if (data is List && data.isEmpty) return <String, dynamic>{};
    throw const ServidorException('O servidor enviou uma resposta inesperada. Tente novamente em alguns minutos.');
  }

  /// Guarda o resultado (e o pedido em andamento: telas abertas juntas fazem uma chamada só).
  Future<T> _memo<T>(String nome, Future<T> Function() carregar) {
    final chave = '$_conta|$nome';
    final m = _cache[chave];
    if (m != null && DateTime.now().difference(m.em) < cacheTtl) return m.futuro as Future<T>;
    final futuro = carregar();
    _cache[chave] = _Memo(futuro, DateTime.now());
    // Falhou: não guarda o erro (a próxima tentativa chama o servidor de novo)
    futuro.then((_) {}, onError: (_) {
      if (identical(_cache[chave]?.futuro, futuro)) _cache.remove(chave);
    });
    return futuro;
  }

  Future<Map<String, String>> _nomes(Future<List<Category>> categorias) async {
    try {
      return {for (final c in await categorias) c.id: c.name};
    } catch (_) {
      return const {};
    }
  }

  // ---------------------------------------------------------------- Conta

  Future<Map<String, dynamic>> authenticate() async {
    final data = await _get('', conferirConta: false);
    if (data is! Map || data['user_info'] is! Map) {
      throw const ServidorException('O endereço não parece ser de um servidor Xtream. Confira o endereço da lista.');
    }
    if (contaRecusada(data)) {
      throw const ServidorException(
          'Usuário ou senha não aceitos. Se estiverem corretos, o servidor recusou a conta agora '
          '(pode estar em uso em outro aparelho ou bloqueada temporariamente). '
          'Feche outros apps com esta lista e tente em alguns minutos.');
    }
    return Map<String, dynamic>.from(data);
  }

  // ---------------------------------------------------------------- Ao vivo

  Future<List<Category>> getLiveCategories() => _memo('live_categories', () async {
        final data = await _getList('get_live_categories');
        return data.map((e) => Category.fromXtream(json: Map<String, dynamic>.from(e as Map), type: 'live')).toList();
      });

  /// Todos os canais numa chamada só (get_live_streams sem category_id).
  Future<List<Channel>> getAllLiveStreams() async {
    final todos = await _memo('live_streams', () async {
      final nomes = _nomes(getLiveCategories());
      final data = await _getList('get_live_streams');
      final n = await nomes;
      return data.map((e) {
        final json = Map<String, dynamic>.from(e as Map);
        return Channel.fromXtream(
          json: json, host: host, username: username, password: password,
          categoryName: n[json['category_id']?.toString() ?? ''] ?? '',
        );
      }).toList();
    });
    return List.of(todos);
  }

  /// Canais de uma categoria: filtra a lista completa (não chama o servidor de novo).
  Future<List<Channel>> getLiveStreams(String categoryId, String categoryName) async =>
      (await getAllLiveStreams()).where((c) => c.categoryId == categoryId).toList();

  // ---------------------------------------------------------------- Filmes

  Future<List<Category>> getMovieCategories() => _memo('vod_categories', () async {
        final data = await _getList('get_vod_categories');
        return data.map((e) => Category.fromXtream(json: Map<String, dynamic>.from(e as Map), type: 'movie')).toList();
      });

  Future<List<Movie>> getAllMovies() async {
    final todos = await _memo('vod_streams', () async {
      final nomes = _nomes(getMovieCategories());
      final data = await _getList('get_vod_streams');
      final n = await nomes;
      return data.map((e) {
        final json = Map<String, dynamic>.from(e as Map);
        return Movie.fromXtream(
          json: json, host: host, username: username, password: password,
          categoryName: n[json['category_id']?.toString() ?? ''] ?? '',
        );
      }).toList();
    });
    return List.of(todos);
  }

  Future<List<Movie>> getMovies(String categoryId, String categoryName) async =>
      (await getAllMovies()).where((m) => m.categoryId == categoryId).toList();

  // ---------------------------------------------------------------- Séries

  Future<List<Category>> getSeriesCategories() => _memo('series_categories', () async {
        final data = await _getList('get_series_categories');
        return data.map((e) => Category.fromXtream(json: Map<String, dynamic>.from(e as Map), type: 'series')).toList();
      });

  Future<List<Series>> getAllSeries() async {
    final todas = await _memo('series', () async {
      final nomes = _nomes(getSeriesCategories());
      final data = await _getList('get_series');
      final n = await nomes;
      return data.map((e) {
        final json = Map<String, dynamic>.from(e as Map);
        return Series.fromXtream(json: json, categoryName: n[json['category_id']?.toString() ?? ''] ?? '');
      }).toList();
    });
    return List.of(todas);
  }

  Future<List<Series>> getSeries(String categoryId, String categoryName) async =>
      (await getAllSeries()).where((s) => s.categoryId == categoryId).toList();

  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) =>
      _getMap('get_series_info&series_id=$seriesId');

  // ---------------------------------------------------------------- Detalhes

  /// EPG resumido: programa atual + próximos do canal (padrão: 2 itens)
  Future<Map<String, dynamic>> getShortEpg(String streamId, {int limit = 2}) =>
      _getMap('get_short_epg&stream_id=$streamId&limit=$limit');

  /// Detalhes completos de um filme (sinopse, elenco, diretor, etc.)
  Future<Map<String, dynamic>> getVodInfo(String vodId) => _getMap('get_vod_info&vod_id=$vodId');
}

class _Memo {
  final Future<Object?> futuro;
  final DateTime em;
  _Memo(this.futuro, this.em);
}
