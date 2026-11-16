import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/jogos_lista.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import 'ao_vivo_loader.dart';
import 'grade_esportes_service.dart';

/// Jogos do plano B prontos para a tela, com os canais de cada um.
class JogosEncontrados {
  final List<JogoDaLista> jogos;

  /// A lista tem dados (eventos com data ou grade) para o dia pedido. Sem dados, a tela
  /// diz "Sua lista não traz a programação de jogos para esta data."
  final bool temDadosDoDia;

  /// Dias (00:00) com dados na lista: a tela esconde "Ontem" quando ontem não está aqui.
  final Set<DateTime> diasComDados;

  const JogosEncontrados(this.jogos, {this.temDadosDoDia = true, this.diasComDados = const {}});
  Map<int, List<Channel>> get canaisPorJogo => {for (final j in jogos) j.id: j.canais};
}

typedef CarregarCanais = Future<List<Channel>> Function(AppSession session);
typedef CarregarGrade = Future<List<ProgramaGrade>> Function(AppSession session, List<Channel> canaisDeEsporte, {DateTime? ate});

/// Plano B da aba Jogos: jogos tirados da lista do cliente (nomes dos canais de evento
/// e grade dos canais de esporte), quando o backend de jogos não responde.
class JogosDaListaService {
  JogosDaListaService({CarregarCanais? carregarCanais, CarregarGrade? carregarGrade, this.ttl = const Duration(minutes: 15)})
      : _carregarCanais = carregarCanais ?? _canaisAoVivo,
        _carregarGrade = carregarGrade ?? GradeEsportesService.instance.programas;

  static final JogosDaListaService instance = JogosDaListaService();

  final CarregarCanais _carregarCanais;
  final CarregarGrade _carregarGrade;
  final Duration ttl;

  // Análise da lista e grade por sessão (a grade também fica em disco por 60 min)
  String? _chave;
  DateTime? _em;
  Future<AnaliseDaLista>? _analise;

  static Future<List<Channel>> _canaisAoVivo(AppSession s) async => (await CarregadorAoVivo.carregar(s)).canais;

  static String _chaveDa(AppSession s) =>
      '${s.type}|${s.effectiveXtreamHost}|${s.effectiveXtreamUsername}|${s.effectiveXtreamPassword}|${s.primaryM3uUrl}';

  void _validar(AppSession s) {
    final chave = _chaveDa(s);
    final em = _em;
    if (chave == _chave && em != null && DateTime.now().difference(em) < ttl) return;
    _chave = chave;
    _em = DateTime.now();
    _analise = null;
  }

  Future<AnaliseDaLista> _analisar(AppSession s) {
    _validar(s);
    final atual = _analise;
    if (atual != null) return atual;
    final f = () async {
      final canais = await _carregarCanais(s);
      // Fora da interface: listas grandes têm milhares de canais
      return compute(analisarCanais, (canais, agoraEmBrasilia()));
    }();
    _analise = f;
    f.catchError((_) {
      if (identical(_analise, f)) _analise = null; // erro não fica guardado
      return const AnaliseDaLista([], []);
    });
    return f;
  }

  /// Grade dos canais de esporte (o serviço da grade guarda em disco e evita pedidos
  /// repetidos). Para dias depois de hoje (Amanhã), pede a grade até 23:00 desse dia: se o
  /// xmltv não chegar lá, o serviço complementa canal a canal.
  Future<List<ProgramaGrade>> _programas(AppSession s, List<Channel> canais, DateTime dia) {
    final hoje = agoraEmBrasilia();
    final futuro = _diaDe(dia).isAfter(_diaDe(hoje));
    return _carregarGrade(s, canais, ate: futuro ? DateTime(dia.year, dia.month, dia.day, 23) : null)
        .catchError((_) => const <ProgramaGrade>[]);
  }

  static DateTime _diaDe(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Jogos de [dia]. [parcial] recebe primeiro os jogos dos nomes dos canais e depois
  /// os da grade. Lista sem jogos (ou que não carregou): vazio.
  Future<JogosEncontrados> buscar(
    AppSession session,
    DateTime dia, {
    void Function(JogosEncontrados parcial)? parcial,
  }) async {
    final AnaliseDaLista analise;
    try {
      analise = await _analisar(session);
    } catch (_) {
      return const JogosEncontrados([], temDadosDoDia: false);
    }
    final dosNomes = [
      for (final j in analise.jogosDosNomes)
        if (mesmoDia(j.inicio, dia)) j,
    ];
    final diasNomes = {for (final j in analise.jogosDosNomes) _diaDe(j.inicio)};
    parcial?.call(JogosEncontrados(juntarJogos(dosNomes), diasComDados: diasNomes));

    final programas = await _programas(session, analise.canaisParaEpg, dia);
    final dias = {...diasNomes, for (final p in programas) _diaDe(p.inicio)};
    final canais = {for (final c in analise.canaisParaEpg) c.id: c};
    final daGrade = jogosDaGrade(programas, dia, dosNomes, canais);
    return JogosEncontrados(
      juntarJogos([...dosNomes, ...daGrade]),
      temDadosDoDia: dias.contains(_diaDe(dia)),
      diasComDados: dias,
    );
  }
}
