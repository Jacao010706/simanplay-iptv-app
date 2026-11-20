import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/modo_tv.dart';

/// Grade de capas (Filmes, Séries) que funciona com o controle remoto da TV:
///
/// - capas em pôster 2:3 com o nome embaixo, numa linha só;
/// - na TV, 7 colunas; no celular em pé, 4; no celular deitado e no tablet, as colunas saem da
///   largura (capa com ~[larguraMinima] de largura);
/// - uma fileira sempre cabe inteira na área visível da grade (com a tela baixa, a grade ganha
///   mais colunas em vez de capas mais altas que a própria área);
/// - entre as fileiras sobra espaço para a borda de foco ([FocusRing]);
/// - ao receber o foco, o item rola para o meio da grade, longe da fileira de cima e das
///   opções acima da grade (busca e categorias).
class GradeCapas extends StatelessWidget {
  const GradeCapas({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;

  /// Cada item: [Expanded] com a capa e, embaixo, [GradeCapas.titulo].
  final IndexedWidgetBuilder itemBuilder;

  static const margem = 12.0;
  static const espaco = 12.0;

  /// Folga acima e abaixo da fileira focada, maior que a borda de foco (3 px) e a sombra.
  static const folgaFoco = 16.0;

  /// Capa em pôster: altura = largura × 1,5 (2:3).
  static const alturaPorLargura = 1.5;

  /// Colunas na TV e mínimo de colunas fora dela.
  static const colunasTv = 7;
  static const colunasMin = 4;

  /// Fora da TV: largura mínima da capa, em pixels lógicos.
  static const larguraMinima = 110.0;

  /// Nome embaixo da capa.
  static const fonteTitulo = 10.0;
  static const _alturaLinha = 1.25;
  static const _espacoTitulo = 4.0;

  /// Altura da faixa do nome (espaço + uma linha) com a escala de texto [texto].
  static double alturaTitulo(TextScaler texto) =>
      _espacoTitulo + texto.scale(fonteTitulo) * _alturaLinha + 2;

  /// Nome do item embaixo da capa: uma linha, com reticências.
  static Widget titulo(String nome) => Padding(
        padding: const EdgeInsets.only(top: _espacoTitulo),
        child: Text(nome,
            style: const TextStyle(color: Colors.white, fontSize: fonteTitulo, height: _alturaLinha),
            maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
      );

  /// Altura de um item (capa + nome) com [n] colunas na largura útil [w].
  static double alturaDoItem(double w, int n, double legenda) =>
      ((w - (n - 1) * espaco) / n) * alturaPorLargura + legenda;

  /// Colunas para a largura [largura] e a altura visível [altura] da grade.
  static int colunas(double largura, double altura, {required bool tv, double legenda = 0}) {
    final w = largura - 2 * margem;
    var cols = tv ? colunasTv : math.max(colunasMin, ((w + espaco) / (larguraMinima + espaco)).floor());
    if (!altura.isFinite) return cols;
    final visivel = altura - 2 * margem - 2 * folgaFoco;
    while (cols < 16 && alturaDoItem(w, cols, legenda) > visivel) {
      cols++;
    }
    return cols;
  }

  @override
  Widget build(BuildContext context) {
    final legenda = alturaTitulo(MediaQuery.textScalerOf(context));
    return LayoutBuilder(builder: (context, box) {
      final cols = colunas(box.maxWidth, box.maxHeight, tv: ModoTv.tv, legenda: legenda);
      return GridView.builder(
        padding: const EdgeInsets.all(margem),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: alturaDoItem(box.maxWidth - 2 * margem, cols, legenda),
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
