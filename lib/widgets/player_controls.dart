import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controles do player pensados para o controle remoto da TV (e toque).
///
/// Com os controles escondidos:
///   OK            -> pausa / continua
///   esquerda/dir. -> volta / avanca 10s (filmes, series, gravacoes)
///   cima/baixo    -> mostra os controles
/// Com os controles na tela: setas andam entre os botoes e OK aciona.
/// Teclas de midia (play/pause, avancar, voltar) funcionam sempre.
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
  String? _selected; // 'back', 'rew', 'play', 'fwd', 'rec' ou null
  Timer? _hideTimer;

  bool get controlsVisible => _visible;
  String? get selectedButton => _visible ? _selected : null;

  List<String> get _bottomRow => [
        if (widget.onSeek != null) 'rew',
        'play',
        if (widget.onSeek != null) 'fwd',
        if (widget.onRecord != null) 'rec',
      ];

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
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.paused) return;
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
      default:
        widget.onPlayPause();
    }
    _scheduleHide();
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
    return Focus(
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
            ]),
          ),
        ],
      ]),
    );
  }
}
