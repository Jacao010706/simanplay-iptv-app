# Rascunho: formulário "Segurança dos dados" (Play Console)

RASCUNHO. Não enviado. Feito a partir do código da variante `play` (branch `feature/play-store`)
e da política em sofae.com.br/privacidade (atualizada em 12/10/2026). O que o servidor guarda e
por quanto tempo **não foi conferido** (backend fora do escopo): confirme antes de enviar.

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
| **Local > Local aproximado** | Cidade estimada pelo IP no servidor (a política declara) | servidor | Sim | Sim, se o revendedor vê a cidade (**confirmar no painel**) | Sim | Prevenção de fraudes e segurança |

Senha do painel: vai ao servidor só para autenticar (`/app/login`) e o app guarda o token. Não é
uma categoria própria no formulário; fica coberta por "IDs de usuário" + criptografia em trânsito.
**Confirmar** que o servidor não grava a senha em texto puro.

Não coletado pela variante `play`: nome, e-mail, telefone, endereço, pagamentos (sem PIX/Mercado
Pago no app), contatos, fotos, áudio, arquivos, calendário, saúde, localização precisa,
histórico de navegação, registros de falha, diagnósticos, anúncios.

Dados que **ficam só no aparelho** (não declaram): listas em cache, favoritos, gravações
(pasta interna do app), tema escolhido.

## Ajustes na política de privacidade antes de enviar
1. Citar o **Android ID** (identificador do sistema) enviado no registro da licença; hoje a
   política só fala do MAC.
2. Frequência do "assistindo": o código envia a cada **30 s** durante o vídeo e **60 s** no menu
   (a política diz "a cada minuto").
3. Dizer que a senha do painel trafega para o servidor no login (só para autenticar).
4. Informar prazo de retenção no servidor e, de preferência, CNPJ/endereço do controlador.
5. Para a versão Play, a menção ao Mercado Pago/PIX pode ficar (é sobre o serviço), mas o app da
   Play não processa pagamento.
