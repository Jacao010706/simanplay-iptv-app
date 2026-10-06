import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/epg_service.dart';

/// Controles do player pensados para o controle remoto da TV (e toque).
///
/// Com os controles escondidos:
///   OK            -> pausa / continua
///   esquerda/dir. -> volta / avanca 10s (filmes, series, gravacoes)
///   cima/baixo    -> mostra os controles
/// Com os controles na tela: setas andam entre os botoes e OK aciona.
/// Teclas de midia (play/pause, avancar, voltar) funcionam sempre.
/// Canal ao vivo com [programs]: painel "AGORA" acima dos botoes e botao
/// Programacao, que abre a grade na lateral (cima/baixo escolhem, OK agenda,
/// Voltar ou seta esquerda fecha).
class PlayerRemoteControls extends StatefulWidget {
  const PlayerRemoteControls({
    super.key,
    required this.child,
    required this.title,
    required this.paused,
    required this.onPlayPause,
    required this.onBack,
    this.subtitle,
    this.onSeek,
    this.onRecord,
    this.recording = false,
    this.recordingInfo,
    this.programs,
    this.programsLoading = false,
    this.isScheduled,
    this.onToggleSchedule,
    this.clock,
  });

  final Widget child;
  final String title;
  final String? subtitle;
  final bool paused;
  final VoidCallback onPlayPause;
  final VoidCallback onBack;
  /// null = conteudo ao vivo (sem avancar/voltar)
  final void Function(int seconds)? onSeek;
  /// null = sem botao de gravar
  final VoidCallback? onRecord;
  final bool recording;
  /// Texto do selo "REC" (null = nao esta gravando este canal)
  final String? recordingInfo;
  /// Programacao do canal ao vivo (null = sem programacao, ex.: filmes;
  /// vazia = "Programacao indisponivel")
  final List<EpgProgram>? programs;
  final bool programsLoading;
  final bool Function(EpgProgram program)? isScheduled;
  /// Agenda ou desagenda a gravacao do programa (null = sem botao Agendar)
  final Future<void> Function(EpgProgram program)? onToggleSchedule;
  /// So para testes: relogio usado para "agora"
  final DateTime Function()? clock;

  static const hideAfter = Duration(seconds: 5);

  @override
  State<PlayerRemoteControls> createState() => PlayerRemoteControlsState();
}

class PlayerRemoteControlsState extends State<PlayerRemoteControls> {
  // O player controla sozinho qual botao esta selecionado (nao usa o foco do
  // Flutter nos botoes): o foco fica sempre aqui e as teclas sao tratadas
  // de forma previsivel em qualquer TV.
  final FocusNode _rootFocus = FocusNode(debugLabel: 'player-root');
  bool _visible = true;
  String? _selected; // 'back', 'rew', 'play', 'fwd', 'rec', 'guide' ou null
  Timer? _hideTimer;
  bool _guideOpen = false;
  int _guideIndex = 0;
  final ScrollController _guideScroll = ScrollController();
  static const double _guideItemHeight = 92;

  bool get controlsVisible => _visible;
  String? get selectedButton => _visible ? _selected : null;
  bool get guideOpen => _guideOpen;
  int get guideSelected => _guideIndex;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  List<String> get _bottomRow => [
        if (widget.onSeek != null) 'rew',
        'play',
        if (widget.onSeek != null) 'fwd',
        if (widget.onRecord != null) 'rec',
        if (widget.programs != null) 'guide',
      ];

  /// Ate 10 programas que ainda nao terminaram (o atual primeiro)
  List<EpgProgram> get _guidePrograms {
    final now = _now();
    return (widget.programs ?? const <EpgProgram>[])
        .where((p) => p.end.isAfter(now))
        .take(10)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _scheduleHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rootFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(PlayerRemoteControls old) {
    super.didUpdateWidget(old);
    if (old.paused != widget.paused) {
      if (widget.paused) {
        _hideTimer?.cancel(); // pausado: controles ficam na tela
        if (!_visible) setState(() => _visible = true);
      } else {
        _scheduleHide();
      }
    }
    if (_selected != null && _selected != 'back' && !_bottomRow.contains(_selected)) {
      _selected = 'play';
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _rootFocus.dispose();
    _guideScroll.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    // Pausado ou com a programacao aberta: os controles ficam na tela
    if (widget.paused || _guideOpen) return;
    _hideTimer = Timer(PlayerRemoteControls.hideAfter, () {
      if (!mounted || widget.paused) return;
      setState(() {
        _visible = false;
        _selected = null;
      });
    });
  }

  void _show({bool select = true}) {
    setState(() {
      _visible = true;
      if (select) _selected ??= 'play';
    });
    _scheduleHide();
  }

  void _activate(String id) {
    switch (id) {
      case 'back':
        widget.onBack();
        break;
      case 'rew':
        widget.onSeek?.call(-10);
        break;
      case 'fwd':
        widget.onSeek?.call(10);
        break;
      case 'rec':
        widget.onRecord?.call();
        break;
      case 'guide':
        _openGuide();
        return;
      default:
        widget.onPlayPause();
    }
    _scheduleHide();
  }

  void _openGuide() {
    _hideTimer?.cancel();
    setState(() {
      _visible = true;
      _selected = 'guide';
      _guideOpen = true;
      _guideIndex = 0;
    });
  }

  void _closeGuide() {
    setState(() => _guideOpen = false);
    _scheduleHide();
  }

  void _moveGuide(int delta) {
    final n = _guidePrograms.length;
    if (n == 0) return;
    setState(() => _guideIndex = (_guideIndex + delta).clamp(0, n - 1));
    // Mantem o item escolhido visivel na lista
    if (_guideScroll.hasClients) {
      final pos = _guideScroll.position;
      final top = _guideIndex * _guideItemHeight;
      final bottom = top + _guideItemHeight;
      if (top < pos.pixels) {
        _guideScroll.jumpTo(top);
      } else if (bottom > pos.pixels + pos.viewportDimension) {
        _guideScroll.jumpTo((bottom - pos.viewportDimension).clamp(0.0, pos.maxScrollExtent));
      }
    }
  }

  Future<void> _toggleSchedule(EpgProgram p) async {
    final toggle = widget.onToggleSchedule;
    if (toggle == null || !p.end.isAfter(_now())) return;
    await toggle(p);
    if (mounted) setState(() {});
  }

  static bool _isBack(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.goBack ||
      k == LogicalKeyboardKey.escape ||
      k == LogicalKeyboardKey.browserBack;

  KeyEventResult _onGuideKey(LogicalKeyboardKey k, bool down) {
    if (_isOk(k)) {
      if (down) {
        final list = _guidePrograms;
        if (_guideIndex < list.length) _toggleSchedule(list[_guideIndex]);
      }
      return KeyEventResult.handled;
    }
    if (_isBack(k) || k == LogicalKeyboardKey.arrowLeft) {
      if (down) _closeGuide();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      _moveGuide(k == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  void _move(LogicalKeyboardKey k) {
    final row = _bottomRow;
    setState(() {
      final cur = _selected ?? 'play';
      if (k == LogicalKeyboardKey.arrowUp) {
        _selected = 'back';
      } else if (k == LogicalKeyboardKey.arrowDown) {
        if (cur == 'back') _selected = 'play';
      } else if (cur != 'back') {
        final i = row.indexOf(cur);
        final d = k == LogicalKeyboardKey.arrowRight ? 1 : -1;
        _selected = row[(i + d).clamp(0, row.length - 1)];
      }
    });
    _scheduleHide();
  }

  static bool _isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  static bool _isArrow(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.arrowUp ||
      k == LogicalKeyboardKey.arrowDown ||
      k == LogicalKeyboardKey.arrowLeft ||
      k == LogicalKeyboardKey.arrowRight;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final down = e is KeyDownEvent;

    // Teclas de midia: sempre
    if (k == LogicalKeyboardKey.mediaPlayPause ||
        k == LogicalKeyboardKey.mediaPlay ||
        k == LogicalKeyboardKey.mediaPause) {
      if (down) {
        widget.onPlayPause();
        _show(select: false);
      }
      return KeyEventResult.handled;
    }
    if (widget.onSeek != null &&
        (k == LogicalKeyboardKey.mediaFastForward || k == LogicalKeyboardKey.mediaRewind)) {
      widget.onSeek!(k == LogicalKeyboardKey.mediaFastForward ? 30 : -30);
      _show(select: false);
      return KeyEventResult.handled;
    }

    if (_guideOpen) return _onGuideKey(k, down);

    final hasSelection = _visible && _selected != null;

    if (_isOk(k)) {
      if (!down) return KeyEventResult.handled;
      if (hasSelection) {
        _activate(_selected!);
      } else {
        widget.onPlayPause();
        _show(select: false);
      }
      return KeyEventResult.handled;
    }

    if (_isArrow(k)) {
      if (hasSelection) {
        _move(k);
      } else if (widget.onSeek != null &&
          (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight)) {
        widget.onSeek!(k == LogicalKeyboardKey.arrowRight ? 10 : -10);
        _show(select: false);
      } else {
        _show();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _button({
    required String id,
    required IconData icon,
    required String label,
    double size = 30,
    Color? color,
  }) {
    final sel = selectedButton == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () {
            setState(() => _selected = id);
            _activate(id);
          },
          child: AnimatedScale(
            scale: sel ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              key: ValueKey('player-btn-$id'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sel ? Colors.white24 : Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
              ),
              child: Icon(icon, size: size, color: color ?? Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recordingInfo;
    // Voltar do sistema com a programacao aberta: fecha a grade, nao o player
    return PopScope(
      canPop: !_guideOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _guideOpen) _closeGuide();
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(fit: StackFit.expand, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_visible) {
              setState(() {
                _visible = false;
                _selected = null;
              });
            } else {
              _show(select: false);
            }
          },
          child: widget.child,
        ),
        if (widget.paused)
          const IgnorePointer(
            child: Center(
              child: Icon(Icons.pause_circle_filled, color: Colors.white70, size: 84),
            ),
          ),
        if (rec != null)
          Positioned(
            top: 14,
            right: 18,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                  const SizedBox(width: 6),
                  Text(rec,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        if (_visible) ...[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                ),
              ),
              child: Row(children: [
                _button(id: 'back', icon: Icons.arrow_back, label: 'Voltar', size: 22),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
                if (widget.subtitle != null)
                  Text(widget.subtitle!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (rec != null) const SizedBox(width: 130),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.onSeek != null)
                _button(id: 'rew', icon: Icons.replay_10, label: 'Voltar 10s'),
              _button(
                id: 'play',
                icon: widget.paused ? Icons.play_arrow : Icons.pause,
                label: widget.paused ? 'Continuar' : 'Pausar',
                size: 40,
              ),
              if (widget.onSeek != null)
                _button(id: 'fwd', icon: Icons.forward_10, label: 'Avancar 10s'),
              if (widget.onRecord != null)
                _button(
                  id: 'rec',
                  icon: widget.recording ? Icons.stop : Icons.fiber_manual_record,
                  label: widget.recording ? 'Parar gravacao' : 'Gravar',
                  color: Colors.redAccent,
                ),
              if (widget.programs != null)
                _button(id: 'guide', icon: Icons.list_alt, label: 'Programacao'),
            ]),
          ),
          if (widget.programs != null && !_guideOpen)
            Positioned(left: 24, right: 24, bottom: 104, child: _nowPanel()),
          if (_guideOpen) _guidePanel(),
        ],
        ]),
      ),
    );
  }

  static const _panelColor = Color(0xCC000000);

  /// "AGORA 20:00-21:00 Titulo", barra de progresso e os proximos 3
  Widget _nowPanel() {
    final now = _now();
    final programs = widget.programs!;
    final atual = currentProgram(programs, now);
    final proximos = upcomingPrograms(programs, now, 3);
    Widget body;
    if (atual == null && proximos.isEmpty) {
      body = Text(
        widget.programsLoading ? 'Carregando programacao...' : 'Programacao indisponivel',
        style: const TextStyle(color: Colors.white54, fontSize: 13),
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (atual != null) ...[
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
              child: const Text('AGORA',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Text('${formatHm(atual.start)}–${formatHm(atual.end)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(atual.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              key: const ValueKey('epg-progress'),
              value: programProgress(atual, now),
              minHeight: 3,
              backgroundColor: Colors.white24,
              color: Colors.redAccent,
            ),
          ),
        ],
        for (final p in proximos)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${formatHm(p.start)}  ${p.title}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ]);
    }
    return IgnorePointer(
      child: Container(
        key: const ValueKey('epg-now-panel'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: _panelColor, borderRadius: BorderRadius.circular(10)),
        child: body,
      ),
    );
  }

  /// Grade na lateral direita (~40% da largura)
  Widget _guidePanel() {
    final list = _guidePrograms;
    final now = _now();
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.4,
        heightFactor: 1,
        child: Container(
          key: const ValueKey('epg-guide-panel'),
          color: const Color(0xEE0d0b14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(children: [
                const Icon(Icons.list_alt, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Programacao',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                GestureDetector(
                  onTap: _closeGuide,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, color: Colors.white54, size: 20),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        widget.programsLoading ? 'Carregando programacao...' : 'Programacao indisponivel',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      controller: _guideScroll,
                      itemExtent: _guideItemHeight,
                      itemCount: list.length,
                      itemBuilder: (_, i) => _guideItem(list[i], i, now),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _guideItem(EpgProgram p, int i, DateTime now) {
    final sel = i == _guideIndex;
    final agendada = widget.isScheduled?.call(p) ?? false;
    final noAr = p.isOnAt(now);
    return GestureDetector(
      onTap: () {
        setState(() => _guideIndex = i);
        _toggleSchedule(p);
      },
      child: Container(
        key: ValueKey('epg-guide-item-$i'),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${formatHm(p.start)}–${formatHm(p.end)}${noAr ? '  •  no ar' : ''}',
                    style: TextStyle(color: noAr ? Colors.redAccent : Colors.white54, fontSize: 11)),
                Text(p.title,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (p.description.isNotEmpty)
                  Text(p.description,
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (widget.onToggleSchedule != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: agendada ? Colors.green.withValues(alpha: 0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(agendada ? Icons.check_circle : Icons.alarm_add,
                    size: 14, color: agendada ? Colors.greenAccent : Colors.redAccent),
                const SizedBox(width: 4),
                Text(agendada ? 'Agendada' : 'Agendar',
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}
