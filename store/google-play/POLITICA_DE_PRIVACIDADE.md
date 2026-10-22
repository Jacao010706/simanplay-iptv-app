# Política de Privacidade do Sofae

> RASCUNHO para revisão. Não publicado. Substitui o texto de sofae.com.br/privacidade
> (versão de 12/10/2026) quando aprovado. Os itens entre [colchetes] dependem do Jacques.
> O resto foi conferido no código do app e do backend em 22/10/2026 (commit `06adf16` do
> backend). Atenção: o item 2 descreve como a senha é guardada **hoje**. Se a correção
> proposta no relatório entrar antes da publicação, o texto do item 2 muda.

**Última atualização:** [data da publicação]

O Sofae é um **player de vídeo**: ele toca as listas de canais e filmes que você já tem, do seu
provedor ou digitadas por você. O Sofae não vende, não fornece e não escolhe nenhum conteúdo.

Esta página explica, sem juridiquês, quais dados o app usa, para quê, e o que você pode fazer
com eles.

## Quem cuida dos seus dados

- **Responsável:** [seu nome completo], pessoa física, responsável pelo Sofae (Akitemtech)
- **Contato:** akitemtech@gmail.com
- Seguimos a Lei Geral de Proteção de Dados (LGPD, Lei 13.709/2018).

## Resumo em 30 segundos

- O app manda ao nosso servidor um **código do aparelho** para liberar o acesso.
- Se você entrar com **usuário e senha do painel**, o app avisa o painel **o que está tocando**
  (a cada 30 segundos durante o vídeo) enquanto ele estiver aberto.
- No **Modo Livre** (lista que você mesmo digita no app), **os dados da lista ficam só no seu
  aparelho** e nunca são enviados para nós.
- Não vendemos dados. Não há anúncios nem rastreadores de terceiros. O app não usa GPS, câmera,
  microfone, contatos nem suas fotos.

## 1. Código do aparelho (sempre)

Quando você abre o app pela primeira vez, ele se registra no nosso servidor para liberar o uso
neste aparelho. Para isso envia:

- o **Android ID**, um código que o próprio Android cria para este app neste aparelho. Ele não
  é o seu número de telefone, nem o seu e-mail, nem o IMEI;
- o tipo de aparelho (por exemplo, "android") e a versão do app.

No nosso servidor, o Android ID **não fica guardado como é**: guardamos só um código derivado
dele (um *hash* com chave secreta), que serve para reconhecer o mesmo aparelho e não pode ser
transformado de volta no Android ID.

O servidor devolve o **MAC e a chave do aparelho** que aparecem na tela. Depois disso o app
consulta o servidor de tempos em tempos para saber se o acesso continua liberado.

**Para quê:** liberar e controlar o acesso deste aparelho e evitar abuso (por exemplo, o mesmo
aparelho tentando se passar por vários).

Na versão baixada pelo site (fora da Google Play), o app também pergunta ao servidor se existe
versão nova. Essa consulta envia só o nome do pacote do app e o revendedor, sem dados seus. Na
versão da Google Play quem atualiza é a própria loja.

## 2. Login com usuário e senha do painel (só se você usar)

Se o seu provedor te deu um usuário e uma senha do nosso painel e você entra com eles:

- O app envia usuário e senha ao nosso servidor, por conexão segura (HTTPS), **só para conferir
  o seu acesso**.
- A sua senha é criada pelo seu provedor e fica guardada no nosso servidor de um jeito que o
  **seu provedor consegue vê-la no painel**, para poder reenviar os seus dados de acesso.
- O servidor responde com os dados da sua lista e um **código de acesso temporário** (vale até
  30 dias, ou até a senha ser trocada ou o plano vencer).
- O usuário e a senha ficam **guardados no seu aparelho**, para o app abrir direto da próxima
  vez. Eles saem do aparelho quando você toca em **Sair** ou desinstala o app.

## 3. "Assistindo agora" (só para quem entrou com o painel)

Enquanto o app está aberto com uma conta do painel, ele avisa o painel:

- **a cada 30 segundos** durante um vídeo, e **a cada 60 segundos** nos menus;
- o que é avisado: o **tipo** (canal, filme, série ou menu), o **nome** do que está tocando,
  "Android" e um código aleatório deste aparelho.

**Quem vê:** você não aparece para outros usuários. Quem vê é o **seu provedor (revendedor)** e
a administração do painel. Isso serve para mostrar quem está conectado e para o provedor
encerrar uma conexão em caso de uso indevido (por exemplo, conta compartilhada).
**Não guardamos histórico do que foi assistido.** Essa informação fica só na memória do servidor
e some 3 minutos depois do último aviso (ou quando o servidor reinicia). O painel mostra só o
que está tocando agora.

O aviso para quando você toca em **Sair** na conta. Ele também para **na hora** em que você
abre uma lista própria (item 4), uma lista cadastrada pelo site (item 5) ou a demonstração
(item 7). Nesse momento, o app esquece o código de acesso do painel. Para voltar a usar a conta
do painel, basta entrar de novo com usuário e senha.

## 4. Modo Livre: lista que você digita no app

Você pode usar o Sofae com uma lista sua, digitando no app o **servidor, o usuário e a senha**
(Xtream) ou um **link M3U**. Nesse caso:

- os dados da lista ficam **somente no seu aparelho**;
- o app conversa **direto** com o servidor da lista que você digitou;
- **nada disso é enviado para o nosso servidor**: nem o endereço, nem o usuário, nem a senha,
  nem os canais da lista;
- quem recebe esses dados é o servidor do **seu provedor**, que tem a política de privacidade
  dele;
- enquanto você usa a lista própria, o app **não avisa o painel** o que você está assistindo
  (item 3).

Mesmo no Modo Livre, o app continua usando o código do aparelho do item 1 para liberar o acesso.

## 5. Listas cadastradas pelo site (MAC e chave)

Se você ou o seu provedor cadastrou listas para o MAC do aparelho no nosso site, o app baixa
essas listas do nosso servidor (nome, servidor, usuário e senha, ou link M3U). Elas ficam
guardadas no servidor para aparecer no app, e você pode apagá-las no próprio site de cadastro.

## 6. Endereço IP

Toda conexão com a internet mostra o seu endereço IP. O nosso servidor usa o IP para
**segurança** (por exemplo, limitar tentativas de senha erradas) e, no "assistindo agora"
(item 3), para estimar a **cidade aproximada** da conexão. Não usamos localização precisa (GPS).

No "assistindo agora", o **seu provedor** vê a cidade aproximada e só o começo do seu IP (por
exemplo, `189.40.x.x`); a administração do Sofae vê o IP completo. Isso também fica só na
memória do servidor e some 3 minutos depois do último aviso: o IP não é gravado no banco de
dados.

A empresa que hospeda o nosso servidor registra, como qualquer site, o horário e o endereço de
cada acesso (registros técnicos). Esses registros ficam com ela por [prazo dos registros do
Railway, conforme o plano contratado].

## 7. Lista de demonstração (versão Google Play)

O botão "Ver demonstração" toca filmes abertos da Blender Foundation (licença Creative Commons)
a partir do Wikimedia Commons. Ele funciona mesmo sem acesso liberado. Nada é enviado ao nosso servidor por causa da demonstração; os
servidores do Wikimedia Commons recebem o seu IP, como em qualquer vídeo da internet.

## 8. Com quem compartilhamos

- **Seu provedor (revendedor):** vê o MAC e a conta do aparelho e, para contas do painel, o
  "assistindo agora" (item 3).
- **Hospedagem do nosso servidor:** guarda os dados para nós, sem uso próprio.
- **Pagamentos:** feitos fora do app, no site, pelo Mercado Pago. O app da Google Play não
  processa pagamentos.
- Não vendemos nem alugamos dados para ninguém.

## 9. Por quanto tempo guardamos

- **No aparelho:** até você sair da conta, apagar os dados do app ou desinstalá-lo.
- **No servidor:**
  - o código de acesso do login vale até 30 dias e não fica guardado (é conferido por
    assinatura);
  - o "assistindo agora", o IP e a cidade ficam só na memória e somem em 3 minutos;
  - o registro do aparelho (MAC, chave, código derivado do Android ID, tipo de aparelho, versão
    do app e datas de início e último acesso), as listas cadastradas no site e a conta do painel
    **não são apagados automaticamente**. Eles ficam guardados até serem apagados por você (as
    listas, no site), pelo seu provedor (a conta do painel) ou a seu pedido (item 10).

## 10. Seus direitos e como apagar seus dados

Você pode pedir para ver, corrigir ou apagar os seus dados. Mande um e-mail para
**akitemtech@gmail.com** com o **MAC que aparece no app**. Respondemos em até 15 dias, prazo da
LGPD (art. 19).
As listas cadastradas pelo site também podem ser apagadas por lá.

## 11. Crianças

O Sofae não é feito para menores de 13 anos e não coleta de propósito dados de crianças.

## 12. Segurança

A conexão com o nosso servidor é sempre criptografada (HTTPS). Algumas listas de provedores usam
conexão sem criptografia (HTTP); nesse caso, a conversa é entre o seu aparelho e o servidor do
provedor, não com o nosso.

## 13. Mudanças nesta política

Quando mudarmos algo importante, atualizamos esta página e a data lá em cima.
