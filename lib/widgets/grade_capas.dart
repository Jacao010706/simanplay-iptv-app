import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Grade de capas (Filmes, Séries) que funciona com o controle remoto da TV:
///
/// - uma fileira sempre cabe inteira na área visível da grade (na TV, com a tela baixa, a
///   grade ganha mais colunas em vez de capas mais altas que a própria área);
/// - entre as fileiras sobra espaço para a borda de foco ([FocusRing]);
/// - ao receber o foco, o item rola para o meio da grade, longe da fileira de cima e das
///   opções acima da grade (busca e categorias).
///
/// No celular em pé continua com 3 colunas, como antes.
class GradeCapas extends StatelessWidget {
  const GradeCapas({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.proporcao,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Largura / altura de cada item (capa + nome).
  final double proporcao;

  static const margem = 12.0;
  static const espaco = 12.0;

  /// Folga acima e abaixo da fileira focada, maior que a borda de foco (3 px) e a sombra.
  static const folgaFoco = 16.0;

  /// Colunas para a largura [largura] e a altura visível [altura] da grade.
  static int colunas(double largura, double altura, double proporcao) {
    final w = largura - 2 * margem;
    var cols = math.max(3, (w / 170).floor());
    if (!altura.isFinite) return cols;
    final visivel = altura - 2 * margem - 2 * folgaFoco;
    double alturaDoItem(int n) => ((w - (n - 1) * espaco) / n) / proporcao;
    while (cols < 12 && alturaDoItem(cols) > visivel) {
      cols++;
    }
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = colunas(box.maxWidth, box.maxHeight, proporcao);
      return GridView.builder(
        padding: const EdgeInsets.all(margem),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: proporcao,
          crossAxisSpacing: espaco,
          mainAxisSpacing: espaco,
        ),
        itemCount: itemCount,
        itemBuilder: (c, i) => RolarAoFocar(child: itemBuilder(c, i)),
      );
    });
  }
}

/// Quando algo dentro de [child] recebe o foco, rola as listas em volta para deixar o item
/// inteiro no meio da área visível (o padrão do Flutter deixa o item colado na borda, e a
/// borda de foco passava por cima das opções de cima).
class RolarAoFocar extends StatelessWidget {
  const RolarAoFocar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focado) {
        if (!focado || !context.mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      },
      child: child,
    );
  }
}
