import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'pc_input.dart';

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
      // PC: cursor de mão e destaque ao passar o mouse
      child: HoverPc(ativo: onTap != null, child: GestureDetector(onTap: onTap, child: child)),
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

  /// Parte da tela onde a borda pode aparecer: a área visível das listas em volta do item.
  /// Um item meio escondido atrás da busca ou das categorias não leva a borda por cima delas.
  Rect? _clip;

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
    Rect? clip;
    if (node != null && box != null && box.hasSize) {
      try {
        final r = node.rect;
        final local = box.globalToLocal(r.topLeft) & r.size;
        final screen = Offset.zero & box.size;
        // Itens enormes (teclado, player em tela cheia) nao ganham borda
        final big = r.width * r.height > screen.width * screen.height * 0.6;
        if (!big && r.width > 0 && r.height > 0) {
          next = local;
          clip = _areaVisivel(node.context!, box, screen.inflate(12));
        }
      } catch (_) {}
    }
    if (next != _rect || clip != _clip) {
      setState(() {
        _rect = next;
        _clip = clip;
      });
    }
  }

  /// [base] cortado, no eixo de rolagem, pela área visível de cada lista em volta do item.
  static Rect _areaVisivel(BuildContext item, RenderBox box, Rect base) {
    var area = base;
    var lista = Scrollable.maybeOf(item);
    while (lista != null) {
      final ro = lista.context.findRenderObject();
      if (ro is RenderBox && ro.hasSize && ro.attached) {
        final v = box.globalToLocal(ro.localToGlobal(Offset.zero)) & ro.size;
        area = lista.position.axis == Axis.vertical
            ? Rect.fromLTRB(area.left, math.max(area.top, v.top), area.right, math.min(area.bottom, v.bottom))
            : Rect.fromLTRB(math.max(area.left, v.left), area.top, math.min(area.right, v.right), area.bottom);
      }
      lista = Scrollable.maybeOf(lista.context);
    }
    return area;
  }

  @override
  Widget build(BuildContext context) {
    final r = _rect;
    final clip = _clip;
    return Stack(fit: StackFit.passthrough, children: [
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          // A rolagem pode acontecer no meio do layout: so agenda a atualizacao
          if (_target() != null && !_ticker.isActive) _ticker.start();
          return false;
        },
        child: widget.child,
      ),
      if (r != null && clip != null && clip.width > 0 && clip.height > 0)
        Positioned.fromRect(
          rect: clip,
          child: IgnorePointer(
            child: ClipRect(
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fromRect(
                  rect: r.inflate(3).shift(-clip.topLeft),
                  child: Container(
                    key: FocusRing.ringKey,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}
