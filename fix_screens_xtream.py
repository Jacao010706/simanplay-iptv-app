# Adiciona getters effectiveXtream* no AppSession
with open(r"C:\Users\Jacques\iptv-player-app\lib\models\app_session.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD_GETTER = "  bool get isXtream => type == SessionType.xtream || (type == SessionType.simanplay && xtreamHost != null);"
NEW_GETTER = """  bool get isXtream => type == SessionType.xtream || (type == SessionType.simanplay && xtreamHost != null);

  static Map<String, String>? extractXtreamFromUrl(String? url) {
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
      effectiveXtreamPassword != null;"""

count = content.count(OLD_GETTER)
if count != 1:
    print(f"ERRO app_session getter: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_GETTER, NEW_GETTER)

with open(r"C:\Users\Jacques\iptv-player-app\lib\models\app_session.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! app_session.dart atualizado.")

# Atualiza movies_screen.dart
with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\movies_screen.dart", "r", encoding="utf-8") as f:
    movies = f.read()

OLD_MOVIES = """    if (!widget.session.isXtream) {
      setState(() {
        _error = 'Filmes disponíveis apenas em conexões Xtream Codes.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = XtreamService(
        host: widget.session.xtreamHost!,
        username: widget.session.xtreamUsername!,
        password: widget.session.xtreamPassword!,
      );"""

NEW_MOVIES = """    if (!widget.session.hasXtreamAccess) {
      setState(() {
        _error = 'Filmes não disponíveis para esta playlist.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );"""

count2 = movies.count(OLD_MOVIES)
if count2 != 1:
    print(f"ERRO movies: encontrado {count2} vez(es). Abortando.")
    exit(1)

movies = movies.replace(OLD_MOVIES, NEW_MOVIES)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\movies_screen.dart", "w", encoding="utf-8") as f:
    f.write(movies)

print("OK! movies_screen.dart atualizado.")

# Atualiza series_screen.dart
with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\series_screen.dart", "r", encoding="utf-8") as f:
    series = f.read()

OLD_SERIES = """    if (!widget.session.isXtream) {
      setState(() {
        _error = 'Séries disponíveis apenas em conexões Xtream Codes.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = XtreamService(
        host: widget.session.xtreamHost!,
        username: widget.session.xtreamUsername!,
        password: widget.session.xtreamPassword!,
      );"""

NEW_SERIES = """    if (!widget.session.hasXtreamAccess) {
      setState(() {
        _error = 'Séries não disponíveis para esta playlist.';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = XtreamService(
        host: widget.session.effectiveXtreamHost!,
        username: widget.session.effectiveXtreamUsername!,
        password: widget.session.effectiveXtreamPassword!,
      );"""

count3 = series.count(OLD_SERIES)
if count3 != 1:
    print(f"ERRO series: encontrado {count3} vez(es). Abortando.")
    exit(1)

series = series.replace(OLD_SERIES, NEW_SERIES)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\series_screen.dart", "w", encoding="utf-8") as f:
    f.write(series)

print("OK! series_screen.dart atualizado.")
print("Pronto! Filmes e Series vao funcionar com M3U Xtream automaticamente.")