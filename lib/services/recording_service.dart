import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Informação sobre a gravação ativa
class RecordingInfo {
  final String channelName;
  final String filePath;
  final DateTime startTime;
  DateTime? endTime;
  int bytesRecorded;

  RecordingInfo({
    required this.channelName,
    required this.filePath,
    required this.startTime,
    this.endTime,
    this.bytesRecorded = 0,
  });

  Duration get elapsed {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get elapsedFormatted {
    final d = elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get sizeFormatted {
    if (bytesRecorded < 1024 * 1024) {
      return '${(bytesRecorded / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytesRecorded / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Gravação salva no disco
class SavedRecording {
  final String filePath;
  final String channelName;
  final DateTime recordedAt;
  final int sizeBytes;

  SavedRecording({
    required this.filePath,
    required this.channelName,
    required this.recordedAt,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get dateFormatted {
    final d = recordedAt;
    final day   = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour  = d.hour.toString().padLeft(2, '0');
    final min   = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$min';
  }
}

/// Serviço de gravação de canais ao vivo via HLS
class RecordingService {
  RecordingService._();
  static final RecordingService instance = RecordingService._();

  RecordingInfo? _active;
  Timer? _pollTimer;
  IOSink? _sink;
  bool _stopping = false;
  final Set<String> _seenSegments = {};

  /// Callback chamado a cada atualização (para UI)
  void Function()? onUpdate;

  RecordingInfo? get activeRecording => _active;
  bool get isRecording => _active != null;

  // ── Diretório de gravações ─────────────────────────────────────────────────

  Future<String> get _recordingsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/simanplay_gravacoes');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  // ── Iniciar gravação ───────────────────────────────────────────────────────

  Future<RecordingInfo> startRecording(String channelName, String streamUrl) async {
    if (_active != null) await stopRecording();

    _seenSegments.clear();
    _stopping = false;

    final dir      = await _recordingsDir;
    final now      = DateTime.now();
    final safeName = channelName
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final fileName = '${safeName}_$stamp.ts';
    final filePath = '$dir/$fileName';

    final info = RecordingInfo(
      channelName: channelName,
      filePath:    filePath,
      startTime:   now,
    );
    _active = info;
    _sink   = File(filePath).openWrite(mode: FileMode.write);

    final m3u8Url = _toM3u8Url(streamUrl);
    _startPolling(m3u8Url, info);
    return info;
  }

  /// Converte URL .ts → .m3u8 para obter a playlist HLS
  String _toM3u8Url(String url) {
    final uri = Uri.parse(url);
    final path = uri.path;
    if (path.endsWith('.ts')) {
      final newPath = '${path.substring(0, path.length - 3)}.m3u8';
      return uri.replace(path: newPath).toString();
    }
    if (!path.endsWith('.m3u8')) {
      return '$url.m3u8';
    }
    return url;
  }

  void _startPolling(String m3u8Url, RecordingInfo info) {
    // Primeira busca imediata
    _downloadNewSegments(m3u8Url, info);
    // Polling a cada 3 segundos
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_stopping) _downloadNewSegments(m3u8Url, info);
    });
  }

  Future<void> _downloadNewSegments(String m3u8Url, RecordingInfo info) async {
    try {
      final resp = await http
          .get(Uri.parse(m3u8Url))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;

      // Detecta sub-playlist (master m3u8)
      final lines = resp.body.split('\n');
      String? segPlaylist;
      for (final line in lines) {
        final t = line.trim();
        if (t.isNotEmpty && !t.startsWith('#')) {
          // Se contém bandwidth/resolution, é sub-stream — pega o primeiro
          if (segPlaylist == null) {
            segPlaylist = t.startsWith('http') ? t : _resolveUrl(m3u8Url, t);
          }
        }
      }

      // Se for master m3u8, busca a sub-playlist
      final playlistUrl = (resp.body.contains('EXT-X-STREAM-INF') && segPlaylist != null)
          ? segPlaylist
          : m3u8Url;

      final playlistResp = playlistUrl == m3u8Url
          ? resp
          : await http.get(Uri.parse(playlistUrl)).timeout(const Duration(seconds: 10));

      if (playlistResp.statusCode != 200) return;

      final segLines = playlistResp.body.split('\n');
      final baseUrl  = playlistUrl.substring(0, playlistUrl.lastIndexOf('/') + 1);

      for (final line in segLines) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;

        final segUrl = t.startsWith('http') ? t : '$baseUrl$t';
        if (_seenSegments.contains(segUrl)) continue;
        _seenSegments.add(segUrl);

        if (_stopping || _sink == null) break;

        try {
          final segResp = await http
              .get(Uri.parse(segUrl))
              .timeout(const Duration(seconds: 15));
          if (segResp.statusCode == 200 && _sink != null) {
            _sink!.add(segResp.bodyBytes);
            info.bytesRecorded += segResp.bodyBytes.length;
            onUpdate?.call();
          }
        } catch (_) {
          // Segmento falhou — continua
        }
      }
    } catch (_) {
      // Erro de rede — tenta novamente no próximo ciclo
    }
  }

  String _resolveUrl(String base, String relative) {
    final baseDir = base.substring(0, base.lastIndexOf('/') + 1);
    return '$baseDir$relative';
  }

  // ── Parar gravação ─────────────────────────────────────────────────────────

  Future<void> stopRecording() async {
    _stopping = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _active?.endTime = DateTime.now();
    _active = null;
    _seenSegments.clear();
    onUpdate?.call();
  }

  // ── Listar gravações salvas ────────────────────────────────────────────────

  Future<List<SavedRecording>> getSavedRecordings() async {
    try {
      final dir = Directory(await _recordingsDir);
      if (!dir.existsSync()) return [];

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.ts'))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));

      return files.map((f) {
        final stat      = f.statSync();
        final fileName  = f.path.split(Platform.pathSeparator).last;
        final noExt     = fileName.replaceAll('.ts', '');
        // Nome está antes do sufixo de data (últimos 2 segmentos separados por _)
        final parts     = noExt.split('_');
        final nameParts = parts.length > 2
            ? parts.sublist(0, parts.length - 2)
            : parts;
        final name = nameParts.join(' ');
        return SavedRecording(
          filePath:    f.path,
          channelName: name.isEmpty ? noExt : name,
          recordedAt:  stat.modified,
          sizeBytes:   stat.size,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteRecording(String filePath) async {
    try {
      final f = File(filePath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
