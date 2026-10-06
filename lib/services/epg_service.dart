import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import '../models/app_session.dart';
import 'xtream_service.dart';

/// Um programa da grade de um canal (horários já em hora local).
class EpgProgram {
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  bool isOnAt(DateTime t) => !start.isAfter(t) && end.isAfter(t);

  @override
  String toString() => 'EpgProgram(${formatHm(start)}-${formatHm(end)} $title)';
}

/// "20:05"
String formatHm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

final RegExp _base64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
final RegExp _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

/// Título/descrição da grade do Xtream: vêm em base64 (UTF-8); se não for
/// base64 válido, usa o texto como veio.
String decodeEpgText(String? raw) {
  final t = raw?.trim() ?? '';
  if (t.isEmpty) return '';
  if (t.length % 4 == 0 && _base64.hasMatch(t)) {
    try {
      final s = utf8.decode(base64.decode(t)).trim();
      if (!_controlChars.hasMatch(s)) return s;
    } catch (_) {}
  }
  return t;
}

DateTime? _epgTime(Map item, String timestampKey, List<String> textKeys) {
  final ts = item[timestampKey];
  final n = ts is num ? ts.toInt() : int.tryParse('${ts ?? ''}'.trim());
  if (n != null && n > 0) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
  for (final k in textKeys) {
    final raw = item[k]?.toString().trim() ?? '';
    if (raw.isEmpty) continue;
    final d = DateTime.tryParse(raw);
    if (d != null) return d.toLocal();
  }
  return null;
}

/// Lê a resposta do get_short_epg ({"epg_listings": [...]} ou a lista direta).
/// Horários por start_timestamp/stop_timestamp (segundos) ou start/end/stop em
/// texto. Com [now], descarta os que já terminaram. Sai ordenado por início.
List<EpgProgram> parseEpgListings(dynamic data, {DateTime? now}) {
  final list = data is Map ? data['epg_listings'] : data;
  if (list is! List) return const [];
  final out = <EpgProgram>[];
  for (final item in list) {
    if (item is! Map) continue;
    final start = _epgTime(item, 'start_timestamp', const ['start']);
    final end = _epgTime(item, 'stop_timestamp', const ['end', 'stop']);
    if (start == null || end == null || !end.isAfter(start)) continue;
    if (now != null && !end.isAfter(now)) continue;
    out.add(EpgProgram(
      title: decodeEpgText(item['title']?.toString()),
      description: decodeEpgText(item['description']?.toString()),
      start: start,
      end: end,
    ));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// O programa no ar em [now] (null se não houver).
EpgProgram? currentProgram(List<EpgProgram> programs, DateTime now) {
  for (final p in programs) {
    if (p.isOnAt(now)) return p;
  }
  return null;
}

/// Os próximos [count] programas que começam depois de [now].
List<EpgProgram> upcomingPrograms(List<EpgProgram> programs, DateTime now, int count) =>
    programs.where((p) => p.start.isAfter(now)).take(count).toList();

/// Quanto do programa já passou, de 0 a 1.
double programProgress(EpgProgram p, DateTime now) {
  final total = p.end.difference(p.start).inSeconds;
  if (total <= 0) return 0;
  return (now.difference(p.start).inSeconds / total).clamp(0.0, 1.0).toDouble();
}

/// Busca a grade de um canal (stream id) no Xtream.
typedef EpgFetcher = Future<dynamic> Function(String streamId, int limit);

class _CacheEntry {
  final List<EpgProgram> programs;
  final DateTime fetchedAt;
  final Duration ttl;
  _CacheEntry(this.programs, this.fetchedAt, this.ttl);
}

/// Programação dos canais com cache (10 min por canal), no máximo 4
/// requisições ao mesmo tempo e pedidos repetidos reaproveitando o mesmo Future.
class EpgService {
  EpgService({
    this.fetcher,
    DateTime Function()? clock,
    this.cacheTtl = const Duration(minutes: 10),
    this.maxConcurrent = 4,
  }) : clock = clock ?? DateTime.now;

  static final EpgService instance = EpgService();

  static const int maxPrograms = 10;
  // Falha (rede, painel fora): tenta de novo antes dos 10 minutos.
  static const Duration _failureTtl = Duration(minutes: 2);

  EpgFetcher? fetcher;
  DateTime Function() clock;
  final Duration cacheTtl;
  final int maxConcurrent;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<List<EpgProgram>>> _inflight = {};
  final Queue<Completer<void>> _waiting = Queue();
  int _running = 0;
  String? _sessionKey;

  /// Usa as credenciais Xtream da sessão (sem Xtream, não há programação).
  void useSession(AppSession session) {
    if (!session.hasXtreamAccess) {
      _sessionKey = null;
      fetcher = null;
      clearCache();
      return;
    }
    final host = session.effectiveXtreamHost!;
    final user = session.effectiveXtreamUsername!;
    final pass = session.effectiveXtreamPassword!;
    final key = '$host|$user|$pass';
    if (key == _sessionKey && fetcher != null) return;
    _sessionKey = key;
    clearCache();
    final svc = XtreamService(host: host, username: user, password: pass);
    fetcher = (id, limit) => svc.getShortEpg(id, limit: limit);
  }

  bool get isAvailable => fetcher != null;

  void clearCache() {
    _cache.clear();
    _inflight.clear();
  }

  List<EpgProgram> _notEnded(List<EpgProgram> list) {
    final now = clock();
    return list.where((p) => p.end.isAfter(now)).toList();
  }

  /// Grade já em cache e válida (sem acessar a rede); null se não houver.
  List<EpgProgram>? cached(String streamId) {
    final e = _cache[streamId];
    if (e == null || clock().difference(e.fetchedAt) >= e.ttl) return null;
    return _notEnded(e.programs);
  }

  /// Até 10 programas do canal que ainda não terminaram, em ordem.
  Future<List<EpgProgram>> getEpg(String streamId) {
    final hit = cached(streamId);
    if (hit != null) return Future.value(hit);
    final pending = _inflight[streamId];
    if (pending != null) return pending;
    final f = fetcher;
    if (f == null) return Future.value(const []);

    final future = _withSlot(() async {
      try {
        final data = await f(streamId, maxPrograms);
        final programs = parseEpgListings(data).take(maxPrograms).toList();
        _cache[streamId] = _CacheEntry(programs, clock(), cacheTtl);
      } catch (_) {
        _cache[streamId] = _CacheEntry(const [], clock(), _failureTtl);
      }
      return _notEnded(_cache[streamId]!.programs);
    }).whenComplete(() {
      // Sem "=>": remove() devolve este mesmo Future e o whenComplete esperaria por ele
      _inflight.remove(streamId);
    });
    _inflight[streamId] = future;
    return future;
  }

  Future<T> _withSlot<T>(Future<T> Function() task) async {
    if (_running >= maxConcurrent) {
      final c = Completer<void>();
      _waiting.add(c);
      await c.future;
    } else {
      _running++;
    }
    try {
      return await task();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete(); // a vaga passa direto para o próximo
      } else {
        _running--;
      }
    }
  }
}
