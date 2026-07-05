# Atualiza AppSession.simanplay factory para aceitar credenciais Xtream opcionais
with open(r"C:\Users\Jacques\iptv-player-app\lib\models\app_session.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD_FACTORY = '''  factory AppSession.simanplay({
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
  }'''

NEW_FACTORY = '''  factory AppSession.simanplay({
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
  }'''

count = content.count(OLD_FACTORY)
if count != 1:
    print(f"ERRO factory: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_FACTORY, NEW_FACTORY)

# Atualiza isXtream para incluir simanplay com credenciais xtream
OLD_GETTER = "  bool get isXtream => type == SessionType.xtream;"
NEW_GETTER = "  bool get isXtream => type == SessionType.xtream || (type == SessionType.simanplay && xtreamHost != null);"

count2 = content.count(OLD_GETTER)
if count2 != 1:
    print(f"ERRO getter: encontrado {count2} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_GETTER, NEW_GETTER)

with open(r"C:\Users\Jacques\iptv-player-app\lib\models\app_session.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! app_session.dart atualizado.")

# Agora atualiza activation_screen_v3.dart para passar credenciais Xtream
with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\activation_screen_v3.dart", "r", encoding="utf-8") as f:
    content2 = f.read()

OLD_SESSION1 = '''          final session = AppSession.simanplay(
            username: _spUserCtrl.text.trim(),
            password: _spPassCtrl.text,
            primaryM3uUrl: clientSession.primaryUrl ?? \'\',
            backupM3uUrls: clientSession.backupPlaylists
                .map((b) => b.playlistUrl ?? \'\')
                .where((u) => u.isNotEmpty)
                .toList(),
            expiresAt: clientSession.expiresAt,
          );'''

NEW_SESSION1 = '''          final session = AppSession.simanplay(
            username: _spUserCtrl.text.trim(),
            password: _spPassCtrl.text,
            primaryM3uUrl: clientSession.primaryUrl ?? \'\',
            backupM3uUrls: clientSession.backupPlaylists
                .map((b) => b.playlistUrl ?? \'\')
                .where((u) => u.isNotEmpty)
                .toList(),
            expiresAt: clientSession.expiresAt,
            xtreamHost: clientSession.xtreamHost,
            xtreamUsername: clientSession.xtreamUsername,
            xtreamPassword: clientSession.xtreamPassword,
          );'''

count3 = content2.count(OLD_SESSION1)
if count3 != 1:
    print(f"ERRO session1: encontrado {count3} vez(es). Abortando.")
    exit(1)

content2 = content2.replace(OLD_SESSION1, NEW_SESSION1)

OLD_SESSION2 = '''          final session = AppSession.simanplay(
            username: \'mac:$mac\',
            password: \'\',
            primaryM3uUrl: clientSession.primaryUrl ?? \'\',
            backupM3uUrls: clientSession.backupPlaylists
                .map((b) => b.playlistUrl ?? \'\')
                .where((u) => u.isNotEmpty)
                .toList(),
            expiresAt: clientSession.expiresAt,
          );'''

NEW_SESSION2 = '''          final session = AppSession.simanplay(
            username: \'mac:$mac\',
            password: \'\',
            primaryM3uUrl: clientSession.primaryUrl ?? \'\',
            backupM3uUrls: clientSession.backupPlaylists
                .map((b) => b.playlistUrl ?? \'\')
                .where((u) => u.isNotEmpty)
                .toList(),
            expiresAt: clientSession.expiresAt,
            xtreamHost: clientSession.xtreamHost,
            xtreamUsername: clientSession.xtreamUsername,
            xtreamPassword: clientSession.xtreamPassword,
          );'''

count4 = content2.count(OLD_SESSION2)
if count4 != 1:
    print(f"ERRO session2: encontrado {count4} vez(es). Abortando.")
    exit(1)

content2 = content2.replace(OLD_SESSION2, NEW_SESSION2)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\activation_screen_v3.dart", "w", encoding="utf-8") as f:
    f.write(content2)

print("OK! activation_screen_v3.dart atualizado.")
print("Pronto! Filmes e Series vao funcionar com SimanPlay + Xtream.")