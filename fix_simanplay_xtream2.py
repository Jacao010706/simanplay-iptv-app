with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\activation_screen_v3.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD_SESSION1 = """      final session = AppSession.simanplay(
        username: _spUserCtrl.text.trim(),
        password: _spPassCtrl.text,
        primaryM3uUrl: clientSession.primaryUrl ?? '',
        backupM3uUrls: clientSession.backupPlaylists
            .map((b) => b.playlistUrl ?? '')
            .where((u) => u.isNotEmpty)
            .toList(),
        expiresAt: clientSession.expiresAt,
      );"""

NEW_SESSION1 = """      final session = AppSession.simanplay(
        username: _spUserCtrl.text.trim(),
        password: _spPassCtrl.text,
        primaryM3uUrl: clientSession.primaryUrl ?? '',
        backupM3uUrls: clientSession.backupPlaylists
            .map((b) => b.playlistUrl ?? '')
            .where((u) => u.isNotEmpty)
            .toList(),
        expiresAt: clientSession.expiresAt,
        xtreamHost: clientSession.xtreamHost,
        xtreamUsername: clientSession.xtreamUsername,
        xtreamPassword: clientSession.xtreamPassword,
      );"""

count = content.count(OLD_SESSION1)
if count != 1:
    print(f"ERRO session1: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_SESSION1, NEW_SESSION1)
print("session1 OK")

# Agora vamos ver o bloco do MAC
with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\activation_screen_v3.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! activation_screen_v3.dart atualizado para login SimanPlay.")