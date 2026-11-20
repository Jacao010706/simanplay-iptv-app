import 'package:flutter/material.dart';

/// Janela de detalhes (Filmes, Canais) que cabe inteira na TV (1920x1080, 1280x720,
/// densidade 1.5, texto ampliado):
///
/// - centralizada, com margem de 5% da tela de cada lado e no máximo 760 de largura;
/// - [conteudo] rola por dentro quando não cabe;
/// - [rodape] (o botão "Assistir" e afins) fica fixo embaixo, fora da rolagem, sempre
///   visível. Quem monta o rodapé põe `autofocus: true` no "Assistir".
class JanelaDetalhes extends StatelessWidget {
  const JanelaDetalhes({
    super.key,
    required this.conteudo,
    required this.rodape,
    this.paddingRodape = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  static const larguraMaxima = 760.0;
  static const fundo = Color(0xFF1a1625);

  final Widget conteudo;
  final Widget rodape;
  final EdgeInsetsGeometry paddingRodape;

  /// Margem em volta da janela: 5% da tela de cada lado.
  static EdgeInsets margem(Size tela) =>
      EdgeInsets.symmetric(horizontal: tela.width * 0.05, vertical: tela.height * 0.05);

  /// Altura disponível para a janela (tela menos as margens).
  static double alturaUtil(Size tela) => tela.height - margem(tela).vertical;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: fundo,
      insetPadding: margem(MediaQuery.sizeOf(context)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: larguraMaxima),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(child: SingleChildScrollView(child: conteudo)),
          // Fora da rolagem: sempre visível e com o foco do controle remoto
          Padding(padding: paddingRodape, child: rodape),
        ]),
      ),
    );
  }
}
