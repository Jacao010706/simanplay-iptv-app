import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/plataforma.dart';

/// Teclado e mouse no PC (Windows). Fora do Windows tudo aqui devolve o [child] sem mudar nada.
///
/// - Esc ou Backspace: volta uma tela (Backspace só quando não há campo de texto em edição).
/// - Setas e Enter já funcionam no app inteiro (navegação feita para o controle remoto).
class AtalhosPc extends StatelessWidget {
  const AtalhosPc({super.key, required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  static bool _editandoTexto() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    if (ctx.widget is EditableText) return true;
    final campo = ctx.findAncestorStateOfType<EditableTextState>();
    return campo != null && !campo.widget.readOnly;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final voltar = k == LogicalKeyboardKey.escape ||
        (k == LogicalKeyboardKey.backspace && !_editandoTexto());
    if (!voltar) return KeyEventResult.ignored;
    final nav = navigatorKey.currentState;
    if (nav == null || !nav.canPop()) return KeyEventResult.ignored;
    nav.maybePop();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!Plataforma.windows) return child;
    return Focus(debugLabel: 'atalhos-pc', canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: child);
  }
}

/// Rolagem no PC: listas também rolam arrastando com o mouse; a roda rola as listas verticais
/// e, com Shift, as fileiras horizontais (padrão do Flutter no desktop).
class RolagemPc extends MaterialScrollBehavior {
  const RolagemPc();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Destaque ao passar o mouse sobre um item clicável (PC): cursor de mão, leve aumento e
/// borda branca, a mesma cor da borda de foco do controle remoto.
class HoverPc extends StatefulWidget {
  const HoverPc({super.key, required this.child, this.ativo = true});

  final Widget child;
  final bool ativo;

  @override
  State<HoverPc> createState() => _HoverPcState();
}

class _HoverPcState extends State<HoverPc> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    if (!Plataforma.windows || !widget.ativo) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: AnimatedScale(
        scale: _sobre ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          foregroundDecoration: _sobre
              ? BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
