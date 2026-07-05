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

  bool get isXtream => type == SessionType.xtream;
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
  }) {
    return AppSession(
      type: SessionType.simanplay,
      simanplayUsername: username,
      simanplayPassword: password,
      primaryM3uUrl: primaryM3uUrl,
      backupM3uUrls: backupM3uUrls,
      expiresAt: expiresAt,
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
