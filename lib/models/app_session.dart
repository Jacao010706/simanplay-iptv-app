enum SessionType { xtream, simanplay }

class AppSession {
  final SessionType type;

  // Campos Xtream
  final String? xtreamHost;
  final String? xtreamUsername;
  final String? xtreamPassword;

  // Campos SimanPlay
  final String? simanplayUsername;
  final String? simanplayPassword;
  final String? primaryM3uUrl;
  final List<String> backupM3uUrls;
  final DateTime? expiresAt;

  const AppSession({
    required this.type,
    this.xtreamHost,
    this.xtreamUsername,
    this.xtreamPassword,
    this.simanplayUsername,
    this.simanplayPassword,
    this.primaryM3uUrl,
    this.backupM3uUrls = const [],
    this.expiresAt,
  });

  bool get isXtream => type == SessionType.xtream || (type == SessionType.simanplay && xtreamHost != null);

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
    return extractXtreamFromUrl(primaryM3uUrl)?['host'];
  }

  String? get effectiveXtreamUsername {
    if (xtreamUsername != null) return xtreamUsername;
    return extractXtreamFromUrl(primaryM3uUrl)?['username'];
  }

  String? get effectiveXtreamPassword {
    if (xtreamPassword != null) return xtreamPassword;
    return extractXtreamFromUrl(primaryM3uUrl)?['password'];
  }

  bool get hasXtreamAccess =>
      effectiveXtreamHost != null &&
      effectiveXtreamUsername != null &&
      effectiveXtreamPassword != null;
  bool get isSimanplay => type == SessionType.simanplay;

  factory AppSession.xtream({
    required String host,
    required String username,
    required String password,
  }) {
    return AppSession(
      type: SessionType.xtream,
      xtreamHost: host,
      xtreamUsername: username,
      xtreamPassword: password,
    );
  }

  factory AppSession.simanplay({
    required String username,
    required String password,
    required String primaryM3uUrl,
    List<String> backupM3uUrls = const [],
    DateTime? expiresAt,
    String? xtreamHost,
    String? xtreamUsername,
    String? xtreamPassword,
  }) {
    return AppSession(
      type: SessionType.simanplay,
      simanplayUsername: username,
      simanplayPassword: password,
      primaryM3uUrl: primaryM3uUrl,
      backupM3uUrls: backupM3uUrls,
      expiresAt: expiresAt,
      xtreamHost: xtreamHost,
      xtreamUsername: xtreamUsername,
      xtreamPassword: xtreamPassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'xtreamHost': xtreamHost,
      'xtreamUsername': xtreamUsername,
      'xtreamPassword': xtreamPassword,
      'simanplayUsername': simanplayUsername,
      'simanplayPassword': simanplayPassword,
      'primaryM3uUrl': primaryM3uUrl,
      'backupM3uUrls': backupM3uUrls,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      type: SessionType.values.firstWhere((e) => e.name == json['type']),
      xtreamHost: json['xtreamHost'],
      xtreamUsername: json['xtreamUsername'],
      xtreamPassword: json['xtreamPassword'],
      simanplayUsername: json['simanplayUsername'],
      simanplayPassword: json['simanplayPassword'],
      primaryM3uUrl: json['primaryM3uUrl'],
      backupM3uUrls: List<String>.from(json['backupM3uUrls'] ?? []),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
    );
  }
}
