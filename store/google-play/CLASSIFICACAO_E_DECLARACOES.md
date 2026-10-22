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
> Para revisar: [instruções de acesso + MAC liberado/lista de demonstração com conteúdo de
> domínio público — PREENCHER]. Nenhum login é necessário além disso.

Revisores precisam conseguir usar o app. Sem uma lista de demonstração legal liberada, a revisão
tende a recusar por "Acesso ao app" ou "funcionalidade mínima".

## 4. Outras declarações do Console
| Declaração | Resposta proposta |
|---|---|
| Anúncios | Não contém anúncios |
| Acesso ao app | Restrito: fornecer instruções/lista de demonstração (item 3) |
| App de notícias / governo / financeiro / saúde | Não |
| ID de publicidade | Não usa (conferir no manifesto final: nenhuma lib de anúncios no `pubspec.yaml`) |
| Serviço em primeiro plano (`dataSync`) | **Precisa declarar** se a gravação ficar na versão Play: descrição, impacto, use case "Upload or download (network transfer)" e **link de vídeo** mostrando o usuário iniciando a gravação. Ver risco no relatório: a política de PI cita gravação/cópia local |
| Permissão de instalar pacotes | Não aplicável: removida na variante `play` |
