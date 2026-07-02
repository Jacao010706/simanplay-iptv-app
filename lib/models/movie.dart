/// Representa um filme (VOD - Video on Demand) na lista IPTV.
class Movie {
  final String id;
  final String name;
  final String streamUrl;
  final String? posterUrl;
  final String categoryId;
  final String categoryName;
  final String? plot;
  final String? releaseDate;
  final double? rating;
  final String? extension;

  Movie({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.posterUrl,
    required this.categoryId,
    required this.categoryName,
    this.plot,
    this.releaseDate,
    this.rating,
    this.extension,
  });

  factory Movie.fromXtream({
    required Map<String, dynamic> json,
    required String host,
    required String username,
    required String password,
    required String categoryName,
  }) {
    final streamId = json['stream_id'].toString();
    final ext = json['container_extension'] ?? 'mp4';
    return Movie(
      id: streamId,
      name: json['name'] ?? 'Sem nome',
      streamUrl: '$host/movie/$username/$password/$streamId.$ext',
      posterUrl: json['stream_icon'],
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: categoryName,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      extension: ext,
    );
  }

  factory Movie.fromM3u({
    required String id,
    required String name,
    required String streamUrl,
    String? posterUrl,
    required String categoryName,
  }) {
    return Movie(
      id: id,
      name: name,
      streamUrl: streamUrl,
      posterUrl: posterUrl,
      categoryId: categoryName,
      categoryName: categoryName,
    );
  }
}