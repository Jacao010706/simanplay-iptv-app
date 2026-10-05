import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Atalhos do app: os padroes do Flutter + OK do controle remoto ativando
/// botoes (select / botao A), garantido em qualquer versao.
Map<ShortcutActivator, Intent> get appShortcuts => <ShortcutActivator, Intent>{
      ...WidgetsApp.defaultShortcuts,
      const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
      const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
    };

/// Substituto do GestureDetector para itens clicaveis: alem do toque, o item
/// recebe o foco do controle remoto (setas) e e acionado com OK/Enter.
class TvTap extends StatelessWidget {
  const TvTap({super.key, required this.onTap, required this.child, this.autofocus = false});

  final VoidCallback? onTap;
  final Widget child;
  final bool autofocus;

  static bool _isActivateKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  @override
  Widget build(BuildContext context) {
    return Focus(
      debugLabel: 'TvTap',
      autofocus: autofocus,
      canRequestFocus: onTap != null,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _isActivateKey(event.logicalKey) && onTap != null) {
          onTap!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(onTap: onTap, child: child),
    );
  }
}

/// Desenha uma borda branca em volta do item que esta com o foco do controle
/// remoto, em qualquer tela do app (botoes, listas, cards, menus...).
/// So aparece quando o usuario navega por teclas (controle/teclado), nao no toque.
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child});
  final Widget child;

  static const ringKey = ValueKey('focus-ring');

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> with SingleTickerProviderStateMixin {
  // Acompanha o item por alguns quadros (rolagem/animacao) e depois para,
  // para nao ficar redesenhando a tela o tempo todo.
  late final Ticker _ticker = createTicker((elapsed) {
    _update();
    if (elapsed > const Duration(milliseconds: 700)) _ticker.stop();
  });
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_changed);
    FocusManager.instance.addHighlightModeListener(_modeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_changed);
    FocusManager.instance.removeHighlightModeListener(_modeChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _modeChanged(FocusHighlightMode _) => _changed();

  void _changed() {
    if (!mounted) return;
    if (_target() != null) {
      _burst();
    } else {
      if (_ticker.isActive) _ticker.stop();
      if (_rect != null) setState(() => _rect = null);
    }
  }

  void _burst() {
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
    _update();
  }

  FocusNode? _target() {
    if (FocusManager.instance.highlightMode != FocusHighlightMode.traditional) return null;
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node is FocusScopeNode || node.context == null) return null;
    return node;
  }

  void _update() {
    final node = _target();
    final box = context.findRenderObject() as RenderBox?;
    Rect? next;
    if (node != null && box != null && box.hasSize) {
      try {
        final r = node.rect;
        final local = box.globalToLocal(r.topLeft) & r.size;
        final screen = Offset.zero & box.size;
        // Itens enormes (teclado, player em tela cheia) nao ganham borda
        final big = r.width * r.height > screen.width * screen.height * 0.6;
        if (!big && r.width > 0 && r.height > 0) next = local;
      } catch (_) {}
    }
    if (next != _rect) setState(() => _rect = next);
  }

  @override
  Widget build(BuildContext context) {
    final r = _rect;
    return Stack(fit: StackFit.passthrough, children: [
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          // A rolagem pode acontecer no meio do layout: so agenda a atualizacao
          if (_target() != null && !_ticker.isActive) _ticker.start();
          return false;
        },
        child: widget.child,
      ),
      if (r != null)
        Positioned.fromRect(
          rect: r.inflate(3),
          child: IgnorePointer(
            child: Container(
              key: FocusRing.ringKey,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ),
        ),
    ]);
  }
}
