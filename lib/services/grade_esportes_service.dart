import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/jogos_lista.dart';
import '../core/user_agent.dart';
import '../models/app_session.dart';
import '../models/channel.dart';

/// Grade dos canais de esporte para o plano B da aba Jogos, com o mínimo de pedidos ao
/// painel (contas com max_connections 1 são bloqueadas por excesso de chamadas):
/// 1) cópia em disco com menos de 60 min: nenhum pedido;
/// 2) xmltv.php: a grade de todos os canais num único download (até [limiteXmltv]);
/// 3) sem xmltv.php: get_simple_data_table só nos canais mais relevantes (até 25),
///    2 pedidos por vez, com intervalo entre eles.
/// Conta recusada (auth 0, 401, 403, 429): para na hora e usa o que já tiver.
/// A cópia em disco é por dia: dias que o painel já não manda (ontem) ficam guardados.
class GradeEsportesService {
  GradeEsportesService({
    this.client,
    this.validade = const Duration(minutes: 60),
    this.limiteXmltv = 25 * 1024 * 1024,
    this.intervalo = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  static final GradeEsportesService instance = GradeEsportesService();

  http.Client? client;
  final Duration validade;
  final int limiteXmltv;
  final Duration intervalo;
  final DateTime Function() clock;

  http.Client? _cliente;

  /// Pedidos feitos ao painel desde que o serviço foi criado (para testes/diagnóstico).
  int pedidos = 0;

  static String _chaveDisco(AppSession s) {
    // Sem senha na chave: hash de host + usuário
    var h = 0x811c9dc5;
    for (final c in '${s.effectiveXtreamHost}|${s.effectiveXtreamUsername}'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return 'grade_jogos_v2_$h';
  }

  // Pedido em andamento por sessão (telas abertas juntas fazem um pedido só)
  final Map<String, Future<List<ProgramaGrade>>> _andamento = {};

  /// Programas que parecem jogo dos [canaisDeEsporte], de todos os dias disponíveis.
  /// [ate]: a tela precisa da grade até este horário (ex.: 23:00 de amanhã). Se a cópia
  /// em disco / o xmltv não chegarem lá, complementa canal a canal (até 25 canais), no
  /// máximo uma vez a cada 60 min.
  Future<List<ProgramaGrade>> programas(AppSession session, List<Channel> canaisDeEsporte, {DateTime? ate}) {
    if (!session.hasXtreamAccess || canaisDeEsporte.isEmpty) return Future.value(const []);
    final k = '${_chaveDisco(session)}|${ate?.millisecondsSinceEpoch}';
    // Sem "=>" no whenComplete: remove() devolve este mesmo Future e ele esperaria por si mesmo
    final f = _andamento[k] ??= _programas(session, canaisDeEsporte, ate).whenComplete(() {
      _andamento.remove(k);
    });
    return f;
  }

  Future<List<ProgramaGrade>> _programas(AppSession session, List<Channel> canaisDeEsporte, DateTime? ate) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = _chaveDisco(session);
    var salvo = _ler(prefs.getString(chave));
    final agora = clock();
    final ids = {for (final c in canaisDeEsporte) c.id};

    Future<void> guardar(_Grade g) async {
      try {
        await prefs.setString(chave, jsonEncode(g.toJson()));
      } catch (_) {}
      salvo = g;
    }

    // 1) Grade geral (xmltv ou canal a canal), no máximo a cada 60 min
    if (salvo == null || agora.difference(salvo!.em) >= validade) {
      _Leitura? nova;
      var recusou = false;
      try {
        nova = await _xmltv(session, canaisDeEsporte);
        nova ??= await _canalACanal(session, canaisRelevantes(canaisDeEsporte));
      } on _ContaRecusada catch (e) {
        nova = _Leitura(e.parcial, null);
        recusou = true;
      } catch (_) {}
      if (nova != null) {
        await guardar(_juntar(salvo, nova, ids, agora, completo: false));
      }
      if (recusou) return salvo?.programas ?? const [];
    }

    // 2) Falta grade para o dia pedido (xmltv curto): complemento canal a canal
    final g = salvo;
    if (g != null && ate != null && (g.ate == null || g.ate!.isBefore(ate)) &&
        (g.complementoEm == null || agora.difference(g.complementoEm!) >= validade)) {
      _Leitura? extra;
      try {
        extra = await _canalACanal(session, canaisRelevantes(canaisDeEsporte));
      } on _ContaRecusada catch (e) {
        extra = _Leitura(e.parcial, null);
      } catch (_) {}
      await guardar(_juntar(g, extra ?? const _Leitura([], null), ids, agora, completo: true));
    }
    return salvo?.programas ?? const [];
  }

  /// Junta a leitura nova com a guardada. Por dia: os dias que vieram agora substituem os
  /// guardados; os outros (até 3 dias atrás) continuam. [completo]: foi o complemento
  /// canal a canal (só soma dias/programas, não reinicia a validade da grade geral).
  _Grade _juntar(_Grade? salvo, _Leitura nova, Set<String> ids, DateTime agora, {required bool completo}) {
    final limite = DateTime(agora.year, agora.month, agora.day).subtract(const Duration(days: 3));
    final List<ProgramaGrade> programas;
    if (completo) {
      // Complemento: só os canais/dias que ele trouxe substituem
      final chaves = {for (final p in nova.programas) '${p.canal}|${_dia(p.inicio)}'};
      programas = [
        ...?salvo?.programas.where((p) => !chaves.contains('${p.canal}|${_dia(p.inicio)}')),
        ...nova.programas,
      ];
    } else {
      final diasNovos = {for (final p in nova.programas) _dia(p.inicio)};
      programas = [
        ...?salvo?.programas.where((p) => !diasNovos.contains(_dia(p.inicio))),
        ...nova.programas,
      ];
    }
    DateTime? ate = salvo?.ate;
    final n = nova.ate;
    if (n != null && (ate == null || n.isAfter(ate))) ate = n;
    return _Grade(
      em: completo ? (salvo?.em ?? agora) : agora,
      complementoEm: completo ? agora : salvo?.complementoEm,
      ate: ate,
      programas: programas.where((p) => p.inicio.isAfter(limite) && ids.contains(p.canal)).toList(),
    );
  }

  static String _dia(DateTime d) => '${d.year}-${d.month}-${d.day}';

  _Grade? _ler(String? txt) {
    if (txt == null) return null;
    try {
      return _Grade.fromJson(jsonDecode(txt) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<http.StreamedResponse> _enviar(Uri uri) {
    pedidos++;
    final req = http.Request('GET', uri)..headers.addAll(kIptvHeaders);
    return (client ?? (_cliente ??= http.Client())).send(req).timeout(const Duration(seconds: 60));
  }

  static bool _recusa(int status) => status == 401 || status == 403 || status == 429;

  /// null = o painel não tem xmltv.php (ou é grande demais): tentar canal a canal.
  Future<_Leitura?> _xmltv(AppSession s, List<Channel> canais) async {
    final porEpg = <String, List<String>>{};
    for (final c in canais) {
      final k = c.epgKey;
      if (k != null && k.isNotEmpty) (porEpg[k] ??= []).add(c.id);
    }
    if (porEpg.isEmpty) return null;
    final uri = Uri.parse('${s.effectiveXtreamHost}/xmltv.php').replace(queryParameters: {
      'username': s.effectiveXtreamUsername!,
      'password': s.effectiveXtreamPassword!,
    });
    final http.StreamedResponse res;
    try {
      res = await _enviar(uri);
    } catch (_) {
      return null;
    }
    if (_recusa(res.statusCode)) throw const _ContaRecusada([]);
    if (res.statusCode != 200) return null;
    if ((res.contentLength ?? 0) > limiteXmltv) return null;
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final parte in res.stream.timeout(const Duration(seconds: 90))) {
        bytes.add(parte);
        if (bytes.length > limiteXmltv) return null; // grande demais: para de baixar
      }
    } catch (_) {
      return null;
    }
    final dados = bytes.takeBytes();
    // Decodificação e leitura fora da interface
    final (programas, ate) = await compute(_lerXmltvBytes, (dados, porEpg));
    return _Leitura(programas, ate);
  }

  /// get_simple_data_table nos canais relevantes: 2 por vez, com intervalo.
  Future<_Leitura?> _canalACanal(AppSession s, List<Channel> canais) async {
    if (canais.isEmpty) return null;
    final out = <ProgramaGrade>[];
    var parar = false;
    var algumOk = false;
    final fila = [...canais];
    Future<void> trabalhador() async {
      while (fila.isNotEmpty && !parar) {
        final c = fila.removeAt(0);
        final uri = Uri.parse('${s.effectiveXtreamHost}/player_api.php').replace(queryParameters: {
          'username': s.effectiveXtreamUsername!,
          'password': s.effectiveXtreamPassword!,
          'action': 'get_simple_data_table',
          'stream_id': c.id,
        });
        try {
          final res = await _enviar(uri);
          final corpo = await res.stream.bytesToString().timeout(const Duration(seconds: 30));
          if (_recusa(res.statusCode)) {
            parar = true;
            break;
          }
          if (res.statusCode == 200) {
            final data = jsonDecode(corpo);
            if (data is Map && data['user_info'] is Map && '${(data['user_info'] as Map)['auth']}' != '1') {
              parar = true;
              break;
            }
            algumOk = true;
            out.addAll(programasDoDataTable(data, c.id));
          }
        } catch (_) {}
        if (!parar) await Future.delayed(intervalo);
      }
    }

    await Future.wait([trabalhador(), trabalhador()]);
    if (parar) throw _ContaRecusada(out);
    if (!algumOk) return null;
    DateTime? ate;
    for (final p in out) {
      if (ate == null || p.fim.isAfter(ate)) ate = p.fim;
    }
    return _Leitura(out, ate);
  }
}

class _Leitura {
  final List<ProgramaGrade> programas;
  final DateTime? ate;
  const _Leitura(this.programas, this.ate);
}

/// Cópia em disco: grade dos canais de esporte (só o que parece jogo), por dia.
class _Grade {
  final DateTime em; // última leitura geral (xmltv ou canal a canal)
  final DateTime? complementoEm; // último complemento canal a canal
  final DateTime? ate; // até quando a grade vai
  final List<ProgramaGrade> programas;
  const _Grade({required this.em, this.complementoEm, this.ate, required this.programas});

  Map<String, Object?> toJson() => {
        'em': em.millisecondsSinceEpoch,
        'cc': complementoEm?.millisecondsSinceEpoch,
        'ate': ate?.millisecondsSinceEpoch,
        'p': [for (final p in programas) p.toJson()],
      };

  static _Grade fromJson(Map j) {
    DateTime? d(dynamic v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    return _Grade(
      em: d(j['em'])!,
      complementoEm: d(j['cc']),
      ate: d(j['ate']),
      programas: (j['p'] as List).map(ProgramaGrade.fromJson).whereType<ProgramaGrade>().toList(),
    );
  }
}

class _ContaRecusada implements Exception {
  final List<ProgramaGrade> parcial;
  const _ContaRecusada(this.parcial);
}

(List<ProgramaGrade>, DateTime?) _lerXmltvBytes((Uint8List, Map<String, List<String>>) e) =>
    lerXmltvComCobertura((utf8.decode(e.$1, allowMalformed: true), e.$2));

/// Programas (que parecem jogo) da resposta do get_simple_data_table / get_short_epg.
List<ProgramaGrade> programasDoDataTable(dynamic data, String canal) {
  final lista = data is Map ? data['epg_listings'] : data;
  if (lista is! List) return const [];
  String texto(dynamic v) {
    final t = v?.toString().trim() ?? '';
    if (t.isEmpty) return '';
    if (t.length % 4 == 0 && RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(t)) {
      try {
        return utf8.decode(base64.decode(t)).trim();
      } catch (_) {}
    }
    return t;
  }

  DateTime? hora(dynamic ts) {
    final n = ts is num ? ts.toInt() : int.tryParse('${ts ?? ''}');
    return n == null || n <= 0 ? null : emBrasilia(DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true));
  }

  final out = <ProgramaGrade>[];
  for (final e in lista) {
    if (e is! Map) continue;
    final titulo = texto(e['title']);
    if (!pareceJogo(titulo)) continue;
    final ini = hora(e['start_timestamp']), fim = hora(e['stop_timestamp']);
    if (ini == null || fim == null) continue;
    out.add(ProgramaGrade(canal, titulo, texto(e['description']), ini, fim));
  }
  return out;
}
