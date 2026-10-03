import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Teclado customizado navegável via controle remoto (D-pad) para Android TV.
/// Mostra um diálogo com grid de caracteres que responde a setas + OK/Select.
class TvKeyboardDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final bool obscure;

  const TvKeyboardDialog({
    super.key,
    required this.title,
    this.initialValue = '',
    this.obscure = false,
  });

  /// Abre o teclado TV como diálogo. Retorna o texto digitado ou null se cancelado.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    String initialValue = '',
    bool obscure = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TvKeyboardDialog(
        title: title,
        initialValue: initialValue,
        obscure: obscure,
      ),
    );
  }

  @override
  State<TvKeyboardDialog> createState() => _TvKeyboardDialogState();
}

class _TvKeyboardDialogState extends State<TvKeyboardDialog> {
  late String _value;
  int _row = 1; // começa na linha "a"
  int _col = 0;
  bool _caps = false;

  // Layout do teclado — 10 colunas por linha
  static const List<List<String>> _rows = [
    ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j'],
    ['k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't'],
    ['u', 'v', 'w', 'x', 'y', 'z', '.', '@', '-', '_'],
    ['/', ':', '#', '!', '?', ' ', '⌫', '✓', '⇧', '✕'],
  ];

  static const int _kDel = 0; // índice especial — '⌫'
  static const int _kDone = 1; // índice especial — '✓'
  static const int _kCaps = 2; // índice especial — '⇧'
  static const int _kCancel = 3; // índice especial — '✕'

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _pressKey(String key) {
    setState(() {
      switch (key) {
        case '✓':
          Navigator.of(context).pop(_value);
          return;
        case '✕':
          Navigator.of(context).pop(null);
          return;
        case '⌫':
          if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
          return;
        case '⇧':
          _caps = !_caps;
          return;
        case ' ':
          _value += ' ';
          return;
        default:
          _value += _caps ? key.toUpperCase() : key;
      }
    });
  }

  void _move(int dr, int dc) {
    setState(() {
      int newRow = _row + dr;
      if (newRow < 0) newRow = 0;
      if (newRow >= _rows.length) newRow = _rows.length - 1;
      int newCol = _col + dc;
      final maxCol = _rows[newRow].length - 1;
      if (newCol < 0) newCol = 0;
      if (newCol > maxCol) newCol = maxCol;
      _row = newRow;
      _col = newCol;
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        _move(-1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1, 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _move(0, -1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _move(0, 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.gameButtonA:
        _pressKey(_rows[_row][_col]);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
        _pressKey('⌫');
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        Navigator.of(context).pop(null);
        return KeyEventResult.handled;
    }
    // Teclas de caractere digitado diretamente (caso o sistema mande o char)
    final char = event.character;
    if (char != null && char.isNotEmpty) {
      setState(() => _value += char);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: const Color(0xFF1a1625),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              Text(
                widget.title,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              // Visor do texto digitado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                ),
                child: Text(
                  widget.obscure && _value.isNotEmpty
                      ? '•' * _value.length
                      : (_value.isEmpty ? ' ' : _value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              // Grid de teclas
              for (int r = 0; r < _rows.length; r++) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int c = 0; c < _rows[r].length; c++)
                      _buildKey(r, c),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 4),
              // Dica
              const Text(
                '← ↑ ↓ → para navegar • OK para selecionar',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(int r, int c) {
    final key = _rows[r][c];
    final selected = _row == r && _col == c;
    final isSpecial = ['⌫', '✓', '✕', '⇧', ' '].contains(key);
    final displayLabel = _getDisplayLabel(key, r, c);

    Color bgColor;
    Color textColor;
    if (selected) {
      bgColor = const Color(0xFF8B5CF6);
      textColor = Colors.white;
    } else if (key == '✓') {
      bgColor = const Color(0xFF16a34a).withValues(alpha: 0.5);
      textColor = Colors.greenAccent;
    } else if (key == '✕') {
      bgColor = const Color(0xFFdc2626).withValues(alpha: 0.4);
      textColor = Colors.redAccent;
    } else if (key == '⇧') {
      bgColor = _caps
          ? const Color(0xFFd97706).withValues(alpha: 0.7)
          : const Color(0xFF2a2435);
      textColor = _caps ? Colors.amber : Colors.white70;
    } else {
      bgColor = const Color(0xFF2a2435);
      textColor = isSpecial ? Colors.white70 : Colors.white;
    }

    final width = (key == ' ') ? 52.0 : (isSpecial ? 44.0 : 34.0);

    return GestureDetector(
      onTap: () {
        setState(() {
          _row = r;
          _col = c;
        });
        _pressKey(key);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.all(2),
        width: width,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), blurRadius: 8)]
              : null,
        ),
        child: Text(
          displayLabel,
          style: TextStyle(
            color: textColor,
            fontSize: key.length == 1 ? 13 : 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _getDisplayLabel(String key, int r, int c) {
    if (key == ' ') return '⎵';
    if (key == '⇧') return _caps ? '⇪' : '⇧';
    if (key.length == 1 && key.compareTo('a') >= 0 && key.compareTo('z') <= 0) {
      return _caps ? key.toUpperCase() : key;
    }
    return key;
  }
}
