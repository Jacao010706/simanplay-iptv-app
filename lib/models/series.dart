/// Representa uma série de TV na lista IPTV.
class Series {
  final String id;
  final String name;
  final String? posterUrl;
  final String categoryId;
  final String categoryName;
  final String? plot;
  final double? rating;
  final String? releaseDate;

  Series({
    required this.id,
    required this.name,
    this.posterUrl,
    required this.categoryId,
    required this.categoryName,
    this.plot,
    this.rating,
    this.releaseDate,
  });

  factory Series.fromXtream({
    required Map<String, dynamic> json,
    required String categoryName,
  }) {
    return Series(
      id: json['series_id'].toString(),
      name: json['name'] ?? 'Sem nome',
      posterUrl: json['cover'],
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: categoryName,
      plot: json['plot'],
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      releaseDate: json['releaseDate'],
    );
  }
}

/// Representa um episódio dentro de uma temporada de série.
class Episode {
  final String id;
  final String title;
  final int episodeNumber;
  final int season;
  final String extension;
  final String? plot;
  final String? duration;
  final String? coverUrl;

  Episode({
    required this.id,
    required this.title,
    required this.episodeNumber,
    required this.season,
    this.extension = 'mp4',
    this.plot,
    this.duration,
    this.coverUrl,
  });

  String streamUrl({required String host, required String username, required String password}) =>
      '$host/series/$username/$password/$id.$extension';

  /// Episódio vindo do get_series_info do Xtream. Campos numéricos podem vir
  /// como número ou texto ("01"), e [fallbackNumber] é usado se faltar o número.
  factory Episode.fromXtream(Map<String, dynamic> json, {required int season, int fallbackNumber = 0}) {
    final number = _toInt(json['episode_num']) ?? fallbackNumber;
    final info = json['info'] is Map ? Map<String, dynamic>.from(json['info'] as Map) : const <String, dynamic>{};
    final title = json['title']?.toString().trim() ?? '';
    final ext = json['container_extension']?.toString().trim() ?? '';
    String? text(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return Episode(
      id: json['id']?.toString() ?? '',
      title: title.isNotEmpty ? title : 'Episódio $number',
      episodeNumber: number,
      season: season,
      extension: ext.isNotEmpty ? ext : 'mp4',
      plot: text(info['plot']),
      duration: text(info['duration']),
      coverUrl: text(info['movie_image']) ?? text(info['cover_big']),
    );
  }
}

/// Uma temporada com seus episódios (em ordem).
class SeriesSeason {
  final int number;
  final List<Episode> episodes;

  const SeriesSeason({required this.number, required this.episodes});
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString().trim() ?? '');
}

/// Lê as temporadas da resposta get_series_info do Xtream.
///
/// Os painéis variam no formato: "episodes" pode ser um Map (chave = número da
/// temporada, em texto) ou uma List (de listas por temporada ou de episódios com
/// o campo "season"); "seasons" pode vir vazio. Temporadas e episódios saem
/// ordenados numericamente; temporadas de "seasons" sem episódios também entram.
List<SeriesSeason> parseSeriesSeasons(Map<String, dynamic>? info) {
  final bySeason = <int, List<Episode>>{};

  void addEpisodes(dynamic eps, int? season) {
    final list = eps is List ? eps : (eps is Map ? eps.values.toList() : const []);
    for (final e in list) {
      if (e is! Map) continue;
      final json = Map<String, dynamic>.from(e);
      final s = season ?? _toInt(json['season']) ?? 1;
      final group = bySeason.putIfAbsent(s, () => []);
      group.add(Episode.fromXtream(json, season: s, fallbackNumber: group.length + 1));
    }
  }

  final episodes = info?['episodes'];
  if (episodes is Map) {
    episodes.forEach((key, value) {
      final s = _toInt(key);
      if (s != null) addEpisodes(value, s);
    });
  } else if (episodes is List) {
    for (var i = 0; i < episodes.length; i++) {
      final item = episodes[i];
      if (item is List) {
        addEpisodes(item, i + 1);
      } else {
        addEpisodes([item], null);
      }
    }
  }

  final seasons = info?['seasons'];
  if (seasons is List) {
    for (final s in seasons) {
      final n = s is Map ? _toInt(s['season_number']) : _toInt(s);
      if (n != null) bySeason.putIfAbsent(n, () => []);
    }
  }

  final numbers = bySeason.keys.toList()..sort();
  return [
    for (final n in numbers)
      SeriesSeason(
        number: n,
        episodes: bySeason[n]!
          ..sort((a, b) {
            final c = a.episodeNumber.compareTo(b.episodeNumber);
            return c != 0 ? c : a.id.compareTo(b.id);
          }),
      ),
  ];
}
