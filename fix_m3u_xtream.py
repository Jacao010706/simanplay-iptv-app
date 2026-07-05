with open(r"C:\Users\Jacques\iptv-player-app\lib\models\client_session.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD_GETTER = """  String? get primaryUrl {
    if (playlistType == 'xtream' && xtreamHost != null) {
      return '$xtreamHost/get.php?username=${Uri.encodeComponent(xtreamUsername ?? '')}&password=${Uri.encodeComponent(xtreamPassword ?? '')}&type=m3u_plus&output=ts';
    }
    return m3uUrl;
  }"""

NEW_GETTER = """  static Map<String, String>? extractXtreamFromUrl(String? url) {
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
  }"""

count = content.count(OLD_GETTER)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_GETTER, NEW_GETTER)

with open(r"C:\Users\Jacques\iptv-player-app\lib\models\client_session.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! client_session.dart atualizado.")