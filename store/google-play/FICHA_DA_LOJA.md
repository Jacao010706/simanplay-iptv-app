# Ficha da loja (Google Play, pt-BR)

**Texto para colar: `FICHA_DA_LOJA_PARA_COLAR.md`** (cada campo do Console em ordem). Este
arquivo guarda as regras, a contagem e o porquê das escolhas.

## Contagem (conferida por script em 24/10/2026)
| Campo | Caracteres | Limite |
|---|---|---|
| Nome: `Sofae` | 5 | 30 |
| Descrição curta | 80 | 80 |
| Descrição completa | 1.454 | 4.000 |

Busca por termos proibidos na ficha (IPTV, grátis, Xtream, nomes de canais/emissoras/streamings,
futebol, PIX, preço, assinatura): **nenhum**.

## Regras seguidas
- Marca **Sofae**; nome só "Sofae" (sem "IPTV" nem "Player" no título).
- Deixa claro que é **player** e que o usuário usa a **lista do próprio provedor**; o app vem vazio.
- Sem prometer conteúdo, sem citar canais, times, filmes comerciais, emissoras ou streamings.
- Sem preço, PIX, plano, link de pagamento, "teste grátis" (o app da Play é só de consumo).
- Sem marcas de terceiros, exceto: **Android TV** (plataforma da própria Google, para dizer onde
  funciona) e **Blender Foundation** (crédito exigido pela licença Creative Commons dos filmes da
  demonstração).

## Revisado contra o app (variante `play`, branch `feature/sofae-release`)
| Rascunho anterior | Agora | Motivo |
|---|---|---|
| Nome "Sofae Player" | "Sofae" | pedido; igual ao nome do app no aparelho |
| "M3U e Xtream Codes" | "M3U e listas com servidor, usuário e senha" | "Xtream Codes" é marca de terceiro (e ligada a pirataria na revisão) |
| "Favoritos e continuar assistindo" | "Favoritos e busca" | não existe "continuar assistindo" no código |
| "Vários temas de tela" | removido | a Play usa só o tema Sofae; não há tela para trocar de tema |
| "Guia de programação (EPG)" | "guia de programação, quando a sua lista oferece" | existe (`epg_service.dart`), só para listas com servidor/usuário/senha |
| "anote o código (MAC)" | "mostra o código deste aparelho" | mais simples; o código é o MAC exibido |
| "ou digite você mesmo os dados" | "Com o acesso liberado, você também pode digitar…" | a entrada manual só funciona com o acesso do aparelho liberado |
| Crédito "Wikimedia Commons" | removido | a licença pede crédito aos autores (Blender), não ao servidor |
| — | "Sem anúncios e sem compras dentro do app." | verdade na variante `play` e coerente com o formulário de dados |

## Capturas de tela
Só com a **demonstração** (filmes da Blender, CC). Nada de logos de emissoras, pôsteres de filmes
comerciais ou escudos de times. Ver `capturas/LEIA-ME.md` e `graficos/LEIA-ME.md`.
