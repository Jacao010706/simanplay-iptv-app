class BackupPlaylist {
  final int priority;
  final int playlistId;
  final String name;
  final String type;
  final String? xtreamHost;
  final String? xtreamUsername;
  final String? xtreamPassword;
  final String? m3uUrl;

  const BackupPlaylist({
    required this.priority,
    required this.playlistId,
    required this.name,
    required this.type,
    this.xtreamHost,
    this.xtreamUsername,
    this.xtreamPassword,
    this.m3uUrl,
  });

  factory BackupPlaylist.fromJson(Map<String, dynamic> json) {
    return BackupPlaylist(
      priority: json['priority'] as int,
      playlistId: json['playlist_id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      xtreamHost: json['xtream_host'] as String?,
      xtreamUsername: json['xtream_username'] as String?,
      xtreamPassword: json['xtream_password'] as String?,
      m3uUrl: json['m3u_url'] as String?,
    );
  }

  String? get playlistUrl {
    if (type == 'xtream' && xtreamHost != null) {
      return '$xtreamHost/get.php?username=${Uri.encodeComponent(xtreamUsername ?? '')}&password=${Uri.encodeComponent(xtreamPassword ?? '')}&type=m3u_plus&output=ts';
    }
    return m3uUrl;
  }
}

class ClientSession {
  final String status;
  final DateTime? expiresAt;
  final String? playlistType;
  final String? xtreamHost;
  final String? xtreamUsername;
  final String? xtreamPassword;
  final String? m3uUrl;
  final List<BackupPlaylist> backupPlaylists;

  const ClientSession({
    required this.status,
    this.expiresAt,
    this.playlistType,
    this.xtreamHost,
    this.xtreamUsername,
    this.xtreamPassword,
    this.m3uUrl,
    this.backupPlaylists = const [],
  });

  factory ClientSession.fromJson(Map<String, dynamic> json) {
    return ClientSession(
      status: json['status'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      playlistType: json['playlist_type'] as String?,
      xtreamHost: json['xtream_host'] as String?,
      xtreamUsername: json['xtream_username'] as String?,
      xtreamPassword: json['xtream_password'] as String?,
      m3uUrl: json['m3u_url'] as String?,
      backupPlaylists: (json['backup_playlists'] as List<dynamic>? ?? [])
          .map((e) => BackupPlaylist.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, String>? extractXtreamFromUrl(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];
      if (username != null && password != null) {
        final port = uri.port != 0 && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '';
        final host = '${uri.scheme}://${uri.host}$port';
        return {'host': host, 'username': username, 'password': password};
      }
    } catch (_) {}
    return null;
  }

  String? get effectiveXtreamHost {
    if (xtreamHost != null) return xtreamHost;
    return extractXtreamFromUrl(m3uUrl)?['host'];
  }

  String? get effectiveXtreamUsername {
    if (xtreamUsername != null) return xtreamUsername;
    return extractXtreamFromUrl(m3uUrl)?['username'];
  }

  String? get effectiveXtreamPassword {
    if (xtreamPassword != null) return xtreamPassword;
    return extractXtreamFromUrl(m3uUrl)?['password'];
  }

  bool get hasXtreamAccess =>
      effectiveXtreamHost != null &&
      effectiveXtreamUsername != null &&
      effectiveXtreamPassword != null;

  String? get primaryUrl {
    if (playlistType == 'xtream' && xtreamHost != null) {
      return '$xtreamHost/get.php?username=${Uri.encodeComponent(xtreamUsername ?? '')}&password=${Uri.encodeComponent(xtreamPassword ?? '')}&type=m3u_plus&output=ts';
    }
    return m3uUrl;
  }

  List<String> get allPlaylistUrls {
    final urls = <String>[];
    if (primaryUrl != null) urls.add(primaryUrl!);
    for (final b in backupPlaylists) {
      final url = b.playlistUrl;
      if (url != null) urls.add(url);
    }
    return urls;
  }
}