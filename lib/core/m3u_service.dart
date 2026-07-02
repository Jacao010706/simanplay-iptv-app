import 'package:http/http.dart' as http;
import '../models/channel.dart';

/// Serviço responsável por baixar e interpretar listas M3U/M3U8.
class M3uService {
  /// Baixa o conteúdo de uma URL de lista M3U e retorna o texto bruto.
  Future<String> fetchPlaylist(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar a lista (${response.statusCode})');
    }
    return response.body;
  }

  /// Interpreta o conteúdo M3U e retorna uma lista de canais.
  ///
  /// Formato esperado:
  /// #EXTM3U
  /// #EXTINF:-1 tvg-id="" tvg-logo="http://..." group-title="Categoria",Nome do Canal
  /// http://servidor/stream/url
  List<Channel> parse(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');

    String? currentName;
    String? currentLogo;
    String currentCategory = 'Sem categoria';
    int autoId = 0;

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        // Extrai nome (depois da última vírgula)
        final commaIndex = line.lastIndexOf(',');
        currentName = commaIndex != -1
            ? line.substring(commaIndex + 1).trim()
            : 'Canal sem nome';

        // Extrai logo (tvg-logo="...")
        final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line);
        currentLogo = logoMatch?.group(1);

        // Extrai categoria (group-title="...")
        final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        currentCategory = groupMatch?.group(1) ?? 'Sem categoria';
      } else if (!line.startsWith('#')) {
        // Esta linha é a URL do stream
        if (currentName != null) {
          autoId++;
          channels.add(Channel.fromM3u(
            id: 'm3u_$autoId',
            name: currentName,
            streamUrl: line,
            logoUrl: currentLogo,
            categoryName: currentCategory,
          ));
          currentName = null;
          currentLogo = null;
        }
      }
    }

    return channels;
  }

  /// Conveniência: baixa e já interpreta a lista em um único passo.
  Future<List<Channel>> fetchAndParse(String url) async {
    final content = await fetchPlaylist(url);
    return parse(content);
  }
}