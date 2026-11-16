/// User-Agent único do app em toda conversa com o servidor IPTV: API (player_api.php),
/// listas M3U, player de vídeo (mpv) e gravação.
///
/// Por que o do VLC: é o player que os próprios provedores indicam para testar uma lista,
/// então os painéis Xtream (XUI, Xtream UI, 1-Stream) praticamente nunca o bloqueiam. Já os
/// padrões que o app mandava antes ("libmpv" no vídeo e "Dart/x.y (dart:io)" na API) não são
/// de nenhum player conhecido e aparecem em listas de bloqueio de alguns painéis.
const String kIptvUserAgent = 'VLC/3.0.20 LibVLC/3.0.20';

/// Cabeçalhos HTTP enviados ao servidor IPTV.
const Map<String, String> kIptvHeaders = {'User-Agent': kIptvUserAgent};
