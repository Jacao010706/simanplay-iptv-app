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
  final FocusNode _rootFocus = FocusNode(debugLabel: 'player-root');
  final FocusNode _playFocus = FocusNode(debugLabel: 'player-play');
  bool _visible = true;
  Timer? _hideTimer;

  bool get controlsVisible => _visible;

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
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _rootFocus.dispose();
    _playFocus.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (widget.paused) return;
    _hideTimer = Timer(PlayerRemoteControls.hideAfter, () {
      if (!mounted || widget.paused) return;
      setState(() => _visible = false);
      _rootFocus.requestFocus();
    });
  }

  void _show({bool focusPlay = true}) {
    if (_visible) {
      // Botoes ja estao na tela: foca agora (nao depende de um novo quadro)
      if (focusPlay) _playFocus.requestFocus();
    } else {
      setState(() => _visible = true);
      if (focusPlay) {
        // Botoes aparecem no proximo quadro; foca logo depois
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _visible) _playFocus.requestFocus();
        });
      }
    }
    _scheduleHide();
  }

  static bool _isOk(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

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
        _show(focusPlay: false);
      }
      return KeyEventResult.handled;
    }
    if (widget.onSeek != null &&
        (k == LogicalKeyboardKey.mediaFastForward || k == LogicalKeyboardKey.mediaRewind)) {
      widget.onSeek!(k == LogicalKeyboardKey.mediaFastForward ? 30 : -30);
      _show(focusPlay: false);
      return KeyEventResult.handled;
    }

    // Um botao esta selecionado: navegacao normal entre os botoes
    if (!_rootFocus.hasPrimaryFocus) {
      _scheduleHide();
      return KeyEventResult.ignored;
    }

    if (_isOk(k)) {
      if (down) {
        widget.onPlayPause();
        _show(focusPlay: false);
      }
      return KeyEventResult.handled;
    }
    if (widget.onSeek != null &&
        (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight)) {
      widget.onSeek!(k == LogicalKeyboardKey.arrowRight ? 10 : -10);
      _show(focusPlay: false);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowRight) {
      _show();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    FocusNode? focusNode,
    double size = 30,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: label,
        child: IconButton(
          focusNode: focusNode,
          iconSize: size,
          style: IconButton.styleFrom(backgroundColor: Colors.black54),
          icon: Icon(icon, color: color ?? Colors.white),
          onPressed: () {
            onPressed();
            _scheduleHide();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recordingInfo;
    return Focus(
      focusNode: _rootFocus,
      onKeyEvent: _onKey,
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_visible) {
              setState(() => _visible = false);
              _rootFocus.requestFocus();
            } else {
              _show(focusPlay: false);
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
                _button(icon: Icons.arrow_back, label: 'Voltar', onPressed: widget.onBack, size: 24),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
                if (widget.subtitle != null)
                  Text(widget.subtitle!,
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (rec != null) const SizedBox(width: 110),
              ]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (widget.onSeek != null)
                _button(icon: Icons.replay_10, label: 'Voltar 10s', onPressed: () => widget.onSeek!(-10)),
              _button(
                icon: widget.paused ? Icons.play_arrow : Icons.pause,
                label: widget.paused ? 'Continuar' : 'Pausar',
                onPressed: widget.onPlayPause,
                focusNode: _playFocus,
                size: 44,
              ),
              if (widget.onSeek != null)
                _button(icon: Icons.forward_10, label: 'Avancar 10s', onPressed: () => widget.onSeek!(10)),
              if (widget.onRecord != null)
                _button(
                  icon: widget.recording ? Icons.stop : Icons.fiber_manual_record,
                  label: widget.recording ? 'Parar gravacao' : 'Gravar',
                  onPressed: widget.onRecord!,
                  color: Colors.redAccent,
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}
