with open(r"C:\Users\Jacques\iptv-player-app\lib\models\app_session.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = r"""  static Map<String, String>? extractXtreamFromUrl(String? url) {
    if (url == null) return null;
    try {
      final uri = Uri.parse(url);
      final username = uri.queryParameters['username'];
      final password = uri.queryParameters['password'];
      if (username != null && password != null) {
        final port = uri.port != 0 && uri.port != 80 && uri.port != 443 ? ':\${uri.port}' : '';
        final host = '\${uri.scheme}://\${uri.host}\$port';
        return {'host': host, 'username': username, 'password': password};
      }
    } catch (_) {}
    return null;
  }"""

NEW = """  static Map<String, String>? extractXtreamFromUrl(String? url) {
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
  }"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\models\app_session.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! getter corrigido.")