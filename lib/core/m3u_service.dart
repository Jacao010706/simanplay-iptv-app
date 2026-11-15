import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'user_agent.dart';
import 'text_fix.dart';
import '../models/channel.dart';

/// Serviço responsável por baixar e interpretar listas M3U/M3U8.
class M3uService {
  /// Só para testes: cliente HTTP falso. null = cliente padrão.
  final http.Client? client;

  M3uService({this.client});

  static const _extensoesDeVideo = {
    '.mp4', '.mkv', '.avi', '.mov', '.m4v', '.wmv', '.flv', '.webm', '.mpg', '.mpeg',
  };

  /// A entrada é canal ao vivo? O M3U de um painel Xtream (get.php) traz também filmes
  /// (/movie/…mp4) e episódios (/series/…mp4); esses não entram no Ao Vivo. Canais 24h
  /// (ex.: "FILMES 24 HORAS") são /live/… e continuam.
  static bool ehAoVivo(String url) {
    final caminho = url.trim().split(RegExp(r'[?#]')).first.toLowerCase();
    if (caminho.contains('/movie/') || caminho.contains('/series/')) return false;
    final arquivo = caminho.substring(caminho.lastIndexOf('/') + 1);
    final ponto = arquivo.lastIndexOf('.');
    return ponto == -1 || !_extensoesDeVideo.contains(arquivo.substring(ponto));
  }

  Future<Uint8List> _baixar(String url) async {
    final uri = Uri.parse(url);
    final response = await (client != null
        ? client!.get(uri, headers: kIptvHeaders)
        : http.get(uri, headers: kIptvHeaders));
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar a lista (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  /// Baixa o conteúdo de uma URL de lista M3U e retorna o texto bruto.
  Future<String> fetchPlaylist(String url) async => decodeBytes(await _baixar(url));

  /// Interpreta o conteúdo M3U e retorna uma lista de canais.
  ///
  /// Formato esperado:
  /// #EXTM3U
  /// #EXTINF:-1 tvg-id="" tvg-logo="http://..." group-title="Categoria",Nome do Canal
  /// http://servidor/stream/url
  ///
  /// Com [soAoVivo], filmes e episódios ([ehAoVivo] falso) são descartados sem nem
  /// montar o item. Os ids ("m3u_N") contam todas as entradas, então continuam os
  /// mesmos de antes do filtro (favoritos salvos não mudam).
  List<Channel> parse(String content, {bool soAoVivo = false}) {
    final List<Channel> channels = [];
    String? extinf;
    int autoId = 0;

    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        extinf = line; // só é interpretada se a URL for mantida
      } else if (!line.startsWith('#')) {
        // Esta linha é a URL do stream
        if (extinf == null) continue;
        autoId++;
        final info = extinf;
        extinf = null;
        if (soAoVivo && !ehAoVivo(line)) continue;

        final texto = fixMojibake(info); // nomes já corrompidos no provedor
        // Nome: depois da última vírgula
        final commaIndex = texto.lastIndexOf(',');
        final name = commaIndex != -1 ? texto.substring(commaIndex + 1).trim() : 'Canal sem nome';
        final logo = RegExp(r'tvg-logo="([^"]*)"').firstMatch(texto)?.group(1);
        final group = RegExp(r'group-title="([^"]*)"').firstMatch(texto)?.group(1) ?? 'Sem categoria';
        channels.add(Channel.fromM3u(
          id: 'm3u_$autoId',
          name: name,
          streamUrl: fixMojibake(line),
          logoUrl: logo,
          categoryName: group,
        ));
      }
    }

    return channels;
  }

  /// Conveniência: baixa e já interpreta a lista em um único passo.
  Future<List<Channel>> fetchAndParse(String url) async {
    final content = await fetchPlaylist(url);
    return parse(content);
  }

  /// Só os canais ao vivo da lista. A decodificação e o parse (listas de ~300 mil
  /// linhas) rodam em outro isolate, sem travar a interface; volta só o que foi mantido.
  Future<List<Channel>> fetchAoVivo(String url) async =>
      compute(_parseAoVivo, await _baixar(url));
}

List<Channel> _parseAoVivo(Uint8List bytes) => M3uService().parse(decodeBytes(bytes), soAoVivo: true);
