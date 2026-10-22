# Política de Privacidade do Sofae

> RASCUNHO para revisão. Não publicado. Substitui o texto de sofae.com.br/privacidade
> (versão de 12/10/2026) quando aprovado. Itens entre [colchetes] precisam ser preenchidos ou
> confirmados antes de publicar.

**Última atualização:** [data da publicação]

O Sofae é um **player de vídeo**: ele toca as listas de canais e filmes que você já tem, do seu
provedor ou digitadas por você. O Sofae não vende, não fornece e não escolhe nenhum conteúdo.

Esta página explica, sem juridiquês, quais dados o app usa, para quê, e o que você pode fazer
com eles.

## Quem cuida dos seus dados

- **Responsável:** Akitemtech, desenvolvedora do Sofae [CNPJ ou CPF, se for publicar]
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
  o seu acesso**. [Confirmar com o backend: a senha não é gravada em texto aberto no servidor.]
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
[Confirmar: não guardamos histórico do que foi assistido; o painel mostra só o momento atual.]

O aviso para quando você toca em **Sair** na conta. Se você usou uma conta do painel neste
aparelho e depois passou para uma lista própria (item 4), o aviso continua até você sair da
conta do painel.

## 4. Modo Livre: lista que você digita no app

Você pode usar o Sofae com uma lista sua, digitando no app o **servidor, o usuário e a senha**
(Xtream) ou um **link M3U**. Nesse caso:

- os dados da lista ficam **somente no seu aparelho**;
- o app conversa **direto** com o servidor da lista que você digitou;
- **nada disso é enviado para o nosso servidor**: nem o endereço, nem o usuário, nem a senha,
  nem os canais da lista;
- quem recebe esses dados é o servidor do **seu provedor**, que tem a política de privacidade
  dele.

Mesmo no Modo Livre, o app continua usando o código do aparelho do item 1 para liberar o acesso.

## 5. Listas cadastradas pelo site (MAC e chave)

Se você ou o seu provedor cadastrou listas para o MAC do aparelho no nosso site, o app baixa
essas listas do nosso servidor (nome, servidor, usuário e senha, ou link M3U). Elas ficam
guardadas no servidor para aparecer no app, e você pode apagá-las no próprio site de cadastro.

## 6. Endereço IP

Toda conexão com a internet mostra o seu endereço IP. O nosso servidor usa o IP para
**segurança** e para estimar a **cidade aproximada** da conexão. Não usamos localização precisa
(GPS). [Confirmar se o revendedor vê a cidade no painel.]

## 7. Lista de demonstração (versão Google Play)

O botão "Ver demonstração" toca filmes abertos da Blender Foundation (licença Creative Commons)
a partir do Wikimedia Commons. Nada é enviado ao nosso servidor por causa da demonstração; os
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
- **No servidor:** o código de acesso vale até 30 dias. Registro do aparelho e listas
  cadastradas: [prazo — por exemplo, enquanto o aparelho estiver ativo e até X meses depois do
  último acesso].

## 10. Seus direitos e como apagar seus dados

Você pode pedir para ver, corrigir ou apagar os seus dados. Mande um e-mail para
**akitemtech@gmail.com** com o **MAC que aparece no app**. Respondemos em até [15] dias.
As listas cadastradas pelo site também podem ser apagadas por lá.

## 11. Crianças

O Sofae não é feito para menores de 13 anos e não coleta de propósito dados de crianças.

## 12. Segurança

A conexão com o nosso servidor é sempre criptografada (HTTPS). Algumas listas de provedores usam
conexão sem criptografia (HTTP); nesse caso, a conversa é entre o seu aparelho e o servidor do
provedor, não com o nosso.

## 13. Mudanças nesta política

Quando mudarmos algo importante, atualizamos esta página e a data lá em cima.
