# Rascunho: classificação de conteúdo, público-alvo e declarações (Play Console)

RASCUNHO. Não enviado.

## 1. Classificação de conteúdo (questionário IARC)
Categoria do app: **"Todos os outros tipos de app"** (não é jogo, nem rede social, nem notícias).

| Pergunta (resumo) | Resposta proposta | Motivo |
|---|---|---|
| Violência, sexo, linguagem, drogas, terror no próprio app | Não | O app não traz conteúdo; só telas de menu |
| Os usuários interagem ou trocam conteúdo entre si? | Não | Sem chat, comentários ou perfis |
| Compartilha a localização do usuário com outros usuários? | Não | |
| Permite compras digitais? | Não (variante `play`) | Sem compra no app |
| Acesso irrestrito à internet / conteúdo de fontes externas não moderadas? | **Sim** | O app reproduz qualquer URL de lista que o provedor/usuário configurar. Responder com honestidade: isso pode subir a classificação |
| Jogos de azar | Não | |

Resultado esperado: classificação baixa pelo conteúdo do app, possivelmente com o aviso de
"acesso irrestrito à internet". **Não confirmado** qual faixa a ClassInd/IARC vai atribuir.

## 2. Público-alvo
**18 anos ou mais** (só adultos). Evita a política de Famílias e é coerente com listas de terceiros
que podem ter conteúdo adulto. Não marcar "pode atrair crianças".

## 3. Declaração "app de player" (texto para Notas ao revisor / Acesso ao app)

> O Sofae é exclusivamente um reprodutor de mídia. O app não contém, hospeda, vende, indexa nem
> recomenda nenhum conteúdo de vídeo, canal, filme ou série, e não fornece listas. O usuário
> reproduz apenas listas (M3U/Xtream) que recebe do próprio provedor, que é responsável pelo
> conteúdo e pelas licenças. O app não tem compras nem links de pagamento. Atualizações são
> feitas somente pela Google Play.
>
> Para revisar sem lista própria: abra o app e toque em **"Ver demonstração (filmes livres,
> sem lista)"** na tela inicial. A demonstração tem 10 filmes abertos da Blender Foundation
> (Creative Commons, servidos pelo Wikimedia Commons) em Filmes e 3 canais de demonstração em
> TV ao Vivo. Nenhum login ou pagamento é necessário. O acesso de teste vale por 7 dias a partir
> da primeira abertura no aparelho.

O botão existe só na versão Play (`test/play_variante_test.dart`). **Atenção:** se o período
de teste do aparelho do revisor acabar, a tela de acesso bloqueia também a demonstração (ver o
relatório, decisão pendente).

## 4. Outras declarações do Console
| Declaração | Resposta proposta |
|---|---|
| Anúncios | Não contém anúncios |
| Acesso ao app | Restrito: fornecer instruções/lista de demonstração (item 3) |
| App de notícias / governo / financeiro / saúde | Não |
| ID de publicidade | Não usa (conferir no manifesto final: nenhuma lib de anúncios no `pubspec.yaml`) |
| Serviço em primeiro plano | **Não se aplica**: a versão Play não tem gravação; o serviço e as permissões `FOREGROUND_SERVICE*`, `WAKE_LOCK` e `POST_NOTIFICATIONS` saem do manifesto |
| Permissão de instalar pacotes | Não aplicável: removida na variante `play` |
