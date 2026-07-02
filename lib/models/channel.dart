/// Representa um canal de TV (live stream) na lista IPTV.
class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String categoryId;
  final String categoryName;
  final int? epgChannelId;
  final bool isFavorite;

  Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    required this.categoryId,
    required this.categoryName,
    this.epgChannelId,
    this.isFavorite = false,
  });

  /// Cria um Channel a partir da resposta JSON da API Xtream Codes
  /// (endpoint: get_live_streams)
  factory Channel.fromXtream({
    required Map<String, dynamic> json,
    required String host,
    required String username,
    required String password,
    required String categoryName,
  }) {
    final streamId = json['stream_id'].toString();
    return Channel(
      id: streamId,
      name: json['name'] ?? 'Sem nome',
      streamUrl: '$host/live/$username/$password/$streamId.m3u8',
      logoUrl: json['stream_icon'],
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: categoryName,
      epgChannelId: json['epg_channel_id'] != null
          ? int.tryParse(json['epg_channel_id'].toString())
          : null,
    );
  }

  /// Cria um Channel a partir de uma entrada de lista M3U
  factory Channel.fromM3u({
    required String id,
    required String name,
    required String streamUrl,
    String? logoUrl,
    required String categoryName,
  }) {
    return Channel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      logoUrl: logoUrl,
      categoryId: categoryName,
      categoryName: categoryName,
    );
  }

  Channel copyWith({bool? isFavorite}) {
    return Channel(
      id: id,
      name: name,
      streamUrl: streamUrl,
      logoUrl: logoUrl,
      categoryId: categoryId,
      categoryName: categoryName,
      epgChannelId: epgChannelId,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}