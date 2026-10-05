// Fontes de vídeo e textos de erro do player (funções puras, testáveis).

/// Separa "http://host/caminho" de "?query#fragmento".
(String, String) _splitQuery(String url) {
  final i = url.indexOf(RegExp(r'[?#]'));
  return i < 0 ? (url, '') : (url.substring(0, i), url.substring(i));
}

/// A mesma URL em outro formato de stream: .ts <-> .m3u8; sem extensão, + .m3u8.
/// Devolve null quando não há variante (outra extensão, como .mp4, ou URL sem caminho).
String? alternateStreamUrl(String url) {
  final (base, rest) = _splitQuery(url.trim());
  final path = Uri.tryParse(base)?.path ?? '';
  if (path.isEmpty || path == '/' || path.endsWith('/')) return null;
  final lower = base.toLowerCase();
  if (lower.endsWith('.ts')) return '${base.substring(0, base.length - 3)}.m3u8$rest';
  if (lower.endsWith('.m3u8')) return '${base.substring(0, base.length - 5)}.ts$rest';
  final last = path.substring(path.lastIndexOf('/') + 1);
  if (last.contains('.')) return null;
  return '$base.m3u8$rest';
}

/// Fontes a tentar num canal ao vivo, em ordem: cada URL original seguida da
/// variante em outro formato. Sem repetições.
List<String> liveStreamSources(List<String> urls) {
  final out = <String>[];
  void add(String? u) {
    if (u != null && u.trim().isNotEmpty && !out.contains(u.trim())) out.add(u.trim());
  }

  for (final url in urls) {
    add(url);
    add(alternateStreamUrl(url));
  }
  return out;
}

final RegExp _xtreamPath = RegExp(r'/(live|movie|series|timeshift)/([^/]+)/([^/]+)/');
final RegExp _credentialQuery = RegExp(r'([?&](?:username|password)=)[^&#]*', caseSensitive: false);

/// URL para mostrar na tela de erro, sem usuário e senha:
/// /live/USUARIO/SENHA/123.ts -> /live/***/***/123.ts (também em ?username=&password=).
String maskStreamUrl(String url) => url
    .replaceAllMapped(_xtreamPath, (m) => '/${m[1]}/***/***/')
    .replaceAllMapped(_credentialQuery, (m) => '${m[1]}***');
