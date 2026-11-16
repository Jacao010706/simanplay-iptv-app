import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/jogos_lista.dart';
import '../models/app_session.dart';
import '../models/channel.dart';
import 'ao_vivo_loader.dart';
import 'epg_service.dart';

/// Jogos do plano B prontos para a tela, com os canais de cada um.
class JogosEncontrados {
  final List<JogoDaLista> jogos;
  const JogosEncontrados(this.jogos);
  Map<int, List<Channel>> get canaisPorJogo => {for (final j in jogos) j.id: j.canais};
}

typedef CarregarCanais = Future<List<Channel>> Function(AppSession session);

/// Plano B da aba Jogos: jogos tirados da lista do cliente (nomes dos canais de evento
/// e programação dos canais de esporte), quando o backend de jogos não responde.
class JogosDaListaService {
  JogosDaListaService({CarregarCanais? carregarCanais, EpgService? epg, this.ttl = const Duration(minutes: 15)})
      : _carregarCanais = carregarCanais ?? _canaisAoVivo,
        _epg = epg;

  static final JogosDaListaService instance = JogosDaListaService();

  final CarregarCanais _carregarCanais;
  final EpgService? _epg;
  final Duration ttl;

  // Análise da lista por sessão (a leitura dos canais é feita uma vez a cada 15 min)
  String? _chave;
  DateTime? _em;
  Future<AnaliseDaLista>? _analise;

  static Future<List<Channel>> _canaisAoVivo(AppSession s) async => (await CarregadorAoVivo.carregar(s)).canais;

  static String _chaveDa(AppSession s) =>
      '${s.type}|${s.effectiveXtreamHost}|${s.effectiveXtreamUsername}|${s.effectiveXtreamPassword}|${s.primaryM3uUrl}';

  Future<AnaliseDaLista> _analisar(AppSession s) {
    final chave = _chaveDa(s);
    final em = _em;
    if (_analise != null && chave == _chave && em != null && DateTime.now().difference(em) < ttl) return _analise!;
    _chave = chave;
    _em = DateTime.now();
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

  /// Jogos de [dia]. [parcial] recebe primeiro os jogos dos nomes dos canais e depois
  /// os que a programação for revelando. Lista sem jogos (ou que não carregou): vazio.
  Future<JogosEncontrados> buscar(
    AppSession session,
    DateTime dia, {
    void Function(JogosEncontrados parcial)? parcial,
  }) async {
    final AnaliseDaLista analise;
    try {
      analise = await _analisar(session);
    } catch (_) {
      return const JogosEncontrados([]);
    }
    final dosNomes = [
      for (final j in analise.jogosDosNomes)
        if (mesmoDia(j.inicio, dia)) j,
    ];
    final achados = <JogoDaLista>[...dosNomes];
    JogosEncontrados atual() => JogosEncontrados(juntarJogos(achados));
    parcial?.call(atual());

    final epg = _epg ?? EpgService.instance;
    if (_epg == null) epg.useSession(session);
    if (!epg.isAvailable || analise.canaisParaEpg.isEmpty) return atual();

    var ultimo = DateTime.fromMillisecondsSinceEpoch(0);
    await Future.wait(analise.canaisParaEpg.map((c) async {
      List<EpgProgram> programas;
      try {
        programas = await epg.getEpg(c.id);
      } catch (_) {
        return;
      }
      var novo = false;
      for (final p in programas) {
        // Horário da grade (timestamp) convertido para Brasília; filtro pelo dia escolhido
        final inicio = emBrasilia(p.start);
        if (!mesmoDia(inicio, dia)) continue;
        final j = jogoDoTituloDoPrograma(p.title, inicio, descricao: p.description, fim: emBrasilia(p.end));
        if (j == null) continue;
        // Só jogo marcado como ao vivo, ou que também está nos eventos da lista
        if (!j.aoVivo && !dosNomes.any((n) => mesmoJogo(n, j))) continue;
        j.canais.add(c);
        achados.add(j);
        novo = true;
      }
      final agora = DateTime.now();
      if (novo && agora.difference(ultimo) > const Duration(milliseconds: 700)) {
        ultimo = agora;
        parcial?.call(atual());
      }
    }));
    return atual();
  }
}
