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
  final String streamUrl;
  final String? extension;

  Episode({
    required this.id,
    required this.title,
    required this.episodeNumber,
    required this.season,
    required this.streamUrl,
    this.extension,
  });

  factory Episode.fromXtream({
    required Map<String, dynamic> json,
    required int season,
    required String host,
    required String username,
    required String password,
    required String seriesId,
  }) {
    final episodeId = json['id'].toString();
    final ext = json['container_extension'] ?? 'mp4';
    return Episode(
      id: episodeId,
      title: json['title'] ?? 'Episódio',
      episodeNumber: int.tryParse(json['episode_num'].toString()) ?? 0,
      season: season,
      streamUrl: '$host/series/$username/$password/$episodeId.$ext',
      extension: ext,
    );
  }
}