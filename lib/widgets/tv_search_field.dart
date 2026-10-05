import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de busca que funciona com o controle remoto.
///
/// Ao receber o foco pelas setas ele fica somente leitura: o teclado do sistema
/// nao abre sozinho e cima/baixo levam o foco para fora do campo (para a lista).
/// OK (ou toque, no celular) ativa a edicao e abre o teclado; cima/baixo ou
/// confirmar a busca encerram a edicao.
class TvSearchField extends StatefulWidget {
  const TvSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.decoration = const InputDecoration(),
    this.style,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final InputDecoration decoration;
  final TextStyle? style;

  @override
  State<TvSearchField> createState() => _TvSearchFieldState();
}

class _TvSearchFieldState extends State<TvSearchField> {
  final _focusNode = FocusNode(debugLabel: 'TvSearchField');
  bool _editing = false;

  static bool _isActivateKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.select ||
      k == LogicalKeyboardKey.enter ||
      k == LogicalKeyboardKey.numpadEnter ||
      k == LogicalKeyboardKey.gameButtonA;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _stopEditing();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (_editing) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _focusNode.requestFocus();
      // O campo ja estava focado (somente leitura): pede a conexao com o teclado.
      _focusNode.context?.findAncestorStateOfType<EditableTextState>()?.requestKeyboard();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _stopEditing() {
    if (_editing && mounted) setState(() => _editing = false);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (!_editing && _isActivateKey(key)) {
      _startEditing();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      FocusManager.instance.primaryFocus?.focusInDirection(
          key == LogicalKeyboardKey.arrowUp ? TraversalDirection.up : TraversalDirection.down);
      _stopEditing();
      return KeyEventResult.handled;
    }
    if (!_editing && (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight)) {
      FocusManager.instance.primaryFocus?.focusInDirection(
          key == LogicalKeyboardKey.arrowLeft ? TraversalDirection.left : TraversalDirection.right);
      return KeyEventResult.handled;
    }
    // Em edicao, esquerda/direita movem o cursor no texto.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKeyEvent,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        readOnly: !_editing,
        showCursor: _editing,
        style: widget.style,
        decoration: widget.decoration,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onTap: _startEditing,
        onSubmitted: (_) => _stopEditing(),
      ),
    );
  }
}
