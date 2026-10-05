import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gravacao agendada (ex.: "gravar o proximo programa").
class ScheduledRecording {
  final String id;
  final String channelName;
  final String streamUrl;
  final DateTime start;
  final DateTime end;
  final String? title;

  ScheduledRecording({
    required this.id,
    required this.channelName,
    required this.streamUrl,
    required this.start,
    required this.end,
    this.title,
  });

  /// Agenda um programa da grade com folga: comeca 2 min antes e termina
  /// 5 min depois (a grade das emissoras costuma atrasar).
  factory ScheduledRecording.fromProgram({
    required String channelName,
    required String streamUrl,
    required DateTime programStart,
    required DateTime programEnd,
    String? title,
  }) {
    return ScheduledRecording(
      id: '${programStart.millisecondsSinceEpoch}_${channelName.hashCode}',
      channelName: channelName,
      streamUrl: streamUrl,
      start: programStart.subtract(const Duration(minutes: 2)),
      end: programEnd.add(const Duration(minutes: 5)),
      title: title,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelName': channelName,
        'streamUrl': streamUrl,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'title': title,
      };

  factory ScheduledRecording.fromJson(Map<String, dynamic> j) => ScheduledRecording(
        id: j['id'] as String,
        channelName: j['channelName'] as String,
        streamUrl: j['streamUrl'] as String,
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        title: j['title'] as String?,
      );

  String get whenFormatted {
    String hm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final d = start;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${hm(start)} - ${hm(end)}';
  }

  /// Qual agendamento deve estar gravando agora (null = nenhum).
  static ScheduledRecording? due(List<ScheduledRecording> list, DateTime now) {
    for (final s in list) {
      if (!s.start.isAfter(now) && s.end.isAfter(now)) return s;
    }
    return null;
  }

  /// Agendamentos que ja passaram do fim.
  static bool expired(ScheduledRecording s, DateTime now) => !s.end.isAfter(now);
}

/// Informação sobre a gravação ativa
class RecordingInfo {
  final String channelName;
  final String filePath;
  final DateTime startTime;
  DateTime? endTime;
  int bytesRecorded;
  /// Quando a gravacao para sozinha (null = so quando o usuario parar)
  final DateTime? stopAt;
  /// Id do agendamento que iniciou esta gravacao (se houver)
  final String? scheduleId;

  RecordingInfo({
    required this.channelName,
    required this.filePath,
    required this.startTime,
    this.endTime,
    this.bytesRecorded = 0,
    this.stopAt,
    this.scheduleId,
  });

  String? get stopAtFormatted {
    final d = stopAt;
    if (d == null) return null;
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

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

/// Serviço singleton de gravação de canais via HLS
class RecordingService {
  RecordingService._();
  static final RecordingService instance = RecordingService._();

  RecordingInfo? _active;
  Timer? _pollTimer;
  Timer? _stopTimer;
  IOSink? _sink;
  http.Client? _directClient;
  bool _stopping = false;
  final Set<String> _seenSegments = {};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  void Function()? onUpdate;

  /// Relogio (trocado nos testes)
  DateTime Function() now = DateTime.now;

  static const _device = MethodChannel('primetv/device');
  static const _prefsKey = 'recording_schedules';
  final List<ScheduledRecording> _schedules = [];
  Timer? _scheduleTimer;
  bool _initialized = false;

  List<ScheduledRecording> get schedules => List.unmodifiable(_schedules);

  void _notify({bool force = false}) {
    final t = DateTime.now();
    if (!force && t.difference(_lastNotify) < const Duration(seconds: 1)) return;
    _lastNotify = t;
    onUpdate?.call();
  }

  /// Chamado ao abrir o app: carrega os agendamentos e passa a vigia-los.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        _schedules
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .map((e) => ScheduledRecording.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (_) {}
    _scheduleTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkSchedules());
    await checkSchedules();
  }

  Future<void> _saveSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_schedules.map((s) => s.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> addSchedule(ScheduledRecording s) async {
    _schedules.removeWhere((e) => e.id == s.id);
    _schedules.add(s);
    _schedules.sort((a, b) => a.start.compareTo(b.start));
    await _saveSchedules();
    await checkSchedules();
    _notify(force: true);
  }

  Future<void> removeSchedule(String id) async {
    _schedules.removeWhere((e) => e.id == id);
    if (_active?.scheduleId == id) await stopRecording();
    await _saveSchedules();
    _updateKeepAlive();
    _notify(force: true);
  }

  /// Inicia o agendamento que estiver na hora e descarta os vencidos.
  Future<void> checkSchedules() async {
    final t = now();
    final before = _schedules.length;
    _schedules.removeWhere((s) =>
        ScheduledRecording.expired(s, t) && _active?.scheduleId != s.id);
    final due = ScheduledRecording.due(_schedules, t);
    if (due != null && _active?.scheduleId != due.id && _active == null) {
      await startRecording(
        due.title?.isNotEmpty == true ? '${due.channelName} ${due.title}' : due.channelName,
        due.streamUrl,
        duration: due.end.difference(t),
        scheduleId: due.id,
      );
    }
    if (_schedules.length != before) await _saveSchedules();
    _updateKeepAlive();
  }

  /// Mantem o app vivo (servico em primeiro plano + Wi-Fi/CPU acordados)
  /// enquanto grava ou ha gravacao agendada — mesmo com a TV na tela inicial
  /// ou com a tela apagada.
  void _updateKeepAlive() {
    final on = _active != null || _schedules.isNotEmpty;
    final text = _active != null
        ? 'Gravando ${_active!.channelName}'
        : (_schedules.isNotEmpty
            ? 'Gravacao agendada: ${_schedules.first.channelName} ${_schedules.first.whenFormatted}'
            : '');
    _device.invokeMethod('keepAlive', {'on': on, 'text': text}).catchError((_) => null);
  }

  RecordingInfo? get activeRecording => _active;
  bool get isRecording => _active != null;

  Future<String> get _recordingsDir async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/simanplay_gravacoes');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<RecordingInfo> startRecording(
    String channelName,
    String streamUrl, {
    Duration? duration,
    String? scheduleId,
  }) async {
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
    final filePath = '$dir/${safeName}_$stamp.ts';

    final stopAt = (duration != null && duration > Duration.zero) ? now.add(duration) : null;
    final info = RecordingInfo(
      channelName: channelName,
      filePath: filePath,
      startTime: now,
      stopAt: stopAt,
      scheduleId: scheduleId,
    );
    _active = info;
    _sink   = File(filePath).openWrite(mode: FileMode.write);

    if (stopAt != null) {
      _stopTimer = Timer(duration!, () {
        if (_active == info) stopRecording();
      });
    }
    _updateKeepAlive();
    _notify(force: true);

    // Prefere HLS (.m3u8, baixa os pedacos); se o servidor nao oferecer,
    // grava o fluxo continuo (.ts) direto.
    final m3u8Url = _toM3u8Url(streamUrl);
    _isHls(m3u8Url).then((hls) {
      if (_active != info || _stopping) return;
      if (hls) {
        _startPolling(m3u8Url, info);
      } else {
        _runDirect(streamUrl, info);
      }
    });
    return info;
  }

  Future<bool> _isHls(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      return r.statusCode == 200 && r.body.contains('#EXTM3U');
    } catch (_) {
      return false;
    }
  }

  /// Grava o fluxo continuo; se a conexao cair, reconecta e continua
  /// no mesmo arquivo ate a gravacao ser parada.
  Future<void> _runDirect(String url, RecordingInfo info) async {
    while (!_stopping && _active == info) {
      final client = http.Client();
      _directClient = client;
      try {
        final resp = await client
            .send(http.Request('GET', Uri.parse(url)))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          await for (final chunk in resp.stream) {
            if (_stopping || _sink == null || _active != info) break;
            _sink!.add(chunk);
            info.bytesRecorded += chunk.length;
            _notify();
          }
        }
      } catch (_) {
      } finally {
        client.close();
        if (_directClient == client) _directClient = null;
      }
      if (_stopping || _active != info) break;
      await Future.delayed(const Duration(seconds: 3)); // reconectar
    }
  }

  String _toM3u8Url(String url) {
    final uri  = Uri.parse(url);
    final path = uri.path;
    if (path.endsWith('.ts')) {
      return uri.replace(path: '${path.substring(0, path.length - 3)}.m3u8').toString();
    }
    if (!path.endsWith('.m3u8')) return '$url.m3u8';
    return url;
  }

  void _startPolling(String m3u8Url, RecordingInfo info) {
    _downloadNewSegments(m3u8Url, info);
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_stopping) _downloadNewSegments(m3u8Url, info);
    });
  }

  Future<void> _downloadNewSegments(String m3u8Url, RecordingInfo info) async {
    try {
      final resp = await http.get(Uri.parse(m3u8Url)).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;

      final lines = resp.body.split('\n');

      // Detecta master playlist — pega a primeira sub-playlist
      String playlistUrl = m3u8Url;
      if (resp.body.contains('EXT-X-STREAM-INF')) {
        for (final line in lines) {
          final t = line.trim();
          if (t.isNotEmpty && !t.startsWith('#')) {
            playlistUrl = t.startsWith('http') ? t : _resolve(m3u8Url, t);
            break;
          }
        }
      }

      final segResp = playlistUrl == m3u8Url
          ? resp
          : await http.get(Uri.parse(playlistUrl)).timeout(const Duration(seconds: 10));
      if (segResp.statusCode != 200) return;

      final baseUrl = playlistUrl.substring(0, playlistUrl.lastIndexOf('/') + 1);
      for (final line in segResp.body.split('\n')) {
        final t = line.trim();
        if (t.isEmpty || t.startsWith('#')) continue;

        final segUrl = t.startsWith('http') ? t : '$baseUrl$t';
        if (_seenSegments.contains(segUrl)) continue;
        _seenSegments.add(segUrl);
        if (_stopping || _sink == null) break;

        try {
          final seg = await http.get(Uri.parse(segUrl)).timeout(const Duration(seconds: 15));
          if (seg.statusCode == 200 && _sink != null) {
            _sink!.add(seg.bodyBytes);
            info.bytesRecorded += seg.bodyBytes.length;
            _notify();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  String _resolve(String base, String relative) =>
      '${base.substring(0, base.lastIndexOf('/') + 1)}$relative';

  Future<void> stopRecording() async {
    _stopping = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    _stopTimer?.cancel();
    _stopTimer = null;
    _directClient?.close();
    _directClient = null;
    final sink = _sink;
    _sink = null;
    try {
      await sink?.flush();
      await sink?.close();
    } catch (_) {}
    final finished = _active;
    finished?.endTime = DateTime.now();
    _active = null;
    _seenSegments.clear();
    if (finished?.scheduleId != null) {
      _schedules.removeWhere((s) => s.id == finished!.scheduleId);
      await _saveSchedules();
    }
    _updateKeepAlive();
    _notify(force: true);
  }

  Future<List<SavedRecording>> getSavedRecordings() async {
    try {
      final dir = Directory(await _recordingsDir);
      if (!dir.existsSync()) return [];
      final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.ts')).toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      return files.map((f) {
        final stat     = f.statSync();
        final noExt    = f.path.split(Platform.pathSeparator).last.replaceAll('.ts', '');
        final parts    = noExt.split('_');
        final nameParts = parts.length > 2 ? parts.sublist(0, parts.length - 2) : parts;
        return SavedRecording(
          filePath: f.path,
          channelName: nameParts.join(' ').isEmpty ? noExt : nameParts.join(' '),
          recordedAt: stat.modified,
          sizeBytes: stat.size,
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
