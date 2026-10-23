# Formulário "Segurança dos dados" (Play Console)

Respostas prontas, conferidas no código da variante `play` (branch `feature/sofae-release`) e do
backend em produção (`37dcd09`, Fase 1 de senhas no ar desde 22/10/2026). Política publicada:
`privacidade.html` (sofae.com.br/privacidade/android).

Definições da Play usadas: "coletado" = sai do aparelho para o nosso servidor; "compartilhado" =
vai para terceiro. Envio ao servidor IPTV que o próprio usuário cadastrou (ação dele, esperada)
não conta como compartilhamento.

## Visão geral

| Pergunta | Resposta proposta |
|---|---|
| O app coleta ou compartilha algum dos tipos de dados exigidos? | **Sim** |
| Todos os dados coletados são criptografados em trânsito? | **Sim** para o nosso servidor (`https://web-production-d8671.up.railway.app`). Observação: listas e vídeos do provedor podem ser `http`, mas vão direto do aparelho para o servidor que o usuário cadastrou, não para nós |
| O usuário pode pedir a exclusão dos dados? | **Sim**: e-mail para akitemtech@gmail.com com o MAC exibido no app (como diz a política). Recomendado: uma página própria, ex. sofae.com.br/excluir-dados |
| Conta criada dentro do app? | **Não** (o registro do aparelho é automático; contas de painel são criadas pelo revendedor fora do app). Se a Play entender o registro do aparelho como conta, passa a exigir link de exclusão de conta |

## Tipos de dados

| Tipo (categoria da Play) | O que é no app | Onde no código | Coletado | Compartilhado | Obrigatório? | Finalidades |
|---|---|---|---|---|---|---|
| **IDs do dispositivo ou outros IDs** | Android ID (`hw_id`) no registro da licença; MAC/código do aparelho; ID aleatório `and-xxxx` do "assistindo" | `license_service.dart` `_register`; `assistindo_service.dart` | Sim | **Sim** (revendedor vê o MAC) | Sim | Funcionalidade do app; Prevenção de fraudes e segurança |
| **Informações pessoais > IDs de usuário** | Usuário do painel (login usuário/senha) | `api_service.dart` `/app/login` | Sim | Sim (revendedor vê a conta) | Não (só quem entra com conta de painel) | Funcionalidade do app; Gerenciamento da conta |
| **Atividade no app > Interações no app** | Tipo e nome do conteúdo tocando (canal/filme/série), a cada 30 s no vídeo e 60 s no menu | `assistindo_service.dart` `/app/tv/assistindo` | Sim | **Sim** (revendedor vê "assistindo agora") | Sim para contas de painel | Funcionalidade do app; Prevenção de fraudes e segurança (compartilhamento de conta) |
| **Local > Local aproximado** | Cidade estimada pelo IP no servidor (a política declara) | servidor | Sim | **Sim**: o revendedor vê a cidade e o começo do IP (`online.py:232-233`) | Sim para contas de painel (só no "assistindo agora") | Funcionalidade do app; Prevenção de fraudes e segurança |

Senha do painel: vai ao servidor só para autenticar (`/app/login`). O app guarda no aparelho o
token e também usuário e senha, na sessão local (`activation_screen_v3.dart` → `buildSession`
→ `SharedPreferences`), para reabrir a conta; saem ao tocar em Sair. Não é
uma categoria própria no formulário; fica coberta por "IDs de usuário" + criptografia em trânsito.
**Backend (Fase 1 no ar desde 22/10/2026):** a senha é conferida por hash bcrypt (`clients.password_hash`), com limite de tentativas (20 por usuário / 30 por IP em 15 min → 429) e mascarada nos logs (`***`). A cópia em texto puro **ainda existe** (o painel mostra; sai na Fase 2), e a política diz isso. O formulário não pergunta sobre isso.

Android ID: o servidor guarda só um hash SHA-256 com segredo (`licenses.py:85-87`). Na Play continua sendo "IDs do dispositivo" (ele é enviado).

**Modo Livre** (lista digitada no app): servidor, usuário, senha e link M3U ficam só no aparelho
e vão direto para o servidor do provedor; não são coletados por nós. **Lista de demonstração:**
não envia nada ao nosso servidor.

Não coletado pela variante `play`: nome, e-mail, telefone, endereço, pagamentos (sem PIX/Mercado
Pago no app), contatos, fotos, áudio, arquivos, calendário, saúde, localização precisa,
histórico de navegação, registros de falha, diagnósticos, anúncios.

Dados que **ficam só no aparelho** (não declaram): listas em cache, listas do Modo Livre,
favoritos, sessão do painel (usuário e senha, para reabrir), tema escolhido. A versão Play não tem
gravação.

## Política de privacidade
Os 5 ajustes apontados no rascunho (Android ID, 30 s / 60 s, senha só para autenticar, retenção,
pagamento fora do app) estão na versão final `privacidade.html`, junto com a Fase 1 (bcrypt,
limite de tentativas, senha mascarada nos registros).
